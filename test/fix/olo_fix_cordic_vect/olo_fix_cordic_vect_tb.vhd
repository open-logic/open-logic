---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler, Switzerland
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
entity olo_fix_cordic_vect_tb is
    generic (
        InFmt_g           : string   := "(1,0,16)";
        OutAngFmt_g       : string   := "(0,0,16)";
        OutMagFmt_g       : string   := "(0,0,15)";
        IntXyFmt_g        : string   := "AUTO";
        IntAngFmt_g       : string   := "AUTO";
        Iterations_g      : positive := 16;
        Mode_g            : string   := "PIPELINED";
        GainCorrCoefFmt_g : string   := "(0,0,17)";
        Round_g           : string   := "Trunc_s";
        Saturate_g        : string   := "Sat_s";
        runner_cfg        : string
    );
end entity;

architecture sim of olo_fix_cordic_vect_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Latency calculation
    constant GainLatency_c     : natural := choose(GainCorrCoefFmt_g = "NONE", 0, 1);
    constant BaseLatency_c     : natural := choose(Mode_g = "PIPELINED", 5, 4);
    constant ExpectedLatency_c : natural := BaseLatency_c + GainLatency_c + Iterations_g;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                                   := '0';
    signal Rst       : std_logic                                                   := '0';
    signal In_Valid  : std_logic                                                   := '0';
    signal In_Ready  : std_logic;
    signal In_I      : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal In_Q      : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic;
    signal Out_Ang   : std_logic_vector(fixFmtWidthFromString(OutAngFmt_g)-1 downto 0);
    signal Out_Mag   : std_logic_vector(fixFmtWidthFromString(OutMagFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant StimuliI_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliQ_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerMag_c : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerAng_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant InIFile_c    : string := output_path(runner_cfg) & "InI.fix";
    constant InQFile_c    : string := output_path(runner_cfg) & "InQ.fix";
    constant OutAngFile_c : string := output_path(runner_cfg) & "OutAng.fix";
    constant OutMagFile_c : string := output_path(runner_cfg) & "OutMag.fix";

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

            -- *** First Run ***
            if run("FullSpeed") then
                fix_stimuli_play_file (net, StimuliI_c, InIFile_c);
                fix_stimuli_play_file (net, StimuliQ_c, InQFile_c);
                fix_checker_check_file (net, CheckerAng_c, OutAngFile_c);
                fix_checker_check_file (net, CheckerMag_c, OutMagFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliI_c, InIFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_stimuli_play_file (net, StimuliQ_c, InQFile_c);
                fix_checker_check_file (net, CheckerAng_c, OutAngFile_c);
                fix_checker_check_file (net, CheckerMag_c, OutMagFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliI_c));
            wait_until_idle(net, as_sync(StimuliQ_c));
            wait_until_idle(net, as_sync(CheckerMag_c));
            wait_until_idle(net, as_sync(CheckerAng_c));
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
        wait until rising_edge(Clk) and In_Valid = '1' and In_Ready = '1';
        StartTime_v := now;

        -- Wait for first sample to exit
        wait until rising_edge(Clk) and Out_Valid = '1';

        -- Check latency
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
    i_dut : entity olo.olo_fix_cordic_vect
        generic map (
            InFmt_g           => InFmt_g,
            OutMagFmt_g       => OutMagFmt_g,
            OutAngFmt_g       => OutAngFmt_g,
            IntXyFmt_g        => IntXyFmt_g,
            IntAngFmt_g       => IntAngFmt_g,
            Iterations_g      => Iterations_g,
            Mode_g            => Mode_g,
            GainCorrCoefFmt_g => GainCorrCoefFmt_g,
            Round_g           => Round_g,
            Saturate_g        => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready,
            In_I      => In_I,
            In_Q      => In_Q,
            Out_Valid => Out_Valid,
            Out_Mag   => Out_Mag,
            Out_Ang   => Out_Ang
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_i_i : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliI_c,
            Fmt              => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Ready,
            Data     => In_I
        );

    vc_stimuli_q_i : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliQ_c,
            Fmt              => cl_fix_format_from_string(InFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Ready,
            Valid    => In_Valid,
            Data     => In_Q
        );

    vc_checker_mag_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerMag_c,
            Fmt      => cl_fix_format_from_string(OutMagFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Mag
        );

    vc_checker_ang_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerAng_c,
            Fmt      => cl_fix_format_from_string(OutAngFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Ang
        );

end architecture;
