---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler, Switzerland
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
entity olo_fix_mix_r2c_tb is
    generic (
        InFmt_g    : string  := "(1,0,8)";
        MixFmt_g   : string  := "(1,0,8)";
        OutFmt_g   : string  := "(1,0,16)";
        Round_g    : string  := "NonSymPos_s";
        Saturate_g : string  := "Sat_s";
        MultRegs_g : natural := 1;
        runner_cfg : string
    );
end entity;

architecture sim of olo_fix_mix_r2c_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic := '0';
    signal Rst        : std_logic := '0';
    signal In_Valid   : std_logic;
    signal In_SigReal : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_MixI    : std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
    signal In_MixQ    : std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
    signal Out_Valid  : std_logic;
    signal Out_I      : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
    signal Out_Q      : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant StimuliSig_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliMixI_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliMixQ_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerI_c    : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerQ_c    : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- File paths
    constant SigRealFile_c : string := output_path(runner_cfg) & "SigReal.fix";
    constant MixIFile_c    : string := output_path(runner_cfg) & "MixI.fix";
    constant MixQFile_c    : string := output_path(runner_cfg) & "MixQ.fix";
    constant ResultIFile_c : string := output_path(runner_cfg) & "Result_I.fix";
    constant ResultQFile_c : string := output_path(runner_cfg) & "Result_Q.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

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

            -- Full speed test
            if run("FullSpeed") then
                fix_stimuli_play_file(net, StimuliSig_c,  SigRealFile_c);
                fix_stimuli_play_file(net, StimuliMixI_c, MixIFile_c);
                fix_stimuli_play_file(net, StimuliMixQ_c, MixQFile_c);
                fix_checker_check_file(net, CheckerI_c, ResultIFile_c);
                fix_checker_check_file(net, CheckerQ_c, ResultQFile_c);
            end if;

            -- Throttled test (stall on signal input)
            if run("Throttled") then
                fix_stimuli_play_file(net, StimuliSig_c,  SigRealFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_stimuli_play_file(net, StimuliMixI_c, MixIFile_c);
                fix_stimuli_play_file(net, StimuliMixQ_c, MixQFile_c);
                fix_checker_check_file(net, CheckerI_c, ResultIFile_c);
                fix_checker_check_file(net, CheckerQ_c, ResultQFile_c);
            end if;

            -- Wait until done
            wait_until_idle(net, as_sync(StimuliSig_c));
            wait_until_idle(net, as_sync(StimuliMixI_c));
            wait_until_idle(net, as_sync(StimuliMixQ_c));
            wait_until_idle(net, as_sync(CheckerI_c));
            wait_until_idle(net, as_sync(CheckerQ_c));
            wait for 1 us;

        end loop;

        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_mix_r2c
        generic map (
            InFmt_g    => InFmt_g,
            MixFmt_g   => MixFmt_g,
            OutFmt_g   => OutFmt_g,
            Round_g    => Round_g,
            Saturate_g => Saturate_g,
            MultRegs_g => MultRegs_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid,
            In_SigReal => In_SigReal,
            In_MixI    => In_MixI,
            In_MixQ    => In_MixQ,
            Out_Valid  => Out_Valid,
            Out_I      => Out_I,
            Out_Q      => Out_Q
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_sig : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => StimuliSig_c,
            Fmt      => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid,
            Data  => In_SigReal
        );

    vc_stimuli_mix_i : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliMixI_c,
            Fmt              => cl_fix_format_from_string(MixFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid,
            Ready => In_Valid,
            Data  => In_MixI
        );

    vc_stimuli_mix_q : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliMixQ_c,
            Fmt              => cl_fix_format_from_string(MixFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid,
            Ready => In_Valid,
            Data  => In_MixQ
        );

    vc_checker_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerI_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk   => Clk,
            Valid => Out_Valid,
            Data  => Out_I
        );

    vc_checker_q : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerQ_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk   => Clk,
            Valid => Out_Valid,
            Data  => Out_Q
        );

end architecture;
