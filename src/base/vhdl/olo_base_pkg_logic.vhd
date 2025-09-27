---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing logic functions.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pkg_logic.md
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

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_logic is

    function zerosVector (size : in natural) return std_logic_vector;

    function onesVector (size : in natural) return std_logic_vector;

    function shiftLeft (
        arg  : in std_logic_vector;
        bits : in integer;
        fill : in std_logic := '0') return std_logic_vector;

    function shiftRight (
        arg  : in std_logic_vector;
        bits : in integer;
        fill : in std_logic := '0') return std_logic_vector;

    function binaryToGray (binary : in std_logic_vector) return std_logic_vector;

    function grayToBinary (gray : in std_logic_vector) return std_logic_vector;

    -- Parallel Prefix Computation of the OR function
    -- Input --> Output
    -- 0100  --> 0111
    -- 0101  --> 0111
    -- 0011  --> 0011
    -- 0010  --> 0011
    function ppcOr (inp : in std_logic_vector) return std_logic_vector;

    function to01X (inp : in std_logic) return std_logic;

    function to01X (inp : in std_logic_vector) return std_logic_vector;

    function to01 (inp : in std_logic) return std_logic;

    function to01 (inp : in std_logic_vector) return std_logic_vector;

    function invertBitOrder (inp : in std_logic_vector) return std_logic_vector;

    function invertByteOrder (inp : in std_logic_vector) return std_logic_vector;

    function getSetBitIndex (vec : in std_logic_vector; fromMsb : in boolean) return integer;

    function getLeadingSetBitIndex (vec : in std_logic_vector) return integer;

    function getTrailingSetBitIndex (vec : in std_logic_vector) return integer;

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

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_logic is

    -- *** ZerosVector ***
    function zerosVector (size : in natural) return std_logic_vector is
        constant Vector_c : std_logic_vector(size - 1 downto 0) := (others => '0');
    begin
        return Vector_c;
    end function;

    -- *** OnesVector ***
    function onesVector (size : in natural) return std_logic_vector is
        constant Vector_c : std_logic_vector(size - 1 downto 0) := (others => '1');
    begin
        return Vector_c;
    end function;

    -- *** ShiftLeft ***
    function shiftLeft (
        arg  : in std_logic_vector;
        bits : in integer;
        fill : in std_logic := '0') return std_logic_vector is
        constant ArgDownto_c : std_logic_vector(arg'high downto arg'low) := arg;
        variable Vector_v    : std_logic_vector(ArgDownto_c'range);
    begin
        if bits < 0 then
            return shiftRight(ArgDownto_c, -bits, fill);
        else
            Vector_v(Vector_v'left downto bits)      := ArgDownto_c(ArgDownto_c'left - bits downto ArgDownto_c'right);
            Vector_v(bits - 1 downto Vector_v'right) := (others => fill);
            return Vector_v;
        end if;
    end function;

    -- *** ShiftRight ***
    function shiftRight (
        arg  : in std_logic_vector;
        bits : in integer;
        fill : in std_logic := '0') return std_logic_vector is
        constant ArgDownto_c : std_logic_vector(arg'high downto arg'low) := arg;
        variable Vector_v    : std_logic_vector(ArgDownto_c'range);
    begin
        if bits < 0 then
            return shiftLeft(ArgDownto_c, -bits, fill);
        else
            Vector_v(Vector_v'left - bits downto Vector_v'right)    := ArgDownto_c(ArgDownto_c'left downto bits);
            Vector_v(Vector_v'left downto Vector_v'left - bits + 1) := (others => fill);
            return Vector_v;
        end if;
    end function;

    -- *** BinaryToGray ***
    function binaryToGray (binary : in std_logic_vector) return std_logic_vector is
        variable Gray_v : std_logic_vector(binary'range);
    begin
        Gray_v := binary xor ('0' & binary(binary'high downto binary'low + 1));
        return Gray_v;
    end function;

    -- *** GrayToBinary ***
    function grayToBinary (gray : in std_logic_vector) return std_logic_vector is
        variable Binary_v : std_logic_vector(gray'range);
    begin
        Binary_v(Binary_v'high) := gray(gray'high);

        -- Loop through all bits
        for b in gray'high - 1 downto gray'low loop
            Binary_v(b) := gray(b) xor Binary_v(b + 1);
        end loop;

        return Binary_v;
    end function;

    -- *** PpcOr ***
    function ppcOr (inp : in std_logic_vector) return std_logic_vector is
        -- Constants
        constant Stages_c    : integer := log2ceil(inp'length);
        constant Pwr2Width_c : integer := 2**Stages_c;

        -- Types
        type StageOut_t is array (natural range <>) of std_logic_vector(Pwr2Width_c downto 0);

        -- Variables
        variable StageOut_v : StageOut_t(0 to Stages_c) := (others => (others => '0'));
        variable BinCnt_v   : unsigned(Pwr2Width_c - 1 downto 0);
    begin
        StageOut_v(0)                          := (others => '0');
        StageOut_v(0)(inp'length - 1 downto 0) := inp;

        -- Loop through all stages
        for stage in 0 to Stages_c - 1 loop
            BinCnt_v := (others => '0');

            -- Loop through all bits
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

    function to01X (inp : in std_logic) return std_logic is
    begin

        -- Convert to 0, 1 or X (weak aware)
        case inp is
            when '0' | 'L' => return '0';
            when '1' | 'H' => return '1';
            when others => return 'X';
        end case;

    end function;

    function to01X (inp : in std_logic_vector) return std_logic_vector is
        variable Result_v : std_logic_vector(inp'range);
    begin

        -- Loop through all bits
        for i in inp'low to inp'high loop
            Result_v(i) := to01X(inp(i));
        end loop;

        return Result_v;
    end function;

    function to01 (inp : in std_logic) return std_logic is
    begin

        -- Convert to 0 or 1
        case inp is
            when '0' | 'L' => return '0';
            when '1' | 'H' => return '1';
            when others => return '0';
        end case;

    end function;

    function to01 (inp : in std_logic_vector) return std_logic_vector is
        variable Result_v : std_logic_vector(inp'range);
    begin

        -- Loop through all bits
        for i in inp'low to inp'high loop
            Result_v(i) := to01(inp(i));
        end loop;

        return Result_v;
    end function;

    function invertBitOrder (inp : in std_logic_vector) return std_logic_vector is
        variable Inp_v    : std_logic_vector(inp'length-1 downto 0);
        variable Result_v : std_logic_vector(Inp_v'range);
    begin
        Inp_v := inp;

        -- Loop through all bits
        for i in 0 to Inp_v'high loop
            Result_v(Result_v'high - i) := Inp_v(i);
        end loop;

        return Result_v;
    end function;

    function invertByteOrder (inp : in std_logic_vector) return std_logic_vector is
        constant Inp_c    : std_logic_vector(inp'length-1 downto 0) := inp;
        constant Bytes_c  : natural                                 := inp'length/8;
        variable Result_v : std_logic_vector(Inp_c'range);
        variable InByte_v : natural;
    begin

        -- Check input width
        -- synthesis translate_off
        assert inp'length mod 8 = 0
            report "invertByteOrder(): Number of bits must be a multiple of 8"
            severity error;
        -- synthesis translate_on

        -- Invert byte order
        for byte in 0 to Bytes_c-1 loop
            InByte_v                         := Bytes_c - 1 - byte;
            Result_v(byte*8+7 downto byte*8) := Inp_c(InByte_v*8+7 downto InByte_v*8);
        end loop;

        return Result_v;
    end function;

    function getSetBitIndex (vec : in std_logic_vector; fromMsb : in boolean) return integer is
    begin
        if fromMsb then

            for i in vec'high downto vec'low loop
                if vec(i) = '1' then
                    return i;
                end if;
            end loop;

            return vec'low;
        else

            for i in vec'low to vec'high loop
                if vec(i) = '1' then
                    return i;
                end if;
            end loop;

            return vec'high;
        end if;
    end function;

    function getLeadingSetBitIndex (vec : in std_logic_vector) return integer is
    begin
        return getSetBitIndex(vec, fromMsb => true);
    end function;

    function getTrailingSetBitIndex (vec : in std_logic_vector) return integer is
    begin
        return getSetBitIndex(vec, fromMsb => false);
    end function;

end package body;
