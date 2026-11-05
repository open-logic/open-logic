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

library std;
    use std.textio.all;

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
entity olo_fix_fir_dec_par_chtdm_tb is
    generic (
        InFmt_g        : string   := "(1,0,15)";
        OutFmt_g       : string   := "(1,0,15)";
        CoefFmt_g      : string   := "(1,0,17)";
        GuardBits_g    : natural  := 1;
        CoefWritable_g : boolean  := false;
        Channels_g     : positive := 2;
        Ratio_g        : positive := 4;
        Taps_g         : positive := 16;
        IsSymmetric_g  : boolean  := false;
        MultRegs_g     : positive := 1;
        Round_g        : string   := "NonSymPos_s";
        Saturate_g     : string   := "Sat_s";
        -- TB only
        WriteCoefs_g   : boolean  := false;
        runner_cfg     : string
    );
end entity;

architecture sim of olo_fix_fir_dec_par_chtdm_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    constant InFmt_c  : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Symmetric filters have one stage per pair of taps
    constant Stages_c : positive := choose(IsSymmetric_g, (Taps_g + 1) / 2, Taps_g);

    -- Coefficients are read from the file written by the cosimulation
    constant CoefFmt_c    : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant CoefFile_c   : string      := output_path(runner_cfg) & "Coef.fix";
    constant CoefInitTb_c : string      := choose(WriteCoefs_g, "0.0",
                                                  fixFileReadString(CoefFile_c, CoefFmt_c));

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic                                                       := '0';
    signal Rst         : std_logic                                                       := '0';
    signal Coef_Addr   : std_logic_vector(log2Ceil(Taps_g) - 1 downto 0)                 := (others => '0');
    signal Coef_WrEna  : std_logic                                                       := '0';
    signal Coef_WrData : std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
    signal Stim_Valid  : std_logic;
    signal Stim_Data   : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal Stim_Last   : std_logic;
    signal Dirty_Valid : std_logic                                                       := '0';
    signal Dirty_Data  : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)   := (others => '0');
    signal In_Valid    : std_logic;
    signal In_Data     : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
    signal In_Last     : std_logic;
    signal Out_Valid   : std_logic;
    signal Out_Data    : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
    signal Out_Last    : std_logic;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant Stimuli_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    constant InFile_c  : string := output_path(runner_cfg) & "In_Interleaved.fix";
    constant OutFile_c : string := output_path(runner_cfg) & "Out_Interleaved.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
        file CoefFile_v : text;
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

            -- Write coefficients through the configuration port (when not through CoefInit_g)
            if WriteCoefs_g then
                file_open(CoefFile_v, CoefFile_c, read_mode);
                fixFileCheckHeader(CoefFile_v, CoefFmt_c);

                for i in 0 to Taps_g - 1 loop
                    Coef_Addr   <= toUslv(i, Coef_Addr'length);
                    Coef_WrData <= fixFileReadSample(CoefFile_v, CoefFmt_c);
                    Coef_WrEna  <= '1';
                    -- Symmetric: Writes to the upper half must be ignored
                    if i >= Stages_c then
                        Coef_WrData <= (others => '1');
                    end if;
                    wait until rising_edge(Clk);
                end loop;

                file_close(CoefFile_v);

                -- Addresses above the number of taps are ignored
                Coef_WrData <= (others => '1');

                for i in Taps_g to 2 ** Coef_Addr'length - 1 loop
                    Coef_Addr <= toUslv(i, Coef_Addr'length);
                    wait until rising_edge(Clk);
                end loop;

                Coef_WrEna  <= '0';
                Coef_Addr   <= (others => '0');
                Coef_WrData <= (others => '0');
                wait until rising_edge(Clk);
            end if;

            -- *** Full input rate: a sample on every clock cycle ***
            if run("FullRate") then
                fix_stimuli_play_file(net, Stimuli_c, InFile_c,
                                      Mode      => stimuli_mode_tdm,
                                      Tdm_Slots => Channels_g);
                fix_checker_check_file(net, Checker_c, OutFile_c,
                                       Mode      => checker_mode_tdm,
                                       Tdm_Slots => Channels_g);
            end if;

            -- *** Throttled: Random gaps between samples ***
            if run("Throttled") then
                fix_stimuli_play_file(net, Stimuli_c, InFile_c,
                                      stall_probability => 0.5,
                                      stall_min_cycles  => 1,
                                      stall_max_cycles  => 5,
                                      Mode              => stimuli_mode_tdm,
                                      Tdm_Slots         => Channels_g);
                fix_checker_check_file(net, Checker_c, OutFile_c,
                                       Mode      => checker_mode_tdm,
                                       Tdm_Slots => Channels_g);
            end if;

            -- *** Latency as documented ***
            if run("Latency") then
                Dirty_Valid <= '1';
                wait until rising_edge(Clk);
                Dirty_Valid <= '0';

                for i in 1 to Stages_c + MultRegs_g + 3 loop
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '0', "Out_Valid too early, cycle " & to_string(i));
                end loop;

                wait until rising_edge(Clk);
                check_equal(Out_Valid, '1', "Out_Valid not high after documented latency");
                wait until rising_edge(Clk);
                check_equal(Out_Valid, '0', "Out_Valid high for more than one cycle");
            end if;

            -- *** Reset during operation clears the delay lines and keeps coefficients ***
            if run("ResetDuringOperation") then

                -- Fill the delay lines and end in the middle of a frame (if multi-channel)
                wait until rising_edge(Clk);
                Dirty_Data <= (others => '1');

                for i in 0 to Channels_g * (Taps_g + 2) + choose(Channels_g > 1, 1, 0) - 1 loop
                    Dirty_Valid <= '1';
                    wait until rising_edge(Clk);
                end loop;

                -- Reset with samples in flight, shortest reset allowed
                Dirty_Valid <= '0';
                wait until rising_edge(Clk);
                Rst         <= '1';
                wait until rising_edge(Clk);
                Rst         <= '0';
                wait until rising_edge(Clk);
                check_equal(Out_Valid, '0', "Out_Valid high after reset");

                -- Must be bit-true without any further action
                fix_stimuli_play_file(net, Stimuli_c, InFile_c,
                                      Mode      => stimuli_mode_tdm,
                                      Tdm_Slots => Channels_g);
                fix_checker_check_file(net, Checker_c, OutFile_c,
                                       Mode      => checker_mode_tdm,
                                       Tdm_Slots => Channels_g);
            end if;

            -- *** Wait for completion ***
            wait_until_idle(net, as_sync(Stimuli_c));
            wait_until_idle(net, as_sync(Checker_c));
            wait for 1 us;

        end loop;

        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- Input Selection
    -----------------------------------------------------------------------------------------------
    In_Valid <= Dirty_Valid or Stim_Valid;
    In_Data  <= Dirty_Data when Dirty_Valid = '1' else Stim_Data;
    In_Last  <= Stim_Last;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_fir_dec_par_chtdm
        generic map (
            InFmt_g        => InFmt_g,
            OutFmt_g       => OutFmt_g,
            CoefFmt_g      => CoefFmt_g,
            Channels_g     => Channels_g,
            Ratio_g        => Ratio_g,
            Taps_g         => Taps_g,
            IsSymmetric_g  => IsSymmetric_g,
            GuardBits_g    => GuardBits_g,
            Round_g        => Round_g,
            Saturate_g     => Saturate_g,
            MultRegs_g     => MultRegs_g,
            CoefInit_g     => CoefInitTb_c,
            CoefWritable_g => CoefWritable_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            Coef_Addr   => Coef_Addr,
            Coef_WrEna  => Coef_WrEna,
            Coef_WrData => Coef_WrData,
            In_Valid    => In_Valid,
            In_Data     => In_Data,
            In_Last     => In_Last,
            Out_Valid   => Out_Valid,
            Out_Data    => Out_Data,
            Out_Last    => Out_Last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance => Stimuli_c,
            Fmt      => InFmt_c
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Valid => Stim_Valid,
            Last  => Stim_Last,
            Data  => Stim_Data
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => Checker_c,
            Fmt      => OutFmt_c
        )
        port map (
            Clk   => Clk,
            Valid => Out_Valid,
            Last  => Out_Last,
            Data  => Out_Data
        );

end architecture;
