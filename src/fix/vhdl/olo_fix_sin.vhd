---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity calculates sine and (optionally) cosine of a phase given in rotations, where 0.0
-- corresponds to 0 degrees and 1.0 corresponds to 360 degrees.
--
-- The entity implements the range reduction only. The approximation itself is done by
-- olo_fix_lin_approx_qsin, which covers one quadrant.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sin.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;
    use work.olo_fix_private_lin_approx_qsin_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_sin is
    generic (
        -- Formats
        OutFmt_g    : string  := "(1, 0, 16)";
        InFmt_g     : string  := "(0, 0, 18)";
        -- Configuration
        CosOutput_g : boolean := false;
        MemStyle_g  : string  := "auto";
        -- Round / Saturate
        Round_g     : string  := FixRound_NonSymPos_c;
        Saturate_g  : string  := FixSaturate_Sat_c
    );
    port (
        -- Control Ports
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Valid  : in    std_logic := '1';
        In_Data   : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        -- Output
        Out_Valid : out   std_logic;
        Out_Sin   : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Cos   : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_sin is

    -- Constants
    constant EntityName_c : string      := "olo_fix_sin";
    constant InFmt_c      : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Formats
    constant QuadrantFmt_c : FixFormat_t := (0, 0, 2);
    constant QPhaseFmt_c   : FixFormat_t := (0, -2, InFmt_c.F);

    -- The table is selected by name from the generated package - the same name is assembled by
    -- olo_fix_lin_approx_qsin and by the Python model (see qsin_table_name()).
    constant TableName_c  : string   := "qsin_i" & integer'image(OutFmt_c.I) &
                                            "f" & integer'image(OutFmt_c.F);
    constant Points_c     : positive := getTableSize(TableName_c);

    -- Latency of olo_fix_lin_approx_qsin. The quadrant is delayed by the same number of stages.
 --   constant QsinLatency_c : positive := 9;

    -- Peak value of the wave and the values at the critical angles (0, 90, 180 and 270 degrees)
 --   subtype Result_t is std_logic_vector(cl_fix_width(OutFmt_c) - 1 downto 0);
 --   type Critical_t is array (0 to 3) of Result_t;

    -- Without integer bit the wave is scaled to 1.0-1LSB, hence the peak is the largest
    -- representable value. With integer bit the wave is unscaled.
    function peakValue return std_logic_vector is
    begin
        if OutFmt_c.I = 0 then
            return cl_fix_max_value(OutFmt_c);
        end if;
        return cl_fix_from_real(1.0, OutFmt_c);
    end function;

    constant Peak_c    : Result_t := peakValue;
    constant NegPeak_c : Result_t := cl_fix_neg(Peak_c, OutFmt_c, OutFmt_c, Trunc_s, None_s);
    constant Zero_c    : Result_t := (others => '0');

    constant SinCritical_c : Critical_t := (Zero_c, Peak_c, Zero_c, NegPeak_c);
    constant CosCritical_c : Critical_t := (Peak_c, Zero_c, NegPeak_c, Zero_c);

    -- Types
    type Quadrant_t is array (natural range <>) of std_logic_vector(1 downto 0);

    -- Two Process Method
    -- The quadrant and the critical angle flag are delayed to arrive at the output stage together
    -- with the result of the approximation.
    type TwoProcess_r is record
        Quadrant  : Quadrant_t(0 to QsinLatency_c - 1);
        Critical  : std_logic_vector(0 to QsinLatency_c - 1);
        Out_Valid : std_logic;
        Out_Sin   : Result_t;
        Out_Cos   : Result_t;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signals
    signal Phase       : std_logic_vector(PhaseBits_c - 1 downto 0);
    signal Quadrant    : std_logic_vector(1 downto 0);
    signal InQuad      : std_logic_vector(InQuadBits_c - 1 downto 0);
    signal QuadAddr    : std_logic_vector(QuarterBits_c - 1 downto 0);
    signal QuadAddrMir : std_logic_vector(QuarterBits_c - 1 downto 0);
    signal Quarter     : std_logic_vector(QuarterBits_c - 1 downto 0);
    signal QsinValid   : std_logic;
    signal QsinSin     : Result_t;
    signal QsinCos     : Result_t;

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert OutFmt_c.S = 1
        report errorMessage(EntityName_c, "OutFmt_g must be signed")
        severity error;
    assert InFmt_c.F >= 3
        report errorMessage(EntityName_c, "InFmt_g must have at least three fractional bits")
        severity error;

    -- *** Range Reduction ***
    -- Dropping the integer bits and the sign wraps the phase into one rotation. This is pure wiring.
    Phase    <= cl_fix_resize(In_Data, InFmt_c, PhaseFmt_c, Trunc_s, None_s);
    Quadrant <= Phase(PhaseBits_c - 1 downto PhaseBits_c - 2);
    InQuad   <= Phase(InQuadBits_c - 1 downto 0);

    QuadAddr <= InQuad;

    -- The wave is symmetric around the quadrant boundaries, hence the quarter phase is mirrored in
    -- the odd quadrants. The two's complement is exactly 1-a for every a /= 0 - the a = 0 case is
    -- covered by the critical angles in the output stage.
    QuadAddrMir <= std_logic_vector(0 - unsigned(QuadAddr));
    Quarter     <= QuadAddrMir when Quadrant(0) = '1' else QuadAddr;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Pipe Handling ***
        v.Quadrant(1 to v.Quadrant'high) := r.Quadrant(0 to r.Quadrant'high - 1);
        v.Critical(1 to v.Critical'high) := r.Critical(0 to r.Critical'high - 1);

        -- *** Input Stage ***
        v.Quadrant(0) := Quadrant;
        v.Critical(0) := '0';

        if unsigned(InQuad) = 0 then
            v.Critical(0) := '1';
        end if;

        -- *** Output Stage ***
        v.Out_Valid := QsinValid;

        -- The sine is negative in the lower half plane, the cosine in the left half plane
        v.Out_Sin := QsinSin;

        if r.Quadrant(r.Quadrant'high)(1) = '1' then
            v.Out_Sin := cl_fix_neg(QsinSin, OutFmt_c, OutFmt_c, Trunc_s, None_s);
        end if;

        v.Out_Cos := QsinCos;

        if (r.Quadrant(r.Quadrant'high)(1) xor r.Quadrant(r.Quadrant'high)(0)) = '1' then
            v.Out_Cos := cl_fix_neg(QsinCos, OutFmt_c, OutFmt_c, Trunc_s, None_s);
        end if;

        -- The critical angles are exact. They must be handled separately because the mirrored
        -- quarter phase wraps to zero for them.
        if r.Critical(r.Critical'high) = '1' then
            v.Out_Sin := SinCritical_c(to_integer(unsigned(r.Quadrant(r.Quadrant'high))));
            v.Out_Cos := CosCritical_c(to_integer(unsigned(r.Quadrant(r.Quadrant'high))));
        end if;

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
                r.Critical  <= (others => '0');
                r.Out_Valid <= '0';
            end if;
        end if;
    end process;

    -- *** Outputs ***
    Out_Valid <= r.Out_Valid;
    Out_Sin   <= r.Out_Sin;

    g_cos_out : if CosOutput_g generate
        Out_Cos <= r.Out_Cos;
    end generate;

    g_ncos_out : if not CosOutput_g generate
        Out_Cos <= (others => '0');
    end generate;

    -- *** Component Instantiations ***

    -- Approximation of one quadrant
    i_qsin : entity work.olo_fix_lin_approx_qsin
        generic map (
            OutFmt_g    => OutFmt_g,
            InFmt_g     => to_string(QuarterFmt_c),
            CosOutput_g => CosOutput_g,
            MemStyle_g  => MemStyle_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Data   => Quarter,
            Out_Valid => QsinValid,
            Out_Sin   => QsinSin,
            Out_Cos   => QsinCos
        );

end architecture;
