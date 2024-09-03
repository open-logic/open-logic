---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows passing multple independent
-- single-bit signals from one clock domain to another one.
-- Double stage synchronizers are implemeted for each bit, including then
-- required attributes for correct synthesis

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------

entity olo_base_cc_bits is
    generic (
        Width_g : positive := 1
    );
    port (
        -- Input clock domain
        In_Clk   : in    std_logic;
        In_Rst   : in    std_logic := '0';
        In_Data  : in    std_logic_vector(Width_g - 1 downto 0);
        -- Output clock domain
        Out_Clk  : in    std_logic;
        Out_Rst  : in    std_logic := '0';
        Out_Data : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------

architecture struct of olo_base_cc_bits is

    -- Synchronizer registers (plain VHDL)
    signal RegIn : std_logic_vector(Width_g - 1 downto 0) := (others => '0');
    signal Reg0  : std_logic_vector(Width_g - 1 downto 0) := (others => '0');
    signal Reg1  : std_logic_vector(Width_g - 1 downto 0) := (others => '0');

    -- Synthesis attributes AMD (Vivado)
    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of Reg0  : signal is "no";
    attribute SHREG_EXTRACT of Reg1  : signal is "no";
    attribute SHREG_EXTRACT of RegIn : signal is "no";

    -- Synthesis attributes for AMD (Vivado) and Efinix (Efinity)
    attribute ASYNC_REG : boolean;
    attribute ASYNC_REG of Reg0  : signal is true;
    attribute ASYNC_REG of Reg1  : signal is true;
    attribute ASYNC_REG of RegIn : signal is true;

    attribute SYN_SRLSTYLE : string;
    attribute SYN_SRLSTYLE of Reg0  : signal is "registers";
    attribute SYN_SRLSTYLE of Reg1  : signal is "registers";
    attribute SYN_SRLSTYLE of RegIn : signal is "registers";

    -- Synthesis attributes Altera (Quartus)
    attribute DONT_MERGE : boolean;
    attribute DONT_MERGE of Reg0  : signal is true;
    attribute DONT_MERGE of Reg1  : signal is true;
    attribute DONT_MERGE of RegIn : signal is true;

    attribute PRESERVE : boolean;
    attribute PRESERVE of Reg0  : signal is true;
    attribute PRESERVE of Reg1  : signal is true;
    attribute PRESERVE of RegIn : signal is true;

    signal In_Clk_Sig : std_logic;

    -- Synthesis attributes Xilinx
    attribute DONT_TOUCH                    : boolean;
    attribute KEEP                          : string;
    attribute DONT_TOUCH of In_Clk_Sig : signal is true;
    attribute KEEP of In_Clk_Sig       : signal is "yes";

begin

    In_Clk_Sig <= In_Clk;

    p_inff : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            RegIn <= In_Data;
            if In_Rst = '1' then
                RegIn <= (others => '0');
            end if;
        end if;
    end process;

    p_outff : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then
            Reg0 <= RegIn;
            Reg1 <= Reg0;
            if Out_Rst = '1' then
                Reg0 <= (others => '0');
                Reg1 <= (others => '0');
            end if;
        end if;
    end process;

    Out_Data <= Reg1;

end architecture;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
