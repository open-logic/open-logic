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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cc_reset_tb is
    generic (
        runner_cfg     : string;
        ClockRatio_N_g : integer               := 3;
        ClockRatio_D_g : integer               := 2;
        SyncStages_g   : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_reset_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClockRatio_c : real := real(ClockRatio_N_g) / real(ClockRatio_D_g);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkA_Frequency_c     : real := 100.0e6;
    constant ClkA_Period_c        : time := (1 sec) / ClkA_Frequency_c;
    constant ClkB_Frequency_c     : real := ClkA_Frequency_c * ClockRatio_c;
    constant ClkB_Period_c        : time := (1 sec) / ClkB_Frequency_c;
    constant SlowerClock_Period_c : time := (1 sec) / minimum(ClkA_Frequency_c, ClkB_Frequency_c);
    constant PropagationTime_c    : time := (real(SyncStages_g + 1) + 0.01) * SlowerClock_Period_c;
    constant RemovalTime_c        : time := 10*SlowerClock_Period_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal A_Clk    : std_logic := '0';
    signal A_RstIn  : std_logic := '0';
    signal A_RstOut : std_logic;
    signal B_Clk    : std_logic := '0';
    signal B_RstIn  : std_logic := '0';
    signal B_RstOut : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Signals
    -----------------------------------------------------------------------------------------------
    signal LastRstA : time := 0 ns;
    signal LastRstB : time := 0 ns;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_reset
        generic map (
            SyncStages_g => SyncStages_g
        )
        port map (
            -- Clock Domain A
            A_Clk     => A_Clk,
            A_RstIn   => A_RstIn,
            A_RstOut  => A_RstOut,
            -- Clock Domain B
            B_Clk     => B_Clk,
            B_RstIn   => B_RstIn,
            B_RstOut  => B_RstOut
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    A_Clk <= not A_Clk after 0.5 * ClkA_Period_c;
    B_Clk <= not B_Clk after 0.5 * ClkB_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because Resets are not data-flow oriented
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        wait for RemovalTime_c;
        check_equal(B_RstOut, '0', "deassert B 1");
        check_equal(A_RstOut, '0', "deassert A 1");
        check(LastRstA > 0 ns, "reset A not detected");
        check(LastRstB > 0 ns, "reset B not detected");

        while test_suite loop

            -- Check if singla RST A  pulse is distribued to both sides and held
            if run("RstA-Distribution") then
                -- long pulse
                wait until rising_edge(A_Clk);
                A_RstIn <= '1';
                wait for PropagationTime_c;
                check_equal(B_RstOut, '1', "assert B 2.1");
                check_equal(A_RstOut, '1', "assert A 2.1");
                wait for PropagationTime_c;
                check_no_activity_stdl(B_RstOut, PropagationTime_c, "unexpected activity B 2.1");
                check_no_activity_stdl(A_RstOut, PropagationTime_c, "unexpected activity A 2.1");
                wait until rising_edge(A_Clk);
                A_RstIn <= '0';
                wait for RemovalTime_c;
                check_equal(B_RstOut, '0', "deassert B 2.1");
                check_equal(A_RstOut, '0', "deassert A 2.1");

                -- short pulse
                wait for 1 us;
                pulse_sig(A_RstIn, A_Clk);
                wait for PropagationTime_c;
                check(LastRstA > now-PropagationTime_c-0.5 us, "reset A not detected 2.2");
                check(LastRstB > now-PropagationTime_c-0.5 us, "reset B not detected 2.2");
                wait for RemovalTime_c;
                check_equal(B_RstOut, '0', "deassert B 2.2");
                check_equal(A_RstOut, '0', "deassert A 2.2");

            -- Check if singla RST B  pulse is distribued to both sides and held
            elsif run("RstB-Distribution") then
                -- long pulse
                wait until rising_edge(B_Clk);
                B_RstIn <= '1';
                wait for PropagationTime_c;
                check_equal(B_RstOut, '1', "assert B 3.1");
                check_equal(A_RstOut, '1', "assert A 3.1");
                wait for PropagationTime_c;
                check_no_activity_stdl(B_RstOut, PropagationTime_c, "unexpected activity B 3.1");
                check_no_activity_stdl(A_RstOut, PropagationTime_c, "unexpected activity A 3.1");
                wait until rising_edge(B_Clk);
                B_RstIn <= '0';
                wait for RemovalTime_c;
                check_equal(B_RstOut, '0', "deassert B 3.1");
                check_equal(A_RstOut, '0', "deassert A 3.1");

                -- short pulse
                wait for 1 us;
                pulse_sig(B_RstIn, B_Clk);
                wait for PropagationTime_c;
                check(LastRstA > now-PropagationTime_c-0.5 us, "reset A not detected 3.2");
                check(LastRstB > now-PropagationTime_c-0.5 us, "reset B not detected 3.2");
                wait for RemovalTime_c;
                check_equal(B_RstOut, '0', "deassert B 3.2");
                check_equal(A_RstOut, '0', "deassert A 3.2");

            -- Check ignore glitches RST B
            elsif run("RstB-GlitchIgnore") then
                wait until rising_edge(B_Clk);
                wait for ClkB_Period_c/10;
                B_RstIn <= '1';
                wait for ClkB_Period_c/2;
                B_RstIn <= '0';
                wait for RemovalTime_c;
                check(B_RstOut'last_event >= RemovalTime_c, "RstB glitch affected RstB");
                check(A_RstOut'last_event >= RemovalTime_c, "RstB glitch affected RstA");

            -- Check ignore glitches RST A
            elsif run("RstA-GlitchIgnore") then
                wait until rising_edge(A_Clk);
                wait for ClkA_Period_c/10;
                A_RstIn <= '1';
                wait for ClkA_Period_c/2;
                A_RstIn <= '0';
                wait for RemovalTime_c;
                check(B_RstOut'last_event >= RemovalTime_c, "RstA glitch affected RstB");
                check(A_RstOut'last_event >= RemovalTime_c, "RstA glitch affected RstA");

            -- Check hold both
            elsif run("HoldBoth") then
                wait until rising_edge(B_Clk);
                B_RstIn <= '1';
                wait until rising_edge(A_Clk);
                A_RstIn <= '1';
                wait until rising_edge(A_Clk);
                wait_for_value_stdl(A_RstOut, '1', PropagationTime_c, "assert A 6"); -- Wait until both resets asserted
                wait_for_value_stdl(B_RstOut, '1', PropagationTime_c, "assert B 6"); -- Wait until both resets asserted

                for i in 0 to 9 loop
                    wait until rising_edge(A_Clk);
                    check_equal(A_RstOut, '1', "hold A 6");
                    wait until rising_edge(B_Clk);
                    check_equal(B_RstOut, '1', "hold B 6");
                end loop;

                wait until rising_edge(B_Clk);
                B_RstIn <= '0';
                wait until rising_edge(A_Clk);
                A_RstIn <= '0';
                wait for RemovalTime_c;
                check_equal(B_RstOut, '0', "deassert B 6");
                check_equal(A_RstOut, '0', "deassert A 6");
            end if;
        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    p_rst_detect_a : process is
    begin
        wait until A_RstOut = '1' and B_RstOut = '1'; -- chekck that both resets are asserted at the same time
        wait until rising_edge(A_Clk) and A_RstOut = '1'; -- check that the reset gets de-asserted
        LastRstA <= now;
    end process;

    p_rst_detect_b : process is
    begin
        wait until A_RstOut = '1' and A_RstOut = '1';
        wait until rising_edge(B_Clk) and B_RstOut = '1';
        LastRstB <= now;
    end process;

end architecture;
