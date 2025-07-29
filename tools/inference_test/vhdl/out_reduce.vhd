---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Route a number of DUT outputs to only 2 I/Os but avoid them to be optimized away.
-- This is useful for synthesis tools that cannot complete synthesis for designs with more I/Os
-- than the target device.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity out_reduce is
    generic (
        Size_g : natural := 8
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        -- Real ports
        Data        : out   std_logic;
        Latch       : in    std_logic;
        -- DUT Ports
        DutPorts    : in    std_logic_vector(Size_g - 1 downto 0)
    );
end entity;

architecture rtl of out_reduce is

    signal ShiftReg : std_logic_vector(Size_g - 1 downto 0) := (others => '0');

begin

    p_reduce : process (Clk) is
    begin
        if rising_edge(Clk) then
            ShiftReg <= ShiftReg(Size_g - 2 downto 0) & '0';
            if Latch = '1' then
                ShiftReg <= DutPorts;
            end if;
        end if;
    end process;

    Data <= ShiftReg(ShiftReg'high);

end architecture;
