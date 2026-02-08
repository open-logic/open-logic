---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a CIC decimator. It supports one or multiple channels (time-division-multiplexed).
-- The decimation ratio can either be configurable or fixed.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cic_dec_tdm.md
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
entity olo_fix_cic_dec_tdm is
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
        In_Data      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_Last      : in    std_logic := '0';

        -- Output
        Out_Valid    : out   std_logic;
        Out_Data     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Last     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_cic_dec_tdm is

    -- String upping
    constant GainCorrCoefFmtUpper_c : string := toUpper(GainCorrCoefFmt_g);

    -- Formats
    constant InFmt_c           : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c          : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant GainCorrCoefFmt_c : FixFormat_t := fixFmtFromStringTolerant(GainCorrCoefFmtUpper_c);

    -- Constants
    constant MaxCicGain_c    : real    := (real(Ratio_g) * real(DiffDelay_g))**real(Order_g);
    constant MaxCicAddBits_c : natural := log2ceil(MaxCicGain_c - 0.1);
    -- ... WORKAROUND: Vivado does real calculations imprecisely. With the -0.1, wrong results are avoided.
    constant MaxShift_c      : natural     := MaxCicAddBits_c;
    constant AccuFmt_c       : FixFormat_t := (InFmt_c.S, InFmt_c.I + MaxCicAddBits_c, InFmt_c.F);
    constant DiffFmt_c       : FixFormat_t := (OutFmt_c.S, InFmt_c.I, OutFmt_c.F + Order_g + 1);
    constant GcInFmt_c       : FixFormat_t := (1, OutFmt_c.I, work.olo_base_pkg_math.min(OutFmt_c.F + 2, DiffFmt_c.F));
    constant SftFmt_c        : FixFormat_t := (AccuFmt_c.S, AccuFmt_c.I, max(AccuFmt_c.F, DiffFmt_c.F));
    constant RealGc_c        : real        := 2.0**real(MaxCicAddBits_c)/MaxCicGain_c;

    constant FixedGc_c : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0) :=
        cl_fix_from_real(RealGc_c, GainCorrCoefFmt_c);

    -- Types
    type Accus_t is array (natural range <>) of std_logic_vector(cl_fix_width(AccuFmt_c) - 1 downto 0);
    type Diff_t is array (natural range <>) of std_logic_vector(cl_fix_width(DiffFmt_c) - 1 downto 0);

    -- Two Process Method
    type TwoProcess_r is record
        -- GainCorr Registers
        GcCoef    : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0);
        -- Accu Section
        Input_0   : std_logic_vector(cl_fix_width(InFmt_c) - 1 downto 0);
        VldAccu   : std_logic_vector(0 to Order_g);
        Accu      : Accus_t(1 to Order_g);
        Rcnt      : integer range 0 to Ratio_g - 1;
        Chcnt     : integer range 0 to Channels_g - 1;
        -- Diff Section
        DiffIn_0  : std_logic_vector(cl_fix_width(DiffFmt_c) - 1 downto 0);
        VldDiff   : std_logic_vector(0 to Order_g);
        DiffVal   : Diff_t(1 to Order_g);
        -- Output
        OutChCnt  : natural range 0 to Channels_g - 1;
        Outp      : std_logic_vector(cl_fix_width(OutFmt_c) - 1 downto 0);
        Out_Valid : std_logic;
        Out_Last  : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Component Connection Signals
    signal DiffDel      : Diff_t(0 to Order_g - 1);
    signal IntDel       : Accus_t(1 to Order_g);
    signal ShiftVld     : std_logic;
    signal ShiftDataOut : std_logic_vector(cl_fix_width(SftFmt_c) - 1 downto 0);

    -- Gain Correction Signals
    signal CompOut    : std_logic_vector(cl_fix_width(OutFmt_c) - 1 downto 0);
    signal CompOutVld : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert (GainCorrCoefFmtUpper_c = "NONE" or GainCorrCoefFmt_c.I = 1)
        report "olo_fix_cic_dec_tdm: Gain correction coefficient format must have 1 integer bit (or be NONE)"
        severity failure;
    assert (GainCorrCoefFmtUpper_c = "NONE" or GainCorrCoefFmt_c.S = 0)
        report "olo_fix_cic_dec_tdm: Gain correction coefficient format must be unsigned (or be NONE)"
        severity failure;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v        : TwoProcess_r;
        variable AccuIn_v : Accus_t(1 to Order_g);
        variable Ratio_v  : std_logic_vector(Cfg_Ratio'range);
    begin
        -- hold variables stable
        v := r;

        -- Ratio from port or constant
        if FixedRatio_g then
            Ratio_v := toUslv(Ratio_g - 1, Cfg_Ratio'length);
        else
            Ratio_v := Cfg_Ratio;
        end if;

        -- *** Pipe Handling ***
        v.VldAccu(v.VldAccu'low + 1 to v.VldAccu'high) := r.VldAccu(r.VldAccu'low to r.VldAccu'high - 1);
        v.VldDiff(v.VldDiff'low + 1 to v.VldDiff'high) := r.VldDiff(r.VldDiff'low to r.VldDiff'high - 1);

        -- *** Stage Accu 0 ***
        -- Input Registers
        v.VldAccu(0) := In_Valid;
        v.Input_0    := In_Data;

        -- Select accumulator input (register for single channel, delay line other wise)
        if Channels_g = 1 then
            AccuIn_v := r.Accu;
        else
            AccuIn_v := IntDel;
        end if;

        -- *** Stage Accu 1 ***
        -- First accumulator
        if r.VldAccu(0) = '1' then
            v.Accu(1) := cl_fix_add(AccuIn_v(1), AccuFmt_c,
                                    r.Input_0, InFmt_c,
                                    AccuFmt_c, Trunc_s, None_s);
        end if;

        -- *** Accumuator Stages (2 to Order) ***
        for stage in 1 to Order_g - 1 loop
            if r.VldAccu(stage) = '1' then
                v.Accu(stage + 1) := cl_fix_add(AccuIn_v(stage + 1), AccuFmt_c,
                                                r.Accu(stage), AccuFmt_c,
                                                AccuFmt_c, Trunc_s, None_s);
            end if;
        end loop;

        -- *** Stage Diff 0 ***
        -- Decimate
        v.VldDiff(0) := '0';
        if ShiftVld = '1' then
            -- channel counter
            if r.Chcnt = 0 then
                v.Chcnt := Channels_g - 1;
                if r.Rcnt = 0 then
                    v.Rcnt := fromUslv(Ratio_v);
                else
                    v.Rcnt := r.Rcnt - 1;
                end if;
            else
                v.Chcnt := r.Chcnt - 1;
            end if;
            -- Resample
            if r.Rcnt = 0 then
                v.VldDiff(0) := '1';
                v.DiffIn_0   := cl_fix_resize(ShiftDataOut, SftFmt_c, DiffFmt_c, Trunc_s, None_s);
            end if;
        end if;

        -- *** Stage Diff 1 ***
        -- First differentiator
        if r.VldDiff(0) = '1' then
            -- Differentiate
            v.DiffVal(1) := cl_fix_sub(r.DiffIn_0, DiffFmt_c,
                                       DiffDel(0), DiffFmt_c,
                                       DiffFmt_c, Trunc_s, None_s);
        end if;

        -- *** Diff Stages ***
        -- Differentiators
        for stage in 1 to Order_g - 1 loop
            if r.VldDiff(stage) = '1' then
                -- Differentiate
                v.DiffVal(stage + 1) := cl_fix_sub(r.DiffVal(stage), DiffFmt_c,
                                                   DiffDel(stage), DiffFmt_c,
                                                   DiffFmt_c, Trunc_s, None_s);
            end if;
        end loop;

        if GainCorrCoefFmtUpper_c /= "NONE" then
            -- *** Gain Coefficient Register ***
            v.GcCoef := Cfg_GainCorr;
        end if;

        -- *** Output Assignment ***
        v.Outp      := CompOut;
        v.Out_Valid := CompOutVld;

        -- *** Last calculation for TDM output ***
        v.Out_Last := '0';
        if v.Out_Valid = '1' then
            if r.OutChCnt = Channels_g - 1 then
                v.Out_Last := '1';
                v.OutChCnt := 0;
            else
                v.OutChCnt := r.OutChCnt + 1;
            end if;
        end if;

        -- Apply to record
        r_next <= v;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Output Assignment
    -----------------------------------------------------------------------------------------------
    Out_Valid <= r.Out_Valid;
    Out_Data  <= r.Outp;
    Out_Last  <= r.Out_Last;

    -----------------------------------------------------------------------------------------------
    -- Sequential Process
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.VldAccu   <= (others => '0');
                r.Accu      <= (others => (others => '0'));
                r.Rcnt      <= 0;
                r.Chcnt     <= Channels_g - 1;
                r.VldDiff   <= (others => '0');
                r.OutChCnt  <= 0;
                r.Out_Valid <= '0';
                r.Out_Last  <= '0';
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
                if In_Last = '1' then
                    -- Only report if In_Last is asserted when NOT expected
                    assert ChCnt_v = Channels_g - 1
                        report "olo_fix_cic_dec_tdm: In_Last asserted at channel index " & integer'image(ChCnt_v) &
                               " but expected at " & integer'image(Channels_g - 1)
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
    -- *** Gain Correction Chain ***
    g_gc : if GainCorrCoefFmtUpper_c /= "NONE" generate
        signal GcIn_0   : std_logic_vector(cl_fix_width(GcInFmt_c) - 1 downto 0);
        signal GcCoef_0 : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0);
    begin

        GcIn_0 <= cl_fix_resize(r.DiffVal(Order_g), DiffFmt_c, GcInFmt_c, Trunc_s, None_s);

        -- Multiplier
        GcCoef_0 <= FixedGc_c when FixedRatio_g else r.GcCoef;

        i_gc_mult : entity work.olo_fix_mult
            generic map (
                AFmt_g      => to_string(GcInFmt_c),
                BFmt_g      => to_string(GainCorrCoefFmt_c),
                ResultFmt_g => to_string(OutFmt_c),
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                OpRegs_g    => 1,
                RoundReg_g  => "auto",
                SatReg_g    => "auto"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.VldDiff(Order_g),
                In_A       => GcIn_0,
                In_B       => GcCoef_0,
                Out_Valid  => CompOutVld,
                Out_Result => CompOut
            );

    end generate;

    g_no_gc : if GainCorrCoefFmtUpper_c = "NONE" generate

        i_resize_out : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(DiffFmt_c),
                ResultFmt_g => to_string(OutFmt_c),
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => "auto",
                SatReg_g    => "auto"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.VldDiff(Order_g),
                In_A       => r.DiffVal(Order_g),
                Out_Valid  => CompOutVld,
                Out_Result => CompOut
            );

    end generate;

    -- *** Dynamic Shifter ***
    -- For configurable ratio, the shift is dynamic. For fixed ratio it is fixed.
    g_shift_conf : if not FixedRatio_g generate
        signal ShiftSel    : std_logic_vector(log2ceil(MaxShift_c + 1) - 1 downto 0);
        signal ShiftDataIn : std_logic_vector(cl_fix_width(SftFmt_c) - 1 downto 0);
    begin

        ShiftSel    <= Cfg_Shift(ShiftSel'range);
        ShiftDataIn <= cl_fix_resize(r.Accu(Order_g), AccuFmt_c, SftFmt_c);

        i_sft : entity work.olo_base_dyn_sft
            generic map (
                Direction_g       => "RIGHT",
                SelBitsPerStage_g => 4,
                MaxShift_g        => MaxShift_c,
                Width_g           => cl_fix_width(SftFmt_c),
                SignExtend_g      => true
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Valid  => r.VldAccu(Order_g),
                In_Shift  => ShiftSel,
                In_Data   => ShiftDataIn,
                Out_Valid => ShiftVld,
                Out_Data  => ShiftDataOut
            );

    end generate;

    g_shift_fixed : if FixedRatio_g generate
        -- Shift is combinatorial because it is pure wiring
        ShiftVld     <= r.VldAccu(Order_g);
        ShiftDataOut <= cl_fix_shift(r.Accu(Order_g), AccuFmt_c, -MaxShift_c, SftFmt_c, Trunc_s, None_s);
    end generate;

    -- *** Diff-delays ***
    g_diffdel : for stage in 0 to Order_g - 1 generate
        signal DiffDelIn : std_logic_vector(cl_fix_width(DiffFmt_c) - 1 downto 0);
        signal DiffVldIn : std_logic;
    begin
        DiffDelIn <= r.DiffIn_0 when stage = 0 else r.DiffVal(max(stage, 1));
        DiffVldIn <= r.VldDiff(0) when stage = 0 else r.VldDiff(max(stage, 1));

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

                -- Data
                In_Data  => DiffDelIn,
                In_Valid => DiffVldIn,
                Out_Data => DiffDel(stage)
            );

    end generate;

    -- *** Int-delays ***
    g_intdel_yes : if Channels_g > 1 generate

        g_intdel : for stage in 0 to Order_g - 1 generate

            i_del : entity work.olo_base_delay
                generic map (
                    Width_g       => cl_fix_width(AccuFmt_c),
                    Delay_g       => Channels_g - 1,
                    RstState_g    => true,
                    Resource_g    => Resource_g,
                    RamBehavior_g => RamBehavior_g,
                    RamStyle_g    => RamStyle_g
                )
                port map (
                    Clk      => Clk,
                    Rst      => Rst,

                    -- Data
                    In_Data  => r.Accu(stage + 1),
                    In_Valid => r.VldAccu(stage),
                    Out_Data => IntDel(stage + 1)
                );

        end generate;

    end generate;

end architecture;