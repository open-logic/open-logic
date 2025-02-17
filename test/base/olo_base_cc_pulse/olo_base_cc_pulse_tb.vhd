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

library vunit_lib;
    context vunit_lib.vunit_context;

library work;
    use work.olo_test_activity_pkg.all;

library olo;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cc_pulse_tb is
    generic (
        runner_cfg     : string;
        ClockRatio_N_g : integer               := 3;
        ClockRatio_D_g : integer               := 2;
        SyncStages_g   : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_pulse_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClockRatio_c : real    := real(ClockRatio_N_g) / real(ClockRatio_D_g);
    constant NumPulses_c  : integer := 4;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkIn_Frequency_c    : real := 100.0e6;
    constant ClkIn_Period_c       : time := (1 sec) / ClkIn_Frequency_c;
    constant ClkOut_Frequency_c   : real := ClkIn_Frequency_c * ClockRatio_c;
    constant ClkOut_Period_c      : time := (1 sec) / ClkOut_Frequency_c;
    constant SlowerClock_Period_c : time := (1 sec) / minimum(ClkIn_Frequency_c, ClkOut_Frequency_c);
    constant MaxReactionTime_c    : time := (8 + SyncStages_g)*SlowerClock_Period_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk     : std_logic                                  := '0';
    signal In_RstIn   : std_logic                                  := '1';
    signal In_RstOut  : std_logic;
    signal In_Pulse   : std_logic_vector(NumPulses_c - 1 downto 0) := x"0";
    signal Out_Clk    : std_logic                                  := '0';
    signal Out_RstIn  : std_logic                                  := '1';
    signal Out_RstOut : std_logic;
    signal Out_Pulse  : std_logic_vector(NumPulses_c - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_pulse
        generic map (
            NumPulses_g  => NumPulses_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            -- Clock Domain A
            In_Clk      => In_Clk,
            In_RstIn    => In_RstIn,
            In_RstOut   => In_RstOut,
            In_Pulse    => In_Pulse,
            -- Clock Domain B
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => Out_RstOut,
            Out_Pulse   => Out_Pulse
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    In_Clk  <= not In_Clk after 0.5 * ClkIn_Period_c;
    Out_Clk <= not Out_Clk after 0.5 * ClkOut_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable v : std_logic_vector(Out_Pulse'range);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            In_RstIn  <= '1';
            Out_RstIn <= '1';
            wait for MaxReactionTime_c;

            -- Check if both sides are in reset
            check(In_RstOut = '1', "In_RstOut not asserted");
            check(Out_RstOut = '1', "Out_RstOut not asserted");

            -- Remove reset
            wait until rising_edge(In_Clk);
            In_RstIn  <= '0';
            wait until rising_edge(Out_Clk);
            Out_RstIn <= '0';
            wait for MaxReactionTime_c;

            -- *** Reset Tests ***
            if run("Reset") then

                -- Check if both sides exited reset
                check(In_RstOut = '0', "In_RstOut not de-asserted");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted");

                -- Check if RstA is propagated to both sides
                wait until rising_edge(In_Clk);
                In_RstIn <= '1';
                wait until rising_edge(In_Clk);
                In_RstIn <= '0';
                wait for MaxReactionTime_c*2;
                check(In_RstOut = '0', "In_RstOut not de-asserted after In_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after In_RstIn");
                check(In_RstOut'last_event < MaxReactionTime_c*2, "In_RstOut not asserted after In_RstIn");
                check(Out_RstOut'last_event < MaxReactionTime_c*2, "Out_RstOut not asserted afterIn_RstIn");

                -- Check if RstB is propagated to both sides
                wait until rising_edge(Out_Clk);
                Out_RstIn <= '1';
                wait until rising_edge(Out_Clk);
                Out_RstIn <= '0';
                wait for MaxReactionTime_c*2;
                check(In_RstOut = '0', "In_RstOut not de-asserted after Out_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after Out_RstIn");
                check(In_RstOut'last_event < MaxReactionTime_c*2, "In_RstOut not asserted after Out_RstIn");
                check(Out_RstOut'last_event < MaxReactionTime_c*2, "Out_RstOut not asserted after Out_RstIn");

            -- *** Pulse Tests ***
            elsif run("Normal-Operation") then

                -- single pulse
                for idx in 0 to 3 loop
                    -- Send pulse
                    wait until rising_edge(In_Clk);
                    In_Pulse(idx) <= '1';
                    wait until rising_edge(In_Clk);
                    In_Pulse(idx) <= '0';
                    -- Wait for output pulse
                    v      := (others => '0');
                    v(idx) := '1';
                    wait_for_value_stdlv(Out_Pulse, v, 100 us, "Pulse not transferred 1");
                    wait until rising_edge(Out_Clk);
                    wait until rising_edge(Out_Clk);
                    v      := (others => '0');
                    check_equal(Out_Pulse, v, "Pulse not removed 1");
                end loop;

                -- multiple pulses
                -- .. in practice pulses could be shifted by one clock cycle but in simulation they are not
                -- Send pulse
                wait until rising_edge(In_Clk);
                In_Pulse <= "0101";
                wait until rising_edge(In_Clk);
                In_Pulse <= "0000";
                -- Wait for output pulse
                wait_for_value_stdlv(Out_Pulse, "0101", 100 us, "Pulse not transferred 2");
                wait until rising_edge(Out_Clk);
                wait until rising_edge(Out_Clk);
                v := (others => '0');
                check_equal(Out_Pulse, v, "Pulse not removed 2");

            -- *** Test if no pulse is transferred after the internal toggle FF is reset by RstIn ***
            elsif run("NoPulse-RstIn") then
                -- transfer one pulse
                pulse_sig(In_Pulse(0), In_Clk);
                wait_for_value_stdlv(Out_Pulse, "0001", 100 us, "Pulse not transferred 3");
                -- Check if no pulse is produced by RstIn
                wait for MaxReactionTime_c;
                pulse_sig(In_RstIn, In_Clk);
                wait for MaxReactionTime_c;
                check_no_activity_stdlv(Out_Pulse, MaxReactionTime_c*2, "Unexpected pulse 3");

            -- *** Test if no pulse is transferred after the internal toggle FF is reset by RstOut ***
            elsif run("NoPulse-RstOut") then
                -- transfer one pulse
                pulse_sig(In_Pulse(0), In_Clk);
                wait_for_value_stdlv(Out_Pulse, "0001", 100 us, "Pulse not transferred 4");
                -- Check if no pulse is produced by RstIn
                wait for MaxReactionTime_c;
                pulse_sig(Out_RstIn, Out_Clk);
                wait for MaxReactionTime_c;
                check_no_activity_stdlv(Out_Pulse, MaxReactionTime_c*2, "Unexpected pulse 4");
            end if;
        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
