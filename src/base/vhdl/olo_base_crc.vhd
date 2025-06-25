---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bründler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description:
---------------------------------------------------------------------------------------------------
-- A CRC generator based on a linear-feedback shifter register. Can be used to generate CRCs to add
-- on TX side or to calculate CRCs to compare to received CRC on RX side.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_crc.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_misc.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_logic.all;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_crc is
    generic (
        DataWidth_g     : positive;
        Polynomial_g    : std_logic_vector;  -- according to https://crccalc.com/?crc=01&method=CRC-8&datatype=hex&outtype=bin
        InitialValue_g  : std_logic_vector := "0";
        BitOrder_g      : string           := "MSB_FIRST"; -- "MSB_FIRST" or "LSB_FIRST"
        ByteOrder_g     : string           := "NONE";      -- "NONE", "MSB_FIRST" or "LSB_FIRST"
        BitflipOutput_g : boolean          := false;
        XorOutput_g     : std_logic_vector := "0"
    );
    port (
        -- Control Ports
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Input
        In_Data          : in    std_logic_vector(DataWidth_g-1 downto 0);
        In_Valid         : in    std_logic := '1';
        In_Ready         : out   std_logic;
        In_Last          : in    std_logic := '0';
        In_First         : in    std_logic := '0';
        -- Output
        Out_Crc          : out   std_logic_vector(Polynomial_g'range);
        Out_Valid        : out   std_logic;
        Out_Ready        : in    std_logic := '1'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc is

    -- Constants
    constant CrcWidth_c     : natural                                 := Polynomial_g'length;
    constant ZeroPoly_c     : std_logic_vector(CrcWidth_c-1 downto 0) := (others => '0');
    constant InitialValue_c : std_logic_vector(CrcWidth_c-1 downto 0) := choose(InitialValue_g = "0", ZeroPoly_c, InitialValue_g);
    constant XorOutput_c    : std_logic_vector(CrcWidth_c-1 downto 0) := choose(XorOutput_g = "0", ZeroPoly_c, XorOutput_g);

    -- Signals
    signal LfsrReg     : std_logic_vector(CrcWidth_c-1 downto 0);
    signal Out_Valid_I : std_logic;
    signal In_Ready_I  : std_logic;

begin

    assert BitOrder_g = "MSB_FIRST" or BitOrder_g = "LSB_FIRST"
        report "###ERROR###: olo_base_crc - Illegal value for BitOrder_g"
        severity error;
    assert ByteOrder_g = "NONE" or ByteOrder_g = "LSB_FIRST" or ByteOrder_g = "MSB_FIRST"
        report "###ERROR###: olo_base_crc - Illegal value for ByteOrder_g"
        severity error;
    assert ByteOrder_g = "NONE" or DataWidth_g mod 8 = 0
        report "###ERROR###: olo_base_crc - For DataWidth_g not being a multiple of 8, only ByteOrder_g=NONE is allowed"
        severity error;
    assert InitialValue_c'length = CrcWidth_c
        report "###ERROR###: olo_base_crc - InitialValue_g must have the same length as Polynomial_g"
        severity error;
    assert XorOutput_c'length = CrcWidth_c
        report "###ERROR###: olo_base_crc - XorOutput_g must have the same length as Polynomial_g"
        severity error;

    p_lfsr : process (Clk) is
        variable Input_v : std_logic_vector(In_Data'range);
        variable Lfsr_v  : std_logic_vector(LfsrReg'range);
        variable InBit_v : std_logic;
        variable Out_v   : std_logic_vector(CrcWidth_c-1 downto 0);
    begin
        if rising_edge(Clk) then
            -- Handle Input permutation (LFFSR always processes MSB first)
            Input_v := In_Data;
            if BitOrder_g = "MSB_FIRST" then
                if ByteOrder_g = "LSB_FIRST" then
                    Input_v := invertByteOrder(Input_v);
                end if;
            else
                if ByteOrder_g = "MSB_FIRST" then
                    Input_v := invertByteOrder(Input_v);
                end if;
                Input_v := invertBitOrder(Input_v);
            end if;

            -- Reset valid after output transmitted
            if Out_Valid_I = '1' and Out_Ready = '1' then
                Out_Valid_I <= '0';
            end if;

            -- Normal Operation
            if In_Valid = '1' and In_Ready_I = '1' then
                -- First Handling
                if In_First = '1' then
                    Lfsr_v := InitialValue_c;
                else
                    Lfsr_v := LfsrReg;
                end if;

                -- Loop over all bits in symbol
                for bit in DataWidth_g-1 downto 0 loop

                    -- Input Handling
                    InBit_v := Input_v(bit) xor Lfsr_v(Lfsr_v'high);

                    -- XOR hanling
                    Lfsr_v := Lfsr_v(Lfsr_v'high-1 downto 0) & '0';
                    if InBit_v = '1' then
                        Lfsr_v := Lfsr_v xor Polynomial_g;
                    end if;

                end loop;

                -- Output Data
                Out_v := Lfsr_v;
                if BitflipOutput_g then
                    Out_v := invertBitOrder(Out_v);
                end if;
                Out_Crc <= Out_v xor XorOutput_c;

                -- Last Handling
                if In_Last = '1' then
                    Lfsr_v      := InitialValue_c;
                    Out_Valid_I <= '1';
                end if;
                LfsrReg <= Lfsr_v;
            end if;

            -- Reset
            if Rst = '1' then
                LfsrReg     <= InitialValue_c;
                Out_Crc     <= (others => '0');
                Out_Valid_I <= '0';
            end if;

        end if;
    end process;

    -- Combinatorial handling
    In_Ready_I <= Out_Ready or not Out_Valid_I;

    -- Forward internal signal to outputs
    Out_Valid <= Out_Valid_I;
    In_Ready  <= In_Ready_I;

end architecture;
