---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing commonly used string manipulation functionality.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pkg_string.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_string is

    function toUpper(a : in string) return string;
    function toLower(a : in string) return string;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_string is

    -- *** toUpper() ***
    function toUpper(a : in string) return string is
        variable Res_v        : string(a'range);
        variable CharIdx_v    : natural;
        constant LowerUpper_c : natural := character'pos('a') - character'pos('A');
    begin
        for i in a'range loop
            CharIdx_v := character'pos(a(i));
            if CharIdx_v >= character'pos('a') and CharIdx_v <= character'pos('z') then
                CharIdx_v := CharIdx_v - LowerUpper_c;
            end if;
            Res_v(i) := character'val(CharIdx_v);
        end loop;
        return Res_v;
    end function;

    -- *** toLower() ***
    function toLower(a : in string) return string is
        variable Res_v        : string(a'range);
        variable CharIdx_v    : natural;
        constant LowerUpper_c : natural := character'pos('a') - character'pos('A');
    begin
        for i in a'range loop
            CharIdx_v := character'pos(a(i));
            if CharIdx_v >= character'pos('A') and CharIdx_v <= character'pos('Z') then
                CharIdx_v := CharIdx_v + LowerUpper_c;
            end if;
            Res_v(i) := character'val(CharIdx_v);
        end loop;
        return Res_v;
    end function;

end package body;
