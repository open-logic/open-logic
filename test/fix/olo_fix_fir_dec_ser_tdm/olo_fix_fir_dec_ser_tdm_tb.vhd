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
    use olo.olo_base_pkg_math.all;

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_fir_dec_ser_tdm_tb is
    generic (
        InFmt_g           : string   := "(1,0,15)";
        OutFmt_g          : string   := "(1,0,15)";
        CoefFmt_g         : string   := "(1,0,17)";
        CoefInit_g        : string   := "0.0";
        CoefStorageType_g : string   := "ROM";
        CoefRamReadback_g : boolean  := false;
        CoefRamBehavior_g : string   := "RBW";
        Channels_g        : positive := 2;
        MaxRatio_g        : positive := 8;
        MaxTaps_g         : positive := 16;
        Round_g           : string   := "NonSymPos_s";
        Saturate_g        : string   := "Sat_s";
        runner_cfg        : string
    );
end entity;

architecture sim of olo_fix_fir_dec_ser_tdm_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Rate-limiting: one TDM frame every MaxTaps_g clocks minimum.
    -- stall_per_sample = ceiling(MaxTaps_g / Channels_g) - 1
    constant RateLimitStall_c : natural := (MaxTaps_g + Channels_g - 1) / Channels_g - 1;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk             : std_logic                                                       := '0';
    signal Rst             : std_logic                                                       := '0';
    signal Cfg_Ratio       : std_logic_vector(log2Ceil(MaxRatio_g) - 1 downto 0)             := (others => '0');
    signal Cfg_Taps        : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := (others => '0');
    signal Coef_Cfg_Addr   : std_logic_vector(log2Ceil(MaxTaps_g) - 1 downto 0)              := (others => '0');
    signal Coef_Cfg_WrEna  : std_logic                                                       := '0';
    signal Coef_Cfg_WrData : std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
    signal Coef_Cfg_RdEna  : std_logic                                                       := '0';
    signal Coef_Cfg_RdData : std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
    signal In_Valid        : std_logic                                                       := '0';
    signal In_Data         : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)   := (others => '0');
    signal In_Last         : std_logic                                                       := '0';
    signal Out_Valid       : std_logic;
    signal Out_Data        : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
    signal Out_Last        : std_logic;

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
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset and apply config
            wait until rising_edge(Clk);
            Rst       <= '1';
            Cfg_Ratio <= toUslv(MaxRatio_g - 1, Cfg_Ratio'length);
            Cfg_Taps  <= toUslv(MaxTaps_g - 1, Cfg_Taps'length);
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst       <= '0';
            wait until rising_edge(Clk);

            -- *** Rate-limited test: one TDM frame every MaxTaps_g clocks ***
            if run("RateLimited") then
                fix_stimuli_play_file(net, Stimuli_c, InFile_c,
                                      stall_probability => 1.0,
                                      stall_min_cycles  => RateLimitStall_c,
                                      stall_max_cycles  => RateLimitStall_c,
                                      Mode              => stimuli_mode_tdm,
                                      Tdm_Slots         => Channels_g);
                fix_checker_check_file(net, Checker_c, OutFile_c,
                                       Mode      => checker_mode_tdm,
                                       Tdm_Slots => Channels_g);
            end if;

            -- *** Throttled test: more stalls on top of rate limit ***
            if run("Throttled") then
                fix_stimuli_play_file(net, Stimuli_c, InFile_c,
                                      stall_probability => 1.0,
                                      stall_min_cycles  => RateLimitStall_c,
                                      stall_max_cycles  => RateLimitStall_c + 5,
                                      Mode              => stimuli_mode_tdm,
                                      Tdm_Slots         => Channels_g);
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
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_fir_dec_ser_tdm
        generic map (
            InFmt_g           => InFmt_g,
            OutFmt_g          => OutFmt_g,
            CoefFmt_g         => CoefFmt_g,
            CoefInit_g        => CoefInit_g,
            CoefStorageType_g => CoefStorageType_g,
            CoefRamReadback_g => CoefRamReadback_g,
            CoefRamBehavior_g => CoefRamBehavior_g,
            Channels_g        => Channels_g,
            MaxRatio_g        => MaxRatio_g,
            MaxTaps_g         => MaxTaps_g,
            Round_g           => Round_g,
            Saturate_g        => Saturate_g
        )
        port map (
            Clk              => Clk,
            Rst              => Rst,
            Cfg_Ratio        => Cfg_Ratio,
            Cfg_Taps         => Cfg_Taps,
            Coef_Cfg_Addr    => Coef_Cfg_Addr,
            Coef_Cfg_WrEna   => Coef_Cfg_WrEna,
            Coef_Cfg_WrData  => Coef_Cfg_WrData,
            Coef_Cfg_RdEna   => Coef_Cfg_RdEna,
            Coef_Cfg_RdData  => Coef_Cfg_RdData,
            In_Valid         => In_Valid,
            In_Data          => In_Data,
            In_Last          => In_Last,
            Out_Valid        => Out_Valid,
            Out_Data         => Out_Data,
            Out_Last         => Out_Last
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
            Clk   => Clk,
            Rst   => Rst,
            Valid => In_Valid,
            Last  => In_Last,
            Data  => In_Data
        );

    vc_checker : entity work.olo_test_fix_checker_vc
        generic map (
            Instance => Checker_c,
            Fmt      => cl_fix_format_from_string(OutFmt_g)
        )
        port map (
            Clk   => Clk,
            Valid => Out_Valid,
            Last  => Out_Last,
            Data  => Out_Data
        );

end architecture;
