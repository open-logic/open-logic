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
entity olo_fix_cplx_mult_tb is
    generic (
        Mode_g           : string  := "MULT";
        Implementation_g : string  := "MULT4";
        IqHandling_g     : string  := "Parallel";
        AFmt_g           : string  := "(1,0,8)";
        BFmt_g           : string  := "(1,0,8)";
        ResultFmt_g      : string  := "(1,0,16)";
        Round_g          : string  := "NonSymPos_s";
        Saturate_g       : string  := "Sat_s";
        MultRegs_g       : natural := 1;
        RoundReg_g       : string  := "YES";
        SatReg_g         : string  := "YES";
        runner_cfg       : string
    );
end entity;

architecture sim of olo_fix_cplx_mult_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic := '0';
    signal Rst       : std_logic := '0';
    signal In_Valid  : std_logic;
    signal In_Last   : std_logic;
    signal InA_I     : std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
    signal InA_Q     : std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
    signal InA_IQ    : std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
    signal InB_I     : std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
    signal InB_Q     : std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
    signal InB_IQ    : std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
    signal Out_Valid : std_logic;
    signal Out_Last  : std_logic;
    signal Out_I     : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
    signal Out_Q     : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
    signal Out_IQ    : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);

    -- TB signals
    signal In_Valid_Par : std_logic;
    signal In_Valid_Tdm : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant StimuliAI_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliAQ_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliAiq_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliBI_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliBQ_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliBiq_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliLast_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerI_c    : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerQ_c    : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerIQ_c   : olo_test_fix_checker_t := new_olo_test_fix_checker;
    --constant CheckerLast_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant AiFile_c        : string := output_path(runner_cfg) & "AI.fix";
    constant AqFile_c        : string := output_path(runner_cfg) & "AQ.fix";
    constant AiqFile_c       : string := output_path(runner_cfg) & "AIQ.fix";
    constant BiFile_c        : string := output_path(runner_cfg) & "BI.fix";
    constant BqFile_c        : string := output_path(runner_cfg) & "BQ.fix";
    constant BiqFile_c       : string := output_path(runner_cfg) & "BIQ.fix";
    constant CheckerIFile_c  : string := output_path(runner_cfg) & "Result_I.fix";
    constant CheckerQFile_c  : string := output_path(runner_cfg) & "Result_Q.fix";
    constant CheckerIqFile_c : string := output_path(runner_cfg) & "Result_IQ.fix";
    --constant LastParFile_c   : string := output_path(runner_cfg) & "LastPar.fix";
    --constant LastTdmFile_c   : string := output_path(runner_cfg) & "LastTdm.fix";

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
                if IqHandling_g = "Parallel" then
                    fix_stimuli_play_file (net, StimuliAI_c, AiFile_c);
                    fix_stimuli_play_file (net, StimuliAQ_c, AqFile_c);
                    fix_stimuli_play_file (net, StimuliBI_c, BiFile_c);
                    fix_stimuli_play_file (net, StimuliBQ_c, BqFile_c);
                    --fix_stimuli_play_file (net, StimuliLast_c, LastParFile_c);
                    fix_checker_check_file (net, CheckerI_c, CheckerIFile_c);
                    fix_checker_check_file (net, CheckerQ_c, CheckerQFile_c);
                    --fix_checker_check_file (net, CheckerLast_c, LastParFile_c);
                else
                    fix_stimuli_play_file (net, StimuliAiq_c, AiqFile_c);
                    fix_stimuli_play_file (net, StimuliBiq_c, BiqFile_c);
                    --fix_stimuli_play_file (net, StimuliLast_c, LastTdmFile_c);
                    fix_checker_check_file (net, CheckerIQ_c, CheckerIqFile_c);
                    --fix_checker_check_file (net, CheckerLast_c, LastTdmFile_c);
                end if;
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                if IqHandling_g = "Parallel" then
                    fix_stimuli_play_file (net, StimuliAI_c, AiFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                    fix_stimuli_play_file (net, StimuliAQ_c, AqFile_c);
                    fix_stimuli_play_file (net, StimuliBI_c, BiFile_c);
                    fix_stimuli_play_file (net, StimuliBQ_c, BqFile_c);
                    --fix_stimuli_play_file (net, StimuliLast_c, LastParFile_c);
                    fix_checker_check_file (net, CheckerI_c, CheckerIFile_c);
                    fix_checker_check_file (net, CheckerQ_c, CheckerQFile_c);
                    --fix_checker_check_file (net, CheckerLast_c, LastParFile_c);
                else
                    fix_stimuli_play_file (net, StimuliAiq_c, AiqFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                    fix_stimuli_play_file (net, StimuliBiq_c, BiqFile_c);
                    --fix_stimuli_play_file (net, StimuliLast_c, LastTdmFile_c);
                    fix_checker_check_file (net, CheckerIQ_c, CheckerIqFile_c);
                    --fix_checker_check_file (net, CheckerLast_c, LastTdmFile_c);
                end if;
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliAI_c));
            wait_until_idle(net, as_sync(StimuliAQ_c));
            wait_until_idle(net, as_sync(StimuliAiq_c));
            wait_until_idle(net, as_sync(StimuliBI_c));
            wait_until_idle(net, as_sync(StimuliBQ_c));
            wait_until_idle(net, as_sync(StimuliBiq_c));
            wait_until_idle(net, as_sync(CheckerI_c));
            wait_until_idle(net, as_sync(CheckerQ_c));
            wait_until_idle(net, as_sync(CheckerIQ_c));
            --wait_until_idle(net, as_sync(StimuliLast_c));
            --wait_until_idle(net, as_sync(CheckerLast_c));
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
    g_par : if IqHandling_g = "Parallel" generate
        In_Valid <= In_Valid_Par;
    end generate;

    g_tdm : if IqHandling_g = "TDM" generate
        In_Valid <= In_Valid_Tdm;
    end generate;

    i_dut : entity olo.olo_fix_cplx_mult
        generic map (
            Mode_g           => Mode_g,
            Implementation_g => Implementation_g,
            IqHandling_g     => IqHandling_g,
            AFmt_g           => AFmt_g,
            BFmt_g           => BFmt_g,
            ResultFmt_g      => ResultFmt_g,
            Round_g          => Round_g,
            Saturate_g       => Saturate_g,
            MultRegs_g       => MultRegs_g,
            RoundReg_g       => RoundReg_g,
            SatReg_g         => SatReg_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            In_Valid     => In_Valid,
            In_Last      => In_Last,
            InA_I        => InA_I,
            InA_Q        => InA_Q,
            InA_IQ       => InA_IQ,
            InB_I        => InB_I,
            InB_Q        => InB_Q,
            InB_IQ       => InB_IQ,
            Out_Valid    => Out_Valid,
            Out_I        => Out_I,
            Out_Q        => Out_Q,
            Out_IQ       => Out_IQ,
            Out_Last     => Out_Last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_ai : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliAI_c,
            Fmt              => cl_fix_format_from_string(AFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid_Par,
            Data     => InA_I
        );

    vc_stimuli_aq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliAQ_c,
            Fmt              => cl_fix_format_from_string(AFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid_Par,
            Ready    => In_Valid_Par,
            Data     => InA_Q
        );

    vc_stimuli_bi : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliBI_c,
            Fmt              => cl_fix_format_from_string(BFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid_Par,
            Ready    => In_Valid_Par,
            Data     => InB_I
        );

    vc_stimuli_bq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliBQ_c,
            Fmt              => cl_fix_format_from_string(BFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid_Par,
            Ready    => In_Valid_Par,
            Data     => InB_Q
        );

    vc_stimuli_aiq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliAiq_c,
            Fmt              => cl_fix_format_from_string(AFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid_Tdm,
            Data     => InA_IQ
        );

    vc_stimuli_biq : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliBiq_c,
            Fmt              => cl_fix_format_from_string(BFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Valid_Tdm,
            Valid    => In_Valid_Tdm,
            Data     => InB_IQ
        );

    --vc_stimuli_last : entity work.olo_test_fix_stimuli_vc
    --    generic map (
    --        Instance         => StimuliLast_c,
    --        Fmt              => (0,1,0),
    --        Is_Timing_Master => false
    --    )
    --    port map (
    --        Clk      => Clk,
    --        Rst      => Rst,
    --        Valid    => In_Valid,
    --        Ready    => In_Valid,
    --        Data(0)  => In_Last
    --    );

    vc_checker_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => CheckerI_c,
            Fmt              => cl_fix_format_from_string(ResultFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_I
        );

    vc_checker_q : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => CheckerQ_c,
            Fmt              => cl_fix_format_from_string(ResultFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Q
        );

    vc_checker_iq : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => CheckerIQ_c,
            Fmt              => cl_fix_format_from_string(ResultFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_IQ
        );

    --vc_checker_last : entity work.olo_test_fix_checker_vc
    --    generic map (
    --        Instance         => CheckerLast_c,
    --        Fmt              => (0,1,0),
    --        Is_Timing_Master => false
    --    )
    --    port map (
    --        Clk      => Clk,
    --        Valid    => Out_Valid,
    --        Data(0)  => Out_Last
    --    );

end architecture;
