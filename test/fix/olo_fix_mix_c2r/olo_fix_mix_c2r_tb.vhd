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
entity olo_fix_mix_c2r_tb is
    generic (
        InFmt_g      : string  := "(1,0,8)";
        MixFmt_g     : string  := "(1,0,8)";
        OutFmt_g     : string  := "(1,0,16)";
        Round_g      : string  := "NonSymPos_s";
        Saturate_g   : string  := "Sat_s";
        MultRegs_g   : natural := 1;
        IqHandling_g : string  := "Parallel";
        runner_cfg   : string
    );
end entity;

architecture sim of olo_fix_mix_c2r_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic := '0';
    signal Rst         : std_logic := '0';
    signal In_Valid    : std_logic;
    signal In_Last     : std_logic;
    signal In_SigI     : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_SigQ     : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_MixI     : std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
    signal In_MixQ     : std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
    signal In_SigIQ    : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_MixIQ    : std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
    signal Out_Valid   : std_logic;
    signal Out_SigReal : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);

    -- TB signals
    signal In_Valid_Par : std_logic;
    signal In_Valid_Tdm : std_logic;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant StimuliSigI_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliSigQ_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliSigIQ_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliMixI_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliMixQ_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliMixIQ_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliLast_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerReal_c  : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- File paths
    constant SigIFile_c          : string := output_path(runner_cfg) & "SigI.fix";
    constant SigQFile_c          : string := output_path(runner_cfg) & "SigQ.fix";
    constant SigIqFile_c         : string := output_path(runner_cfg) & "SigIQ.fix";
    constant MixIFile_c          : string := output_path(runner_cfg) & "MixI.fix";
    constant MixQFile_c          : string := output_path(runner_cfg) & "MixQ.fix";
    constant MixIqFile_c         : string := output_path(runner_cfg) & "MixIQ.fix";
    constant ResultRealFile_c    : string := output_path(runner_cfg) & "Result_Real.fix";
    constant LastParFile_c       : string := output_path(runner_cfg) & "LastPar.fix";
    constant LastTdmFile_c       : string := output_path(runner_cfg) & "LastTdm.fix";
    constant ResyncSigIqFile_c   : string := output_path(runner_cfg) & "Resync_SigIQ.fix";
    constant ResyncMixIqFile_c   : string := output_path(runner_cfg) & "Resync_MixIQ.fix";
    constant ResyncResultFile_c  : string := output_path(runner_cfg) & "Resync_ResultReal.fix";
    constant ResyncLastInFile_c  : string := output_path(runner_cfg) & "Resync_LastIn.fix";
    constant ResyncLastOutFile_c : string := output_path(runner_cfg) & "Resync_LastOut.fix";

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
                if IqHandling_g = "Parallel" then
                    fix_stimuli_play_file(net, StimuliSigI_c, SigIFile_c);
                    fix_stimuli_play_file(net, StimuliSigQ_c, SigQFile_c);
                    fix_stimuli_play_file(net, StimuliMixI_c, MixIFile_c);
                    fix_stimuli_play_file(net, StimuliMixQ_c, MixQFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, LastParFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResultRealFile_c);
                else
                    fix_stimuli_play_file(net, StimuliSigIQ_c, SigIqFile_c);
                    fix_stimuli_play_file(net, StimuliMixIQ_c, MixIqFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, LastTdmFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResultRealFile_c);
                end if;
            end if;

            -- Throttled test
            if run("Throttled") then
                if IqHandling_g = "Parallel" then
                    fix_stimuli_play_file(net, StimuliSigI_c, SigIFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                    fix_stimuli_play_file(net, StimuliSigQ_c, SigQFile_c);
                    fix_stimuli_play_file(net, StimuliMixI_c, MixIFile_c);
                    fix_stimuli_play_file(net, StimuliMixQ_c, MixQFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, LastParFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResultRealFile_c);
                else
                    fix_stimuli_play_file(net, StimuliSigIQ_c, SigIqFile_c, stall_probability => 1.0, stall_max_cycles => 10, stall_min_cycles => 1);
                    fix_stimuli_play_file(net, StimuliMixIQ_c, MixIqFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, LastTdmFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResultRealFile_c);
                end if;
            end if;

            -- TDM resync test (full speed)
            if run("IqResync-FullSpeed") then
                if IqHandling_g = "TDM" then
                    fix_stimuli_play_file(net, StimuliSigIQ_c, ResyncSigIqFile_c);
                    fix_stimuli_play_file(net, StimuliMixIQ_c, ResyncMixIqFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, ResyncLastInFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResyncResultFile_c);
                end if;
            end if;

            -- TDM resync test (throttled)
            if run("IqResync-Throttled") then
                if IqHandling_g = "TDM" then
                    fix_stimuli_play_file(net, StimuliSigIQ_c, ResyncSigIqFile_c, stall_probability => 1.0, stall_max_cycles => 10, stall_min_cycles => 1);
                    fix_stimuli_play_file(net, StimuliMixIQ_c, ResyncMixIqFile_c);
                    fix_stimuli_play_file(net, StimuliLast_c, ResyncLastInFile_c);
                    fix_checker_check_file(net, CheckerReal_c, ResyncResultFile_c);
                end if;
            end if;

            -- Wait until done
            wait_until_idle(net, as_sync(StimuliSigI_c));
            wait_until_idle(net, as_sync(StimuliSigQ_c));
            wait_until_idle(net, as_sync(StimuliSigIQ_c));
            wait_until_idle(net, as_sync(StimuliMixI_c));
            wait_until_idle(net, as_sync(StimuliMixQ_c));
            wait_until_idle(net, as_sync(StimuliMixIQ_c));
            wait_until_idle(net, as_sync(StimuliLast_c));
            wait_until_idle(net, as_sync(CheckerReal_c));
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
    g_par : if IqHandling_g = "Parallel" generate
        In_Valid <= In_Valid_Par;
    end generate;

    g_tdm : if IqHandling_g = "TDM" generate
        In_Valid <= In_Valid_Tdm;
    end generate;

    i_dut : entity olo.olo_fix_mix_c2r
        generic map (
            InFmt_g      => InFmt_g,
            MixFmt_g     => MixFmt_g,
            OutFmt_g     => OutFmt_g,
            Round_g      => Round_g,
            Saturate_g   => Saturate_g,
            MultRegs_g   => MultRegs_g,
            IqHandling_g => IqHandling_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_Last     => In_Last,
            In_SigI     => In_SigI,
            In_SigQ     => In_SigQ,
            In_MixI     => In_MixI,
            In_MixQ     => In_MixQ,
            In_SigIQ    => In_SigIQ,
            In_MixIQ    => In_MixIQ,
            Out_Valid   => Out_Valid,
            Out_SigReal => Out_SigReal
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_sig_i : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => StimuliSigI_c,
            Fmt      => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid_Par,
            Data  => In_SigI
        );

    vc_stimuli_sig_q : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliSigQ_c,
            Fmt              => cl_fix_format_from_string(InFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid_Par,
            Ready => In_Valid_Par,
            Data  => In_SigQ
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
            Valid => In_Valid_Par,
            Ready => In_Valid_Par,
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
            Valid => In_Valid_Par,
            Ready => In_Valid_Par,
            Data  => In_MixQ
        );

    vc_stimuli_sig_iq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => StimuliSigIQ_c,
            Fmt      => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid_Tdm,
            Data  => In_SigIQ
        );

    vc_stimuli_mix_iq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliMixIQ_c,
            Fmt              => cl_fix_format_from_string(MixFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid_Tdm,
            Ready => In_Valid_Tdm,
            Data  => In_MixIQ
        );

    vc_stimuli_last : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliLast_c,
            Fmt              => (0, 1, 0),
            Is_Timing_Master => false
        )
        port map (
            Clk     => Clk,
            Rst     => Rst,
            Valid   => In_Valid,
            Ready   => In_Valid,
            Data(0) => In_Last
        );

    vc_checker_real : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerReal_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk   => Clk,
            Valid => Out_Valid,
            Data  => Out_SigReal
        );

end architecture;
