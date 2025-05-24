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
entity olo_fix_sim_checker_tb is
    generic (
        Fmt_g      : string := "(1,15,0)";
        runner_cfg : string
    );
end entity;

architecture sim of olo_fix_sim_checker_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic := '0';
    signal Rst       : std_logic;
    signal Valid     : std_logic;
    signal Ready     : std_logic;
    signal Data      : std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
    signal DataSlave : std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant Stimuli_c      : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliSlave_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;

    -- *** Constants ***
    constant FileIn_c  : string := output_path(runner_cfg) & "Data.fix";
    constant FileOut_c : string := output_path(runner_cfg) & "Data.fix";

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

            -- *** Test ***
            if run("Test") then
                fix_stimuli_play_file (net, Stimuli_c, FileIn_c, Stall_Probability => 0.5, Stall_Max_Cycles => 4);
                fix_stimuli_play_file (net, StimuliSlave_c, FileIn_c, Stall_Probability => 0.5, Stall_Max_Cycles => 4);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(Stimuli_c));
            wait_until_idle(net, as_sync(StimuliSlave_c));
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

    i_dut_timing_master : entity olo.olo_fix_sim_checker
        generic map (
            FilePath_g         => FileOut_c,
            Fmt_g              => Fmt_g,
            StallProbability_g => 0.5,
            StallMaxCycles_g   => 4
        )
        port map (
            Clk      => Clk,
            Ready    => Ready,
            Valid    => Valid,
            Data     => Data
        );

    i_dut_timing_slave : entity olo.olo_fix_sim_checker
        generic map (
            FilePath_g         => FileOut_c,
            IsTimingMaster_g   => false,
            Fmt_g              => Fmt_g,
            StallProbability_g => 0.5,
            StallMaxCycles_g   => 4
        )
        port map (
            Clk      => Clk,
            Ready    => Ready,
            Valid    => Valid,
            Data     => DataSlave
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
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

    vc_stimuli_slave : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliSlave_c,
            Is_Timing_Master => false,
            Fmt              => cl_fix_format_from_string(Fmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => Ready,
            Valid    => Valid,
            Data     => DataSlave
        );

end architecture;
