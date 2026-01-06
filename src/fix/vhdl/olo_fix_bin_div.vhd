------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a binary division of two fixed-point numbers using a non-restoring
-- division algorithm.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_bin_div.md
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

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_bin_div is
    generic (
        NumFmt_g   : string;
        DenomFmt_g : string;
        OutFmt_g   : string;
        Mode_g     : string := "PIPELINED";
        Round_g    : string := FixRound_Trunc_c;
        Saturate_g : string := FixSaturate_Sat_c
    );
    port (
        -- Control Signals
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Valid  : in    std_logic := '1';
        In_Ready  : out   std_logic;
        In_Num    : in    std_logic_vector(fixFmtWidthFromString(NumFmt_g)-1 downto 0);
        In_Denom  : in    std_logic_vector(fixFmtWidthFromString(DenomFmt_g)-1 downto 0);
        -- Output
        Out_Valid : out   std_logic;
        Out_Quot  : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_bin_div is

    -- String upping
    constant ModeUpper_c : string := toUpper(Mode_g);

    -- Formats
    constant NumFmt_c   : FixFormat_t   := cl_fix_format_from_string(NumFmt_g);
    constant DenomFmt_c : FixFormat_t   := cl_fix_format_from_string(DenomFmt_g);
    constant OutFmt_c   : FixFormat_t   := cl_fix_format_from_string(OutFmt_g);
    constant Round_c    : FixRound_t    := cl_fix_round_from_string(Round_g);
    constant Saturate_c : FixSaturate_t := cl_fix_saturate_from_string(Saturate_g);

    -- constants
    constant FirstShift_c   : integer     := OutFmt_c.I;
    constant NumAbsFmt_c    : FixFormat_t := (0, NumFmt_c.I+NumFmt_c.S, NumFmt_c.F);
    constant DenomAbsFmt_c  : FixFormat_t := (0, DenomFmt_c.I+DenomFmt_c.S, DenomFmt_c.F);
    constant ResultIntFmt_c : FixFormat_t := (1, OutFmt_c.I+1, OutFmt_c.F+1);
    constant DenomCompFmt_c : FixFormat_t := (0, DenomAbsFmt_c.I+FirstShift_c, DenomAbsFmt_c.F-FirstShift_c);
    constant NumCompFmt_c   : FixFormat_t := (0, max(DenomCompFmt_c.I, NumAbsFmt_c.I), max(DenomCompFmt_c.F, NumAbsFmt_c.F));
    constant Iterations_c   : integer     := OutFmt_c.I+OutFmt_c.F+2;

begin

    -----------------------------------------------------------------------------------------------
    -- Addertions
    -----------------------------------------------------------------------------------------------
    assert ModeUpper_c = "PIPELINED" or ModeUpper_c = "SERIAL"
        report "###ERROR###: olo_fix_cordic_rot: Mode_g must be PIPELINED or SERIAL"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Serial implementation
    -----------------------------------------------------------------------------------------------
    g_serial : if ModeUpper_c = "SERIAL" generate
        -- types
        type State_t is (Idle_s, Init1_s, Init2_s, Calc_s, Output_s);

        -- Two process method
        type TwoProcess_r is record
            State     : State_t;
            Num       : std_logic_vector(In_Num'range);
            Denom     : std_logic_vector(In_Denom'range);
            NumSign   : std_logic;
            DenomSign : std_logic;
            NumAbs    : std_logic_vector(cl_fix_width(NumAbsFmt_c)-1 downto 0);
            DenomAbs  : std_logic_vector(cl_fix_width(DenomAbsFmt_c)-1 downto 0);
            DenomComp : std_logic_vector(cl_fix_width(DenomCompFmt_c)-1 downto 0);
            NumComp   : std_logic_vector(cl_fix_width(NumCompFmt_c)-1 downto 0);
            IterCnt   : integer range 0 to Iterations_c-1;
            ResultInt : std_logic_vector(cl_fix_width(ResultIntFmt_c)-1 downto 0);
            Out_Valid : std_logic;
            Out_Quot  : std_logic_vector(cl_fix_width(OutFmt_c)-1 downto 0);
            In_Ready  : std_logic;
        end record;

        signal r, r_next : TwoProcess_r;
    begin

        -- *** Combinatorial Process ***
        p_comb : process (all) is
            variable v                : TwoProcess_r;
            variable NumIn_DenomFmt_v : std_logic_vector(cl_fix_width(DenomCompFmt_c) -1 downto 0);
        begin
            -- *** Hold variables stable ***
            v := r;

            -- *** State Machine ***
            v.In_Ready       := '0';
            v.Out_Valid      := '0';
            NumIn_DenomFmt_v := (others => '0');

            case r.State is
                when Idle_s =>
                    -- start execution if valid
                    if In_Valid = '1' then
                        v.State := Init1_s;
                        v.Num   := In_Num;
                        v.Denom := In_Denom;
                    else
                        v.In_Ready := '1';
                    end if;

                when Init1_s =>
                    -- state handling
                    v.State := Init2_s;
                    -- latch signs
                    if NumFmt_c.S = 0 then
                        v.NumSign := '0';
                    else
                        v.NumSign := r.Num(r.Num'left);
                    end if;
                    if DenomFmt_c.S = 0 then
                        v.DenomSign := '0';
                    else
                        v.DenomSign := r.Denom(r.Denom'left);
                    end if;
                    -- calculate absolute values
                    v.NumAbs   := cl_fix_abs(r.Num, NumFmt_c, NumAbsFmt_c);
                    v.DenomAbs := cl_fix_abs(r.Denom, DenomFmt_c, DenomAbsFmt_c);

                when Init2_s =>
                    -- state handling
                    v.State := Calc_s;
                    -- Initialize calculation
                    v.DenomComp := cl_fix_shift(r.DenomAbs, DenomAbsFmt_c, FirstShift_c, DenomCompFmt_c);
                    v.NumComp   := cl_fix_resize(r.NumAbs, NumAbsFmt_c, NumCompFmt_c);
                    v.IterCnt   := Iterations_c-1;
                    v.ResultInt := (others => '0');

                when Calc_s =>
                    -- state handling
                    if r.IterCnt = 0 then
                        v.State := Output_s;
                    else
                        v.IterCnt := r.IterCnt - 1;
                    end if;

                    -- Calculation
                    v.ResultInt      := r.ResultInt(r.ResultInt'high-1 downto 0) & '0'; -- shift left
                    NumIn_DenomFmt_v := cl_fix_resize(r.NumComp, NumCompFmt_c, DenomCompFmt_c, Trunc_s, None_s);
                    if unsigned(r.DenomComp) <= unsigned(NumIn_DenomFmt_v) then
                        v.ResultInt(0) := '1';
                        v.NumComp      := cl_fix_sub(r.NumComp, NumCompFmt_c, r.DenomComp, DenomCompFmt_c, NumCompFmt_c);
                    end if;
                    v.NumComp := cl_fix_shift(v.NumComp, NumCompFmt_c, 1, NumCompFmt_c, Trunc_s, Sat_s);

                when Output_s =>
                    v.State     := Idle_s;
                    v.Out_Valid := '1';
                    v.In_Ready  := '1';
                    if r.NumSign /= r.DenomSign then
                        v.Out_Quot := cl_fix_neg(r.ResultInt, ResultIntFmt_c, OutFmt_c, Round_c, Saturate_c);
                    else
                        v.Out_Quot := cl_fix_resize(r.ResultInt, ResultIntFmt_c, OutFmt_c, Round_c, Saturate_c);
                    end if;

                -- coverage off
                when others => null; -- unreachable
                -- coverage on
            end case;

            -- *** Assign to signal ***
            r_next <= v;

        end process;

        -- *** Outputs ***
        Out_Valid <= r.Out_Valid;
        Out_Quot  <= r.Out_Quot;
        In_Ready  <= r.In_Ready;

        -- *** Sequential Proccess ***
        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.State     <= Idle_s;
                    r.Out_Valid <= '0';
                    r.In_Ready  <= '0';
                end if;
            end if;
        end process;

    end generate;

    -----------------------------------------------------------------------------------------------
    -- Pipelined implementation
    -----------------------------------------------------------------------------------------------
    g_pipelined : if ModeUpper_c = "PIPELINED" generate

        -- types
        type DenomComp_a is array (natural range <>) of std_logic_vector(cl_fix_width(DenomCompFmt_c)-1 downto 0);
        type NumComp_a is array (natural range <>) of std_logic_vector(cl_fix_width(NumCompFmt_c)-1 downto 0);
        type Result_a is array (natural range <>) of std_logic_vector(cl_fix_width(ResultIntFmt_c)-1 downto 0);

        -- Two process method
        type TwoProcess_r is record
            Valid      : std_logic_vector(0 to Iterations_c+3);
            Num_0      : std_logic_vector(In_Num'range);
            Denom_0    : std_logic_vector(In_Denom'range);
            OutNeg     : std_logic_vector(1 to Iterations_c+2);
            NumAbs_1   : std_logic_vector(cl_fix_width(NumAbsFmt_c)-1 downto 0);
            DenomAbs_1 : std_logic_vector(cl_fix_width(DenomAbsFmt_c)-1 downto 0);
            DenomComp  : DenomComp_a(2 to Iterations_c+2);
            NumComp    : NumComp_a(2 to Iterations_c+2);
            ResultInt  : Result_a(2 to Iterations_c+2);
            Out_Quot_N : std_logic_vector(cl_fix_width(OutFmt_c)-1 downto 0);
        end record;

        signal r, r_next : TwoProcess_r;
    begin

        -- *** Combinatorial Process ***
        p_comb : process (all) is
            variable v                : TwoProcess_r;
            variable NumIn_DenomFmt_v : std_logic_vector(cl_fix_width(DenomCompFmt_c) -1 downto 0);
            variable NumSign_v        : std_logic;
            variable DenomSign_v      : std_logic;
            variable NextNumComp_v    : std_logic_vector(cl_fix_width(NumCompFmt_c)-1 downto 0);
            variable ResultUnsigned_v : std_logic_vector(cl_fix_width(ResultIntFmt_c)-1 downto 0);
        begin
            -- *** Hold variables stable ***
            v := r;

            -- *** Update Pipeline ***
            v.Valid(v.Valid'low+1 to v.Valid'high)             := r.Valid(r.Valid'low to r.Valid'high-1);
            v.OutNeg(v.OutNeg'low+1 to v.OutNeg'high)          := r.OutNeg(r.OutNeg'low to r.OutNeg'high-1);
            v.DenomComp(v.DenomComp'low+1 to v.DenomComp'high) := r.DenomComp(r.DenomComp'low to r.DenomComp'high-1);
            v.NumComp(v.NumComp'low+1 to v.NumComp'high)       := r.NumComp(r.NumComp'low to r.NumComp'high-1);

            -- *** Stage 0 (Input registers) ***
            v.Valid(0) := In_Valid;
            v.Num_0    := In_Num;
            v.Denom_0  := In_Denom;

            -- *** Stage 1 (Remove Sign) ***
            v.NumAbs_1   := cl_fix_abs(r.Num_0, NumFmt_c, NumAbsFmt_c);
            v.DenomAbs_1 := cl_fix_abs(r.Denom_0, DenomFmt_c, DenomAbsFmt_c);
            if NumFmt_c.S = 0 then
                NumSign_v := '0';
            else
                NumSign_v := r.Num_0(r.Num_0'left);
            end if;
            if DenomFmt_c.S = 0 then
                DenomSign_v := '0';
            else
                DenomSign_v := r.Denom_0(r.Denom_0'left);
            end if;
            v.OutNeg(1) := NumSign_v xor DenomSign_v;

            -- *** Stage 2 (Initialization) ***
            v.DenomComp(2) := cl_fix_shift(r.DenomAbs_1, DenomAbsFmt_c, FirstShift_c, DenomCompFmt_c);
            v.NumComp(2)   := cl_fix_resize(r.NumAbs_1, NumAbsFmt_c, NumCompFmt_c);
            v.ResultInt(2) := (others => '0');

            -- *** Stages 3-N (Calculation) ***
            -- Default Value to avoid latches
            NumIn_DenomFmt_v := (others => '0');

            -- Iterations
            for stg in 3 to 2+Iterations_c loop
                v.ResultInt(stg) := r.ResultInt(stg-1)(r.ResultInt(stg-1)'high-1 downto 0) & '0'; -- shift left
                NextNumComp_v    := r.NumComp(stg-1);
                NumIn_DenomFmt_v := cl_fix_resize(r.NumComp(stg-1), NumCompFmt_c, DenomCompFmt_c, Trunc_s, None_s);
                if unsigned(r.DenomComp(stg-1)) <= unsigned(NumIn_DenomFmt_v) then
                    v.ResultInt(stg)(0) := '1';
                    NextNumComp_v       := cl_fix_sub(r.NumComp(stg-1), NumCompFmt_c, r.DenomComp(stg-1), DenomCompFmt_c, NumCompFmt_c);
                end if;
                v.NumComp(stg) := cl_fix_shift(NextNumComp_v, NumCompFmt_c, 1, NumCompFmt_c, Trunc_s, Sat_s);
            end loop;

            -- *** Stage N+1 (Output) ***
            ResultUnsigned_v := r.ResultInt(2+Iterations_c);
            if r.OutNeg(2+Iterations_c) = '1' then
                v.Out_Quot_N := cl_fix_neg(ResultUnsigned_v, ResultIntFmt_c, OutFmt_c, Round_c, Saturate_c);
            else
                v.Out_Quot_N := cl_fix_resize(ResultUnsigned_v, ResultIntFmt_c, OutFmt_c, Round_c, Saturate_c);
            end if;

            -- *** Assign to signal ***
            r_next <= v;

        end process;

        -- *** Outputs ***
        Out_Valid <= r.Valid(r.Valid'high);
        Out_Quot  <= r.Out_Quot_N;
        In_Ready  <= '1';

        -- *** Sequential Proccess ***
        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.Valid <= (others => '0');
                end if;
            end if;
        end process;

    end generate;

end architecture;





