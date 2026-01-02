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

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
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

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
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

end architecture;





