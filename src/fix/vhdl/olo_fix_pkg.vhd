---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
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

    -- Register is required if:
    -- - logic is present and regMode is "AUTO"
    -- - regMode is "YES"
    -- Meant for internal use only
    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;

    -- Return fixed-point format from string and tolerate wrong strings (returning 0,0,0)
    function fixFmtFromStringTolerant (fmt : string) return FixFormat_t;

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

    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean is
        constant RegMode_c : string  := toLower(regMode);
        variable Result_v  : boolean := false;
    begin

        -- Calculate register requirement
        if RegMode_c = "yes" then
            Result_v := true;
        elsif RegMode_c = "no" then
            Result_v := false;
        elsif RegMode_c = "auto" then
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

        variable Result_v : FixFormat_t := (0, 0, 0);
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

end package body;
