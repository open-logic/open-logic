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
entity olo_fix_bin_div_tb is
    generic (
        NumFmt_g          : string := "(0,0,16)";
        DenomFmt_g        : string := "(0,0,16)";
        OutFmt_g          : string := "(1,0,15)";
        Mode_g            : string := "PIPELINED";
        Round_g           : string := "Trunc_s";
        Saturate_g        : string := "Sat_s";
        runner_cfg        : string
    );
end entity;

architecture sim of olo_fix_bin_div_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real        := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time        := (1 sec) / Clk_Frequency_c;
    constant OutFmt_c        : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Latency
    constant ExpectedLatency_Serial_c    : natural := OutFmt_c.I + OutFmt_c.F + 6;
    constant ExpectedLatency_Pipelined_c : natural := OutFmt_c.I + OutFmt_c.F + 6;
    constant ExpectedLatency_c           : natural := choose(Mode_g = "SERIAL",
                                                              ExpectedLatency_Serial_c,
                                                              ExpectedLatency_Pipelined_c);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                                      := '0';
    signal Rst       : std_logic                                                      := '0';
    signal In_Valid  : std_logic                                                      := '0';
    signal In_Ready  : std_logic;
    signal In_Num    : std_logic_vector(fixFmtWidthFromString(NumFmt_g)-1 downto 0)   := (others => '0');
    signal In_Denom  : std_logic_vector(fixFmtWidthFromString(DenomFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic;
    signal Out_Quot  : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant StimuliNum_c   : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliDenom_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerQuot_c  : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant InNumFile_c   : string := output_path(runner_cfg) & "Numerator.fix";
    constant InDenomFile_c : string := output_path(runner_cfg) & "Denominator.fix";
    constant OutQuotFile_c : string := output_path(runner_cfg) & "Out.fix";

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
                fix_stimuli_play_file (net, StimuliNum_c, InNumFile_c);
                fix_stimuli_play_file (net, StimuliDenom_c, InDenomFile_c);
                fix_checker_check_file (net, CheckerQuot_c, OutQuotFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliNum_c, InNumFile_c, stall_probability => 0.5, stall_max_cycles => 50);
                fix_stimuli_play_file (net, StimuliDenom_c, InDenomFile_c);
                fix_checker_check_file (net, CheckerQuot_c, OutQuotFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliNum_c));
            wait_until_idle(net, as_sync(StimuliDenom_c));
            wait_until_idle(net, as_sync(CheckerQuot_c));
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

        -- Wait for first output sample
        wait until rising_edge(Clk) and Out_Valid = '1';
        ActualLatency_v := (now - StartTime_v) / Clk_Period_c;
        check_equal(ActualLatency_v, ExpectedLatency_c, msg => "Latency mismatch!");

        -- Wait until end of simulation
        wait;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_bin_div
        generic map (
            NumFmt_g          => NumFmt_g,
            DenomFmt_g        => DenomFmt_g,
            OutFmt_g          => OutFmt_g,
            Mode_g            => Mode_g,
            Round_g           => Round_g,
            Saturate_g        => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready,
            In_Num    => In_Num,
            In_Denom  => In_Denom,
            Out_Valid => Out_Valid,
            Out_Quot  => Out_Quot
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_num : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliNum_c,
            Fmt              => cl_fix_format_from_string(NumFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Ready,
            Data     => In_Num
        );

    vc_stimuli_den : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliDenom_c,
            Fmt              => cl_fix_format_from_string(DenomFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Ready,
            Valid    => In_Valid,
            Data     => In_Denom
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerQuot_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Quot
        );

end architecture;
