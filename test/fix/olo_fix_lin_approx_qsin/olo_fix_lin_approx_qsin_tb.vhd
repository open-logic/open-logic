---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler, Switzerland
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
    use olo.olo_base_pkg_math.all;

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_lin_approx_qsin_tb is
    generic (
        OutFmt_g   : string  := "(1,0,16)";
        InFmt_g    : string  := "(0,-2,20)";
        UsePortB_g : boolean := true;
        MemStyle_g : string  := "auto";
        Round_g    : string  := "NonSymPos_s";
        Saturate_g : string  := "Sat_s";
        runner_cfg : string
    );
end entity;

architecture sim of olo_fix_lin_approx_qsin_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Latency: the entity contains the table and olo_fix_lin_approx_calc (8, both resize registers
    -- are always implemented) only, hence it has the same latency as the calculation.
    constant ExpectedLatency_c : natural := 8;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                                   := '0';
    signal Rst       : std_logic                                                   := '0';
    signal In_Valid  : std_logic                                                   := '0';
    signal In_A      : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal In_B      : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic;
    signal Out_A     : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
    signal Out_B     : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Components ***
    constant StimuliA_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliB_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerA_c : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerB_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant PhaseAFile_c : string := output_path(runner_cfg) & "PhaseA.fix";
    constant PhaseBFile_c : string := output_path(runner_cfg) & "PhaseB.fix";
    constant OutAFile_c   : string := output_path(runner_cfg) & "OutA.fix";
    constant OutBFile_c   : string := output_path(runner_cfg) & "OutB.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** First run at full speed ***
            if run("FullSpeed") then
                fix_stimuli_play_file (net, StimuliA_c, PhaseAFile_c);
                fix_checker_check_file (net, CheckerA_c, OutAFile_c);

                if UsePortB_g then
                    fix_stimuli_play_file (net, StimuliB_c, PhaseBFile_c);
                    fix_checker_check_file (net, CheckerB_c, OutBFile_c);
                end if;
            end if;

            -- *** Second run with stalls ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliA_c, PhaseAFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_checker_check_file (net, CheckerA_c, OutAFile_c);

                if UsePortB_g then
                    fix_stimuli_play_file (net, StimuliB_c, PhaseBFile_c);
                    fix_checker_check_file (net, CheckerB_c, OutBFile_c);
                end if;
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliA_c));
            wait_until_idle(net, as_sync(CheckerA_c));

            if UsePortB_g then
                wait_until_idle(net, as_sync(StimuliB_c));
                wait_until_idle(net, as_sync(CheckerB_c));
            end if;
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Latency Check Process
    -----------------------------------------------------------------------------------------------
    p_latency_check : process is
        variable StartTime_v     : time;
        variable ActualLatency_v : natural;
    begin

        -- Wait for first sample to enter
        wait until rising_edge(Clk) and In_Valid = '1';
        StartTime_v := now;

        -- Wait for first sample to exit
        wait until rising_edge(Clk) and Out_Valid = '1';

        -- Check latency for all test cases
        ActualLatency_v := (now - StartTime_v) / Clk_Period_c;
        check_equal(ActualLatency_v, ExpectedLatency_c, msg => "Latency mismatch!");
        wait;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_lin_approx_qsin
        generic map (
            OutFmt_g   => OutFmt_g,
            InFmt_g    => InFmt_g,
            UsePortB_g => UsePortB_g,
            MemStyle_g => MemStyle_g,
            Round_g    => Round_g,
            Saturate_g => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_A      => In_A,
            In_B      => In_B,
            Out_Valid => Out_Valid,
            Out_A     => Out_A,
            Out_B     => Out_B
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_a : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => StimuliA_c,
            Fmt      => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_A
        );

    vc_checker_a : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerA_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_A
        );

    g_port_b : if UsePortB_g generate

        -- Port B is fed in lock-step with port A, hence the timing is controlled by port A
        vc_stimuli_b : entity work.olo_test_fix_stimuli_vc
            generic map (
                Instance         => StimuliB_c,
                Is_Timing_Master => false,
                Fmt              => cl_fix_format_from_string(InFmt_g)
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                Valid    => In_Valid,
                Data     => In_B
            );

        vc_checker_b : entity work.olo_test_fix_checker_vc
            generic map (
                Instance => CheckerB_c,
                Fmt      => cl_fix_format_from_string(OutFmt_g)
            )
            port map (
                Clk      => Clk,
                Valid    => Out_Valid,
                Data     => Out_B
            );

    end generate;

end architecture;
