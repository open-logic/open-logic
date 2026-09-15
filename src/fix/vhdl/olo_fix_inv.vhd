---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity calculates the inverse (1/x) of the input.
--
-- The entity implements the normalization only. The approximation itself is done by
-- olo_fix_private_lin_approx_inv, which covers the range [1, 2).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_inv.md
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

entity olo_fix_inv is
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

architecture rtl of olo_fix_inv is

    -- Constants
    constant EntityName_c : string      := "olo_fix_inv";
    constant InFmt_c      : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Supported precisions - one approximation table exists per precision. The list is the same as
    -- the one in the INV_TABLES dictionary of the Python model.
    constant PrecisionSupported_c : boolean := PrecisionBits_g = 10 or PrecisionBits_g = 14 or
                                               PrecisionBits_g = 18 or PrecisionBits_g = 20;

    -- Absolute value of the input (lossless, hence one more integer bit for signed inputs)
    constant AbsFmt_c : FixFormat_t := (0, InFmt_c.I + InFmt_c.S, InFmt_c.F);

    -- Normalization. The leading one of the normalized value is implicit, hence only the mantissa
    -- fraction is passed to the approximation.
    constant MantFullFmt_c : FixFormat_t := (0, 1, cl_fix_width(AbsFmt_c) - 1);
    constant MantFmt_c     : FixFormat_t := (0, 0, PrecisionBits_g + 2);
    constant ApproxFmt_c   : FixFormat_t := (0, 1, PrecisionBits_g);

    -- Shift. A zero input has no leading one - for it the shift is limited to its maximum, which
    -- yields a mantissa of zero (like an input of 1.0).
    constant MaxShift_c        : positive := cl_fix_width(AbsFmt_c) - 1;
    constant ShiftBits_c       : positive := log2ceil(MaxShift_c + 1);
    constant SelBitsPerStage_c : positive := 4;

    -- Result of the approximation shifted back (lossless)
    constant ShiftedFmt_c : FixFormat_t := (0, cl_fix_width(AbsFmt_c), PrecisionBits_g);
    -- Reverting the normalization of the input is a shift by a constant, hence it is implemented
    -- by reinterpreting the shifted result - which is pure wiring.
    constant DenormFmt_c  : FixFormat_t := (0, ShiftedFmt_c.I + 1 - AbsFmt_c.I,
                                            ShiftedFmt_c.F + AbsFmt_c.I - 1);
    -- Signed for signed inputs, because the result of a negative input is negative
    constant ResFmt_c     : FixFormat_t := (InFmt_c.S, DenormFmt_c.I, DenormFmt_c.F);

    -- Latencies. With 4 select bits per stage, each barrel shifter has an input register plus one
    -- stage for shifts of up to 4 bits (inputs of up to 16 bits) and two stages for shifts of up to 8
    -- bits (inputs of up to 256 bits, the maximum supported).
    constant MaxInWidth_c    : positive := 256;
    constant SftLatency_c    : positive := choose(ShiftBits_c <= SelBitsPerStage_c, 2, 3);
    -- The table of the approximation has a fixed read latency of two clock cycles (see
    -- olo_fix_private_lin_approx_inv)
    constant TableLatency_c  : positive := 2;
    constant ApproxLatency_c : positive := work.olo_fix_lin_approx_pkg.linApproxLatency(TableLatency_c);
    -- The shift count is delayed from the shift count stage to the output shifter
    constant ShiftLatency_c  : positive := SftLatency_c + ApproxLatency_c;
    -- The sign is delayed from the input stage to the output stage (absolute value and shift count
    -- stage, both barrel shifters and the approximation)
    constant SignLatency_c   : positive := 2 + 2*SftLatency_c + ApproxLatency_c;

    -- Two Process Method
    type TwoProcess_r is record
        Valid_0 : std_logic;
        In_0    : std_logic_vector(In_Data'range);
        Valid_1 : std_logic;
        Abs_1   : std_logic_vector(cl_fix_width(AbsFmt_c) - 1 downto 0);
        Valid_2 : std_logic;
        Abs_2   : std_logic_vector(cl_fix_width(AbsFmt_c) - 1 downto 0);
        Shift_2 : std_logic_vector(ShiftBits_c - 1 downto 0);
        ValidR  : std_logic;
        Res     : std_logic_vector(cl_fix_width(ResFmt_c) - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signals
    signal InSign    : std_logic;
    signal ShiftComb : std_logic_vector(ShiftBits_c - 1 downto 0);
    signal ShiftDel  : std_logic_vector(ShiftBits_c - 1 downto 0);
    signal NormValid : std_logic;
    signal NormData  : std_logic_vector(cl_fix_width(AbsFmt_c) - 1 downto 0);
    signal Mantissa  : std_logic_vector(cl_fix_width(MantFmt_c) - 1 downto 0);
    signal ApprValid : std_logic;
    signal ApprData  : std_logic_vector(cl_fix_width(ApproxFmt_c) - 1 downto 0);
    signal SftInData : std_logic_vector(cl_fix_width(ShiftedFmt_c) - 1 downto 0);
    signal SftValid  : std_logic;
    signal SftData   : std_logic_vector(cl_fix_width(ShiftedFmt_c) - 1 downto 0);
    signal SignDel   : std_logic_vector(0 downto 0);

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert PrecisionSupported_c
        report errorMessage(EntityName_c, "PrecisionBits_g must be 10, 14, 18 or 20, got " &
               integer'image(PrecisionBits_g))
        severity error;
    assert cl_fix_width(InFmt_c) >= 2
        report errorMessage(EntityName_c, "InFmt_g must be at least two bits wide")
        severity error;
    assert cl_fix_width(InFmt_c) <= MaxInWidth_c
        report errorMessage(EntityName_c, "InFmt_g must be at most " & integer'image(MaxInWidth_c) &
               " bits wide")
        severity error;
    assert InFmt_c.S = 0 or OutFmt_c.S = 1
        report errorMessage(EntityName_c, "OutFmt_g must be signed because InFmt_g is signed")
        severity error;
    -- synthesis translate_on

    -- *** Input sign ***
    g_sign : if InFmt_c.S = 1 generate
        InSign <= r.In_0(r.In_0'high);
    end generate;

    g_nsign : if InFmt_c.S = 0 generate
        InSign <= '0';
    end generate;

    -- *** Normalization shift count ***
    -- The number of leading zeros of the absolute value. For a zero input the function returns
    -- index zero, which limits the shift to its maximum.
    ShiftComb <= std_logic_vector(to_unsigned(MaxShift_c - getLeadingSetBitIndex(r.Abs_1),
                                              ShiftBits_c));

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v        : TwoProcess_r;
        variable Denorm_v : std_logic_vector(cl_fix_width(ResFmt_c) - 1 downto 0);
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Input Stage ***
        -- The input is registered before any logic is applied to it
        v.Valid_0 := In_Valid;
        v.In_0    := In_Data;

        -- *** Absolute Value Stage ***
        v.Valid_1 := r.Valid_0;
        v.Abs_1   := cl_fix_abs(r.In_0, InFmt_c, AbsFmt_c, Trunc_s, None_s);

        -- *** Shift Count Stage ***
        v.Valid_2 := r.Valid_1;
        v.Abs_2   := r.Abs_1;
        v.Shift_2 := ShiftComb;

        -- *** Output Stage ***
        -- Reverting the normalization is pure wiring, hence the shifted result is reinterpreted
        v.ValidR := SftValid;
        Denorm_v := cl_fix_resize(SftData, DenormFmt_c, ResFmt_c, Trunc_s, None_s);

        -- Sign handling - the result of a negative input is negative
        if InFmt_c.S = 1 and SignDel(0) = '1' then
            v.Res := cl_fix_neg(Denorm_v, ResFmt_c, ResFmt_c, Trunc_s, None_s);
        else
            v.Res := Denorm_v;
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
                r.Valid_0 <= '0';
                r.Valid_1 <= '0';
                r.Valid_2 <= '0';
                r.ValidR  <= '0';
            end if;
        end if;
    end process;

    -- *** Component Instantiations ***

    -- Normalization of the input into the range [1, 2)
    i_sft_in : entity work.olo_base_dyn_sft
        generic map (
            Direction_g       => "LEFT",
            SelBitsPerStage_g => SelBitsPerStage_c,
            MaxShift_g        => MaxShift_c,
            Width_g           => cl_fix_width(AbsFmt_c),
            SignExtend_g      => false
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => r.Valid_2,
            In_Shift  => r.Shift_2,
            In_Data   => r.Abs_2,
            Out_Valid => NormValid,
            Out_Data  => NormData
        );

    -- Delay of the shift count to the output shifter
    i_shift_del : entity work.olo_base_latency_comp
        generic map (
            Width_g       => ShiftBits_c,
            Mode_g        => "FIXED_CYCLES",
            Latency_g     => ShiftLatency_c,
            AssertsName_g => "shift"
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => r.Shift_2,
            In_Valid  => r.Valid_2,
            Out_Data  => ShiftDel,
            Out_Valid => ApprValid
        );

    -- *** Mantissa fraction ***
    -- The normalized value is 1+m, the leading one is dropped. Truncating or zero padding the
    -- mantissa to the resolution the approximation requires is pure wiring.
    Mantissa <= cl_fix_resize(NormData, MantFullFmt_c, MantFmt_c, Trunc_s, None_s);

    -- Approximation of 1/x in the range [1, 2)
    i_approx : entity work.olo_fix_private_lin_approx_inv
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
            Direction_g       => "LEFT",
            SelBitsPerStage_g => SelBitsPerStage_c,
            MaxShift_g        => MaxShift_c,
            Width_g           => cl_fix_width(ShiftedFmt_c),
            SignExtend_g      => false
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => ApprValid,
            In_Shift  => ShiftDel,
            In_Data   => SftInData,
            Out_Valid => SftValid,
            Out_Data  => SftData
        );

    -- Delay of the input sign to the output stage
    i_sign_del : entity work.olo_base_latency_comp
        generic map (
            Width_g       => 1,
            Mode_g        => "FIXED_CYCLES",
            Latency_g     => SignLatency_c,
            AssertsName_g => "sign"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Data(0) => InSign,
            In_Valid   => r.Valid_0,
            Out_Data   => SignDel,
            Out_Valid  => SftValid
        );

    -- Rounding and saturation to the user format
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
            In_Valid   => r.ValidR,
            In_A       => r.Res,
            Out_Valid  => Out_Valid,
            Out_Result => Out_Result
        );

end architecture;
