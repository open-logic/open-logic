---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a sample and hold. The output holds the last
-- sampled value until a new sample is taken.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_sample_hold.md
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
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_sample_hold is
    generic (
        Width_g      : positive;
        ResetValue_g : std_logic_vector;
        ResetValid_g : boolean := true
    );
    port (
        -- Control Ports
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Data   : in    std_logic_vector(Width_g - 1 downto 0);
        In_Valid  : in    std_logic;
        -- Output
        Out_Data  : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Valid : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_sample_hold is

    -- Reset value as std_logic_vector
    constant RstVal_c   : std_logic_vector(Width_g - 1 downto 0) := ResetValue_g;
    constant RstValid_c : std_logic                              := choose(ResetValid_g, '1', '0');

    -- Registers
    signal Data  : std_logic_vector(Width_g - 1 downto 0);
    signal Valid : std_logic;

begin

    -- Assertions
    -- synthesis translate_off
    assert ResetValue_g'length = Width_g
        report "Rolo_base_sample_hold - ResetValue_g must have the same length as Width_g"
        severity failure;
    -- synthesis translate_on

    -- Sample and hold process
    p_sample_hold : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Sample on valid
            if In_Valid = '1' then
                Out_Data  <= In_Data;
                Out_Valid <= '1';
            end if;

            -- Reset
            if Rst = '1' then
                Out_Data  <= RstVal_c;
                Out_Valid <= RstValid_c;
            end if;
        end if;
    end process;

end architecture;
