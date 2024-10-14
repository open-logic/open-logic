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
entity olo_intf_debounce_tb is
    generic (
        IdleLevel_g         : integer range 0 to 1 := 0;
        DebounceCycles_g    : integer              := 200;
        Mode_g              : string               := "LOW_LATENCY";
        runner_cfg          : string
    );
end entity;

architecture sim of olo_intf_debounce_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : integer := 2;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant IdleLevel_c     : std_logic := choose(IdleLevel_g = 0, '0', '1');
    constant Clk_Frequency_c : real      := 100.0e6;
    constant Clk_Period_c    : time      := (1 sec) / Clk_Frequency_c;
    constant Time_Debounce_c : time      := Clk_Period_c*DebounceCycles_g;
    constant IsLowLat_c      : boolean   := (Mode_g = "LOW_LATENCY");
    constant MaxPropDelay_c  : time      := 5*Clk_Period_c;
    constant MaxDetTime_c    : time      := Time_Debounce_c*1.1+MaxPropDelay_c;

    signal BounceOhter : boolean := false;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                  := '0';
    signal Rst       : std_logic                                  := '1';
    signal DataAsync : std_logic_vector(DataWidth_c - 1 downto 0) := (others => IdleLevel_c);
    signal DataOut   : std_logic_vector(DataWidth_c - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_debounce
        generic map (
            ClkFrequency_g  => Clk_Frequency_c,
            DebounceTime_g  => (1.0/Clk_Frequency_c)*real(DebounceCycles_g),
            Width_g         => DataWidth_c,
            IdleLevel_g     => IdleLevel_c,
            Mode_g          => Mode_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => DataAsync,
            DataOut     => DataOut
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        constant RstVal_c    : std_logic_vector(DataWidth_c - 1 downto 0) := (others => IdleLevel_c);
        variable StartTime_v : time;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- *** Reset ***
            Rst <= '1';
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("ResetValue") then
                check_equal(DataOut, RstVal_c, "Data not reset");
            end if;

            if run("SlowPulse") then
                -- Check initial state
                check_equal(DataOut(0), IdleLevel_c, "Wrong initial value");
                -- Toggle value
                DataAsync(0) <= not IdleLevel_c;
                -- Wait until value is detected
                if IsLowLat_c then
                    wait for MaxPropDelay_c;
                else
                    wait for MaxDetTime_c;
                end if;
                check_equal(DataOut(0), not IdleLevel_c, "Pulse Value wrong");
                -- wait for minimum time
                wait for MaxDetTime_c;
                -- End of pulse
                DataAsync(0) <= IdleLevel_c;
                -- Wait until new value is detected
                if IsLowLat_c then
                    wait for MaxPropDelay_c;
                else
                    wait for MaxDetTime_c;
                end if;
                check_equal(DataOut(0), IdleLevel_c, "Idle Value wrong after pulse");
            end if;

            if run("ShortPulse") then
                StartTime_v := now;
                -- Check initial state
                check_equal(DataOut(0), IdleLevel_c, "Wrong initial value");
                -- Toggle value
                DataAsync(0) <= not IdleLevel_c;
                -- Wait until value is detected for low latency
                wait for MaxPropDelay_c;
                if IsLowLat_c then
                    check_equal(DataOut(0), not IdleLevel_c, "Pulse Value wrong");
                else
                    check_equal(DataOut(0), IdleLevel_c, "Pulse Value wrong"); -- In GLTCH_FILTER mode we don't detect the pulse
                end if;
                -- End of pulse
                DataAsync(0) <= IdleLevel_c;
                -- Wait until new value is detected
                wait for Time_Debounce_c*0.8;
                if IsLowLat_c then
                    check_equal(DataOut(0), not IdleLevel_c, "After Pulse Value wrong");
                else
                    check_last_activity(DataOut(0), Time_Debounce_c*0.8, choose(IdleLevel_c='0', 0, 1), "Value after pulse 1");
                end if;
                -- After pulse value
                wait for Time_Debounce_c*0.3+MaxPropDelay_c;
                check_equal(DataOut(0), IdleLevel_c, "After Pulse Value wrong 2");
            end if;

            -- Bouncy Pulse
            if run("BouncPulse") then
                -- Check initial state
                check_equal(DataOut(0), IdleLevel_c, "Wrong initial value");
                -- Toggle value
                DataAsync(0) <= not IdleLevel_c;

                -- bounce phase
                for i in 0 to  5 loop
                    -- Check value
                    if IsLowLat_c then
                        wait for MaxPropDelay_c;
                        check_equal(DataOut(0), not IdleLevel_c, "Pulse Value wrong during bounce");
                        wait for Time_Debounce_c*0.75-MaxPropDelay_c;
                    else
                        check_equal(DataOut(0), IdleLevel_c, "Pulse Detected Early during bounce");
                        wait for Time_Debounce_c*0.75;
                    end if;
                    -- Toggle Signal
                    DataAsync(0) <= not DataAsync(0);
                end loop;

                -- wait for minimum time
                wait for MaxDetTime_c;
                check_equal(DataOut(0), not IdleLevel_c, "Pulse Value wrong");
                -- End of pulse
                DataAsync(0) <= IdleLevel_c;

                -- bounce phase
                for i in 0 to  5 loop
                    -- Check value
                    if IsLowLat_c then
                        wait for MaxPropDelay_c;
                        check_equal(DataOut(0), IdleLevel_c, "Pulse not removed during after bounce phase");
                        wait for Time_Debounce_c*0.75-MaxPropDelay_c;
                    else
                        check_equal(DataOut(0), not IdleLevel_c, "Pulse removed during after bounce phase");
                        wait for Time_Debounce_c*0.75;
                    end if;
                    -- Toggle Signal
                    DataAsync(0) <= not DataAsync(0);
                end loop;

                wait for MaxDetTime_c;
                check_equal(DataOut(0), IdleLevel_c, "Idle Value wrong after pulse");
            end if;

            -- Bounce other signal constantly
            if run("BounceOtherSig") then
                -- bounce other signal
                BounceOhter <= true;
                -- Check initial state
                check_equal(DataOut(0), IdleLevel_c, "Wrong initial value");
                -- Toggle value
                DataAsync(0) <= not IdleLevel_c;
                -- Wait until value is detected
                if IsLowLat_c then
                    wait for MaxPropDelay_c;
                else
                    wait for MaxDetTime_c;
                end if;
                check_equal(DataOut(0), not IdleLevel_c, "Pulse Value wrong");
                -- wait for minimum time
                wait for MaxDetTime_c;
                -- End of pulse
                DataAsync(0) <= IdleLevel_c;
                -- Wait until new value is detected
                if IsLowLat_c then
                    wait for MaxPropDelay_c;
                else
                    wait for MaxDetTime_c;
                end if;
                check_equal(DataOut(0), IdleLevel_c, "Idle Value wrong after pulse");
                -- end bouncing other signal
                BounceOhter <= false;
            end if;

            -- Delay between tests
            wait for 1 us;
            wait until rising_edge(Clk);

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -- Continuously bounce DataAsync(1) when requested by main process
    p_other : process is
    begin
        wait until rising_edge(Clk);
        if BounceOhter then

            loop
                wait for Time_Debounce_c*0.1;
                DataAsync(1) <= not  DataAsync(1);
                if not BounceOhter then
                    exit;
                end if;
            end loop;

            DataAsync(1) <= IdleLevel_c;
        end if;
    end process;

end architecture;
