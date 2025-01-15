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
-- Test: Multi cycle
-- Test: Last, First
-- Test: Different widths
-- Test: Same/different data/crc width
-- Test: Different polynomials
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
        BitOrder_g     : string := "MSB_FIRST"
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
        Out_Valid        : out   std_logic;
        Out_Last         : out   std_logic
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

    p_lfsr : process (Clk) is
        variable Lfsr_v       : std_logic_vector(LfsrReg'range);
        variable InBit_v      : std_logic;
        variable Idx_v        : integer range 0 to DataWidth_g-1;
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            if In_Valid = '1' then
                -- First Handling
                if In_First = '1' then
                    Lfsr_v := InitialValue_g;
                else
                    Lfsr_v := LfsrReg;
                end if;

                -- Loop over all bits in symbol
                for bit in 0 to DataWidth_g-1 loop
                    -- Handle Bit-Order
                    if BitOrder_g = "LSB_FIRST" then
                        Idx_v := bit;
                    else
                        Idx_v := DataWidth_g-1 - bit;
                    end if;

                    -- Input Handling
                    InBit_v := In_Data(Idx_v) xor Lfsr_v(Lfsr_v'high);
                    
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
            Out_Valid <= In_Valid;
            Out_Last <= In_Last;

            -- Reset
            if Rst = '1' then
                LfsrReg <= InitialValue_g;
                Out_Crc <= (others => '0');
                Out_Valid <= '0';
                Out_Last <= '0';
            end if;

        end if;
    end process;

end architecture;
