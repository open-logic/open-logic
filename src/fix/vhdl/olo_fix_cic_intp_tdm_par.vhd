---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a CIC interpolator for one or multiple channels. The input is received
-- time-division multiplexed (TDM), the output is produced with all channels in parallel.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cic_intp_tdm_par.md
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
    use work.olo_base_pkg_string.all;
    use work.olo_base_pkg_array.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_fix_cic_intp_tdm_par is
    generic (
        Channels_g        : positive := 1;
        Order_g           : positive range 2 to 32;
        Ratio_g           : positive;
        FixedRatio_g      : boolean  := true;
        DiffDelay_g       : positive := 1;
        InFmt_g           : string;
        OutFmt_g          : string;
        GainCorrCoefFmt_g : string   := "(0,1,16)";
        Round_g           : string   := FixRound_NonSymPos_c;
        Saturate_g        : string   := FixSaturate_Warn_c;
        -- Resource control generics
        RamBehavior_g     : string   := "RBW";
        RamStyle_g        : string   := "auto";
        Resource_g        : string   := "AUTO"
    );
    port (
        -- Control Signals
        Clk          : in    std_logic;
        Rst          : in    std_logic;

        -- Configuration (only change when in reset!)
        Cfg_Ratio    : in    std_logic_vector(log2ceil(Ratio_g) - 1 downto 0);
        Cfg_Shift    : in    std_logic_vector(7 downto 0);
        Cfg_GainCorr : in    std_logic_vector(fixFmtWidthFromStringTolerant(GainCorrCoefFmt_g) - 1 downto 0);

        -- Input
        In_Valid     : in    std_logic := '1';
        In_Ready     : out   std_logic;
        In_Data      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_Last      : in    std_logic := '0';

        -- Output
        Out_Valid    : out   std_logic;
        Out_Data     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g)*Channels_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture section
---------------------------------------------------------------------------------------------------

architecture rtl of olo_fix_cic_intp_tdm_par is

    -- Constants
    constant EntityName_c : string := "olo_fix_cic_intp_tdm_par";

    -- Formats
    constant InFmt_c           : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c          : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant GainCorrCoefFmt_c : FixFormat_t := fixFmtFromStringTolerant(GainCorrCoefFmt_g);
    constant GainCorrOn_c      : boolean     := not compareNoCase(GainCorrCoefFmt_g, "NONE");

    -- CIC gain (for the maximum ratio)
    constant MaxCicGain_c    : real    := (real(Ratio_g)*real(DiffDelay_g))**real(Order_g) / real(Ratio_g);
    constant MaxCicAddBits_c : integer := log2ceil(MaxCicGain_c-0.1);
    -- ... WORKAROUND: Vivado does real calculations imprecisely. With the -0.1, wrong results are avoided.
    constant MaxShift_c      : integer := MaxCicAddBits_c;
    constant SftSelBits_c    : natural := log2ceil(max(MaxShift_c, 1) + 1);

    -- Number of comb and integrator stages (one of each is replaced by running sum and sample and hold)
    constant Stages_c : positive := Order_g - 1;

    -- Internal Formats
    -- .. Gain correction is applied at the input. One additional integer bit is required because the gain correction
    --    factor is in the range 1.0 ... 2.0.
    constant GcOutFmt_c : FixFormat_t := (InFmt_c.S, InFmt_c.I + 1,
                                          work.olo_base_pkg_math.min(OutFmt_c.F + 2, InFmt_c.F + GainCorrCoefFmt_c.F));
    constant CicInFmt_c : FixFormat_t := choose(GainCorrOn_c, GcOutFmt_c, InFmt_c);
    -- .. Order_g-1 comb stages followed by a running sum over DiffDelay_g samples (replaces the last comb, see doc)
    constant DiffFmt_c  : FixFormat_t := (1, CicInFmt_c.I + Order_g - 1, CicInFmt_c.F);
    constant HoldFmt_c  : FixFormat_t := (1, DiffFmt_c.I + log2ceil(DiffDelay_g), CicInFmt_c.F);
    constant AccuFmt_c  : FixFormat_t := (CicInFmt_c.S, CicInFmt_c.I + MaxCicAddBits_c, CicInFmt_c.F);
    constant SftFmt_c   : FixFormat_t := (CicInFmt_c.S, CicInFmt_c.I, CicInFmt_c.F + MaxShift_c);
    constant RealGc_c   : real        := 2.0**real(MaxCicAddBits_c)/MaxCicGain_c;

    constant FixedGc_c : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0) :=
        cl_fix_from_real(RealGc_c, GainCorrCoefFmt_c);

    -- Widths
    constant AccuWidth_c : positive := cl_fix_width(AccuFmt_c);
    constant OutWidth_c  : positive := cl_fix_width(OutFmt_c);

    -- Types
    type AccuStage_t is array (natural range <>) of std_logic_vector(AccuWidth_c-1 downto 0);
    type Accus_t is array (natural range <>) of AccuStage_t(0 to Channels_g-1);
    type Diff_t is array (natural range <>) of std_logic_vector(cl_fix_width(DiffFmt_c)-1 downto 0);

    -- Two Process Method
    type TwoProcess_t is record
        -- Configuration Registers
        GcCoef   : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c)-1 downto 0);
        SftSel   : std_logic_vector(SftSelBits_c - 1 downto 0);
        -- Input Handshaking
        InRdy    : std_logic;
        InChCnt  : natural range 0 to Channels_g-1;
        FrameCnt : natural range 0 to Ratio_g-1;
        -- Diff Section
        Input_0  : std_logic_vector(cl_fix_width(InFmt_c)-1 downto 0);
        VldIn_0  : std_logic;
        VldDiff  : std_logic_vector(1 to Stages_c);
        DiffVal  : Diff_t(1 to Stages_c);
        -- Running Sum
        VldSum   : std_logic;
        SumVal   : std_logic_vector(cl_fix_width(HoldFmt_c)-1 downto 0);
        -- Sample and Hold
        HoldCnt  : natural range 0 to Ratio_g-1;
        -- Accu Section
        VldAccu  : std_logic_vector(0 to Stages_c);
        Accu     : Accus_t(1 to Stages_c);
    end record;

    signal r, r_next : TwoProcess_t;

    -- Component Connection Signals
    signal CicIn        : std_logic_vector(cl_fix_width(CicInFmt_c)-1 downto 0);
    signal CicIn_Valid  : std_logic;
    signal DiffIn_0     : std_logic_vector(cl_fix_width(DiffFmt_c)-1 downto 0);
    signal DiffDel      : Diff_t(0 to Stages_c-1);
    signal SumTaps      : Diff_t(1 to max(DiffDelay_g-1, 1));
    signal HoldData     : AccuStage_t(0 to Channels_g-1);
    signal SftIn        : std_logic_vector(AccuWidth_c-1 downto 0);
    signal SftOut       : std_logic_vector(AccuWidth_c-1 downto 0);
    signal SftOut_Valid : std_logic;
    signal TdmPar_Valid : std_logic;
    signal TdmPar_Data  : std_logic_vector(AccuWidth_c*Channels_g-1 downto 0);
    signal OutVld       : std_logic_vector(0 to Channels_g-1);

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert (not GainCorrOn_c) or GainCorrCoefFmt_c.I = 1
        report errorMessage(EntityName_c, "Gain correction coefficient format must have 1 integer bit (or be NONE)")
        severity failure;
    assert (not GainCorrOn_c) or GainCorrCoefFmt_c.S = 0
        report errorMessage(EntityName_c, "Gain correction coefficient format must be unsigned (or be NONE)")
        severity failure;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v        : TwoProcess_t;
        variable Ratio_v  : std_logic_vector(Cfg_Ratio'range);
        variable Shift_v  : integer;
        variable InAcpt_v : boolean;
        variable Sum_v    : std_logic_vector(cl_fix_width(HoldFmt_c)-1 downto 0);
    begin
        -- hold variables stable
        v := r;

        -- Ratio from port or constant
        if FixedRatio_g then
            Ratio_v := toUslv(Ratio_g - 1, Cfg_Ratio'length);
        else
            Ratio_v := Cfg_Ratio;
        end if;

        -- *** Configuration Registers ***
        -- Left shift before the integrators (see documentation)
        if not FixedRatio_g then
            Shift_v := fromUslv(Cfg_Shift);
            if Shift_v > MaxShift_c then
                Shift_v := MaxShift_c;
            end if;
            v.SftSel := toUslv(MaxShift_c - Shift_v, SftSelBits_c);
        end if;

        if GainCorrOn_c then
            v.GcCoef := Cfg_GainCorr;
        end if;

        -- *** Pipe Handling ***
        v.VldDiff(v.VldDiff'low+1 to v.VldDiff'high) := r.VldDiff(r.VldDiff'low to r.VldDiff'high-1);
        v.VldAccu(v.VldAccu'low+1 to v.VldAccu'high) := r.VldAccu(r.VldAccu'low to r.VldAccu'high-1);

        -- *** Input Handshaking ***
        -- The last sample of a TDM frame is only accepted if at least "Ratio" clock cycles passed since the last
        -- sample of the previous TDM frame. This ensures the sample and hold is completed before the next frame
        -- arrives (the pipeline in between has fixed latency).
        InAcpt_v := r.InRdy = '1' and In_Valid = '1';
        if r.FrameCnt /= 0 then
            v.FrameCnt := r.FrameCnt - 1;
        end if;
        if InAcpt_v then
            if r.InChCnt = Channels_g-1 then
                v.InChCnt  := 0;
                v.FrameCnt := fromUslv(Ratio_v);
            else
                v.InChCnt := r.InChCnt + 1;
            end if;
        end if;
        if v.InChCnt = Channels_g-1 and v.FrameCnt /= 0 then
            v.InRdy := '0';
        else
            v.InRdy := '1';
        end if;

        -- *** Input Registers ***
        v.VldIn_0 := '0';
        if InAcpt_v then
            v.VldIn_0 := '1';
            v.Input_0 := In_Data;
        end if;

        -- *** Stage Diff 1 ***
        -- First differentiator
        v.VldDiff(1) := CicIn_Valid;
        if CicIn_Valid = '1' then
            v.DiffVal(1) := cl_fix_sub(DiffIn_0, DiffFmt_c,
                                       DiffDel(0), DiffFmt_c,
                                       DiffFmt_c, Trunc_s, None_s);
        end if;

        -- *** Diff Stages (2 to Order-1) ***
        for stage in 1 to Stages_c-1 loop
            if r.VldDiff(stage) = '1' then
                v.DiffVal(stage+1) := cl_fix_sub(r.DiffVal(stage), DiffFmt_c,
                                                 DiffDel(stage), DiffFmt_c,
                                                 DiffFmt_c, Trunc_s, None_s);
            end if;
        end loop;

        -- *** Running Sum ***
        -- Sum over DiffDelay_g samples of the same channel (replaces the last comb stage, see documentation)
        v.VldSum := r.VldDiff(Stages_c);
        if r.VldDiff(Stages_c) = '1' then
            Sum_v := cl_fix_resize(r.DiffVal(Stages_c), DiffFmt_c, HoldFmt_c, Trunc_s, None_s);

            for tap in 1 to DiffDelay_g-1 loop
                Sum_v := cl_fix_add(Sum_v, HoldFmt_c, SumTaps(tap), DiffFmt_c, HoldFmt_c, Trunc_s, None_s);
            end loop;

            v.SumVal := Sum_v;
        end if;

        -- *** Sample and Hold ***
        -- Each sample is held for Ratio clock cycles (data is held by olo_fix_sample_hold, valid is generated here)
        v.VldAccu(0) := '0';
        if TdmPar_Valid = '1' then
            v.VldAccu(0) := '1';
            v.HoldCnt    := fromUslv(Ratio_v);
        elsif r.HoldCnt /= 0 then
            v.VldAccu(0) := '1';
            v.HoldCnt    := r.HoldCnt - 1;
        end if;

        -- *** Stage Accu 1 ***
        -- First accumulator
        if r.VldAccu(0) = '1' then

            for ch in 0 to Channels_g-1 loop
                v.Accu(1)(ch) := cl_fix_add(r.Accu(1)(ch), AccuFmt_c,
                                            HoldData(ch), AccuFmt_c,
                                            AccuFmt_c, Trunc_s, None_s);
            end loop;

        end if;

        -- *** Accumulator Stages (2 to Order-1) ***
        for stage in 1 to Stages_c-1 loop
            if r.VldAccu(stage) = '1' then

                for ch in 0 to Channels_g-1 loop
                    v.Accu(stage+1)(ch) := cl_fix_add(r.Accu(stage+1)(ch), AccuFmt_c,
                                                      r.Accu(stage)(ch), AccuFmt_c,
                                                      AccuFmt_c, Trunc_s, None_s);
                end loop;

            end if;
        end loop;

        -- Apply to record
        r_next <= v;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Output Assignment
    -----------------------------------------------------------------------------------------------
    In_Ready  <= r.InRdy;
    Out_Valid <= OutVld(0);

    -----------------------------------------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.InRdy    <= '0';
                r.InChCnt  <= 0;
                r.FrameCnt <= 0;
                r.VldIn_0  <= '0';
                r.VldDiff  <= (others => '0');
                r.VldSum   <= '0';
                r.HoldCnt  <= 0;
                r.VldAccu  <= (others => '0');
                r.Accu     <= (others => (others => (others => '0')));
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Simulation Checks
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    p_assert : process (Clk) is
        variable ChCnt_v : natural range 0 to Channels_g - 1;
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                ChCnt_v := 0;
            else
                -- Input TDM frame boundaries
                if In_Valid = '1' and r.InRdy = '1' then
                    if In_Last = '1' then
                        -- Only report if In_Last is asserted when NOT expected
                        assert ChCnt_v = Channels_g - 1
                            report errorMessage(EntityName_c, "In_Last asserted at channel index " &
                                   integer'image(ChCnt_v) & " but expected at " & integer'image(Channels_g - 1))
                            severity error;
                    end if;

                    if ChCnt_v = Channels_g - 1 then
                        ChCnt_v := 0;
                    else
                        ChCnt_v := ChCnt_v + 1;
                    end if;
                end if;

                -- Internal consistency (sample and hold must be completed when next sample arrives)
                assert not (TdmPar_Valid = '1' and r.HoldCnt /= 0)
                    report errorMessage(EntityName_c, "Internal error: sample arrived during sample and hold")
                    severity error;
            end if;
        end if;
    end process;

    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
    -- *** Gain Correction ***
    -- Gain correction is done at the input, so only one multiplier is required for all channels. Rounding errors
    -- are not accumulated because the CIC filter as a whole (combs plus integrators) is an FIR filter.
    g_gc : if GainCorrOn_c generate
        signal GcCoef_0 : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0);
    begin

        GcCoef_0 <= FixedGc_c when FixedRatio_g else r.GcCoef;

        i_gc_mult : entity work.olo_fix_mult
            generic map (
                AFmt_g      => to_string(InFmt_c),
                BFmt_g      => to_string(GainCorrCoefFmt_c),
                ResultFmt_g => to_string(GcOutFmt_c),
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                OpRegs_g    => 1,
                RoundReg_g  => "auto",
                SatReg_g    => "auto"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.VldIn_0,
                In_A       => r.Input_0,
                In_B       => GcCoef_0,
                Out_Valid  => CicIn_Valid,
                Out_Result => CicIn
            );

    end generate;

    g_no_gc : if not GainCorrOn_c generate
        CicIn_Valid <= r.VldIn_0;
        CicIn       <= r.Input_0;
    end generate;

    -- *** Diff-delays ***
    DiffIn_0 <= cl_fix_resize(CicIn, CicInFmt_c, DiffFmt_c, Trunc_s, None_s);

    g_diffdel : for stage in 0 to Stages_c-1 generate
        signal DiffDelIn  : std_logic_vector(cl_fix_width(DiffFmt_c)-1 downto 0);
        signal DiffDelVld : std_logic;
    begin
        DiffDelIn  <= DiffIn_0 when stage = 0 else r.DiffVal(max(stage, 1));
        DiffDelVld <= CicIn_Valid when stage = 0 else r.VldDiff(max(stage, 1));

        i_del : entity work.olo_base_delay
            generic map (
                Width_g       => cl_fix_width(DiffFmt_c),
                Delay_g       => Channels_g * DiffDelay_g,
                RstState_g    => true,
                Resource_g    => Resource_g,
                RamBehavior_g => RamBehavior_g,
                RamStyle_g    => RamStyle_g
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                In_Data  => DiffDelIn,
                In_Valid => DiffDelVld,
                Out_Data => DiffDel(stage)
            );

    end generate;

    -- *** Running Sum Taps ***
    -- Tap N holds the sample N samples back (of the same channel)
    g_sumtaps : for tap in 1 to DiffDelay_g-1 generate
        signal TapIn : std_logic_vector(cl_fix_width(DiffFmt_c)-1 downto 0);
    begin
        TapIn <= r.DiffVal(Stages_c) when tap = 1 else SumTaps(max(tap-1, 1));

        i_del : entity work.olo_base_delay
            generic map (
                Width_g       => cl_fix_width(DiffFmt_c),
                Delay_g       => Channels_g,
                RstState_g    => true,
                Resource_g    => Resource_g,
                RamBehavior_g => RamBehavior_g,
                RamStyle_g    => RamStyle_g
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                In_Data  => TapIn,
                In_Valid => r.VldDiff(Stages_c),
                Out_Data => SumTaps(tap)
            );

    end generate;

    -- *** Shifter ***
    -- Integrators are implemented for the maximum ratio. For smaller ratios, the data is shifted left before the
    -- integrators. This is equivalent to shifting the integrator output right (no information is lost) but requires
    -- only one shifter for all channels on the TDM side.
    SftIn <= cl_fix_resize(r.SumVal, HoldFmt_c, AccuFmt_c, Trunc_s, None_s);

    g_shift_conf : if not FixedRatio_g generate

        i_sft : entity work.olo_base_dyn_sft
            generic map (
                Direction_g       => "LEFT",
                SelBitsPerStage_g => 4,
                MaxShift_g        => max(MaxShift_c, 1),
                Width_g           => AccuWidth_c
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Valid  => r.VldSum,
                In_Shift  => r.SftSel,
                In_Data   => SftIn,
                Out_Valid => SftOut_Valid,
                Out_Data  => SftOut
            );

    end generate;

    g_shift_fixed : if FixedRatio_g generate
        SftOut_Valid <= r.VldSum;
        SftOut       <= SftIn;
    end generate;

    -- *** TDM to parallel conversion before sample and hold ***
    i_tdmpar : entity work.olo_base_wconv_n2xn
        generic map (
            InWidth_g  => AccuWidth_c,
            OutWidth_g => AccuWidth_c * Channels_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => SftOut_Valid,
            In_Ready    => open,
            In_Data     => SftOut,
            Out_Valid   => TdmPar_Valid,
            Out_Ready   => '1',
            Out_Data    => TdmPar_Data,
            Out_Last    => open,
            Out_WordEna => open
        );

    -- *** Sample and Hold (per channel) ***
    g_hold : for ch in 0 to Channels_g-1 generate

        i_hold : entity work.olo_fix_sample_hold
            generic map (
                Fmt_g => to_string(AccuFmt_c)
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Data   => TdmPar_Data(AccuWidth_c*(ch+1)-1 downto AccuWidth_c*ch),
                In_Valid  => TdmPar_Valid,
                Out_Data  => HoldData(ch),
                Out_Valid => open
            );

    end generate;

    -- *** Output Stage (per channel) ***
    g_out : for ch in 0 to Channels_g-1 generate
        signal SftData : std_logic_vector(cl_fix_width(SftFmt_c) - 1 downto 0);
    begin

        -- Shift is pure wiring (reinterpretation of the integrator output)
        SftData <= cl_fix_shift(r.Accu(Stages_c)(ch), AccuFmt_c, -MaxShift_c, SftFmt_c, Trunc_s, None_s);

        i_resize_out : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(SftFmt_c),
                ResultFmt_g => to_string(OutFmt_c),
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => "auto",
                SatReg_g    => "auto"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.VldAccu(Stages_c),
                In_A       => SftData,
                Out_Valid  => OutVld(ch),
                Out_Result => Out_Data(OutWidth_c*(ch+1)-1 downto OutWidth_c*ch)
            );

    end generate;

end architecture;
