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
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_bits.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

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
        Width_g      : positive              := 1;
        SyncStages_g : positive range 2 to 4 := 2
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

    -- Types
    type SyncStages_t is array(0 to SyncStages_g - 2) of std_logic_vector(Width_g - 1 downto 0);

    -- Synchronizer registers
    signal RegIn : std_logic_vector(Width_g - 1 downto 0) := (others => '0');
    signal Reg0  : std_logic_vector(Width_g - 1 downto 0) := (others => '0');
    signal RegN  : SyncStages_t                           := (others => (others => '0'));

    -- Synthesis attributes AMD (Vivado)
    attribute shreg_extract : string;
    attribute shreg_extract of Reg0  : signal is "no";
    attribute shreg_extract of RegN  : signal is "no";
    attribute shreg_extract of RegIn : signal is "no";

    -- Synthesis attributes for AMD (Vivado) and Efinix (Efinity)
    attribute async_reg : boolean;
    attribute async_reg of Reg0  : signal is true;
    attribute async_reg of RegN  : signal is true;
    attribute async_reg of RegIn : signal is true;

    -- Synthesis attributes for AMD (Vivado) and Efinix (Efinity) and Gowin
    attribute syn_srlstyle : string;
    attribute syn_srlstyle of Reg0  : signal is "registers";
    attribute syn_srlstyle of RegN  : signal is "registers";
    attribute syn_srlstyle of RegIn : signal is "registers";

    -- Synthesis attributes Altera (Quartus)
    attribute dont_merge : boolean;
    attribute dont_merge of Reg0  : signal is true;
    attribute dont_merge of RegN  : signal is true;
    attribute dont_merge of RegIn : signal is true;

    attribute preserve : boolean;
    attribute preserve of Reg0  : signal is true;
    attribute preserve of RegN  : signal is true;
    attribute preserve of RegIn : signal is true;

    -- Synthesis attributes for Synopsis (Lattice, Microchip), Efinity and Gowin
    -- Note: integer is also confirmed to work for Synopsys/Efinity although documentation only states boolean. Chose
    --       integer because Gowin only accepts integer.
    attribute syn_preserve : integer;
    attribute syn_preserve of Reg0  : signal is 1;
    attribute syn_preserve of RegN  : signal is 1;
    attribute syn_preserve of RegIn : signal is 1;

    attribute syn_keep : integer;
    attribute syn_keep of Reg0  : signal is 1;
    attribute syn_keep of RegN  : signal is 1;
    attribute syn_keep of RegIn : signal is 1;

    signal In_Clk_Sig : std_logic;

    -- Synthesis attributes automatic constraining (AMD only)
    attribute dont_touch               : boolean;
    attribute keep                     : string;
    attribute dont_touch of In_Clk_Sig : signal is true;
    attribute keep of In_Clk_Sig       : signal is "yes";

begin

    In_Clk_Sig <= In_Clk;

    -- Input Register
    p_inff : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            RegIn <= In_Data;
            if In_Rst = '1' then
                RegIn <= (others => '0');
            end if;
        end if;
    end process;

    -- Synchronizer process
    p_outff : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then
            -- *** Synchronization ***
            -- First two stages
            Reg0    <= RegIn;
            RegN(0) <= Reg0;

            -- Loop through aremaining stages
            for i in 1 to RegN'high loop
                RegN(i) <= RegN(i - 1);
            end loop;

            -- *** Reset ***
            if Out_Rst = '1' then
                Reg0 <= (others => '0');
                RegN <= (others => (others => '0'));
            end if;
        end if;
    end process;

    -- Output is content of last sync stage
    Out_Data <= RegN(RegN'high);

end architecture;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
