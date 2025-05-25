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

    -- Functions
    function fixFmtWidthFromString (fmt : string) return natural;

    -- Register is required if:
    -- - logic is present and regMode is "AUTO"
    -- - regMode is "YES"
    -- Meant for internal use only
    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;

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
        constant RegMode_c : string := toLower(regMode);
    begin

        -- Calculate register requirement
        if RegMode_c = "yes" then
            return true;
        elsif RegMode_c = "no" then
            return false;
        elsif RegMode_c = "auto" then
            return logicPresent;
        -- coverage off
        -- unrechable
        else
            assert false
                report "olo_fix - Invalid register mode '" & regMode & "' - must be YES, NO or AUTO"
                severity failure;
            return false;
        -- coverage on
        end if;

    end function;

end package body;
