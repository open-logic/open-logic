---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025-2026 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing functions related to Open Logic fixed point mathematics.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_fix_pkg.md
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
    use work.en_cl_fix_pkg.all;
    use work.en_cl_fix_private_pkg.all;
    use work.olo_base_pkg_string.all;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_fix_pkg is

    -- String Constants
    constant FixRound_Trunc_c     : string := "Trunc_s";
    constant FixRound_NonSymPos_c : string := "NonSymPos_s";
    constant FixRound_NonSymNeg_c : string := "NonSymNeg_s";
    constant FixRound_SymInf_c    : string := "SymInf_s";
    constant FixRound_SymZero_c   : string := "SymZero_s";
    constant FixRound_ConvEven_c  : string := "ConvEven_s";
    constant FixRound_ConvOdd_c   : string := "ConvOdd_s";

    constant FixSaturate_None_c    : string := "None_s";
    constant FixSaturate_Warn_c    : string := "Warn_s";
    constant FixSaturate_Sat_c     : string := "Sat_s";
    constant FixSaturate_SatWarn_c : string := "SatWarn_s";

    constant FixFmt_Unused_c : FixFormat_t := (0, 1, 0); -- Unused formats must have one bit to avoid issues

    -- Functions
    function fixFmtWidthFromString (fmt : string) return natural;
    function fixFmtWidthFromStringTolerant (fmt : string) return natural;

    -- Register is required if:
    -- - logic is present and regMode is "AUTO"
    -- - regMode is "YES"
    -- Meant for internal use only
    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;

    -- Return fixed-point format from string and tolerate wrong strings (returning 0,0,0)
    function fixFmtFromStringTolerant (fmt : string) return FixFormat_t;

    -- Dynamic shifting function
    -- Required because synthesis tools do not accept variable shifts the way cl_fix_shift is writtin.
    function fixDynShift (
        a        : std_logic_vector;
        aFmt     : FixFormat_t;
        shift    : integer;
        minShift : integer       := 0;
        maxShift : integer;
        rFmt     : FixFormat_t;
        rnd      : FixRound_t    := Trunc_s;
        sat      : FixSaturate_t := None_s) return std_logic_vector;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_fix_pkg is

    function fixFmtWidthFromString (fmt : string) return natural is
        constant FixFmt_c : FixFormat_t := cl_fix_format_from_string(fmt);
    begin
        return cl_fix_width(FixFmt_c);
    end function;

    function fixFmtWidthFromStringTolerant (fmt : string) return natural is
        constant FixFmt_c : FixFormat_t := fixFmtFromStringTolerant(fmt);
    begin
        return cl_fix_width(FixFmt_c);
    end function;

    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean is
        variable Result_v : boolean := false;
    begin

        -- Calculate register requirement
        if compareNoCase(regMode, "yes") then
            Result_v := true;
        elsif compareNoCase(regMode, "no") then
            Result_v := false;
        elsif compareNoCase(regMode, "auto") then
            Result_v := logicPresent;
        -- coverage off
        -- unreachable
        else
            -- synthesis translate_off
            assert false
                report "olo_fix - Invalid register mode '" & regMode & "' - must be YES, NO or AUTO"
                severity failure;
            -- synthesis translate_on
            -- coverage on
        end if;

        return Result_v;

    end function;

    function fixFmtFromStringTolerant (fmt : string) return FixFormat_t is
        type State_t is (BracketOpen_s, IntBits_s, FracBits_s, BracketClose_s, Done_s);

        variable Result_v : FixFormat_t := FixFmt_Unused_c;
        variable State_v  : State_t     := BracketOpen_s;
    begin

        for i in fmt'low to fmt'high loop

            case State_v is
                when BracketOpen_s =>
                    if fmt(i) = '(' then
                        State_v := IntBits_s;
                    end if;
                when IntBits_s =>
                    if fmt(i) = ',' then
                        State_v := FracBits_s;
                    end if;
                when FracBits_s =>
                    if fmt(i) = ',' then
                        State_v := BracketClose_s;
                    end if;
                when BracketClose_s =>
                    if fmt(i) = ')' then
                        State_v := Done_s;
                    end if;
                when Done_s =>
                    null; -- unreachable
                -- coverage off
                when others =>
                    null; -- unreachable
                -- coverage on
            end case;

        end loop;

        if State_v = Done_s then
            Result_v := cl_fix_format_from_string(fmt);
        end if;

        return Result_v;
    end function;

    function fixDynShift (
        a        : std_logic_vector;
        aFmt     : FixFormat_t;
        shift    : integer;
        minShift : integer       := 0;
        maxShift : integer;
        rFmt     : FixFormat_t;
        rnd      : FixRound_t    := Trunc_s;
        sat      : FixSaturate_t := None_s) return std_logic_vector is
        -- Local declaratoins
        constant FullFmt_c : FixFormat_t := (max(aFmt.S, rFmt.S), max(aFmt.I+maxShift, rFmt.I), max(aFmt.F-minShift, rFmt.F+1)); -- Additional bit for rounding
        variable FullA_v   : std_logic_vector(cl_fix_width(FullFmt_c)-1 downto 0);
        variable FullOut_v : std_logic_vector(FullA_v'range);
    begin
        -- assertions
        -- synthesis translate_off
        assert shift >= minShift
            report "olo_fix_pkg.fixDynShift: Shift must be >= minShift"
            severity error;
        assert shift <= maxShift
            report "olo_fix_pkg.fixDynShift: Shift must be <= maxShift"
            severity error;
        -- synthesis translate_on

        -- Implementation
        FullA_v := cl_fix_resize(a, aFmt, FullFmt_c);

        for i in minShift to maxShift loop -- make a loop to ensure the shift is a constant (required by the tools)
            if i = shift then
                FullOut_v := cl_fix_shift(FullA_v, FullFmt_c, i, FullFmt_c, Trunc_s, None_s);
            end if;
        end loop;

        return cl_fix_resize(FullOut_v, FullFmt_c, rFmt, rnd, sat);
    end function;

end package body;
