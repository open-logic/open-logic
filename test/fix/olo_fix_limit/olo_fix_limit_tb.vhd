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
entity olo_fix_limit_tb is
    generic (
        InFmt_g          : string  := "(1,1,8)";
        LimLoFmt_g       : string  := "(1,1,8)";
        LimHiFmt_g       : string  := "(1,1,8)";
        ResultFmt_g      : string  := "(1,1,8)";
        Round_g          : string  := "NonSymPos_s";
        Saturate_g       : string  := "Sat_s";
        UseFixedLimits_g : boolean := false;
        FixedLimLo_g     : string  := "0.0";
        FixedLimHi_g     : string  := "0.0";
        RoundReg_g       : string  := "YES";
        SatReg_g         : string  := "YES";
        runner_cfg       : string
    );
end entity;

architecture sim of olo_fix_limit_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    constant FixedLimLo_c : real := real'value(FixedLimLo_g);
    constant FixedLimHi_c : real := real'value(FixedLimHi_g);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic := '0';
    signal Rst        : std_logic := '0';
    signal In_Valid   : std_logic;
    signal In_Data    : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_LimLo   : std_logic_vector(fixFmtWidthFromString(LimLoFmt_g) - 1 downto 0);
    signal In_LimHi   : std_logic_vector(fixFmtWidthFromString(LimHiFmt_g) - 1 downto 0);
    signal Out_Valid  : std_logic;
    signal Out_Result : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant StimuliData_c  : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliLimLo_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliLimHi_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c      : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant DataFile_c   : string := output_path(runner_cfg) & "Data.fix";
    constant LiLoFile_c   : string := output_path(runner_cfg) & "LimLo.fix";
    constant LiHiFile_c   : string := output_path(runner_cfg) & "LimHi.fix";
    constant ResultFile_c : string := output_path(runner_cfg) & "Result.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
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
                fix_stimuli_play_file (net, StimuliData_c, DataFile_c);
                if not UseFixedLimits_g then
                    fix_stimuli_play_file (net, StimuliLimLo_c, LiLoFile_c);
                    fix_stimuli_play_file (net, StimuliLimHi_c, LiHiFile_c);
                end if;
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliData_c, DataFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                if not UseFixedLimits_g then
                    fix_stimuli_play_file (net, StimuliLimLo_c, LiLoFile_c);
                    fix_stimuli_play_file (net, StimuliLimHi_c, LiHiFile_c);
                end if;
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliData_c));
            wait_until_idle(net, as_sync(StimuliLimLo_c));
            wait_until_idle(net, as_sync(StimuliLimHi_c));
            wait_until_idle(net, as_sync(Checker_c));
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
    i_dut : entity olo.olo_fix_limit
        generic map (
            InFmt_g          => InFmt_g,
            LimLoFmt_g       => LimLoFmt_g,
            LimHiFmt_g       => LimHiFmt_g,
            ResultFmt_g      => ResultFmt_g,
            Round_g          => Round_g,
            Saturate_g       => Saturate_g,
            UseFixedLimits_g => UseFixedLimits_g,
            FixedLimLo_g     => FixedLimLo_c,
            FixedLimHi_g     => FixedLimHi_c,
            RoundReg_g       => RoundReg_g,
            SatReg_g         => SatReg_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid,
            In_Data    => In_Data,
            In_LimLo   => In_LimLo,
            In_LimHi   => In_LimHi,
            Out_Valid  => Out_Valid,
            Out_Result => Out_Result
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_data : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliData_c,
            Fmt              => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_Data
        );

    vc_stimuli_limlo : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliLimLo_c,
            Fmt              => cl_fix_format_from_string(LimLoFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Valid,
            Valid    => In_Valid,
            Data     => In_LimLo
        );

    vc_stimuli_limhi : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliLimHi_c,
            Fmt              => cl_fix_format_from_string(LimHiFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Valid,
            Valid    => In_Valid,
            Data     => In_LimHi
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => Checker_c,
            Fmt              => cl_fix_format_from_string(ResultFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Result
        );

end architecture;
