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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_clk_meas_tb is
    generic (
        runner_cfg              : string;
        ClkFrequency_g          : integer := 1000;
        MaxClkTestFrequency_g   : integer := 100 
    );
end entity olo_intf_clk_meas_tb;

architecture sim of olo_intf_clk_meas_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant ClkFrequencyReal_c         : real    := real(ClkFrequency_g);
    constant ClockPeriod_c              : time    := (1 sec) / ClkFrequencyReal_c;
    constant MaxClkTestFrequencyReal_c  : real    := real(MaxClkTestFrequency_g);
    constant LowerFreqReal_c            : real    := choose(ClkFrequencyReal_c < MaxClkTestFrequencyReal_c, ClkFrequencyReal_c, MaxClkTestFrequencyReal_c);
    constant UpperFreqReal_c            : real    := choose(ClkFrequencyReal_c < MaxClkTestFrequencyReal_c, MaxClkTestFrequencyReal_c, ClkFrequencyReal_c);

    signal TestFrequencyReal            : real    := 1.0e3; 

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk          : std_logic                         := '0';
    signal Rst          : std_logic                         := '1';
    signal ClkTest      : std_logic                         := '0'; 
    signal Freq_Hz      : std_logic_vector(31 downto 0);
    signal Freq_Vld     : std_logic;

    -------------------------------------------------------------------------
    -- Procedures
    -------------------------------------------------------------------------
    procedure CheckFrequency(   Frquency                 : real; 
                                signal TestFrequencyReal : out real) is
    begin
        TestFrequencyReal <= Frquency;
        wait until rising_edge(Clk) and Freq_Vld = '1'; -- First result might be affected by frequency change
        wait until rising_edge(Clk) and Freq_Vld = '1';
        if Frquency < MaxClkTestFrequencyReal_c then
            check_equal(Freq_Hz, integer(Frquency), "Freq_Hz not correct");
        else
            check_equal(Freq_Hz, integer(MaxClkTestFrequencyReal_c), "Freq_Hz not correct (above max)");
        end if;
    end procedure;

begin

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_clk_meas
        generic map (
            ClkFrequency_g          => ClkFrequencyReal_c,
            MaxClkTestFrequency_g   => MaxClkTestFrequencyReal_c
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            ClkTest   => ClkTest,
            Freq_Hz   => Freq_Hz,
            Freq_Vld  => Freq_Vld
        );

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk  <= not Clk after 0.5 * ClockPeriod_c;
    ClkTest <= not ClkTest after 0.5 * (1 sec) / TestFrequencyReal;

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    test_runner_watchdog(runner, 20 sec);
    p_control : process
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
        
            if run("ResetState") then
                -- Check Reset State            
                check_equal(Freq_Vld, '0', "Freq_Vld not low after reset");
            end if;

            if run("FirstValid-Lower") then
                -- After reset the first measured frequency is correct
                TestFrequencyReal <= LowerFreqReal_c;
                wait until rising_edge(Clk) and Freq_Vld = '1';
                check_equal(Freq_Hz, integer(LowerFreqReal_c), "Freq_Hz not correct");
            end if;   

            if run("Between0AndLower") then
                TestFreq_v := (LowerFreqReal_c + 0.0) / 2.0;
                CheckFrequency(TestFreq_v, TestFrequencyReal); 
            end if;

            if run("BetweenLowerAndupper") then
                TestFreq_v := (LowerFreqReal_c + UpperFreqReal_c) / 2.0;
                CheckFrequency(TestFreq_v, TestFrequencyReal); 
            end if;

            if run("Upper") then
                TestFreq_v := UpperFreqReal_c;
                CheckFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("MaxTestFrequency") then
                TestFreq_v := MaxClkTestFrequencyReal_c;
                CheckFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("AboveMaxTestFrequency") then
                TestFreq_v := MaxClkTestFrequencyReal_c*1.5;
                CheckFrequency(TestFreq_v, TestFrequencyReal);
            end if;

            if run("Zero") then
                -- Clock stopped
                TestFrequencyReal <= 0.2;
                wait until rising_edge(Clk) and Freq_Vld = '1';
                wait until rising_edge(Clk) and Freq_Vld = '1';
                check_equal(Freq_Hz, integer(0), "Zero Herz not detected");
                -- Test correct measurement after
                TestFreq_v := (LowerFreqReal_c + UpperFreqReal_c) / 2.0;
                TestFrequencyReal <= 1.0e3;
                wait until rising_edge(ClkTest); -- Wait until the new clock frequency is applied
                CheckFrequency(TestFreq_v, TestFrequencyReal); 
            end if;


            
            

        end loop;


        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
