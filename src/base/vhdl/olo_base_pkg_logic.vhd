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

    function reduceXor(vec : in std_logic_vector) return std_logic;

    function to01X(inp : in std_logic) return std_logic;

    function to01X(inp : in std_logic_vector) return std_logic_vector;

    function invertBitOrder(inp : in std_logic_vector) return std_logic_vector;

    -- LFSR / CRC / PRBS Polynomials
    -- 1 for the x^n positions used
    constant Polynomial_Prbs2_c  : std_logic_vector( 1 downto 0) := "11";
    constant Polynomial_Prbs3_c  : std_logic_vector( 2 downto 0) := "110";
    constant Polynomial_Prbs4_c  : std_logic_vector( 3 downto 0) := "1100";
    constant Polynomial_Prbs5_c  : std_logic_vector( 4 downto 0) := "10100";
    constant Polynomial_Prbs6_c  : std_logic_vector( 5 downto 0) := "110000";
    constant Polynomial_Prbs7_c  : std_logic_vector( 6 downto 0) := "1100000";
    constant Polynomial_Prbs8_c  : std_logic_vector( 7 downto 0) := "10111000";
    constant Polynomial_Prbs9_c  : std_logic_vector( 8 downto 0) := "100010000";
    constant Polynomial_Prbs10_c : std_logic_vector( 9 downto 0) := "1001000000";
    constant Polynomial_Prbs11_c : std_logic_vector(10 downto 0) := "10100000000";
    constant Polynomial_Prbs12_c : std_logic_vector(11 downto 0) := "100000101001";
    constant Polynomial_Prbs13_c : std_logic_vector(12 downto 0) := "1000000001101";
    constant Polynomial_Prbs14_c : std_logic_vector(13 downto 0) := "10000000010101";
    constant Polynomial_Prbs15_c : std_logic_vector(14 downto 0) := "110000000000000";
    constant Polynomial_Prbs16_c : std_logic_vector(15 downto 0) := "1101000000001000";
    constant Polynomial_Prbs17_c : std_logic_vector(16 downto 0) := "10010000000000000";
    constant Polynomial_Prbs18_c : std_logic_vector(17 downto 0) := "100000010000000000";
    constant Polynomial_Prbs19_c : std_logic_vector(18 downto 0) := "1000000000000100011";
    constant Polynomial_Prbs20_c : std_logic_vector(19 downto 0) := "10010000000000000000";
    constant Polynomial_Prbs21_c : std_logic_vector(20 downto 0) := "101000000000000000000";
    constant Polynomial_Prbs22_c : std_logic_vector(21 downto 0) := "1100000000000000000000";
    constant Polynomial_Prbs23_c : std_logic_vector(22 downto 0) := "10000100000000000000000";
    constant Polynomial_Prbs24_c : std_logic_vector(23 downto 0) := "111000010000000000000000";
    constant Polynomial_Prbs25_c : std_logic_vector(24 downto 0) := "1001000000000000000000000";
    constant Polynomial_Prbs26_c : std_logic_vector(25 downto 0) := "10000000000000000000100011";
    constant Polynomial_Prbs27_c : std_logic_vector(26 downto 0) := "100000000000000000000010011";
    constant Polynomial_Prbs28_c : std_logic_vector(27 downto 0) := "1001000000000000000000000000";
    constant Polynomial_Prbs29_c : std_logic_vector(28 downto 0) := "10100000000000000000000000000";
    constant Polynomial_Prbs30_c : std_logic_vector(29 downto 0) := "100000000000000000000000101001";
    constant Polynomial_Prbs31_c : std_logic_vector(30 downto 0) := "1001000000000000000000000000000";
    constant Polynomial_Prbs32_c : std_logic_vector(31 downto 0) := "10000000001000000000000000000011";

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

    function reduceXor(vec : in std_logic_vector) return std_logic is
        variable tmp : std_logic;
    begin
        tmp := '0';
        for i in vec'low to vec'high loop
            tmp := tmp xor vec(i);
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
        variable inp_v : std_logic_vector(inp'length-1 downto 0);
        variable tmp : std_logic_vector(inp_v'range);
    begin
        inp_v := inp;
        for i in 0 to inp_v'high loop
            tmp(tmp'high - i) := inp_v(i);
        end loop;
        return tmp;
    end function;

end package body;