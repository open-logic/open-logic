---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a simple double-stage synchronizer for synchronizing external
-- signals to the internal system clock.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------

entity olo_intf_sync is
    generic (
        Width_g     : positive  := 1;
        RstLevel_g  : std_logic := '0'
    );
    port (
        -- control signals
        Clk         : in    std_logic;
        Rst         : in    std_logic := '0';
        -- Input clock domain
        DataAsync   : in    std_logic_vector(Width_g - 1 downto 0);
        DataSync    : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------

architecture struct of olo_intf_sync is

    -- Synchronizer registers (plain VHDL)
    signal Reg0 : std_logic_vector(Width_g - 1 downto 0) := (others => '0');
    signal Reg1 : std_logic_vector(Width_g - 1 downto 0) := (others => '0');

    -- Synthesis attributes AMD (Vivado)
    attribute shreg_extract : string;
    attribute shreg_extract of Reg0 : signal is "no";
    attribute shreg_extract of Reg1 : signal is "no";

    -- Synthesis attributes for AMD (Vivado) and Efinitx (Efinity)
    attribute async_reg : boolean;
    attribute async_reg of Reg0 : signal is true;
    attribute async_reg of Reg1 : signal is true;

    attribute syn_srlstyle : string;
    attribute syn_srlstyle of Reg0 : signal is "registers";
    attribute syn_srlstyle of Reg1 : signal is "registers";

    -- Synthesis attributes Altera (Quartus)
    attribute dont_merge : boolean;
    attribute dont_merge of Reg0 : signal is true;
    attribute dont_merge of Reg1 : signal is true;

    attribute preserve : boolean;
    attribute preserve of Reg0 : signal is true;
    attribute preserve of Reg1 : signal is true;

    -- Synthesis attributes for Synopsys (Lattice, Actel)
    attribute syn_keep : boolean;
    attribute syn_keep of Reg0 : signal is true;
    attribute syn_keep of Reg1 : signal is true;

    attribute syn_preserve : boolean;
    attribute syn_preserve of Reg0 : signal is true;
    attribute syn_preserve of Reg1 : signal is true;

begin

    -- Synchronizer process
    p_outff : process (Clk) is
    begin
        if rising_edge(Clk) then
            Reg0 <= DataAsync;
            Reg1 <= Reg0;
            if Rst = '1' then
                Reg0 <= (others => RstLevel_g);
                Reg1 <= (others => RstLevel_g);
            end if;
        end if;
    end process;

    DataSync <= Reg1;

end architecture;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
