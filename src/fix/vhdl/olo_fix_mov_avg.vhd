---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a moving average.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_mov_avg.md
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
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_mov_avg is
    generic (
        -- Formats / Round / Saturate
        InFmt_g           : string;
        OutFmt_g          : string;
        Taps_g            : positive;
        GainCorrCoefFmt_g : string := "(0, 1, 16)";
        GainCorrDataFmt_g : string := "AUTO";
        GainCorrType_g    : string := "EXACT";
        Round_g           : string := FixRound_Trunc_c;
        Saturate_g        : string := FixSaturate_Warn_c;
        -- Registers
        RoundReg_g        : string := "YES";
        SatReg_g          : string := "YES";
        -- Resource control generics
        RamBehavior_g     : string := "RBW";
        RamStyle_g        : string := "auto";
        Resource_g        : string := "AUTO"
    );
    port (
        -- Control Ports
        Clk         : in    std_logic := '0';
        Rst         : in    std_logic := '0';
        -- Input
        In_Valid    : in    std_logic := '1';
        In_Data     : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Result  : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_mov_avg is

    -- Constants
    constant AddBits_c         : integer     := log2ceil(Taps_g);
    constant OutFmt_c          : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant InFmt_c           : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant DiffFmt_c         : FixFormat_t := cl_fix_sub_fmt(InFmt_c, InFmt_c);
    constant MovSumFmt_c       : FixFormat_t := (InFmt_c.S, InFmt_c.I + AddBits_c, InFmt_c.F);
    constant GainCorrCoefFmt_c : FixFormat_t := cl_fix_format_from_string(GainCorrCoefFmt_g);
    constant GainCorrDataFmt_c : FixFormat_t := choose(compareNoCase(GainCorrDataFmt_g, "AUTO"),
                                                       (OutFmt_c.S, InFmt_c.I, OutFmt_c.F + 3),
                                                       fixFmtFromStringTolerant(GainCorrDataFmt_g));
    constant ShiftFmt_c        : FixFormat_t := cl_fix_shift_fmt(MovSumFmt_c, -AddBits_c);

    constant Gc_c    : real                                                           := 2.0**real(AddBits_c)/real(Taps_g);
    constant GcFix_c : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c) - 1 downto 0) := cl_fix_from_real(Gc_c, GainCorrCoefFmt_c);

    -- Two Process Method
    type TwoProcess_r is record
        Valid  : std_logic_vector(0 to 2);
        Data_0 : std_logic_vector(In_Data'range);
        Diff_1 : std_logic_vector(cl_fix_width(DiffFmt_c) - 1 downto 0);
        Sum_2  : std_logic_vector(cl_fix_width(MovSumFmt_c) - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    -- Instantiation Signals
    signal Del_Data : std_logic_vector(In_Data'range);

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert compareNoCase(GainCorrType_g, "EXACT") or compareNoCase(GainCorrType_g, "SHIFT") or compareNoCase(GainCorrType_g, "NONE")
        report "olo_fix_mov_avg -Invalid value for GainCorrType_g"
        severity error;
    assert GainCorrCoefFmt_c.S = 0 and GainCorrCoefFmt_c.I = 1
        report "olo_fix_mov_avg - GainCorrCoefFmt_g must be a (0,1,x) format"
        severity error;
    -- synthesis translate_on

    -- *** Combinatorial Proceess ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Stage 0 - Input Register ***
        v.Data_0   := In_Data;
        v.Valid(0) := In_Valid;

        -- *** Stage 1 - Calculate Difference ***
        v.Diff_1   := cl_fix_sub(r.Data_0, InFmt_c, Del_Data, InFmt_c, DiffFmt_c);
        v.Valid(1) := r.Valid(0);

        -- *** Stage 2 - Calculate Moving Sum ***
        if r.Valid(1) = '1' then
            v.Sum_2 := cl_fix_add(r.Diff_1, DiffFmt_c, r.Sum_2, MovSumFmt_c, MovSumFmt_c);
        end if;
        v.Valid(2) := r.Valid(1);

        -- *** Assign Signal ***
        r_next <= v;
    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;

            -- Reset
            if Rst = '1' then
                r.Valid <= (others => '0');
                r.Sum_2 <= (others => '0');
            end if;
        end if;
    end process;

    -- *** Component Instantiations ***

    -- Delay
    i_del : entity work.olo_base_delay
        generic map (
            Width_g       => In_Data'length,
            Delay_g       => Taps_g,
            RstState_g    => True,
            Resource_g    => Resource_g,
            RamBehavior_g => RamBehavior_g,
            RamStyle_g    => RamStyle_g
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            In_Valid => r.Valid(0),
            In_Data  => r.Data_0,
            Out_Data => Del_Data
        );

    -- Output Resize
    g_none : if compareNoCase(GainCorrType_g, "NONE") generate

        i_resize_none : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(MovSumFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => RoundReg_g,
                SatReg_g    => SatReg_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.Valid(2),
                In_A       => r.Sum_2,
                Out_Valid  => Out_Valid,
                Out_Result => Out_Result
            );

    end generate;

    -- Output Shift
    g_shift : if compareNoCase(GainCorrType_g, "SHIFT") or (isPower2(Taps_g) and compareNoCase(GainCorrType_g, "EXACT")) generate
        signal Shifted : std_logic_vector(cl_fix_width(ShiftFmt_c) - 1 downto 0);
    begin
        -- No register required for shifting (wiring only)
        Shifted <= cl_fix_shift(r.Sum_2, MovSumFmt_c, -AddBits_c, ShiftFmt_c);

        i_resize_shift : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(ShiftFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => RoundReg_g,
                SatReg_g    => SatReg_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.Valid(2),
                In_A       => Shifted,
                Out_Valid  => Out_Valid,
                Out_Result => Out_Result
            );

    end generate;

    -- Output Gain Correction
    g_gain_corr : if compareNoCase(GainCorrType_g, "EXACT") and not isPower2(Taps_g) generate
        signal Shifted : std_logic_vector(cl_fix_width(GainCorrDataFmt_c) - 1 downto 0);
    begin
        -- No register required for shifting (wiring only)
        Shifted <= cl_fix_shift(r.Sum_2, MovSumFmt_c, -AddBits_c, GainCorrDataFmt_c, Trunc_s, Warn_s);

        i_gc : entity work.olo_fix_mult
            generic map (
                AFmt_g      => to_string(GainCorrDataFmt_c),
                BFmt_g      => to_string(GainCorrCoefFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => RoundReg_g,
                SatReg_g    => SatReg_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => r.Valid(2),
                In_A       => Shifted,
                In_B       => GcFix_c,
                Out_Valid  => Out_Valid,
                Out_Result => Out_Result
            );

    end generate;

end architecture;
