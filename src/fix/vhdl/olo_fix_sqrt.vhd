---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
--
-- The concept (normalization into the range of a linear approximation through shifting) is based
-- on psi_fix_sqrt from the PSI psi_fix library
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity calculates the square root of the input.
--
-- The entity implements the normalization only. The approximation itself is done by
-- olo_fix_private_lin_approx_sqrt, which covers the range [0.25, 1).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sqrt.md
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
    use work.olo_base_pkg_logic.all;
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_sqrt is
    generic (
        -- Formats
        OutFmt_g        : string;
        InFmt_g         : string;
        -- Configuration
        PrecisionBits_g : positive := 18;
        MemStyle_g      : string   := "auto";
        -- Round / Saturate
        Round_g         : string   := FixRound_NonSymPos_c;
        Saturate_g      : string   := FixSaturate_Sat_c
    );
    port (
        -- Control Ports
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        -- Input
        In_Valid   : in    std_logic := '1';
        In_Data    : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        -- Output
        Out_Valid  : out   std_logic;
        Out_Result : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_sqrt is

    -- Constants
    constant EntityName_c : string      := "olo_fix_sqrt";
    constant InFmt_c      : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant InWidth_c    : positive    := cl_fix_width(InFmt_c);

    -- Supported precisions - one approximation table exists per precision. The list is the same as
    -- the one in the SQRT_TABLES dictionary of the Python model.
    constant PrecisionSupported_c : boolean := PrecisionBits_g = 10 or PrecisionBits_g = 14 or
                                               PrecisionBits_g = 18 or PrecisionBits_g = 20;

    -- Normalization. The input bits are reinterpreted as a value in [0, 0.5) - the additional bit
    -- at the top guarantees that the normalization shift is never negative. Reinterpreting is a
    -- shift by the constant NormSft_c and hence pure wiring.
    constant NormSft_c   : integer     := InFmt_c.I + 1;
    constant NormInFmt_c : FixFormat_t := (0, -1, InWidth_c + 1);
    constant NormFmt_c   : FixFormat_t := (0, 0, InWidth_c + 1);
    constant MantFmt_c   : FixFormat_t := (0, 0, PrecisionBits_g + 2);
    constant ApproxFmt_c : FixFormat_t := (0, 0, PrecisionBits_g);

    -- Shift. The exponent left after the normalization must be even, because the square root halves
    -- it. Hence the shift has the fixed parity Parity_c - it is the number of leading zeros, rounded
    -- up to that parity. A zero input has no leading one - for it the shift is limited to its
    -- maximum, which yields a normalized value of zero.
    constant MaxShift_c        : positive := InWidth_c;
    constant Parity_c          : natural  := NormSft_c mod 2;
    constant ShiftBits_c       : positive := log2ceil(MaxShift_c + 1);
    constant SelBitsPerStage_c : positive := 4;

    -- Result of the approximation shifted back (lossless). The shift is halved, because the square
    -- root halves the exponent.
    constant MaxShiftOut_c  : positive    := max(1, (MaxShift_c - Parity_c)/2);
    constant ShiftOutBits_c : positive    := log2ceil(MaxShiftOut_c + 1);
    constant ShiftedFmt_c   : FixFormat_t := (0, 0, PrecisionBits_g + MaxShiftOut_c);
    -- The remaining part of the normalization is a shift by a constant, hence it is implemented by
    -- reinterpreting the shifted result - which is pure wiring.
    constant ConstSft_c     : integer     := (NormSft_c - Parity_c)/2;
    constant ResFmt_c       : FixFormat_t := (0, ShiftedFmt_c.I + ConstSft_c,
                                              ShiftedFmt_c.F - ConstSft_c);

    -- Latencies. Each barrel shifter has an input register plus one stage per SelBitsPerStage_c
    -- select bits.
    constant MaxInWidth_c    : positive := 256;
    constant SftLatency_c    : positive := (ShiftBits_c + SelBitsPerStage_c - 1)/SelBitsPerStage_c + 1;
    constant SftOutLatency_c : positive := (ShiftOutBits_c + SelBitsPerStage_c - 1)/SelBitsPerStage_c + 1;
    -- The table of the approximation has a fixed read latency of two clock cycles (see
    -- olo_fix_private_lin_approx_sqrt)
    constant TableLatency_c  : positive := 2;
    constant ApproxLatency_c : positive := work.olo_fix_lin_approx_pkg.linApproxLatency(TableLatency_c);
    -- The shift count is delayed from the shift stage to the output shifter
    constant ShiftLatency_c  : positive := SftLatency_c + ApproxLatency_c;

    -- Two Process Method
    type TwoProcess_r is record
        Valid_0  : std_logic;
        In_0     : std_logic_vector(In_Data'range);
        Valid_1  : std_logic;
        Norm_1   : std_logic_vector(cl_fix_width(NormFmt_c) - 1 downto 0);
        Sft_1    : std_logic_vector(ShiftBits_c - 1 downto 0);
        SftOut_1 : std_logic_vector(ShiftOutBits_c - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signals
    signal SftOutDel : std_logic_vector(ShiftOutBits_c - 1 downto 0);
    signal NormValid : std_logic;
    signal NormData  : std_logic_vector(cl_fix_width(NormFmt_c) - 1 downto 0);
    signal Mantissa  : std_logic_vector(cl_fix_width(MantFmt_c) - 1 downto 0);
    signal ApprValid : std_logic;
    signal ApprData  : std_logic_vector(cl_fix_width(ApproxFmt_c) - 1 downto 0);
    signal SftInData : std_logic_vector(cl_fix_width(ShiftedFmt_c) - 1 downto 0);
    signal SftValid  : std_logic;
    signal SftData   : std_logic_vector(cl_fix_width(ShiftedFmt_c) - 1 downto 0);

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert PrecisionSupported_c
        report errorMessage(EntityName_c, "PrecisionBits_g must be 10, 14, 18 or 20, got " &
               integer'image(PrecisionBits_g))
        severity error;
    assert InFmt_c.S = 0
        report errorMessage(EntityName_c, "InFmt_g must be unsigned - the square root is not " &
               "defined for negative numbers")
        severity error;
    assert InWidth_c >= 2
        report errorMessage(EntityName_c, "InFmt_g must be at least two bits wide")
        severity error;
    assert InWidth_c <= MaxInWidth_c
        report errorMessage(EntityName_c, "InFmt_g must be at most " & integer'image(MaxInWidth_c) &
               " bits wide")
        severity error;
    -- synthesis translate_on

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v          : TwoProcess_r;
        variable LeadZero_v : natural;
        variable Shift_v    : natural;
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Input Stage ***
        -- The input is registered before any logic is applied to it
        v.Valid_0 := In_Valid;
        v.In_0    := In_Data;

        -- *** Shift Count Stage ***
        -- The number of leading zeros of the input. For a zero input the function returns index
        -- zero, which limits the shift to its maximum.
        LeadZero_v := MaxShift_c - 1 - getLeadingSetBitIndex(r.In_0);
        -- Round the shift up to the parity the square root requires
        Shift_v := LeadZero_v + ((LeadZero_v + Parity_c) mod 2);

        v.Valid_1  := r.Valid_0;
        v.Norm_1   := cl_fix_resize(r.In_0, NormInFmt_c, NormFmt_c, Trunc_s, None_s);
        v.Sft_1    := toUslv(Shift_v, ShiftBits_c);
        v.SftOut_1 := toUslv((Shift_v - Parity_c)/2, ShiftOutBits_c);

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
                r.Valid_0 <= '0';
                r.Valid_1 <= '0';
            end if;
        end if;
    end process;

    -- *** Component Instantiations ***

    -- Normalization of the input into the range [0.25, 1)
    i_sft_in : entity work.olo_base_dyn_sft
        generic map (
            Direction_g       => "LEFT",
            SelBitsPerStage_g => SelBitsPerStage_c,
            MaxShift_g        => MaxShift_c,
            Width_g           => cl_fix_width(NormFmt_c),
            SignExtend_g      => false
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => r.Valid_1,
            In_Shift  => r.Sft_1,
            In_Data   => r.Norm_1,
            Out_Valid => NormValid,
            Out_Data  => NormData
        );

    -- Delay of the output shift count to the output shifter
    i_shift_del : entity work.olo_base_latency_comp
        generic map (
            Width_g       => ShiftOutBits_c,
            Mode_g        => "FIXED_CYCLES",
            Latency_g     => ShiftLatency_c,
            AssertsName_g => "shift"
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => r.SftOut_1,
            In_Valid  => r.Valid_1,
            Out_Data  => SftOutDel,
            Out_Valid => ApprValid
        );

    -- *** Approximation input ***
    -- Truncating the normalized value to the resolution the approximation requires is pure wiring.
    Mantissa <= cl_fix_resize(NormData, NormFmt_c, MantFmt_c, Trunc_s, None_s);

    -- Approximation of sqrt(x) in the range [0.25, 1)
    i_approx : entity work.olo_fix_private_lin_approx_sqrt
        generic map (
            OutFmt_g   => to_string(ApproxFmt_c),
            InFmt_g    => to_string(MantFmt_c),
            MemStyle_g => MemStyle_g,
            Round_g    => FixRound_NonSymPos_c,
            Saturate_g => FixSaturate_Sat_c
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => NormValid,
            In_Data   => Mantissa,
            Out_Valid => ApprValid,
            Out_Data  => ApprData
        );

    -- *** Approximation result in the format of the output shifter ***
    SftInData <= cl_fix_resize(ApprData, ApproxFmt_c, ShiftedFmt_c, Trunc_s, None_s);

    -- Compensation of the normalization shift
    i_sft_out : entity work.olo_base_dyn_sft
        generic map (
            Direction_g       => "RIGHT",
            SelBitsPerStage_g => SelBitsPerStage_c,
            MaxShift_g        => MaxShiftOut_c,
            Width_g           => cl_fix_width(ShiftedFmt_c),
            SignExtend_g      => false
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => ApprValid,
            In_Shift  => SftOutDel,
            In_Data   => SftInData,
            Out_Valid => SftValid,
            Out_Data  => SftData
        );

    -- Rounding and saturation to the user format. Reverting the remaining part of the normalization
    -- is pure wiring, hence the shifted result is reinterpreted (passed in as ResFmt_c).
    i_resize : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(ResFmt_c),
            ResultFmt_g => OutFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => "YES",
            SatReg_g    => "YES"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => SftValid,
            In_A       => SftData,
            Out_Valid  => Out_Valid,
            Out_Result => Out_Result
        );

end architecture;
