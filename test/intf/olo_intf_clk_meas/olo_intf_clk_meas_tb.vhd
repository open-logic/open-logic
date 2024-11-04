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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_clk_meas_tb is
    generic (
        runner_cfg              : string;
        ClkFrequency_g          : integer := 1000;
        MaxClkTestFrequency_g   : integer := 100
    );
end entity;

architecture sim of olo_intf_clk_meas_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkFrequencyReal_c        : real := real(ClkFrequency_g);
    constant ClockPeriod_c             : time := (1 sec) / ClkFrequencyReal_c;
    constant MaxClkTestFrequencyReal_c : real := real(MaxClkTestFrequency_g);
    constant LowerFreqReal_c           : real := choose(ClkFrequencyReal_c < MaxClkTestFrequencyReal_c, ClkFrequencyReal_c, MaxClkTestFrequencyReal_c);
    constant UpperFreqReal_c           : real := choose(ClkFrequencyReal_c < MaxClkTestFrequencyReal_c, MaxClkTestFrequencyReal_c, ClkFrequencyReal_c);

    signal TestFrequencyReal : real := 1.0e3;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic := '0';
    signal Rst        : std_logic := '1';
    signal ClkTest    : std_logic := '0';
    signal Freq_Hz    : std_logic_vector(31 downto 0);
    signal Freq_Valid : std_logic;

    -----------------------------------------------------------------------------------------------
    -- Procedures
    -----------------------------------------------------------------------------------------------
    procedure checkFrequency (
        Frquency                 : real;
        signal TestFrequencyReal : out real) is
        variable IntFreq_v        : integer;
        variable IntMaxTestFreq_v : integer;
    begin
        TestFrequencyReal <= Frquency;
        wait until rising_edge(Clk) and Freq_Valid = '1'; -- First result might be affected by frequency change
        wait until rising_edge(Clk) and Freq_Valid = '1';

        IntFreq_v := fromUslv(Freq_Hz);
        if Frquency <= MaxClkTestFrequencyReal_c then
            check(abs(IntFreq_v-integer(Frquency)) <= 1, "Freq_Hz not correct, got " & integer'image(IntFreq_v)); -- +/-1 allowed due to clock shift
        else
            -- Variable required, doing conversion inside check_equal call fails in modelsim due to a bug
            IntMaxTestFreq_v := integer(MaxClkTestFrequencyReal_c);
            check_equal(Freq_Hz, IntMaxTestFreq_v, "Freq_Hz not correct (above max)");
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_clk_meas
        generic map (
            ClkFrequency_g          => ClkFrequencyReal_c,
            MaxClkTestFrequency_g   => MaxClkTestFrequencyReal_c
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            ClkTest     => ClkTest,
            Freq_Hz     => Freq_Hz,
            Freq_Valid  => Freq_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk     <= not Clk after 0.5 * ClockPeriod_c;
    ClkTest <= not ClkTest after 0.5 * (1 sec) / TestFrequencyReal;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 30 sec);

    p_control : process is
        variable TestFreq_v : real;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- *** Reset ***
            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);
            check_equal(Freq_Valid, '0', "Freq_Valid not low after reset");

            -- Omit first measurement after reset (might be affected by reset)
            wait until rising_edge(Clk) and Freq_Valid = '1';

            if run("Lower") then
                -- After reset the first measured frequency is correct
                TestFreq_v := LowerFreqReal_c;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("Between0AndLower") then
                TestFreq_v := (LowerFreqReal_c + 0.0) / 2.0;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("BetweenLowerAndupper") then
                TestFreq_v := (LowerFreqReal_c + UpperFreqReal_c) / 2.0;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("Upper") then
                TestFreq_v := UpperFreqReal_c;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("MaxTestFrequency") then
                TestFreq_v := MaxClkTestFrequencyReal_c;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("AboveMaxTestFrequency") then
                TestFreq_v := MaxClkTestFrequencyReal_c*1.5;
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("Zero") then
                -- Clock stopped
                TestFrequencyReal <= 0.2;
                wait until rising_edge(Clk) and Freq_Valid = '1';
                wait until rising_edge(Clk) and Freq_Valid = '1';
                check_equal(Freq_Hz, integer(0), "Zero Herz not detected");
                -- Test correct measurement after
                TestFreq_v        := (LowerFreqReal_c + UpperFreqReal_c) / 2.0;
                TestFrequencyReal <= 1.0e3;
                wait until rising_edge(ClkTest); -- Wait until the new clock frequency is applied
                wait until rising_edge(Clk) and Freq_Valid = '1'; -- First one might be incorrect because clock can start in the middle of a measurement second
                checkFrequency(TestFreq_v, TestFrequencyReal);
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
