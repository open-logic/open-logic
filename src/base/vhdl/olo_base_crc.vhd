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

-- Enforce "downto" for Polynomial_g and InitialValue_g
-- Add "strobe" (for Nx8 only)
-- Doc: No flip output, no xor output (do external, suggest functions)
       -- Or still do them?
-- Test Valid Low
-- Test: Different initial values
-- Test: Different bit orders
-- Add "byte order" (for Nx8 only)
-- test: different byte orders
-- Test synthesis


---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_crc is
    generic (
        CrcWidth_g     : positive range 2 to natural'high;
        Polynomial_g   : std_logic_vector;  -- according to https://crccalc.com/?crc=01&method=CRC-8&datatype=hex&outtype=bin
        InitialValue_g : std_logic_vector;
        DataWidth_g    : positive;
        BitOrder_g     : string := "MSB_FIRST"; -- "MSB_FIRST" or "LSB_FIRST"
        ByteOrder_g    : string := "NONE"       -- "NONE", "MSB_FIRST" or "LSB_FIRST"  

    );
    port (
        -- Control Ports
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Input
        In_Data          : in    std_logic_vector(DataWidth_g-1 downto 0);
        In_Valid         : in    std_logic := '1';
        In_Last          : in    std_logic := '0';
        In_First         : in    std_logic := '0';
        -- Output
        Out_Crc          : out   std_logic_vector(CrcWidth_g-1 downto 0);
        Out_Valid        : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc is

    -- Signals
    signal LfsrReg : std_logic_vector(CrcWidth_g-1 downto 0);

begin

    assert Polynomial_g'length = CrcWidth_g
        report "###ERROR###: olo_base_crc - Polynomial_g width must match CrcWidth_g"
        severity error;
    assert InitialValue_g'length = CrcWidth_g
        report "###ERROR###: olo_base_crc - InitialValue_g width must match CrcWidth_g"
        severity error;
    assert BitOrder_g = "MSB_FIRST" or BitOrder_g = "LSB_FIRST"
        report "###ERROR###: olo_base_crc - Illegal value for BitOrder_g"
        severity error; 
    assert ByteOrder_g = "NONE" or ByteOrder_g = "LSB_FIRST" or ByteOrder_g = "MSB_FIRST" 
        report "###ERROR###: olo_base_crc - Illegal value for ByteOrder_g"
        severity error;        
    assert ByteOrder_g = "NONE" or DataWidth_g mod 8 = 0
        report "###ERROR###: olo_base_crc - For DataWidth_g not being a multiple of 8, only ByteOrder_g=NONE is allowed"
        severity error;

    p_lfsr : process (Clk) is
        variable Input_v      : std_logic_vector(In_Data'range);
        variable Lfsr_v       : std_logic_vector(LfsrReg'range);
        variable InBit_v      : std_logic;
        variable Idx_v        : integer range 0 to DataWidth_g-1;
    begin
        if rising_edge(Clk) then
            -- Handle Input permutation (LFFSR always processes MSB first)
            if BitOrder_g = "MSB_FIRST" then
                if ByteOrder_g = "LSB_FIRST" then
                    Input_v := invertByteOrder(In_Data);
                else
                    Input_v := In_Data;
                end if;
            else
                if ByteOrder_g = "MSB_FIRST" then
                    Input_v := invertByteOrder(In_Data);
                end if;
                Input_v := invertBitOrder(Input_v);
            end if;


            -- Normal Operation
            if In_Valid = '1' then
                -- First Handling
                if In_First = '1' then
                    Lfsr_v := InitialValue_g;
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
                Out_Crc <= Lfsr_v;

                -- Last Handling
                if In_Last = '1' then
                    Lfsr_v := InitialValue_g;
                end if;
                LfsrReg <= Lfsr_v;
            end if;

            -- Output Handling
            Out_Valid <= In_Valid and In_Last;

            -- Reset
            if Rst = '1' then
                LfsrReg <= InitialValue_g;
                Out_Crc <= (others => '0');
                Out_Valid <= '0';
            end if;

        end if;
    end process;

end architecture;
