---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a decimating FIR filter. It supports one or more channels (time-division-
-- multiplexed). All channels share the same coefficient set. The filter taps are computed
-- semi-parallel: Multipliers_g multiply-add operations are chained together in a classic MACC
-- chain and Taps_g/Multipliers_g cycles are used to compute one output sample.
--
-- The delay lines are stored in RAM and are NOT cleared by reset. After a reset (during operation)
-- the Flush interface must be used to zero the delay lines. After power-up the RAMs are zero
-- initialized, hence flushing is only required after resets that happen during operation.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_fir_dec_semi_chtdm.md
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
entity olo_fix_fir_dec_semi_chtdm is
    generic (
        -- Formats
        InFmt_g              : string;
        OutFmt_g             : string;
        CoefFmt_g            : string;
        -- Filter parameters
        Channels_g           : positive := 1;
        Ratio_g              : positive := 1;
        Taps_g               : positive;
        Multipliers_g        : positive;
        FullInpRateSupport_g : boolean  := false;
        -- Arithmetic
        GuardBits_g          : natural  := 1;
        Round_g              : string   := FixRound_Trunc_c;
        Saturate_g           : string   := FixSaturate_Warn_c;
        MultRegs_g           : positive := 1;
        -- Coefficient storage
        CoefInit_g           : string   := "0.0";
        CoefStorageType_g    : string   := "ROM";
        CoefRamReadback_g    : boolean  := false;
        CoefRamBehavior_g    : string   := "RBW";
        CoefMemStyle_g       : string   := "auto";
        -- Data RAM
        DataRamBehavior_g    : string   := "RBW";
        DataMemStyle_g       : string   := "auto"
    );
    port (
        -- Control Ports
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        -- Coefficient Config Port
        Coef_Addr    : in    std_logic_vector(log2Ceil(Taps_g) - 1 downto 0)                 := (others => '0');
        Coef_WrEna   : in    std_logic                                                       := '0';
        Coef_WrData  : in    std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
        Coef_RdEna   : in    std_logic                                                       := '0';
        Coef_RdData  : out   std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
        Coef_RdValid : out   std_logic;
        -- Delay-Line Flushing Interface
        Flush_Ena    : in    std_logic                                                       := '0';
        Flush_Done   : out   std_logic;
        -- Input
        In_Valid     : in    std_logic;
        In_Data      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_Last      : in    std_logic                                                       := '0';
        -- Output
        Out_Valid    : out   std_logic;
        Out_Data     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Last     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_fir_dec_semi_chtdm is

    -- *** Entity Name ***
    constant EntityName_c : string := "olo_fix_fir_dec_semi_chtdm";

    -- *** Formats ***
    constant InFmt_c      : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant CoefFmt_c    : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant MultFmt_c    : FixFormat_t := cl_fix_mult_fmt(InFmt_c, CoefFmt_c);
    -- Full-precision running sum (never overflows, hence no rounding/saturation warnings)
    constant FullSumFmt_c : FixFormat_t := (1, MultFmt_c.I + log2Ceil(Taps_g), MultFmt_c.F);
    -- Guarded accumulator format (matches the bit-true Python model)
    constant AccuFmt_c    : FixFormat_t := (1, OutFmt_c.I + GuardBits_g, MultFmt_c.F);

    -- *** Port Widths ***
    constant InWidth_c   : natural := fixFmtWidthFromString(InFmt_g);
    constant CoefWidth_c : natural := fixFmtWidthFromString(CoefFmt_g);
    constant OutWidth_c  : natural := fixFmtWidthFromString(OutFmt_g);

    -- *** Semi-Parallel Sizing ***
    constant TapsPerStage_c  : natural := integer(ceil(real(Taps_g) / real(Multipliers_g)));
    constant CyclesPerCalc_c : natural := TapsPerStage_c;
    constant CoefIdxBits_c   : natural := log2Ceil(TapsPerStage_c);

    -- *** Coefficient Memory Sizing (one block per multiplier holds only that lane's taps) ***
    constant CoefMemDepth_c : natural := max(2, 2 ** CoefIdxBits_c);
    constant CoefAddrBits_c : natural := log2Ceil(CoefMemDepth_c);

    -- *** Functions ***
    -- Extract the coefficient slice belonging to one MACC lane (stage) as an init string.
    function getStageInit (fullInit : string; stage : natural) return string is
        constant Coefs_c : RealArray_t                          := fromString(fullInit);
        variable Slice_v : RealArray_t(0 to TapsPerStage_c - 1) := (others => 0.0);
    begin

        for k in 0 to TapsPerStage_c - 1 loop
            if stage * TapsPerStage_c + k <= Coefs_c'high then
                Slice_v(k) := Coefs_c(stage * TapsPerStage_c + k);
            end if;
        end loop;

        return toString(Slice_v);
    end function;

    -- *** Data Memory Sizing (chained delay line, one RAM per multiplier) ***
    constant RamPerChPerStage_c : natural := 2 ** log2Ceil(TapsPerStage_c + Ratio_g + 1);
    constant TapSelBits_c       : natural := log2Ceil(RamPerChPerStage_c);
    -- At least 1 bit: a zero-width channel index would make numeric_std comparisons against
    -- "Channels_g - 1" return FALSE (null-array rule), which breaks the control flow for Channels_g=1.
    constant ChSelBits_c        : natural := max(1, log2Ceil(Channels_g));
    constant RamAddrBits_c      : natural := TapSelBits_c + ChSelBits_c;

    -- *** Pipeline Stage Constants ***
    -- Stage where the final MACC-chain output (spatial sum of all Multipliers_g lanes) is valid.
    -- Address registers are at stage 3..3+M-1, RAM read latency is 1 (data at stage 4..4+M-1) and
    -- each olo_fix_madd adds MultRegs_g+2 cycles of latency.
    constant SpatialStage_c : natural := Multipliers_g + MultRegs_g + 5;

    -- *** Types ***
    subtype InData_t   is std_logic_vector(InWidth_c - 1 downto 0);
    subtype CoefData_t is std_logic_vector(CoefWidth_c - 1 downto 0);
    subtype FullSum_t  is std_logic_vector(cl_fix_width(FullSumFmt_c) - 1 downto 0);
    subtype AccuData_t is std_logic_vector(cl_fix_width(AccuFmt_c) - 1 downto 0);
    subtype OutData_t  is std_logic_vector(OutWidth_c - 1 downto 0);

    type Data_a    is array (natural range <>) of InData_t;
    type FullSum_a is array (natural range <>) of FullSum_t;
    type TapAddr_a is array (natural range <>) of unsigned(TapSelBits_c - 1 downto 0);
    type Channel_a is array (natural range <>) of unsigned(ChSelBits_c - 1 downto 0);
    type RamAddr_a is array (natural range <>) of std_logic_vector(RamAddrBits_c - 1 downto 0);
    type CoefIdx_a is array (natural range <>) of std_logic_vector(CoefIdxBits_c - 1 downto 0);

    -- *** Two Process Record ***
    type TwoProcess_r is record
        -- Stage 0 (input)
        Vld            : std_logic_vector(0 to Multipliers_g);
        Data_0         : InData_t;
        DecCnt_0       : integer range 0 to Ratio_g - 1;
        ChCnt          : Channel_a(0 to Multipliers_g);
        TapUpdWrAddr_0 : unsigned(TapSelBits_c - 1 downto 0);
        -- Stage 1
        Data_1         : InData_t;
        CalcStartLoop  : std_logic;
        TapUpdAddr     : TapAddr_a(1 to Multipliers_g);
        -- Stage 2 (calculation loop control)
        CalcRunning    : std_logic_vector(2 to SpatialStage_c);
        CalcFirst      : std_logic_vector(2 to SpatialStage_c);
        CalcLast       : std_logic_vector(2 to SpatialStage_c);
        CalcCycLeft_2  : integer range 0 to CyclesPerCalc_c - 1;
        CalcChannel_2  : unsigned(ChSelBits_c - 1 downto 0);
        CalcFirstTap_2 : unsigned(TapSelBits_c - 1 downto 0);
        CoefRdIdx_2    : unsigned(CoefIdxBits_c - 1 downto 0);
        TapRdAddr_2    : unsigned(TapSelBits_c - 1 downto 0);
        -- Stage 3..3+M-1 (staggered address pipelines feeding the lanes)
        CoefRdAddr     : CoefIdx_a(3 to Multipliers_g + 2);
        TapRdAddr      : RamAddr_a(3 to Multipliers_g + 2);
        -- Output side
        Accu           : FullSum_t;
        AccuResized    : AccuData_t;
        AccuValid      : std_logic;
        OutChCnt       : natural range 0 to Channels_g - 1;
        Out_Valid      : std_logic;
        Out_Last       : std_logic;
        Out_Data       : OutData_t;
        -- Delay-line flushing
        FlushActive    : std_logic;
        FlushAddr      : std_logic_vector(RamAddrBits_c - 1 downto 0);
        FlushDone      : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Component Connection Signals ***
    type CoefData_a is array (natural range <>) of CoefData_t;

    signal DataInChain : Data_a(1 to Multipliers_g + 1);
    signal AccuChain   : FullSum_a(0 to Multipliers_g);
    signal ResizeData  : OutData_t;
    signal ResizeValid : std_logic;
    signal CfgRdData   : CoefData_a(0 to Multipliers_g - 1);
    signal CfgRdValid  : std_logic_vector(0 to Multipliers_g - 1);

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    assert Ratio_g >= 1
        report errorMessage(EntityName_c, "Ratio_g must be >= 1.")
        severity error;
    assert Taps_g >= 2
        report errorMessage(EntityName_c, "Taps_g must be >= 2.")
        severity error;
    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v           : TwoProcess_r;
        variable StartLoop_v : boolean;
    begin
        v := r;

        -- *** Pipe Handling ***
        v.Vld(1 to Multipliers_g)            := r.Vld(0 to Multipliers_g - 1);
        v.ChCnt(1 to Multipliers_g)          := r.ChCnt(0 to Multipliers_g - 1);
        v.TapUpdAddr(2 to Multipliers_g)     := r.TapUpdAddr(1 to Multipliers_g - 1);
        v.CoefRdAddr(4 to Multipliers_g + 2) := r.CoefRdAddr(3 to Multipliers_g + 1);
        v.TapRdAddr(4 to Multipliers_g + 2)  := r.TapRdAddr(3 to Multipliers_g + 1);
        v.CalcRunning(3 to SpatialStage_c)   := r.CalcRunning(2 to SpatialStage_c - 1);
        v.CalcFirst(3 to SpatialStage_c)     := r.CalcFirst(2 to SpatialStage_c - 1);
        v.CalcLast(3 to SpatialStage_c)      := r.CalcLast(2 to SpatialStage_c - 1);

        -- *** Stage 0: Input Register, Channel and Decimation Counters ***
        v.Vld(0) := In_Valid;
        v.Data_0 := In_Data;
        if r.Vld(0) = '1' then
            if r.ChCnt(0) = Channels_g - 1 or Channels_g = 1 then
                v.ChCnt(0) := (others => '0');
                if r.DecCnt_0 = 0 then
                    v.DecCnt_0 := Ratio_g - 1;
                else
                    v.DecCnt_0 := r.DecCnt_0 - 1;
                end if;
                v.TapUpdWrAddr_0 := r.TapUpdWrAddr_0 + 1;
            else
                v.ChCnt(0) := r.ChCnt(0) + 1;
            end if;
        end if;

        -- *** Stage 1: Start Calculation, Data-RAM Write/Read Address for the Chain ***
        v.Data_1        := r.Data_0;
        v.CalcStartLoop := '0';
        if r.Vld(0) = '1' and r.DecCnt_0 = 0 and (r.ChCnt(0) = Channels_g - 1 or Channels_g = 1) then
            v.CalcStartLoop := '1';
        end if;
        -- On write cycles the newest sample is written (and its old value read for the chain).
        if r.Vld(0) = '1' then
            v.TapUpdAddr(1) := r.TapUpdWrAddr_0;
        -- In between the chain read address is offset to keep delivering delayed samples.
        elsif not FullInpRateSupport_g then
            v.TapUpdAddr(1) := r.TapUpdWrAddr_0 - TapsPerStage_c;
        end if;

        -- *** Stage 2: Calculation Loop (cycles per channel, channel sequencing) ***
        v.CalcFirst(2) := '0';
        v.CalcLast(2)  := '0';
        StartLoop_v    := false;

        if r.CalcStartLoop = '1' then
            v.CalcChannel_2  := (others => '0');
            v.CalcFirstTap_2 := r.TapUpdAddr(1);
            v.TapRdAddr_2    := r.TapUpdAddr(1);
            v.CalcRunning(2) := '1';
            StartLoop_v      := true;
        elsif r.CalcRunning(2) = '1' then
            v.CoefRdIdx_2 := r.CoefRdIdx_2 - 1;
            v.TapRdAddr_2 := r.TapRdAddr_2 + 1;
            if r.CalcCycLeft_2 <= 1 then
                v.CalcLast(2) := '1';
            end if;
            if r.CalcCycLeft_2 /= 0 then
                v.CalcCycLeft_2 := r.CalcCycLeft_2 - 1;
            end if;
        end if;

        -- After the last cycle of a channel calculation ...
        if (r.CalcLast(2) = '1') and (r.CalcRunning(2) = '1') then
            v.CalcLast(2) := '0';
            -- ... start next channel if the current one was not the last one
            if (r.CalcChannel_2 /= Channels_g - 1) and (Channels_g /= 1) then
                v.CalcChannel_2 := r.CalcChannel_2 + 1;
                v.TapRdAddr_2   := r.CalcFirstTap_2;
                StartLoop_v     := true;
            -- ... otherwise finish the calculation loop
            elsif r.CalcStartLoop = '0' then
                v.CalcRunning(2) := '0';
            end if;
        end if;

        -- Shared start-of-channel behavior
        if StartLoop_v then
            v.CalcFirst(2)  := '1';
            v.CalcCycLeft_2 := CyclesPerCalc_c - 1;
            v.CoefRdIdx_2   := to_unsigned(TapsPerStage_c - 1, v.CoefRdIdx_2'length);
            if Taps_g <= Multipliers_g then
                v.CalcLast(2) := '1';
            end if;
        end if;

        -- *** Stage 3: Address Registers Feeding the Lanes ***
        v.CoefRdAddr(3) := std_logic_vector(r.CoefRdIdx_2);
        v.TapRdAddr(3)  := std_logic_vector(r.CalcChannel_2) &
                           std_logic_vector(r.TapRdAddr_2 - TapsPerStage_c + 1);

        -- *** Delay-Line Flushing (outside of the calculation pipeline) ***
        v.FlushDone := '0';
        if Flush_Ena = '1' then
            v.FlushActive := '1';
            v.FlushAddr   := (others => '0');
        elsif signed(r.FlushAddr) = -1 then
            v.FlushActive := '0';
            v.FlushDone   := '1';
            v.FlushAddr   := (others => '0');
        elsif r.FlushActive = '1' then
            v.FlushAddr := std_logic_vector(unsigned(r.FlushAddr) + 1);
        end if;

        -- *** Temporal Accumulation of the Spatial MACC-Chain Output ***
        v.AccuValid := '0';
        if r.CalcRunning(SpatialStage_c) = '1' then
            if r.CalcFirst(SpatialStage_c) = '1' then
                v.Accu := AccuChain(Multipliers_g);
            else
                v.Accu := cl_fix_add(r.Accu, FullSumFmt_c,
                                     AccuChain(Multipliers_g), FullSumFmt_c,
                                     FullSumFmt_c, Trunc_s, None_s);
            end if;
            if r.CalcLast(SpatialStage_c) = '1' then
                v.AccuValid   := '1';
                v.AccuResized := cl_fix_resize(v.Accu, FullSumFmt_c, AccuFmt_c, Trunc_s, None_s);
            end if;
        end if;

        -- *** Output: capture result from olo_fix_resize and track TDM channel ***
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
    Out_Valid  <= r.Out_Valid;
    Out_Data   <= r.Out_Data;
    Out_Last   <= r.Out_Last;
    Flush_Done <= r.FlushDone;

    -- Coefficient readback: mux the response from the lane owning the addressed tap. Only that lane
    -- asserts its Cfg_RdValid, so a valid-masked OR selects the correct data.
    p_coef_rdbk : process (all) is
    begin
        Coef_RdData  <= (others => 'X');
        Coef_RdValid <= '0';

        for m in 0 to Multipliers_g - 1 loop
            if CfgRdValid(m) = '1' then
                Coef_RdData  <= CfgRdData(m);
                Coef_RdValid <= '1';
            end if;
        end loop;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Vld            <= (others => '0');
                r.DecCnt_0       <= 0;
                r.ChCnt(0)       <= (others => '0');
                r.TapUpdWrAddr_0 <= (others => '0');
                r.CalcStartLoop  <= '0';
                r.CalcRunning    <= (others => '0');
                r.CalcFirst      <= (others => '0');
                r.CalcLast       <= (others => '0');
                r.AccuValid      <= '0';
                r.OutChCnt       <= 0;
                r.Out_Valid      <= '0';
                r.Out_Last       <= '0';
                r.FlushActive    <= '0';
                r.FlushDone      <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Input TDM / Processing-Power Assertions
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    p_assert : process (Clk) is
        variable ChCnt_v : natural range 0 to Channels_g - 1;
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                ChCnt_v := 0;
            else
                -- Check processing power (Multipliers_g must be large enough for the data rate)
                if r.CalcStartLoop = '1' then
                    assert (r.CalcRunning(2) = '0') or
                           ((r.CalcChannel_2 = Channels_g - 1) and (r.CalcLast(2) = '1'))
                        report errorMessage(EntityName_c,
                               "Insufficient processing power - increase Multipliers_g or Ratio_g.")
                        severity error;
                end if;

                -- Without full input rate support, In_Valid must not be high on two consecutive cycles
                if not FullInpRateSupport_g then
                    assert not (In_Valid = '1' and r.Vld(0) = '1')
                        report errorMessage(EntityName_c,
                               "In_Valid asserted on two consecutive cycles requires FullInpRateSupport_g = true.")
                        severity error;
                end if;

                -- Check TDM framing
                if In_Valid = '1' then
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
        end if;
    end process;

    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Output Resize (round + saturate accumulator to output format)
    -----------------------------------------------------------------------------------------------
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
            In_A       => r.AccuResized,
            Out_Valid  => ResizeValid,
            Out_Result => ResizeData
        );

    -----------------------------------------------------------------------------------------------
    -- Semi-Parallel MACC Lanes
    -----------------------------------------------------------------------------------------------
    DataInChain(1) <= r.Data_1;
    AccuChain(0)   <= (others => '0');

    g_mac : for i in 0 to Multipliers_g - 1 generate
        signal DataWrAddr : std_logic_vector(RamAddrBits_c - 1 downto 0);
        signal DataWr     : std_logic;
        signal DataDin    : InData_t;
        signal RamRdData  : InData_t;
        signal TapData    : InData_t;
        signal CoefData   : CoefData_t;
        signal CoefRdAddr : std_logic_vector(CoefAddrBits_c - 1 downto 0);
        signal CfgAddr    : std_logic_vector(CoefAddrBits_c - 1 downto 0);
        signal CfgSel     : std_logic;
        signal CfgWrEna   : std_logic;
        signal CfgRdEna   : std_logic;
    begin

        -------------------------------------------------------------------------------------------
        -- Data RAM (chained delay line, port A writes and reads for the chain)
        -------------------------------------------------------------------------------------------
        DataWrAddr <= r.FlushAddr                                                       when r.FlushActive = '1' else
                      std_logic_vector(r.ChCnt(i + 1)) & std_logic_vector(r.TapUpdAddr(i + 1));
        DataWr     <= '1' when r.FlushActive = '1' else r.Vld(i + 1);
        DataDin    <= (others => '0') when r.FlushActive = '1' else DataInChain(i + 1);

        i_data_ram : entity work.olo_base_ram_tdp
            generic map (
                Depth_g       => 2 ** RamAddrBits_c,
                Width_g       => InWidth_c,
                RdLatency_g   => 1,
                RamStyle_g    => DataMemStyle_g,
                RamBehavior_g => DataRamBehavior_g
            )
            port map (
                A_Clk    => Clk,
                A_Addr   => DataWrAddr,
                A_WrEna  => DataWr,
                A_WrData => DataDin,
                A_RdData => RamRdData,
                B_Clk    => Clk,
                B_Addr   => r.TapRdAddr(i + 3),
                B_WrEna  => '0',
                B_RdData => TapData
            );

        -- Chain delay: register the port-A read output (or a dedicated delay for full input rate)
        g_fullrate : if FullInpRateSupport_g generate
            signal FullRateDel : InData_t;
        begin

            i_tapdelay : entity work.olo_base_delay
                generic map (
                    Width_g       => InWidth_c,
                    Delay_g       => Channels_g * TapsPerStage_c,
                    RstState_g    => true,
                    RamBehavior_g => DataRamBehavior_g,
                    RamStyle_g    => DataMemStyle_g
                )
                port map (
                    Clk      => Clk,
                    Rst      => Rst,
                    In_Data  => DataInChain(i + 1),
                    In_Valid => r.Vld(i + 1),
                    Out_Data => FullRateDel
                );

            p_chain : process (Clk) is
            begin
                if rising_edge(Clk) then
                    DataInChain(i + 2) <= FullRateDel;
                end if;
            end process;

        end generate;

        g_nofullrate : if not FullInpRateSupport_g generate

            p_chain : process (Clk) is
            begin
                if rising_edge(Clk) then
                    DataInChain(i + 2) <= RamRdData;
                end if;
            end process;

        end generate;

        -------------------------------------------------------------------------------------------
        -- Coefficient Storage (this lane holds only its own block of taps)
        -------------------------------------------------------------------------------------------
        -- Read address = local within-lane tap index (0 .. TapsPerStage-1)
        CoefRdAddr <= std_logic_vector(resize(unsigned(r.CoefRdAddr(i + 3)), CoefAddrBits_c));
        -- Config accesses are routed to the lane owning the addressed global tap index
        CfgSel   <= '1' when (unsigned(Coef_Addr) >= i * TapsPerStage_c) and
                             (unsigned(Coef_Addr) < (i + 1) * TapsPerStage_c) else
                    '0';
        CfgAddr  <= std_logic_vector(resize(unsigned(Coef_Addr) - i * TapsPerStage_c, CoefAddrBits_c));
        CfgWrEna <= Coef_WrEna and CfgSel;
        CfgRdEna <= Coef_RdEna and CfgSel;

        i_coef : entity work.olo_fix_coef_storage
            generic map (
                Depth_g       => CoefMemDepth_c,
                Fmt_g         => CoefFmt_g,
                Init_g        => getStageInit(CoefInit_g, i),
                StorageType_g => CoefStorageType_g,
                RamReadback_g => CoefRamReadback_g,
                RamBehavior_g => CoefRamBehavior_g,
                RdLatency_g   => 1,
                MemStyle_g    => CoefMemStyle_g
            )
            port map (
                Clk          => Clk,
                Rst          => Rst,
                Cfg_Addr     => CfgAddr,
                Cfg_WrEna    => CfgWrEna,
                Cfg_WrData   => Coef_WrData,
                Cfg_RdEna    => CfgRdEna,
                Cfg_RdData   => CfgRdData(i),
                Cfg_RdValid  => CfgRdValid(i),
                Coef_Addr    => CoefRdAddr,
                Coef_RdEna   => '1',
                Coef_RdData  => CoefData,
                Coef_RdValid => open
            );

        -------------------------------------------------------------------------------------------
        -- Multiply-Add (MACC chain element)
        -------------------------------------------------------------------------------------------
        i_madd : entity work.olo_fix_madd
            generic map (
                AFmt_g        => InFmt_g,
                BFmt_g        => CoefFmt_g,
                AddChainFmt_g => to_string(FullSumFmt_c),
                MultRegs_g    => MultRegs_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                InAC_Valid => r.CalcRunning(i + 4),
                InA_Data   => TapData,
                InB_Valid  => r.CalcRunning(i + 4),
                InB_Data   => CoefData,
                MaccIn     => AccuChain(i),
                Out_Data   => AccuChain(i + 1)
            );

    end generate;

end architecture;
