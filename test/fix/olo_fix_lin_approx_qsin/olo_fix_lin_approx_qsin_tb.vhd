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
        OutFmt_g    : string  := "(1,0,16)";
        InFmt_g     : string  := "(0,-2,20)";
        CosOutput_g : boolean := true;
        MemStyle_g  : string  := "auto";
        Round_g     : string  := "NonSymPos_s";
        Saturate_g  : string  := "Sat_s";
        runner_cfg  : string
    );
end entity;

architecture sim of olo_fix_lin_approx_qsin_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Latency: olo_fix_lin_approx_calc (8, both resize registers are always implemented) plus the
    -- output stage handling the critical input value zero.
    constant ExpectedLatency_c : natural := 9;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                                   := '0';
    signal Rst       : std_logic                                                   := '0';
    signal In_Valid  : std_logic                                                   := '0';
    signal In_Data   : std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic;
    signal Out_Sin   : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
    signal Out_Cos   : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Components ***
    constant Stimuli_c    : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerSin_c : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerCos_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant QuarterFile_c : string := output_path(runner_cfg) & "Quarter.fix";
    constant SinFile_c     : string := output_path(runner_cfg) & "Sin.fix";
    constant CosFile_c     : string := output_path(runner_cfg) & "Cos.fix";

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
                fix_stimuli_play_file (net, Stimuli_c, QuarterFile_c);
                fix_checker_check_file (net, CheckerSin_c, SinFile_c);

                if CosOutput_g then
                    fix_checker_check_file (net, CheckerCos_c, CosFile_c);
                end if;
            end if;

            -- *** Second run with stalls ***
            if run("Throttled") then
                fix_stimuli_play_file (net, Stimuli_c, QuarterFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_checker_check_file (net, CheckerSin_c, SinFile_c);

                if CosOutput_g then
                    fix_checker_check_file (net, CheckerCos_c, CosFile_c);
                end if;
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(Stimuli_c));
            wait_until_idle(net, as_sync(CheckerSin_c));

            if CosOutput_g then
                wait_until_idle(net, as_sync(CheckerCos_c));
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
            OutFmt_g    => OutFmt_g,
            InFmt_g     => InFmt_g,
            CosOutput_g => CosOutput_g,
            MemStyle_g  => MemStyle_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Data   => In_Data,
            Out_Valid => Out_Valid,
            Out_Sin   => Out_Sin,
            Out_Cos   => Out_Cos
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

    g_checker_cos : if CosOutput_g generate

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

    end generate;

    g_check_cos_zero : if not CosOutput_g generate

        -- Out_Cos must be driven with zeros if the cosine output is disabled
        p_check_cos_zero : process (Clk) is
        begin
            if rising_edge(Clk) then
                if Out_Valid = '1' then
                    check_equal(unsigned(Out_Cos), 0,
                                "Out_Cos must be zero if CosOutput_g = false");
                end if;
            end if;
        end process;

    end generate;

end architecture;
