------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
	context vunit_lib.vunit_context;

library work;
    use work.olo_test_activity_pkg.all;

library olo;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_sync_tb is
    generic (
        RstLevel_g  : std_logic := '0';
        runner_cfg     : string
    );
end entity olo_intf_sync_tb;

architecture sim of olo_intf_sync_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant DataWidth_c  : integer := 8;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c     : real    := 100.0e6;
    constant Clk_Period_c        : time    := (1 sec) / Clk_Frequency_c;
    constant Time_MaxDel_c       : time    := 2.1 * Clk_Period_c;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk         : std_logic                                  := '0';
    signal Rst          : std_logic                                  := '1';
    signal DataAsync    : std_logic_vector(DataWidth_c - 1 downto 0) := (others => RstLevel_g);
    signal DataSync     : std_logic_vector(DataWidth_c - 1 downto 0);

begin

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_sync
        generic map (
            Width_g => DataWidth_c,
            RstLevel_g => RstLevel_g
        )
        port map(
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => DataAsync,
            DataSync    => DataSync
        );

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk  <= not Clk after 0.5 * Clk_Period_c;

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        constant RstVal_c : std_logic_vector(DataWidth_c - 1 downto 0) := (others => RstLevel_g);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- *** Reset ***
            Rst <= '1';
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("ResetValue") then
                check_equal(DataSync, RstVal_c, "Data not reset");
            end if;

            if run("SimpleTransfer") then
                DataAsync  <= X"AB";
                WaitForValueStdlv(DataSync, X"AB", Time_MaxDel_c, "Data not transferred 1");
                DataAsync  <= X"CD";
                WaitForValueStdlv(DataSync, X"CD", Time_MaxDel_c, "Data not transferred 2");
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
