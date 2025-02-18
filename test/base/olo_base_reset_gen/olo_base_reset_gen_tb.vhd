---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library work;
    use work.olo_test_activity_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_reset_gen_tb is
    generic (
        runner_cfg          : string;
        RstPulseCycles_g    : positive range 3 to positive'high := 3;
        RstInPolarity_g     : integer range 0 to 1              := 1;
        AsyncResetOutput_g  : boolean                           := true
    );
end entity;

architecture sim of olo_base_reset_gen_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c   : real      := 100.0e6;
    constant Clk_Period_c      : time      := (1 sec) / Clk_Frequency_c;
    constant RstPolarityStdl_c : std_logic := choose(RstInPolarity_g = 1, '1', '0');

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk    : std_logic := '1';
    signal RstOut : std_logic;
    signal RstIn  : std_logic := not RstPolarityStdl_c;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_reset_gen
        generic map (
            RstPulseCycles_g    => RstPulseCycles_g,
            RstInPolarity_g     => RstPolarityStdl_c,
            AsyncResetOutput_g  => AsyncResetOutput_g
        )
        port map (
            Clk     => Clk,
            RstOut  => RstOut,
            RstIn   => RstIn
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because Resets are not data-flow oriented
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        -- Check reset after power-up
        wait for 1 ns;

        for i in 0 to RstPulseCycles_g-1 loop
            check_equal(RstOut, '1', "reset after power-up");
            wait until rising_edge(Clk);
        end loop;

        -- On synchronous assertion removal takes longer due to the synchronizer
        if not AsyncResetOutput_g then
            wait for 2*Clk_Period_c;
        end if;

        -- Check removal
        wait for 0.1*Clk_Period_c;
        check_equal(RstOut, '0', "reset removal after power-up");
        wait for 1 us;

        while test_suite loop
            -- Always edge align before test case
            wait until rising_edge(Clk);

            -- Asynchronous detection
            if run("AsyncDetect") then
                -- Assert reset
                wait until rising_edge(Clk);
                wait for 0.1*Clk_Period_c;
                RstIn <= RstPolarityStdl_c;
                wait for 0.1*Clk_Period_c;
                RstIn <= not RstPolarityStdl_c;

                -- Wait for reset output
                wait_for_value_stdl(RstOut, '1', 1 us, "AsyncDetect - RstOut assertion");
                wait_for_value_stdl(RstOut, '0', Clk_Period_c*(RstPulseCycles_g*2), "AsyncDetect - RstOut de-assertion");
            end if;

            -- Pulse Duration
            if run("PulseDuration") then
                -- Reset Assertion
                RstIn <= RstPolarityStdl_c;
                wait until rising_edge(Clk);
                RstIn <= not RstPolarityStdl_c;

                -- Check Duration
                wait_for_value_stdl(RstOut, '1', 1 us, "RstOut assertion");

                for i in 0 to RstPulseCycles_g-1 loop
                    check_equal(RstOut, '1', "reset removed early");
                    wait until rising_edge(Clk);
                end loop;

                -- On synchronous assertion removal takes longer due to the synchronizer
                if not AsyncResetOutput_g then
                    wait for Clk_Period_c;
                end if;

                wait for 0.1*Clk_Period_c;
                check_equal(RstOut, '0', "reset removed late");
            end if;

            -- Asynchronous Forwarding
            if run("AsyncForward") then
                -- Assert reset
                wait until rising_edge(Clk);
                wait for 0.1*Clk_Period_c;
                RstIn <= RstPolarityStdl_c;
                wait for 0.1*Clk_Period_c;
                RstIn <= not RstPolarityStdl_c;

                -- Wait for reset output (only check when enabled)
                if AsyncResetOutput_g then
                    check_equal(RstOut, '1', "AsyncForward - RstOut assertion");
                    wait_for_value_stdl(RstOut, '0', Clk_Period_c*(RstPulseCycles_g*2), "AsyncForward - RstOut de-assertion");
                end if;
            end if;

            -- Delay between tests
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
