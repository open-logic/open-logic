------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- Package containing logic functions.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package olo_base_pkg_logic is

    function zerosVector(size : in natural) return std_logic_vector;

    function onesVector(size : in natural) return std_logic_vector;

    function shiftLeft(     arg  : in std_logic_vector;
                            bits : in integer;
                            fill : in std_logic := '0')
                            return std_logic_vector;

    function shiftRight(    arg  : in std_logic_vector;
                            bits : in integer;
                            fill : in std_logic := '0')
                            return std_logic_vector;

    function binaryToGray(binary : in std_logic_vector) return std_logic_vector;

    function grayToBinary(gray : in std_logic_vector) return std_logic_vector;

    -- Parallel Prefix Computation of the OR function
    -- Input 	--> Output
    -- 0100		--> 0111
    -- 0101		--> 0111
    -- 0011		--> 0011
    -- 0010		--> 0011
    function ppcOr(inp : in std_logic_vector) return std_logic_vector;

    function reduceOr(vec : in std_logic_vector) return std_logic;

    function reduceAnd(vec : in std_logic_vector) return std_logic;

    function to01X(inp : in std_logic) return std_logic;

    function to01X(inp : in std_logic_vector) return std_logic_vector;

    function invertBitOrder(inp : in std_logic_vector) return std_logic_vector;

end olo_base_pkg_logic;

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body olo_base_pkg_logic is

    -- *** ZerosVector ***
    function zerosVector(size : in natural) return std_logic_vector is
        constant c : std_logic_vector(size - 1 downto 0) := (others => '0');
    begin
        return c;
    end function;

    -- *** OnesVector ***
    function onesVector(size : in natural) return std_logic_vector is
        constant c : std_logic_vector(size - 1 downto 0) := (others => '1');
    begin
        return c;
    end function;

    -- *** ShiftLeft ***
    function shiftLeft(     arg  : in std_logic_vector;
                            bits : in integer;
                            fill : in std_logic := '0')
                            return std_logic_vector is
        constant argDt : std_logic_vector(arg'high downto arg'low) := arg;
        variable v     : std_logic_vector(argDt'range);
    begin
        if bits < 0 then
            return shiftRight(argDt, -bits, fill);
        else
            v(v'left downto bits)      := argDt(argDt'left - bits downto argDt'right);
            v(bits - 1 downto v'right) := (others => fill);
            return v;
        end if;
    end function;

    -- *** ShiftRight ***
    function shiftRight(    arg  : in std_logic_vector;
                            bits : in integer;
                            fill : in std_logic := '0')
                            return std_logic_vector is
        constant argDt : std_logic_vector(arg'high downto arg'low) := arg;
        variable v     : std_logic_vector(argDt'range);
    begin
        if bits < 0 then
            return shiftLeft(argDt, -bits, fill);
        else
            v(v'left - bits downto v'right)    := argDt(argDt'left downto bits);
            v(v'left downto v'left - bits + 1) := (others => fill);
            return v;
        end if;
    end function;

    -- *** BinaryToGray ***
    function binaryToGray(binary : in std_logic_vector) return std_logic_vector is
        variable Gray_v : std_logic_vector(binary'range);
    begin
        Gray_v := binary xor ('0' & binary(binary'high downto binary'low + 1));
        return Gray_v;
    end function;

    -- *** GrayToBinary ***
    function grayToBinary(gray : in std_logic_vector) return std_logic_vector is
        variable Binary_v : std_logic_vector(gray'range);
    begin
        Binary_v(Binary_v'high) := gray(gray'high);
        for b in gray'high - 1 downto gray'low loop
            Binary_v(b) := gray(b) xor Binary_v(b + 1);
        end loop;
        return Binary_v;
    end function;

    -- *** PpcOr ***
    function ppcOr(inp : in std_logic_vector) return std_logic_vector is
        constant Stages_c    : integer := log2ceil(inp'length);
        constant Pwr2Width_c : integer := 2**Stages_c;
        type StageOut_t is array (natural range <>) of std_logic_vector(Pwr2Width_c - 1 downto 0);
        variable StageOut_v  : StageOut_t(0 to Stages_c);
        variable BinCnt_v    : unsigned(Pwr2Width_c - 1 downto 0);
    begin
        StageOut_v(0)                          := (others => '0');
        StageOut_v(0)(inp'length - 1 downto 0) := inp;
        for stage in 0 to Stages_c - 1 loop
            BinCnt_v := (others => '0');
            for idx in 0 to Pwr2Width_c - 1 loop
                if BinCnt_v(stage) = '0' then
                    StageOut_v(stage + 1)(idx) := StageOut_v(stage)(idx) or StageOut_v(stage)((idx / (2**stage) + 1) * 2**stage);
                else
                    StageOut_v(stage + 1)(idx) := StageOut_v(stage)(idx);
                end if;
                BinCnt_v := BinCnt_v + 1;
            end loop;
        end loop;
        return StageOut_v(Stages_c)(inp'length - 1 downto 0);
    end function;

    function reduceOr(vec : in std_logic_vector) return std_logic is
        variable tmp : std_logic;
    begin
        tmp := '0';
        for i in vec'low to vec'high loop
            tmp := tmp or vec(i);
        end loop;
        return tmp;
    end function;

    function reduceAnd(vec : in std_logic_vector) return std_logic is
        variable tmp : std_logic;
    begin
        tmp := '1';
        for i in vec'low to vec'high loop
            tmp := tmp and vec(i);
        end loop;
        return tmp;
    end function;

    function to01X(inp : in std_logic) return std_logic is
    begin
        case inp is
            when '0' | 'L' => return '0';
            when '1' | 'H' => return '1';
            when others    => return 'X';
        end case;
    end function;

    function to01X(inp : in std_logic_vector) return std_logic_vector is
        variable tmp : std_logic_vector(inp'range);
    begin
        for i in inp'low to inp'high loop
            tmp(i) := to01X(inp(i));
        end loop;
        return tmp;
    end function;

    function invertBitOrder(inp : in std_logic_vector) return std_logic_vector is
        variable tmp : std_logic_vector(inp'range);
    begin
        for i in inp'low to inp'high loop
            tmp(tmp'high - i) := inp(i);
        end loop;
        return tmp;
    end function;

end package body;