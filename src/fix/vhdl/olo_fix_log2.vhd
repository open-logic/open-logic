---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity calculates the binary logarithm (log2(x)) of the input.
--
-- The entity implements the normalization only. The approximation itself is done by
-- olo_fix_private_lin_approx_log2, which covers the range [1, 2).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_log2.md
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

entity olo_fix_log2 is
    generic (
        -- Formats
        OutFmt_g   : string;
        InFmt_g    : string;
        -- Configuration
        MemStyle_g : string := "auto";
        -- Round / Saturate
        Round_g    : string := FixRound_NonSymPos_c;
        Saturate_g : string := FixSaturate_Sat_c
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

architecture rtl of olo_fix_log2 is

    -- Constants
    constant EntityName_c : string      := "olo_fix_log2";
    constant InFmt_c      : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant Round_c      : FixRound_t  := cl_fix_round_from_string(Round_g);
    constant InWidth_c    : positive    := cl_fix_width(InFmt_c);

    -- Supported precisions - one approximation table exists per precision. The list is the same as
    -- the one in the LOG2_TABLES dictionary of the Python model.
    type Precisions_t is array (natural range <>) of positive;

    constant Precisions_c : Precisions_t(0 to 3) := (10, 14, 18, 20);

    -- Select the smallest table delivering at least the fractional bits of the output. For
    -- unsupported formats the biggest table is returned, so that elaboration reaches the assertion.
    function getPrecisionBits return positive is
        variable Precision_v : positive := Precisions_c(Precisions_c'high);
    begin

        for i in Precisions_c'range loop
            if Precisions_c(i) >= OutFmt_c.F then
                Precision_v := Precisions_c(i);
                exit;
            end if;
        end loop;

        return Precision_v;
    end function;

    constant PrecisionBits_c : positive := getPrecisionBits;

    -- The fractional part cannot affect the result if it is truncated away, or if rounding to a
    -- multiple of two or more only adds an integer (rounding decision is independent of the
    -- fraction). Normalization and approximation are omitted in this case.
    constant OmitFrac_c : boolean := (OutFmt_c.F <= 0 and Round_c = Trunc_s) or
                                     (OutFmt_c.F < 0 and Round_c = NonSymPos_s);
    constant ResFrac_c  : natural := choose(OmitFrac_c, 0, PrecisionBits_c);

    -- Normalization. The leading one of the normalized value is implicit, hence only the mantissa
    -- fraction is passed to the approximation.
    constant MantFullFmt_c : FixFormat_t := (0, 1, InWidth_c - 1);
    constant MantFmt_c     : FixFormat_t := (0, 0, PrecisionBits_c + 2);
    constant ApproxFmt_c   : FixFormat_t := (0, 0, PrecisionBits_c);

    -- Shift. A zero input has no leading one - for it the shift is limited to its maximum, which
    -- yields a mantissa of zero (like the smallest non-zero input).
    constant MaxShift_c        : positive := InWidth_c - 1;
    -- The barrel shifter is dimensioned for a maximum shift of at least two, so the shift has at
    -- least two bits and the barrel shifter always has two pipeline stages.
    constant SftMaxShift_c     : positive    := max(2, MaxShift_c);
    constant ShiftBits_c       : positive    := log2ceil(SftMaxShift_c + 1);
    constant SelBitsPerStage_c : positive    := (ShiftBits_c + 1)/2;
    constant ShiftFmt_c        : FixFormat_t := (0, ShiftBits_c, 0);

    -- Integer part of the result. The input is x = 2^k * (1+m) with k = I-1-shift, which ranges
    -- from -F (smallest non-zero input) to I-1 (leading one in the MSB). The format is the
    -- smallest signed integer format covering the range, which needs 2^bits >= max(I, F).

    constant IntBits_c : natural                                               := max(log2ceil(max(InFmt_c.I, 0)), log2ceil(max(InFmt_c.F, 0)));
    constant IntFmt_c  : FixFormat_t                                           := (1, IntBits_c, 0);
    constant KConst_c  : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0) :=
        cl_fix_from_real(real(InFmt_c.I - 1), IntFmt_c);
    -- Integer part and fractional part are concatenated, hence it is pure wiring
    constant ResFmt_c  : FixFormat_t := (1, IntBits_c, ResFrac_c);

    -- Latencies. The barrel shifter has an input register plus two stages.
    constant MaxInWidth_c    : positive := 256;
    constant SftLatency_c    : positive := 3;
    -- The table of the approximation has a fixed read latency of two clock cycles (see
    -- olo_fix_private_lin_approx_log2)
    constant TableLatency_c  : positive := 2;
    constant ApproxLatency_c : positive := work.olo_fix_lin_approx_pkg.linApproxLatency(TableLatency_c);
    -- The integer part is registered one cycle after the input of the barrel shifter and delayed
    -- from there to the output of the approximation
    constant IntLatency_c    : positive := SftLatency_c + ApproxLatency_c - 1;

    -- Two Process Method
    type TwoProcess_r is record
        Valid_0 : std_logic;
        In_0    : std_logic_vector(In_Data'range);
        Valid_1 : std_logic;
        In_1    : std_logic_vector(In_Data'range);
        Idx_1   : std_logic_vector(ShiftBits_c - 1 downto 0);
        Valid_2 : std_logic;
        In_2    : std_logic_vector(In_Data'range);
        Shift_2 : std_logic_vector(ShiftBits_c - 1 downto 0);
        Valid_3 : std_logic;
        Int_3   : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signals
    signal ResValid : std_logic;
    signal Result   : std_logic_vector(cl_fix_width(ResFmt_c) - 1 downto 0);

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert OutFmt_c.F <= Precisions_c(Precisions_c'high)
        report errorMessage(EntityName_c, "OutFmt_g must have at most " &
               integer'image(Precisions_c(Precisions_c'high)) & " fractional bits, got " &
               integer'image(OutFmt_c.F))
        severity error;
    assert InFmt_c.S = 0
        report errorMessage(EntityName_c, "InFmt_g must be unsigned")
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
        variable v : TwoProcess_r;
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Input Stage ***
        -- The input is registered before any logic is applied to it
        v.Valid_0 := In_Valid;
        v.In_0    := In_Data;

        -- *** Leading One Stage ***
        -- Index of the leading one. For a zero input the function returns index zero, which limits
        -- the shift to its maximum in the next stage.
        v.Valid_1 := r.Valid_0;
        v.In_1    := r.In_0;
        v.Idx_1   := toUslv(getLeadingSetBitIndex(r.In_0), ShiftBits_c);

        -- *** Shift Count Stage ***
        -- The number of leading zeros
        v.Valid_2 := r.Valid_1;
        v.In_2    := r.In_1;
        v.Shift_2 := toUslv(MaxShift_c - fromUslv(r.Idx_1), ShiftBits_c);

        -- *** Integer Part Stage (I-1-shift) ***
        -- The result always fits into IntFmt_c, hence neither rounding nor saturation are required
        v.Valid_3 := r.Valid_2;
        v.Int_3   := cl_fix_sub(KConst_c, IntFmt_c, r.Shift_2, ShiftFmt_c, IntFmt_c, Trunc_s, None_s);

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
                r.Valid_3 <= '0';
            end if;
        end if;
    end process;

    -- *** Component Instantiations ***

    -- *** Fractional part required ***
    g_approx : if not OmitFrac_c generate
        signal IntDel    : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
        signal NormValid : std_logic;
        signal NormData  : std_logic_vector(InWidth_c - 1 downto 0);
        signal Mantissa  : std_logic_vector(cl_fix_width(MantFmt_c) - 1 downto 0);
        signal ApprData  : std_logic_vector(cl_fix_width(ApproxFmt_c) - 1 downto 0);
    begin

        -- Normalization of the input into the range [1, 2)
        i_sft_in : entity work.olo_base_dyn_sft
            generic map (
                Direction_g       => "LEFT",
                SelBitsPerStage_g => SelBitsPerStage_c,
                MaxShift_g        => SftMaxShift_c,
                Width_g           => InWidth_c,
                SignExtend_g      => false
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Valid  => r.Valid_2,
                In_Shift  => r.Shift_2,
                In_Data   => r.In_2,
                Out_Valid => NormValid,
                Out_Data  => NormData
            );

        -- Delay of the integer part to the output of the approximation
        i_int_del : entity work.olo_base_latency_comp
            generic map (
                Width_g       => cl_fix_width(IntFmt_c),
                Mode_g        => "FIXED_CYCLES",
                Latency_g     => IntLatency_c,
                AssertsName_g => "int"
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Data   => r.Int_3,
                In_Valid  => r.Valid_3,
                Out_Data  => IntDel,
                Out_Valid => ResValid
            );

        -- Mantissa fraction. The normalized value is 1+m, the leading one is dropped. Truncating or
        -- zero padding the mantissa to the resolution the approximation requires is pure wiring.
        Mantissa <= cl_fix_resize(NormData, MantFullFmt_c, MantFmt_c, Trunc_s, None_s);

        -- Approximation of log2(1+m) in the range [0, 1) - the fractional part of the result
        i_approx : entity work.olo_fix_private_lin_approx_log2
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
                Out_Valid => ResValid,
                Out_Data  => ApprData
            );

        -- The integer part (two's complement) and the fractional part are concatenated
        Result <= IntDel & ApprData;

    end generate;

    -- *** Fractional part cannot affect the result ***
    g_no_approx : if OmitFrac_c generate
        Result   <= r.Int_3;
        ResValid <= r.Valid_3;
    end generate;

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
            In_Valid   => ResValid,
            In_A       => Result,
            Out_Valid  => Out_Valid,
            Out_Result => Out_Result
        );

end architecture;
