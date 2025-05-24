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
entity olo_fix_compare_tb is
    generic (
        AFmt_g       : string  := "(1,1,8)";
        BFmt_g       : string  := "(1,1,8)";
        Comparison_g : string  := "=";
        OpRegs_g     : natural := 1;
        runner_cfg   : string
    );
end entity;

architecture sim of olo_fix_compare_tb is

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
    signal In_B       : std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
    signal Out_Valid  : std_logic;
    signal Out_Result : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant HasRegs_c : boolean := (OpRegs_g > 0);

    -- *** Verification Compnents ***
    constant StimuliA_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliB_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c  : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant AFile_c      : string := output_path(runner_cfg) & "A.fix";
    constant BFile_c      : string := output_path(runner_cfg) & "B.fix";
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
                fix_stimuli_play_file (net, StimuliA_c, AFile_c);
                fix_stimuli_play_file (net, StimuliB_c, BFile_c);
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliA_c, AFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_stimuli_play_file (net, StimuliB_c, BFile_c);
                fix_checker_check_file (net, Checker_c, ResultFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliA_c));
            wait_until_idle(net, as_sync(StimuliB_c));
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

    i_dut : entity olo.olo_fix_compare
        generic map (
            AFmt_g       => AFmt_g,
            BFmt_g       => BFmt_g,
            Comparison_g => Comparison_g,
            OpRegs_g     => OpRegs_g
        )
        port map (
            Clk         => ClkDut,
            Rst         => RstDut,
            In_Valid    => In_Valid,
            In_A        => In_A,
            In_B        => In_B,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimulia : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliA_c,
            Fmt              => cl_fix_format_from_string(AFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_A
        );

    vc_stimulib : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliB_c,
            Fmt              => (cl_fix_format_from_string(BFmt_g)),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Valid,
            Valid    => In_Valid,
            Data     => In_B
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance         => Checker_c,
            Fmt              => (0,1,0)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data(0)  => Out_Result
        );

end architecture;
