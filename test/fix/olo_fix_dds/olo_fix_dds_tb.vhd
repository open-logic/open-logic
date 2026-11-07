---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
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
entity olo_fix_dds_tb is
    generic (
        Channels_g      : positive := 1;
        PhaseFmt_g      : string   := "(0,0,24)";
        OutFmt_g        : string   := "(1,0,16)";
        Round_g         : string   := "NonSymPos_s";
        DelayResource_g : string   := "AUTO";
        runner_cfg      : string
    );
end entity;

architecture sim of olo_fix_dds_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Latency: Phase accumulation and phase rounding stage plus olo_fix_sin
    constant ExpectedLatency_c : natural := olo.olo_fix_lin_approx_pkg.linApproxLatency(2) + 5;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                                      := '0';
    signal Rst            : std_logic                                                      := '0';
    signal In_Valid       : std_logic                                                      := '0';
    signal In_PhaseStep   : std_logic_vector(fixFmtWidthFromString(PhaseFmt_g)-1 downto 0) := (others => '0');
    signal In_PhaseOffset : std_logic_vector(fixFmtWidthFromString(PhaseFmt_g)-1 downto 0) := (others => '0');
    signal In_Restart     : std_logic                                                      := '0';
    signal Out_Valid      : std_logic;
    signal Out_Sin        : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
    signal Out_Cos        : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
    signal Out_Last       : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Components ***
    constant StimuliStep_c    : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliOffset_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliRestart_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerSin_c     : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerCos_c     : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerLast_c    : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant StepFile_c    : string := output_path(runner_cfg) & "Step.fix";
    constant OffsetFile_c  : string := output_path(runner_cfg) & "Offset.fix";
    constant RestartFile_c : string := output_path(runner_cfg) & "Restart.fix";
    constant SinFile_c     : string := output_path(runner_cfg) & "Sin.fix";
    constant CosFile_c     : string := output_path(runner_cfg) & "Cos.fix";
    constant LastFile_c    : string := output_path(runner_cfg) & "Last.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        -- Latency must match the value stated in the documentation
        check_equal(ExpectedLatency_c, 14, msg => "ExpectedLatency_c does not match documentation");

        while test_suite loop

            -- Reset
            -- Every test case starts with a reset. Because all test cases run in the same simulation,
            -- this also verifies that the accumulators of all channels are cleared by the reset.
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** First run at full speed ***
            if run("FullSpeed") then
                fix_stimuli_play_file (net, StimuliStep_c, StepFile_c);
                fix_stimuli_play_file (net, StimuliOffset_c, OffsetFile_c);
                fix_stimuli_play_file (net, StimuliRestart_c, RestartFile_c);
                fix_checker_check_file (net, CheckerSin_c, SinFile_c);
                fix_checker_check_file (net, CheckerCos_c, CosFile_c);
                fix_checker_check_file (net, CheckerLast_c, LastFile_c);
            end if;

            -- *** Second run with stalls ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliStep_c, StepFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_stimuli_play_file (net, StimuliOffset_c, OffsetFile_c);
                fix_stimuli_play_file (net, StimuliRestart_c, RestartFile_c);
                fix_checker_check_file (net, CheckerSin_c, SinFile_c);
                fix_checker_check_file (net, CheckerCos_c, CosFile_c);
                fix_checker_check_file (net, CheckerLast_c, LastFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliStep_c));
            wait_until_idle(net, as_sync(StimuliOffset_c));
            wait_until_idle(net, as_sync(StimuliRestart_c));
            wait_until_idle(net, as_sync(CheckerSin_c));
            wait_until_idle(net, as_sync(CheckerCos_c));
            wait_until_idle(net, as_sync(CheckerLast_c));
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
    i_dut : entity olo.olo_fix_dds
        generic map (
            Channels_g      => Channels_g,
            PhaseFmt_g      => PhaseFmt_g,
            OutFmt_g        => OutFmt_g,
            Round_g         => Round_g,
            DelayResource_g => DelayResource_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => In_Valid,
            In_PhaseStep   => In_PhaseStep,
            In_PhaseOffset => In_PhaseOffset,
            In_Restart     => In_Restart,
            Out_Valid      => Out_Valid,
            Out_Sin        => Out_Sin,
            Out_Cos        => Out_Cos,
            Out_Last       => Out_Last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_step : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => StimuliStep_c,
            Fmt      => cl_fix_format_from_string(PhaseFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_PhaseStep
        );

    vc_stimuli_offset : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliOffset_c,
            Fmt              => cl_fix_format_from_string(PhaseFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Valid,
            Data     => In_PhaseOffset
        );

    vc_stimuli_restart : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliRestart_c,
            Fmt              => (0, 1, 0),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Valid,
            Data(0)  => In_Restart
        );

    vc_checker_sin : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerSin_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Sin
        );

    vc_checker_cos : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerCos_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Cos
        );

    vc_checker_last : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerLast_c,
            Fmt      => (0, 1, 0)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data(0)  => Out_Last
        );

end architecture;
