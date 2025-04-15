---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Switzerland
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
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_vc_tb is
    generic (
        Fmt_g                   : string                 := "(1,15,0)";
        FileIn_g                  : string               := "Input.fix";
        FileOut_g                 : string               := "Output.fix";
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_fix_vc_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk           : std_logic                                   := '0';
    signal Rst           : std_logic;
    signal Valid         : std_logic;
    signal Ready         : std_logic;
    signal Data          : std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant Stimuli_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

        while test_suite loop

            -- Add Slave mode
            -- Add stall in
            -- add stall out
            -- add stall both



            -- *** Basics ***
            if run("First-Run") then
                --fix_stimuli_play_file (net, Stimuli_c, FileIn_g);
                --fix_checker_check_file (net, Checker_c, FileOut_g);
            end if;

            -- *** Simple Transaction ***
            if run("Second-Run") then
                --fix_stimuli_play_file (net, Stimuli_c, FileIn_g);
                --fix_checker_check_file (net, Checker_c, FileOut_g);    
            end if;
         

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(Stimuli_c));
            wait_until_idle(net, as_sync(Checker_c));
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => Stimuli_c,
            Is_Timing_Master => true,   
            Fmt              => cl_fix_format_from_string(Fmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => Ready,
            Valid    => Valid,
            Data     => Data
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => Checker_c,
            Is_Timing_Master => true,   
            Fmt              => cl_fix_format_from_string(Fmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => Ready,
            Valid    => Valid,
            Data     => Data
        );
   

end architecture;
