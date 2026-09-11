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
-- olo_fix_private_lin_approx_qsin, which covers one quadrant.
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
    use work.olo_base_pkg_array.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_sin is
    generic (
        -- Formats
        OutFmt_g    : string;
        InFmt_g     : string;
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

    -- Supported output resolutions - one approximation table exists per resolution
    constant MinOutFracBits_c : positive := 10;
    constant MaxOutFracBits_c : positive := 20;

    -- Formats
    constant QuadrantFmt_c : FixFormat_t := (0, 0, 2);
    constant QPhaseFmt_c   : FixFormat_t := (0, -2, InFmt_c.F);

    -- Latency of olo_fix_private_lin_approx_qsin.
    constant QsinLatency_c : positive := 8;

    -- Peak value of the wave and the values at the critical angles (0, 90, 180 and 270 degrees)
    subtype Result_t is std_logic_vector(cl_fix_width(OutFmt_c) - 1 downto 0);

    -- Without integer bit the wave is scaled to 1.0-1LSB
    constant Peak_c    : Result_t := choose(OutFmt_c.I = 0, cl_fix_max_value(OutFmt_c), cl_fix_from_real(1.0, OutFmt_c));
    constant NegPeak_c : Result_t := cl_fix_neg(Peak_c, OutFmt_c, OutFmt_c, Trunc_s, None_s);
    constant Zero_c    : Result_t := (others => '0');

    -- Two Process Method
    type TwoProcess_r is record
        Quadrant    : StlvArray2_t(0 to QsinLatency_c + 1);
        Critical    : std_logic_vector(1 to QsinLatency_c + 1);
        Valid_0     : std_logic;
        QPhase_0    : std_logic_vector(cl_fix_width(QPhaseFmt_c) - 1 downto 0);
        Valid_1     : std_logic;
        QPhaseSin_1 : std_logic_vector(cl_fix_width(QPhaseFmt_c) - 1 downto 0);
        QPhaseCos_1 : std_logic_vector(cl_fix_width(QPhaseFmt_c) - 1 downto 0);
        Valid_10    : std_logic;
        OutSin_10   : Result_t;
        OutCos_10   : Result_t;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signals
    signal Quadrant   : std_logic_vector(1 downto 0);
    signal QPhaseFull : std_logic_vector(cl_fix_width(QPhaseFmt_c) - 1 downto 0);
    signal QsinValid  : std_logic;
    signal QsinSin    : Result_t;
    signal QsinCos    : Result_t;

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert OutFmt_c.S = 1
        report errorMessage(EntityName_c, "OutFmt_g must be signed")
        severity error;
    assert OutFmt_c.I = 0 or OutFmt_c.I = 1
        report errorMessage(EntityName_c, "OutFmt_g must have zero or one integer bit, got " &
               integer'image(OutFmt_c.I))
        severity error;
    assert OutFmt_c.F >= MinOutFracBits_c and OutFmt_c.F <= MaxOutFracBits_c
        report errorMessage(EntityName_c, "OutFmt_g must have between " &
               integer'image(MinOutFracBits_c) & " and " & integer'image(MaxOutFracBits_c) &
               " fractional bits, got " & integer'image(OutFmt_c.F))
        severity error;
    assert InFmt_c.F >= 3
        report errorMessage(EntityName_c, "InFmt_g must have at least three fractional bits")
        severity error;
    -- synthesis translate_on

    -- *** Input splitting ***
    -- Splitting the phase word into quadrant and quarter phase is pure wiring, hence it is done
    -- before the input register.
    Quadrant   <= cl_fix_resize(In_Data, InFmt_c, QuadrantFmt_c, Trunc_s, None_s);
    QPhaseFull <= cl_fix_resize(In_Data, InFmt_c, QPhaseFmt_c, Trunc_s, None_s);

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v           : TwoProcess_r;
        variable QPhaseNeg_v : std_logic_vector(cl_fix_width(QPhaseFmt_c) - 1 downto 0);
        variable SinVal_v    : std_logic_vector(Out_Sin'range);
        variable CosVal_v    : std_logic_vector(Out_Cos'range);
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Pipe Handling ***
        v.Quadrant(1 to v.Quadrant'high) := r.Quadrant(0 to r.Quadrant'high - 1);
        v.Critical(2 to v.Critical'high) := r.Critical(1 to r.Critical'high - 1);

        -- *** Input Stage ***
        -- The input is registered before any logic is applied to it
        v.Valid_0     := In_Valid;
        v.QPhase_0    := QPhaseFull;
        v.Quadrant(0) := Quadrant;

        -- *** Phase Mapping Stage ***
        QPhaseNeg_v := cl_fix_neg(r.QPhase_0, QPhaseFmt_c, QPhaseFmt_c, Trunc_s, None_s);
        v.Valid_1   := r.Valid_0;

        if r.Quadrant(0)(0) = '0' then
            v.QPhaseSin_1 := r.QPhase_0;
            v.QPhaseCos_1 := QPhaseNeg_v;
        else
            v.QPhaseSin_1 := QPhaseNeg_v;
            v.QPhaseCos_1 := r.QPhase_0;
        end if;

        if unsigned(r.QPhase_0) = 0 then
            v.Critical(1) := '1';
        else
            v.Critical(1) := '0';
        end if;

        -- *** Output Stage ***
        v.Valid_10 := QsinValid;

        -- Handle Critical Angle
        -- For a quarter phase of zero the mirrored phase wraps back to zero, hence the mirrored
        -- port does not deliver the peak value. Both results are exact for this angle anyway.
        SinVal_v := QsinSin;
        CosVal_v := QsinCos;

        if r.Critical(r.Critical'high) = '1' then
            if r.Quadrant(r.Quadrant'high)(0) = '0' then
                CosVal_v := Peak_c;
            else
                SinVal_v := Peak_c;
            end if;
        end if;

        -- Handle Quadrant
        case r.Quadrant(r.Quadrant'high) is
            when "00" =>
                v.OutSin_10 := SinVal_v;
                v.OutCos_10 := CosVal_v;
            when "01" =>
                v.OutSin_10 := SinVal_v;
                v.OutCos_10 := cl_fix_neg(CosVal_v, OutFmt_c, OutFmt_c, Trunc_s, None_s);
            when "10" =>
                v.OutSin_10 := cl_fix_neg(SinVal_v, OutFmt_c, OutFmt_c, Trunc_s, None_s);
                v.OutCos_10 := cl_fix_neg(CosVal_v, OutFmt_c, OutFmt_c, Trunc_s, None_s);
            when others =>
                v.OutSin_10 := cl_fix_neg(SinVal_v, OutFmt_c, OutFmt_c, Trunc_s, None_s);
                v.OutCos_10 := CosVal_v;
        end case;

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
                r.Valid_0  <= '0';
                r.Valid_1  <= '0';
                r.Valid_10 <= '0';
            end if;
        end if;
    end process;

    -- *** Outputs ***
    Out_Valid <= r.Valid_10;
    Out_Sin   <= r.OutSin_10;

    g_cos_out : if CosOutput_g generate
        Out_Cos <= r.OutCos_10;
    end generate;

    g_ncos_out : if not CosOutput_g generate
        Out_Cos <= (others => '0');
    end generate;

    -- *** Component Instantiations ***

    -- Approximation of one quadrant
    i_qsin : entity work.olo_fix_private_lin_approx_qsin
        generic map (
            OutFmt_g   => OutFmt_g,
            InFmt_g    => to_string(QPhaseFmt_c),
            UsePortB_g => CosOutput_g,
            MemStyle_g => MemStyle_g,
            Round_g    => Round_g,
            Saturate_g => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => r.Valid_1,
            In_A      => r.QPhaseSin_1,
            In_B      => r.QPhaseCos_1,
            Out_Valid => QsinValid,
            Out_A     => QsinSin,
            Out_B     => QsinCos
        );

end architecture;
