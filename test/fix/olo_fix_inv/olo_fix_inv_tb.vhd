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
entity olo_fix_inv_tb is
    generic (
        OutFmt_g        : string   := "(0,8,12)";
        InFmt_g         : string   := "(0,0,16)";
        PrecisionBits_g : positive := 18;
        MemStyle_g      : string   := "auto";
        Round_g         : string   := "NonSymPos_s";
        Saturate_g      : string   := "Sat_s";
        runner_cfg      : string
    );
end entity;

architecture sim of olo_fix_inv_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Latency: input and absolute value stage (2), both barrel shifters, the approximation (8),
    -- the sign stage (1) and the two registers of the output resize (2).
    constant InFmt_c           : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant AbsWidth_c        : positive    := InFmt_c.S + InFmt_c.I + InFmt_c.F;
    constant SftLatency_c      : positive    := (log2ceil(AbsWidth_c) + 3)/4 + 1;
    constant ExpectedLatency_c : natural     := 13 + 2*SftLatency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                                   := '0';
    signal Rst        : std_logic                                                   := '0';
    signal In_Valid   : std_logic                                                   := '0';
    signal In_Data    : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid  : std_logic;
    signal Out_Result : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Components ***
    constant Stimuli_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant InputFile_c  : string := output_path(runner_cfg) & "Input.fix";
    constant ResultFile_c : string := output_path(runner_cfg) & "Result.fix";

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
                fix_stimuli_play_file (net, Stimuli_c, InputFile_c);
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Second run with stalls ***
            if run("Throttled") then
                fix_stimuli_play_file (net, Stimuli_c, InputFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_checker_check_file (net, Checker_c, ResultFile_c);
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
    i_dut : entity olo.olo_fix_inv
        generic map (
            OutFmt_g        => OutFmt_g,
            InFmt_g         => InFmt_g,
            PrecisionBits_g => PrecisionBits_g,
            MemStyle_g      => MemStyle_g,
            Round_g         => Round_g,
            Saturate_g      => Saturate_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid,
            In_Data    => In_Data,
            Out_Valid  => Out_Valid,
            Out_Result => Out_Result
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => Stimuli_c,
            Fmt      => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_Data
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => Checker_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Result
        );

end architecture;
