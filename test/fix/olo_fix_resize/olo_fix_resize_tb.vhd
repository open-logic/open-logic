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
entity olo_fix_resize_tb is
    generic (
        AFmt_g       : string := "(1,15,0)";
        ResultFmt_g  : string := "(0,1,8)";
        Round_g      : string := "NonSymPos_s";
        Saturate_g   : string := "Sat_s";
        RoundReg_g   : string := "YES";
        SatReg_g     : string := "YES";
        runner_cfg   : string
    );
end entity;

architecture sim of olo_fix_resize_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic := '0';
    signal Rst        : std_logic := '0';
    signal ClkDut     : std_logic := '0';
    signal RstDut     : std_logic := '0';
    signal In_Valid   : std_logic;
    signal In_A       : std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
    signal Out_Valid  : std_logic;
    signal Out_Result : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant HasRegs_c : boolean := (RoundReg_g /= "NO" or SatReg_g /= "NO");

    -- *** Verification Compnents ***
    constant Stimuli_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant AFile_c      : string := output_path(runner_cfg) & "A.fix";
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
                fix_stimuli_play_file (net, Stimuli_c, AFile_c);
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, Stimuli_c, AFile_c, stall_probability => 0.5, stall_max_cycles => 10);
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
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    -- Clk and Rst are only needed for implementations with register, for cases where they are not
    -- needed, they are not applied to check if DUT works unclocked.
    g_regs : if HasRegs_c generate
        ClkDut <= transport Clk after 100 ps; -- delay to avoid delta-cycle problems
        RstDut <= Rst;
    end generate;

    g_nregs : if not HasRegs_c generate
        ClkDut <= '0';
        RstDut <= '0';
    end generate;

    -- DUT
    i_dut : entity olo.olo_fix_resize
        generic map (
            AFmt_g      => AFmt_g,
            ResultFmt_g => ResultFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => RoundReg_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => ClkDut,
            Rst         => RstDut,
            In_Valid    => In_Valid,
            In_A        => In_A,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => Stimuli_c,
            Fmt              => cl_fix_format_from_string(AFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_A
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
