---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a reset generator. It generates a pulse of the specified duration
-- after FPGA configuration. The reset output is High-Active according to the
-- Open-Logic definitions. The reset generator also allows synchronizing
-- asynchronous resets to the output clock domain.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_reset_gen.md
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
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_reset_gen is
    generic (
        RstPulseCycles_g    : positive range 3 to positive'high := 3;
        RstInPolarity_g     : std_logic                         := '1';
        AsyncResetOutput_g  : boolean                           := false;
        SyncStages_g        : positive range 2 to 4             := 2
    );
    port (
        Clk         : in    std_logic;
        RstOut      : out   std_logic;
        RstIn       : in    std_logic := not RstInPolarity_g
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture struct of olo_base_reset_gen is

    -- Reset Synchronizer
    signal RstSyncChain : std_logic_vector(2 downto 0)              := "111";
    signal RstSync      : std_logic;
    signal DsSync       : std_logic_vector(SyncStages_g-1 downto 0) := (others => '1');

    -- Pulse prolongation
    constant PulseCntMax_c : natural                          := max(RstPulseCycles_g-4, 0);
    signal PulseCnt        : integer range 0 to PulseCntMax_c := 0;
    signal RstPulse        : std_logic                        := '1';

    -- Synthesis attributes AMD (Vivado)
    attribute shreg_extract : string;
    attribute shreg_extract of DsSync : signal is "no";

    -- Synthesis attributes for AMD (Vivado) and Efinix (Efinity)
    attribute async_reg : boolean;
    attribute async_reg of DsSync : signal is true;

    -- Synthesis attributes for AMD (Vivado) and Efinix (Efinity) and gowin
    attribute syn_srlstyle : string;
    attribute syn_srlstyle of DsSync : signal is "registers";

    -- Synthesis attributes Altera (Quartus)
    attribute dont_merge : boolean;
    attribute dont_merge of DsSync : signal is true;

    attribute preserve : boolean;
    attribute preserve of DsSync : signal is true;

    -- Synthesis attributes for Synopsis (Lattice, Microchip), Efinity and Gowin
    -- Note: integer is also confirmed to work for Synopsys/Efinity although documentation only states boolean. Chose
    --       integer because Gowin only accepts integer.
    attribute syn_preserve : integer;
    attribute syn_preserve of DsSync : signal is 1;

    attribute syn_keep : integer;
    attribute syn_keep of DsSync : signal is 1;

begin

    -- Reset Synchronizer
    p_rstsync : process (Clk, RstIn) is
    begin
        if RstIn = RstInPolarity_g then
            RstSyncChain <= (others => '1');
        elsif rising_edge(Clk) then
            RstSyncChain <= RstSyncChain(RstSyncChain'left - 1 downto 0) & '0';
        end if;
    end process;

    -- Asynchronous assertion
    g_async : if AsyncResetOutput_g generate
        RstSync <= RstSyncChain(RstSyncChain'left);
    end generate;

    -- Synchronous assertion
    g_sync : if not AsyncResetOutput_g generate

        -- Synchronizer for synchronous assertion
        p_sync : process (Clk) is
        begin
            if rising_edge(Clk) then
                DsSync <= DsSync(DsSync'left - 1 downto 0) & RstSyncChain(RstSyncChain'left);
            end if;
        end process;

        RstSync <= DsSync(DsSync'left);
    end generate;

    -- Prolong reset pulse
    g_prolong : if RstPulseCycles_g > 3 generate

        -- Generate Pulse
        p_prolong : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Reset
                if RstSync = '1' then
                    PulseCnt <= 0;
                    RstPulse <= '1';
                -- Removal
                else
                    if PulseCnt = PulseCntMax_c then
                        RstPulse <= '0';
                    else
                        PulseCnt <= PulseCnt + 1;
                    end if;
                end if;
            end if;
        end process;

        -- Asynchronous output
        g_async : if AsyncResetOutput_g generate
            RstOut <= RstPulse or RstSync;

        end generate;

        -- Synchronous output
        g_sync : if not AsyncResetOutput_g generate
            RstOut <= RstPulse;
        end generate;

    end generate;

    g_direct : if RstPulseCycles_g <= 3 generate
        RstOut <= RstSync;
    end generate;

end architecture;


