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

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_cordic_rot_tb is
    generic (
        InMagFmt_g        : string   := "(0,0,16)";
        InAngFmt_g        : string   := "(0,0,16)";
        OutFmt_g          : string   := "(1,0,15)";
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

architecture sim of olo_fix_cordic_rot_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                                      := '0';
    signal Rst       : std_logic                                                      := '0';
    signal In_Valid  : std_logic                                                      := '0';
    signal In_Ready  : std_logic;
    signal In_Mag    : std_logic_vector(fixFmtWidthFromString(InMagFmt_g)-1 downto 0) := (others => '0');
    signal In_Ang    : std_logic_vector(fixFmtWidthFromString(InAngFmt_g)-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic;
    signal Out_I     : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
    signal Out_Q     : std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant StimuliMag_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant StimuliAng_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant CheckerI_c   : olo_test_fix_checker_t := new_olo_test_fix_checker;
    constant CheckerQ_c   : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant InMagFile_c : string := output_path(runner_cfg) & "InMag.fix";
    constant InAngFile_c : string := output_path(runner_cfg) & "InAng.fix";
    constant OutIFile_c  : string := output_path(runner_cfg) & "OutI.fix";
    constant OutQFile_c  : string := output_path(runner_cfg) & "OutQ.fix";

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
                fix_stimuli_play_file (net, StimuliMag_c, InMagFile_c);
                fix_stimuli_play_file (net, StimuliAng_c, InAngFile_c);
                fix_checker_check_file (net, CheckerI_c, OutIFile_c);
                fix_checker_check_file (net, CheckerQ_c, OutQFile_c);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, StimuliMag_c, InMagFile_c, stall_probability => 0.5, stall_max_cycles => 10);
                fix_stimuli_play_file (net, StimuliAng_c, InAngFile_c);
                fix_checker_check_file (net, CheckerI_c, OutIFile_c);
                fix_checker_check_file (net, CheckerQ_c, OutQFile_c);
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(StimuliMag_c));
            wait_until_idle(net, as_sync(StimuliAng_c));
            wait_until_idle(net, as_sync(CheckerI_c));
            wait_until_idle(net, as_sync(CheckerQ_c));
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
    i_dut : entity olo.olo_fix_cordic_rot
        generic map (
            InMagFmt_g        => InMagFmt_g,
            InAngFmt_g        => InAngFmt_g,
            OutFmt_g          => OutFmt_g,
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
            In_Mag    => In_Mag,
            In_Ang    => In_Ang,
            Out_Valid => Out_Valid,
            Out_I     => Out_I,
            Out_Q     => Out_Q
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_mag : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliMag_c,
            Fmt              => cl_fix_format_from_string(InMagFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Ready,
            Data     => In_Mag
        );

    vc_stimuli_ang : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => StimuliAng_c,
            Fmt              => cl_fix_format_from_string(InAngFmt_g),
            Is_Timing_Master => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Ready    => In_Ready,
            Valid    => In_Valid,
            Data     => In_Ang
        );

    vc_checker_i_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerI_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_I
        );

    vc_checker_q_i : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => CheckerQ_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Q
        );

end architecture;
