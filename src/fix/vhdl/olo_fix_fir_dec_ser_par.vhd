---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a decimating FIR filter. It supports multiple channels that are processed
-- in parallel (all channel samples arrive in the same clock cycle, concatenated into one wide
-- vector). All channels share the same coefficient set. The filter taps are computed serially
-- (one tap per clock cycle) using one multiplier per channel.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_fir_dec_ser_par.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_array.all;
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_fix_fir_dec_ser_par is
    generic (
        -- Formats
        InFmt_g           : string;
        OutFmt_g          : string;
        CoefFmt_g         : string;
        -- Filter parameters
        Channels_g        : positive;
        MaxRatio_g        : positive;
        MaxTaps_g         : positive;
        RuntimeCfg_g      : boolean  := false;
        -- Arithmetic
        GuardBits_g       : natural  := 1;
        Round_g           : string   := FixRound_Trunc_c;
        Saturate_g        : string   := FixSaturate_Warn_c;
        MultRegs_g        : positive := 1;
        -- Coefficient storage
        CoefInit_g        : string   := "0.0";
        CoefStorageType_g : string   := "ROM";
        CoefRamReadback_g : boolean  := false;
        CoefRamBehavior_g : string   := "RBW";
        CoefMemStyle_g    : string   := "auto";
        -- Data RAM
        DataRamBehavior_g : string   := "RBW";
        DataMemStyle_g    : string   := "auto"
    );
    port (
        -- Control Ports
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        -- Runtime Config (only change during Rst = '1')
        Cfg_Ratio    : in    std_logic_vector(log2Ceil(MaxRatio_g) - 1 downto 0)             := toUslv(MaxRatio_g - 1, log2Ceil(MaxRatio_g));
        Cfg_Taps     : in    std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := toUslv(MaxTaps_g - 1, log2Ceil(MaxTaps_g));
        -- Coefficient Config Port
        Coef_Addr    : in    std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := (others => '0');
        Coef_WrEna   : in    std_logic                                                       := '0';
        Coef_WrData  : in    std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
        Coef_RdEna   : in    std_logic                                                       := '0';
        Coef_RdData  : out   std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
        Coef_RdValid : out   std_logic;
        -- Input (all channels concatenated, channel 0 in the LSBs)
        In_Valid     : in    std_logic;
        In_Data      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) * Channels_g - 1 downto 0);
        -- Output (all channels concatenated, channel 0 in the LSBs)
        Out_Valid    : out   std_logic;
        Out_Data     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) * Channels_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_fir_dec_ser_par is

    -- *** Entity Name ***
    constant EntityName_c : string := "olo_fix_fir_dec_ser_par";

    -- *** Formats ***
    constant InFmt_c   : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c  : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant CoefFmt_c : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant MultFmt_c : FixFormat_t := cl_fix_mult_fmt(InFmt_c, CoefFmt_c);
    constant AccuFmt_c : FixFormat_t := (1, OutFmt_c.I + GuardBits_g, MultFmt_c.F);

    -- *** Port Widths ***
    constant InWidth_c  : natural := fixFmtWidthFromString(InFmt_g);
    constant OutWidth_c : natural := fixFmtWidthFromString(OutFmt_g);

    -- *** Pipeline Stage Constant ***
    constant AccuStage_c : natural := 4 + MultRegs_g;

    -- *** Memory Sizing ***
    constant DataMemDepthReq_c : natural := MaxTaps_g + MaxRatio_g;
    constant DataMemAddrBits_c : natural := log2Ceil(DataMemDepthReq_c);
    constant DataMemDepth_c    : natural := 2 ** DataMemAddrBits_c;
    constant CoefMemDepth_c    : natural := 2 ** log2Ceil(MaxTaps_g);

    -- *** Types ***
    subtype InData_t   is std_logic_vector(InWidth_c - 1 downto 0);
    subtype CoefData_t is std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
    subtype MultData_t is std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    subtype AccuData_t is std_logic_vector(cl_fix_width(AccuFmt_c) - 1 downto 0);
    subtype OutData_t  is std_logic_vector(OutWidth_c - 1 downto 0);
    subtype InWide_t   is std_logic_vector(InWidth_c * Channels_g - 1 downto 0);

    type InWide_a  is array (natural range <>) of InWide_t;
    type ChVec_t   is array (0 to Channels_g - 1) of InData_t;
    type AccuVec_t is array (0 to Channels_g - 1) of AccuData_t;
    type MultVec_t is array (0 to Channels_g - 1) of MultData_t;
    type OutVec_t  is array (0 to Channels_g - 1) of OutData_t;

    -- *** Two Process Record ***
    type TwoProcess_r is record
        -- Stage 0
        Vld          : std_logic_vector(0 to 1);
        InSig        : InWide_a(0 to 1);
        -- Stage 1 state
        TapWrAddr    : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        Tap0Addr     : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        DecCnt       : std_logic_vector(log2Ceil(MaxRatio_g) - 1 downto 0);
        TapCnt       : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0);
        -- Stage 2 state
        TapRdAddr_2  : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        CoefRdAddr_2 : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0);
        -- Pipeline control
        CalcOn       : std_logic_vector(1 to AccuStage_c);
        Last         : std_logic_vector(1 to AccuStage_c);
        First        : std_logic_vector(1 to AccuStage_c);
        -- Stage 3 state
        FirstTapLoop : std_logic;
        TapRdAddr_3  : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        ReplaceZero  : std_logic;
        -- Stage 4: multiplier inputs
        MultInTap    : ChVec_t;
        MultInCoef   : CoefData_t;
        -- Accumulator
        Accu         : AccuVec_t;
        AccuValid    : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Component Connection Signals ***
    signal DataRamDout_3  : InWide_t;
    signal CoefRamDout_3  : CoefData_t;
    signal MultOut_Data   : MultVec_t;
    signal ResizeData     : OutVec_t;
    signal ResizeValidVec : std_logic_vector(0 to Channels_g - 1);
    signal ResizeValid    : std_logic;

    -- *** Runtime Config Signals ***
    signal Cfg_Taps_I  : std_logic_vector(Cfg_Taps'range);
    signal Cfg_Ratio_I : std_logic_vector(Cfg_Ratio'range);

begin

    -- Runtime configurability
    Cfg_Taps_I  <= Cfg_Taps when RuntimeCfg_g else toUslv(MaxTaps_g - 1, Cfg_Taps_I'length);
    Cfg_Ratio_I <= Cfg_Ratio when RuntimeCfg_g else toUslv(MaxRatio_g - 1, Cfg_Ratio_I'length);

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    assert MaxRatio_g >= 2
        report errorMessage(EntityName_c, "MaxRatio_g must be >= 2.")
        severity error;
    assert MaxTaps_g >= 2
        report errorMessage(EntityName_c, "MaxTaps_g must be >= 2.")
        severity error;
    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v        : TwoProcess_r;
        variable AccuIn_v : AccuData_t;
    begin
        v := r;

        -- *** Pipe Handling ***
        v.Vld(1)                   := r.Vld(0);
        v.InSig(1)                 := r.InSig(0);
        v.CalcOn(2 to AccuStage_c) := r.CalcOn(1 to AccuStage_c - 1);
        v.Last(2 to AccuStage_c)   := r.Last(1 to AccuStage_c - 1);
        v.First(2 to AccuStage_c)  := r.First(1 to AccuStage_c - 1);

        -- *** Stage 0: Input Register ***
        v.Vld(0)   := In_Valid;
        v.InSig(0) := In_Data;

        -- *** Stage 1: Data RAM Write, Decimation & Calculation Control ***
        -- Advance tap write address when a new sample set was written
        if r.Vld(1) = '1' then
            v.TapWrAddr := std_logic_vector(unsigned(r.TapWrAddr) + 1);
        end if;

        -- Tap count decrement (guarded so it idles at zero)
        v.First(1) := '0';
        v.Last(1)  := '0';
        if unsigned(r.TapCnt) /= 0 then
            v.TapCnt := std_logic_vector(unsigned(r.TapCnt) - 1);
        else
            v.CalcOn(1) := '0';
        end if;

        -- Last tap of the calculation
        if unsigned(r.TapCnt) = 1 or unsigned(Cfg_Taps_I) = 0 then
            v.Last(1) := '1';
        end if;

        -- Start new calculation when a sample set arrives and the decimation phase elapsed
        if r.Vld(0) = '1' then
            if unsigned(r.DecCnt) = 0 then
                v.Tap0Addr  := r.TapWrAddr;
                v.TapCnt    := Cfg_Taps_I;
                v.CalcOn(1) := '1';
                v.First(1)  := '1';
                v.DecCnt    := Cfg_Ratio_I;
            else
                v.DecCnt := std_logic_vector(unsigned(r.DecCnt) - 1);
            end if;
        end if;

        -- *** Stage 2: Address Calculation ***
        v.TapRdAddr_2  := std_logic_vector(unsigned(r.Tap0Addr) - unsigned(r.TapCnt));
        v.CoefRdAddr_2 := r.TapCnt;

        -- *** Stage 3: Pipeline TapRdAddr (RAM data arrives next cycle) ***
        v.TapRdAddr_3 := r.TapRdAddr_2;

        -- *** Stage 4: Multiplier Input MUX with ReplaceZero ***
        -- Replace unwritten RAM locations with zeros for bit-trueness at startup
        for i in 0 to Channels_g - 1 loop
            if r.ReplaceZero = '0' or unsigned(r.TapRdAddr_3) <= unsigned(Cfg_Ratio_I) then
                v.MultInTap(i) := DataRamDout_3(InWidth_c * (i + 1) - 1 downto InWidth_c * i);
            else
                v.MultInTap(i) := (others => '0');
            end if;
        end loop;

        -- Track when zero-replacement can be disabled
        if r.FirstTapLoop = '0' then
            v.ReplaceZero := '0';
        elsif r.CalcOn(3) = '1' then
            if r.First(3) = '1' and unsigned(r.TapRdAddr_3) <= unsigned(Cfg_Ratio_I) then
                v.ReplaceZero  := '0';
                v.FirstTapLoop := '0';
            elsif r.Last(3) = '1' then
                v.ReplaceZero := '1';
            elsif unsigned(r.TapRdAddr_3) = 0 then
                v.ReplaceZero := '0';
            end if;
        end if;

        v.MultInCoef := CoefRamDout_3;

        -- *** Stage AccuStage_c: Accumulate (one accumulator per channel) ***
        for i in 0 to Channels_g - 1 loop
            if r.First(AccuStage_c) = '1' then
                AccuIn_v := (others => '0');
            else
                AccuIn_v := r.Accu(i);
            end if;
            v.Accu(i) := cl_fix_add(MultOut_Data(i), MultFmt_c,
                                    AccuIn_v, AccuFmt_c,
                                    AccuFmt_c, Trunc_s, None_s);
        end loop;

        -- Capture when the last tap of the calculation is done
        v.AccuValid := r.Last(AccuStage_c) and r.CalcOn(AccuStage_c);

        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Output Assignment
    -----------------------------------------------------------------------------------------------
    -- All channel resize instances share the same timing, channel 0 provides the valid
    ResizeValid <= ResizeValidVec(0);
    Out_Valid   <= ResizeValid;

    g_out : for i in 0 to Channels_g - 1 generate
        Out_Data(OutWidth_c * (i + 1) - 1 downto OutWidth_c * i) <= ResizeData(i);
    end generate;

    -----------------------------------------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Vld          <= (others => '0');
                r.TapWrAddr    <= (others => '0');
                r.DecCnt       <= (others => '0');
                r.TapCnt       <= (others => '0');
                r.CalcOn       <= (others => '0');
                r.Last         <= (others => '0');
                r.First        <= (others => '0');
                r.AccuValid    <= '0';
                r.ReplaceZero  <= '1';
                r.FirstTapLoop <= '1';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Configuration Assertions
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    p_assert_cfg : process (Clk) is
    begin
        if rising_edge(Clk) then
            if Rst = '0' and In_Valid = '1' then
                assert unsigned(Cfg_Taps) >= 1 or RuntimeCfg_g = false
                    report errorMessage(EntityName_c, "Cfg_Taps must be >= 1 (1 tap filter is not supported)")
                    severity error;
            end if;
        end if;
    end process;

    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
    -- *** Coefficient Storage (shared by all channels) ***
    i_coef : entity work.olo_fix_coef_storage
        generic map (
            Depth_g       => CoefMemDepth_c,
            Fmt_g         => CoefFmt_g,
            Init_g        => CoefInit_g,
            StorageType_g => CoefStorageType_g,
            RamReadback_g => CoefRamReadback_g,
            RamBehavior_g => CoefRamBehavior_g,
            RdLatency_g   => 1,
            MemStyle_g    => CoefMemStyle_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            Cfg_Addr     => Coef_Addr,
            Cfg_WrEna    => Coef_WrEna,
            Cfg_WrData   => Coef_WrData,
            Cfg_RdEna    => Coef_RdEna,
            Cfg_RdData   => Coef_RdData,
            Cfg_RdValid  => Coef_RdValid,
            Coef_Addr    => r.CoefRdAddr_2,
            Coef_RdEna   => '1',
            Coef_RdData  => CoefRamDout_3,
            Coef_RdValid => open
        );

    -- *** Data RAM (Simple Dual Port, one wide word holding all channels) ***
    i_data_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g       => DataMemDepth_c,
            Width_g       => InWidth_c * Channels_g,
            RdLatency_g   => 1,
            RamStyle_g    => DataMemStyle_g,
            RamBehavior_g => DataRamBehavior_g
        )
        port map (
            Clk     => Clk,
            Rst     => Rst,
            Wr_Addr => r.TapWrAddr,
            Wr_Ena  => r.Vld(1),
            Wr_Data => r.InSig(1),
            Rd_Addr => r.TapRdAddr_2,
            Rd_Ena  => '1',
            Rd_Data => DataRamDout_3
        );

    -- *** Per-Channel Datapath: one multiplier and one output resize each ***
    g_channels : for i in 0 to Channels_g - 1 generate

        -- *** Multiplier ***
        i_mult : entity work.olo_fix_mult
            generic map (
                AFmt_g      => InFmt_g,
                BFmt_g      => CoefFmt_g,
                ResultFmt_g => to_string(MultFmt_c),
                Round_g     => FixRound_Trunc_c,
                Saturate_g  => FixSaturate_None_c,
                OpRegs_g    => MultRegs_g,
                RoundReg_g  => "NO",
                SatReg_g    => "NO"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.CalcOn(4),
                In_A       => r.MultInTap(i),
                In_B       => r.MultInCoef,
                Out_Valid  => open,
                Out_Result => MultOut_Data(i)
            );

        -- *** Output Resize (round + saturate accumulator to output format) ***
        i_resize : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(AccuFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => "YES",
                SatReg_g    => "YES"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.AccuValid,
                In_A       => r.Accu(i),
                Out_Valid  => ResizeValidVec(i),
                Out_Result => ResizeData(i)
            );

    end generate;

end architecture;
