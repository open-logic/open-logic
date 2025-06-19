---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Waldemar Koprek, Oliver Bruendler
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing commonly used array types
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pkg_array.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_array is

    type StlvArray2_t   is array (natural range <>) of std_logic_vector( 1 downto 0);
    type StlvArray3_t   is array (natural range <>) of std_logic_vector( 2 downto 0);
    type StlvArray4_t   is array (natural range <>) of std_logic_vector( 3 downto 0);
    type StlvArray5_t   is array (natural range <>) of std_logic_vector( 4 downto 0);
    type StlvArray6_t   is array (natural range <>) of std_logic_vector( 5 downto 0);
    type StlvArray7_t   is array (natural range <>) of std_logic_vector( 6 downto 0);
    type StlvArray8_t   is array (natural range <>) of std_logic_vector( 7 downto 0);
    type StlvArray9_t   is array (natural range <>) of std_logic_vector( 8 downto 0);
    type StlvArray10_t  is array (natural range <>) of std_logic_vector( 9 downto 0);
    type StlvArray11_t  is array (natural range <>) of std_logic_vector(10 downto 0);
    type StlvArray12_t  is array (natural range <>) of std_logic_vector(11 downto 0);
    type StlvArray13_t  is array (natural range <>) of std_logic_vector(12 downto 0);
    type StlvArray14_t  is array (natural range <>) of std_logic_vector(13 downto 0);
    type StlvArray15_t  is array (natural range <>) of std_logic_vector(14 downto 0);
    type StlvArray16_t  is array (natural range <>) of std_logic_vector(15 downto 0);
    type StlvArray17_t  is array (natural range <>) of std_logic_vector(16 downto 0);
    type StlvArray18_t  is array (natural range <>) of std_logic_vector(17 downto 0);
    type StlvArray19_t  is array (natural range <>) of std_logic_vector(18 downto 0);
    type StlvArray20_t  is array (natural range <>) of std_logic_vector(19 downto 0);
    type StlvArray21_t  is array (natural range <>) of std_logic_vector(20 downto 0);
    type StlvArray22_t  is array (natural range <>) of std_logic_vector(21 downto 0);
    type StlvArray23_t  is array (natural range <>) of std_logic_vector(22 downto 0);
    type StlvArray24_t  is array (natural range <>) of std_logic_vector(23 downto 0);
    type StlvArray25_t  is array (natural range <>) of std_logic_vector(24 downto 0);
    type StlvArray26_t  is array (natural range <>) of std_logic_vector(25 downto 0);
    type StlvArray27_t  is array (natural range <>) of std_logic_vector(26 downto 0);
    type StlvArray28_t  is array (natural range <>) of std_logic_vector(27 downto 0);
    type StlvArray29_t  is array (natural range <>) of std_logic_vector(28 downto 0);
    type StlvArray30_t  is array (natural range <>) of std_logic_vector(29 downto 0);
    type StlvArray32_t  is array (natural range <>) of std_logic_vector(31 downto 0);
    type StlvArray36_t  is array (natural range <>) of std_logic_vector(35 downto 0);
    type StlvArray48_t  is array (natural range <>) of std_logic_vector(47 downto 0);
    type StlvArray64_t  is array (natural range <>) of std_logic_vector(63 downto 0);
    type StlvArray512_t is array (natural range <>) of std_logic_vector(511 downto 0);

    type IntegerArray_t is array (natural range <>) of integer;
    type RealArray_t is array (natural range <>) of real;
    type BoolArray_t is array (natural range <>) of boolean;
    type StlvArray_t is array (natural range <>) of std_logic_vector;
    type UnsignedArray_t is array (natural range <>) of unsigned;
    type SignedArray_t is array (natural range <>) of signed;

    function arrayInteger2Real (a : in IntegerArray_t) return RealArray_t;
    function arrayStdl2Bool (a : in std_logic_vector) return BoolArray_t;
    function arrayBool2Stdl (a : in BoolArray_t) return std_logic_vector;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_array is

    function arrayInteger2Real (a : in IntegerArray_t) return RealArray_t is
        variable Array_v : RealArray_t(a'range);
    begin

        -- loop through all elements of the array
        for i in a'low to a'high loop
            Array_v(i) := real(a(i));
        end loop;

        return Array_v;
    end function;

    function arrayStdl2Bool (a : in std_logic_vector) return BoolArray_t is
        variable Array_v : BoolArray_t(a'range);
    begin

        -- loop through all elements of the array
        for i in a'low to a'high loop
            Array_v(i) := (a(i) = '1');
        end loop;

        return Array_v;
    end function;

    function arrayBool2Stdl (a : in BoolArray_t) return std_logic_vector is
        variable Array_v : std_logic_vector(a'range);
    begin

        -- loop through all elements of the array
        for i in a'low to a'high loop
            if a(i) then
                Array_v(i) := '1';
            else
                Array_v(i) := '0';
            end if;
        end loop;

        return Array_v;
    end function;

end package body;
