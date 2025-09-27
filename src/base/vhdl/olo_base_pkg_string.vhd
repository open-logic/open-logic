---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
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

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_string is

    -- Case Conversions
    function toUpper (a : in string) return string;
    function toLower (a : in string) return string;

    -- Remove Whitespaces
    function trim (a : in string) return string;

    -- Convert from/to numbers
    function hex2StdLogicVector (
        a         : in string;
        bits      : in natural;
        hasPrefix : in boolean := false) return std_logic_vector;

    -- Count occurences of a character
    function countOccurence (
        a : in string;
        c : in character) return natural;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_string is

    -- *** toUpper() ***
    function toUpper (a : in string) return string is
        variable Res_v        : string(a'range);
        variable CharIdx_v    : natural;
        constant LowerUpper_c : natural := character'pos('a') - character'pos('A');
    begin

        -- Loop over characters
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
    function toLower (a : in string) return string is
        variable Res_v        : string(a'range);
        variable CharIdx_v    : natural;
        constant LowerUpper_c : natural := character'pos('a') - character'pos('A');
    begin

        -- Loop over characters
        for i in a'range loop
            CharIdx_v := character'pos(a(i));
            if CharIdx_v >= character'pos('A') and CharIdx_v <= character'pos('Z') then
                CharIdx_v := CharIdx_v + LowerUpper_c;
            end if;
            Res_v(i) := character'val(CharIdx_v);
        end loop;

        return Res_v;
    end function;

    -- *** trim() ***
    function trim (a : in string) return string is
        variable StartIdx_v : natural := a'left;
        variable EndIdx_v   : natural := a'right;
    begin

        -- Find first non-whitespace character
        while StartIdx_v < a'right and a(StartIdx_v) = ' ' loop
            StartIdx_v := StartIdx_v + 1;
        end loop;

        -- Find last non-whitespace character
        while EndIdx_v > a'left and a(EndIdx_v) = ' ' loop
            EndIdx_v := EndIdx_v - 1;
        end loop;

        -- Return trimmed string
        return a(StartIdx_v to EndIdx_v);
    end function;

    -- *** hex2StdLogicVector() ***
    function hex2StdLogicVector (
        a         : in string;
        bits      : in natural;
        hasPrefix : in boolean := false) return std_logic_vector is
        -- Declarations
        constant Trimmed_c   : string                                   := trim(toLower(a));
        constant MaxBits_c   : natural                                  := max(choose(hasPrefix, (Trimmed_c'length-2) * 4, Trimmed_c'length * 4), 0);
        variable StdlvFull_v : std_logic_vector(MaxBits_c - 1 downto 0) := (others => '0');
        variable Result_v    : std_logic_vector(bits - 1 downto 0)      := (others => '0');
        variable LowIdx_v    : natural                                  := 0;
        variable Nibble_v    : std_logic_vector(3 downto 0);
    begin
        -- For empty string return zero
        if Trimmed_c'length = 0 then
            return Result_v;
        end if;

        -- Check prefix
        if hasPrefix then
            -- synthesis translate_off
            assert Trimmed_c(Trimmed_c'left to Trimmed_c'left+1) = "0x"
                report "Invalid prefix in hex2StdLogicVector() - expected prefix is 0x - string: " & a
                severity error;
            -- synthesis translate_on
            -- coverage
            LowIdx_v := LowIdx_v + 2;
        end if;

        -- Convert
        for i in Trimmed_c'left+LowIdx_v to Trimmed_c'right loop

            -- Convert Nibble
            case Trimmed_c(i) is
                when '0' => Nibble_v := x"0";
                when '1' => Nibble_v := x"1";
                when '2' => Nibble_v := x"2";
                when '3' => Nibble_v := x"3";
                when '4' => Nibble_v := x"4";
                when '5' => Nibble_v := x"5";
                when '6' => Nibble_v := x"6";
                when '7' => Nibble_v := x"7";
                when '8' => Nibble_v := x"8";
                when '9' => Nibble_v := x"9";
                when 'a' => Nibble_v := x"A";
                when 'b' => Nibble_v := x"B";
                when 'c' => Nibble_v := x"C";
                when 'd' => Nibble_v := x"D";
                when 'e' => Nibble_v := x"E";
                when 'f' => Nibble_v := x"F";
                -- coverage off
                when others =>
                    report "Invalid character in hex2StdLogicVector() - only 0-9, a-f, A-F are allowed - string: " & a
                        severity error;
                    return Result_v;
                -- coverage on
            end case;

            -- Add nibble to result
            StdlvFull_v := StdlvFull_v(StdlvFull_v'left - 4 downto 0) & Nibble_v;
        end loop;

        -- Convert size
        if bits > MaxBits_c then
            Result_v(MaxBits_c - 1 downto 0) := StdlvFull_v;
        else
            Result_v := StdlvFull_v(bits-1 downto 0);
        end if;
        return Result_v;
    end function;

    -- *** countOccurence() ***
    function countOccurence (
        a : in string;
        c : in character) return natural is
        -- Declarations
        variable Count_v : natural := 0;
    begin

        -- Count occurences
        for i in a'range loop
            if a(i) = c then
                Count_v := Count_v + 1;
            end if;
        end loop;

        return Count_v;
    end function;

end package body;
