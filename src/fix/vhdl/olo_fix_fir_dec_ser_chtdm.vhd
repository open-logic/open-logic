---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a decimating FIR filter. It supports multiple channels (time-division-
-- multiplexed). All channels share the same coefficient set. The filter taps are computed serially
-- (one tap per clock cycle) using a single multiplier.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_fir_dec_ser_chtdm.md
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
entity olo_fix_fir_dec_ser_chtdm is
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
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Runtime Config (only change during Rst = '1')
        Cfg_Ratio        : in    std_logic_vector(log2Ceil(MaxRatio_g) - 1 downto 0)             := toUslv(MaxRatio_g - 1, log2Ceil(MaxRatio_g));
        Cfg_Taps         : in    std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := toUslv(MaxTaps_g - 1, log2Ceil(MaxTaps_g));
        -- Coefficient Config Port
        Coef_Addr        : in    std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := (others => '0');
        Coef_WrEna       : in    std_logic                                                       := '0';
        Coef_WrData      : in    std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
        Coef_RdEna       : in    std_logic                                                       := '0';
        Coef_RdData      : out   std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
        Coef_RdValid     : out   std_logic;
        -- Input
        In_Valid         : in    std_logic;
        In_Data          : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_Last          : in    std_logic                                                       := '0';
        -- Output
        Out_Valid        : out   std_logic;
        Out_Data         : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Last         : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_fir_dec_ser_chtdm is

    -- *** Entity Name ***
    constant EntityName_c : string := "olo_fix_fir_dec_ser_chtdm";

    -- *** Formats ***
    constant InFmt_c   : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c  : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant CoefFmt_c : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant MultFmt_c : FixFormat_t := cl_fix_mult_fmt(InFmt_c, CoefFmt_c);
    constant AccuFmt_c : FixFormat_t := (1, OutFmt_c.I + GuardBits_g, MultFmt_c.F);

    -- *** Pipeline Stage Constant ***
    constant AccuStage_c : natural := 4 + MultRegs_g;

    -- *** Memory Sizing ***
    constant DataMemDepthReq_c : natural := MaxTaps_g + MaxRatio_g;
    constant DataMemAddrBits_c : natural := log2Ceil(DataMemDepthReq_c);
    constant DataMemDepth_c    : natural := 2 ** DataMemAddrBits_c;
    constant CoefMemDepth_c    : natural := 2 ** log2Ceil(MaxTaps_g);

    -- *** Types ***
    subtype InData_t   is std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    subtype CoefData_t is std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
    subtype MultData_t is std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    subtype AccuData_t is std_logic_vector(cl_fix_width(AccuFmt_c) - 1 downto 0);
    subtype OutData_t  is std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);

    type InData_a  is array (natural range <>) of InData_t;
    type ChNr_a    is array (natural range <>) of std_logic_vector(log2Ceil(Channels_g) - 1 downto 0);

    -- *** Two Process Record ***
    type TwoProcess_r is record
        -- Stage 0
        Vld           : std_logic_vector(0 to 1);
        InSig         : InData_a(0 to 1);
        ChannelNr     : ChNr_a(0 to 3);
        FirstAfterRst : std_logic;
        -- Stage 1 state
        TapWrAddr     : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        Tap0Addr      : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        DecCnt        : std_logic_vector(log2Ceil(MaxRatio_g) - 1 downto 0);
        TapCnt        : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0);
        CalcChnl_1    : std_logic_vector(log2Ceil(Channels_g) - 1 downto 0);
        CalcChnl_2    : std_logic_vector(log2Ceil(Channels_g) - 1 downto 0);
        CalcChnl_3    : std_logic_vector(log2Ceil(Channels_g) - 1 downto 0);
        TapRdAddr_2   : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        CoefRdAddr_2  : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0);
        -- Pipeline control
        CalcOn        : std_logic_vector(1 to AccuStage_c);
        Last          : std_logic_vector(1 to AccuStage_c);
        First         : std_logic_vector(1 to AccuStage_c);
        -- Stage 3 / 4 state
        FirstTapLoop  : std_logic;
        TapRdAddr_3   : std_logic_vector(DataMemAddrBits_c - 1 downto 0);
        ReplaceZero   : std_logic;
        -- Stage 4: multiplier inputs
        MultInTap     : InData_t;
        MultInCoef    : CoefData_t;
        -- Accumulator
        Accu          : AccuData_t;
        AccuValid     : std_logic;
        -- Output channel counter
        OutChCnt      : natural range 0 to Channels_g - 1;
        Out_Valid     : std_logic;
        Out_Last      : std_logic;
        Out_Data      : OutData_t;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Component Connection Signals ***
    signal DataRamWrAddr : std_logic_vector(DataMemAddrBits_c + log2Ceil(Channels_g) - 1 downto 0);
    signal DataRamRdAddr : std_logic_vector(DataMemAddrBits_c + log2Ceil(Channels_g) - 1 downto 0);
    signal DataRamDout_3 : InData_t;
    signal CoefRamDout_3 : CoefData_t;
    signal MultOut_Data  : MultData_t;
    signal MultOut_Valid : std_logic;
    signal ResizeData    : OutData_t;
    signal ResizeValid   : std_logic;

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
    assert Channels_g >= 2
        report errorMessage(EntityName_c, "Channels_g must be >= 2. For single-channel use a non-TDM variant.")
        severity error;
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
        v.ChannelNr(1 to 3)        := r.ChannelNr(0 to 2);
        v.CalcOn(2 to AccuStage_c) := r.CalcOn(1 to AccuStage_c - 1);
        v.Last(2 to AccuStage_c)   := r.Last(1 to AccuStage_c - 1);
        v.First(2 to AccuStage_c)  := r.First(1 to AccuStage_c - 1);

        -- *** Stage 0: Input Register ***
        v.Vld(0)   := In_Valid;
        v.InSig(0) := In_Data;

        if In_Valid = '1' then
            if unsigned(r.ChannelNr(0)) = Channels_g - 1 or r.FirstAfterRst = '1' then
                v.ChannelNr(0)  := (others => '0');
                v.FirstAfterRst := '0';
            else
                v.ChannelNr(0) := std_logic_vector(unsigned(r.ChannelNr(0)) + 1);
            end if;
        end if;

        -- *** Stage 1: Data RAM Write, Decimation & Calculation Control ***
        -- Advance tap write address when last channel's sample arrives
        if (r.Vld(1) = '1') and (unsigned(r.ChannelNr(1)) = Channels_g - 1) then
            v.TapWrAddr := std_logic_vector(unsigned(r.TapWrAddr) + 1);
        end if;

        -- Tap count decrement
        v.First(1) := '0';
        v.Last(1)  := '0';
        v.TapCnt   := std_logic_vector(unsigned(r.TapCnt) - 1);

        -- Last tap of a channel
        if unsigned(r.TapCnt) = 1 or unsigned(Cfg_Taps_I) = 0 then
            v.Last(1) := '1';
        end if;

        -- Move to next channel or finish calculation
        if unsigned(r.TapCnt) = 0 then
            if unsigned(r.CalcChnl_1) = Channels_g - 1 then
                v.CalcOn(1) := '0';
            else
                v.First(1)   := '1';
                v.CalcChnl_1 := std_logic_vector(unsigned(r.CalcChnl_1) + 1);
                v.TapCnt     := Cfg_Taps_I;
            end if;
        end if;

        -- Start new calculation when all channels' input samples have arrived
        if r.Vld(0) = '1' then
            if unsigned(r.ChannelNr(0)) = Channels_g - 1 then
                if unsigned(r.DecCnt) = 0 then
                    v.Tap0Addr   := r.TapWrAddr;
                    v.TapCnt     := Cfg_Taps_I;
                    v.CalcOn(1)  := '1';
                    v.First(1)   := '1';
                    v.CalcChnl_1 := (others => '0');
                    v.DecCnt     := Cfg_Ratio_I;
                    -- The idle TapCnt countdown may have set Last(1) spuriously because it is freerunning. We clear
                    -- it in case it would be on by incident.
                    v.Last(1) := '0';
                else
                    v.DecCnt := std_logic_vector(unsigned(r.DecCnt) - 1);
                end if;
            end if;
        end if;

        -- *** Stage 2: Address Calculation ***
        v.CalcChnl_2   := r.CalcChnl_1;
        v.TapRdAddr_2  := std_logic_vector(unsigned(r.Tap0Addr) - unsigned(r.TapCnt));
        v.CoefRdAddr_2 := r.TapCnt;

        -- *** Stage 3: Pipeline TapRdAddr and CalcChnl (RAM data arrives next cycle) ***
        v.TapRdAddr_3 := r.TapRdAddr_2;
        v.CalcChnl_3  := r.CalcChnl_2;

        -- *** Stage 4: Multiplier Input MUX with ReplaceZero ***
        -- Replace unwritten RAM locations with zeros for bit-trueness at startup
        if r.ReplaceZero = '0' or unsigned(r.TapRdAddr_3) <= unsigned(Cfg_Ratio_I) then
            v.MultInTap := DataRamDout_3;
        else
            v.MultInTap := (others => '0');
        end if;

        -- Track when zero-replacement can be disabled
        -- CalcChnl_3 is used (not ChannelNr) so the check works regardless of input stalls
        if r.FirstTapLoop = '0' then
            v.ReplaceZero := '0';
        elsif r.CalcOn(3) = '1' then
            if r.First(3) = '1' and unsigned(r.TapRdAddr_3) <= unsigned(Cfg_Ratio_I) then
                v.ReplaceZero := '0';
                if unsigned(r.CalcChnl_3) = Channels_g - 1 then
                    v.FirstTapLoop := '0';
                end if;
            elsif r.Last(3) = '1' then
                v.ReplaceZero := '1';
            elsif unsigned(r.TapRdAddr_3) = 0 then
                v.ReplaceZero := '0';
            end if;
        end if;

        v.MultInCoef := CoefRamDout_3;

        -- *** Stage AccuStage_c: Accumulate ***
        if r.First(AccuStage_c) = '1' then
            AccuIn_v := (others => '0');
        else
            AccuIn_v := r.Accu;
        end if;
        v.Accu := cl_fix_add(MultOut_Data, MultFmt_c,
                             AccuIn_v, AccuFmt_c,
                             AccuFmt_c, Trunc_s, None_s);

        -- Capture when last tap of a channel's calculation is done
        v.AccuValid := r.Last(AccuStage_c) and r.CalcOn(AccuStage_c);

        -- *** Output: capture result from olo_fix_resize ***
        v.Out_Valid := '0';
        v.Out_Last  := '0';
        if ResizeValid = '1' then
            v.Out_Valid := '1';
            v.Out_Data  := ResizeData;
            if r.OutChCnt = Channels_g - 1 then
                v.Out_Last := '1';
                v.OutChCnt := 0;
            else
                v.OutChCnt := r.OutChCnt + 1;
            end if;
        end if;

        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Output Assignment
    -----------------------------------------------------------------------------------------------
    Out_Valid <= r.Out_Valid;
    Out_Data  <= r.Out_Data;
    Out_Last  <= r.Out_Last;

    -----------------------------------------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.FirstAfterRst <= '1';
                r.Vld           <= (others => '0');
                r.ChannelNr(0)  <= (others => '0');
                r.CalcChnl_1    <= (others => '0');
                r.TapWrAddr     <= (others => '0');
                r.DecCnt        <= (others => '0');
                r.CalcOn        <= (others => '0');
                r.Last          <= (others => '0');
                r.First         <= (others => '0');
                r.AccuValid     <= '0';
                r.Out_Valid     <= '0';
                r.Out_Last      <= '0';
                r.ReplaceZero   <= '1';
                r.FirstTapLoop  <= '1';
                r.OutChCnt      <= 0;
                r.TapCnt        <= Cfg_Taps_I;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Input TDM Validation
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    p_assert_in : process (Clk) is
        variable ChCnt_v : natural range 0 to Channels_g - 1;
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                ChCnt_v := 0;
            elsif In_Valid = '1' then

                -- Check Tap Count > 1
                assert unsigned(Cfg_Taps) >= 1 or RuntimeCfg_g = false
                    report errorMessage(EntityName_c, "Cfg_Taps must be >= 0 (1 tap filter is not supported)")
                    severity error;

                -- Check TDM Timing
                if In_Last = '1' then
                    assert ChCnt_v = Channels_g - 1
                        report errorMessage(EntityName_c, "In_Last asserted at channel index " &
                               integer'image(ChCnt_v) & " but expected at " &
                               integer'image(Channels_g - 1))
                        severity error;
                end if;
                if ChCnt_v = Channels_g - 1 then
                    ChCnt_v := 0;
                else
                    ChCnt_v := ChCnt_v + 1;
                end if;
            end if;
        end if;
    end process;

    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
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
            In_A       => r.MultInTap,
            In_B       => r.MultInCoef,
            Out_Valid  => MultOut_Valid,
            Out_Result => MultOut_Data
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
            In_A       => r.Accu,
            Out_Valid  => ResizeValid,
            Out_Result => ResizeData
        );

    -- *** Coefficient Storage ***
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

    -- *** Data RAM (Simple Dual Port: one write port, one read port) ***
    DataRamWrAddr <= r.ChannelNr(1) & r.TapWrAddr;
    DataRamRdAddr <= r.CalcChnl_2 & r.TapRdAddr_2;

    i_data_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g       => DataMemDepth_c * Channels_g,
            Width_g       => fixFmtWidthFromString(InFmt_g),
            RdLatency_g   => 1,
            RamStyle_g    => DataMemStyle_g,
            RamBehavior_g => DataRamBehavior_g
        )
        port map (
            Clk     => Clk,
            Rst     => Rst,
            Wr_Addr => DataRamWrAddr,
            Wr_Ena  => r.Vld(1),
            Wr_Data => r.InSig(1),
            Rd_Addr => DataRamRdAddr,
            Rd_Ena  => '1',
            Rd_Data => DataRamDout_3
        );

end architecture;
