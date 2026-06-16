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
entity olo_fix_fir_dec_ser_chtdm_tb is
    generic (
        InFmt_g           : string   := "(1,0,15)";
        OutFmt_g          : string   := "(1,0,15)";
        CoefFmt_g         : string   := "(1,0,17)";
        CoefStorageType_g : string   := "ROM";
        CoefRamReadback_g : boolean  := false;
        Channels_g        : positive := 2;
        Ratio_g           : positive := 8;
        Taps_g            : positive := 16;
        MultRegs_g        : positive := 1;
        Round_g           : string   := "NonSymPos_s";
        Saturate_g        : string   := "Sat_s";
        RuntimeCfg_g      : boolean  := false;
        -- TB only
        WriteCoefs_g      : boolean  := false;
        runner_cfg        : string
    );
end entity;

architecture sim of olo_fix_fir_dec_ser_chtdm_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Rate-limiting: stall cycles to reach full multiplier utilization.
    constant RateLimitStall_c : natural := integer(ceil(real(Taps_g) / real(Ratio_g))) - 1;

    -- Coefficients are read from the file written by the cosimulation
    constant CoefFmt_c    : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant CoefFile_c   : string      := output_path(runner_cfg) & "Coef.fix";
    constant CoefInitTb_c : string      := choose(WriteCoefs_g, "0.0",
                                                  fixFileReadString(CoefFile_c, CoefFmt_c));

    -- Fixed Generics
    constant CoefRamBehavior_c : string := "RBW";

    -- Configuratino Generics
    constant MaxRatio_c : positive := choose(RuntimeCfg_g, Ratio_g+5, Ratio_g);
    constant MaxTaps_c  : positive := choose(RuntimeCfg_g, Taps_g*3, Taps_g);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                                       := '0';
    signal Rst          : std_logic                                                       := '0';
    signal Cfg_Ratio    : std_logic_vector(log2Ceil(MaxRatio_c) - 1 downto 0)             := (others => '0');
    signal Cfg_Taps     : std_logic_vector(log2Ceil(MaxTaps_c) - 1 downto 0)              := (others => '1');
    signal Coef_Addr    : std_logic_vector(log2Ceil(MaxTaps_c) - 1 downto 0)              := (others => '0');
    signal Coef_WrEna   : std_logic                                                       := '0';
    signal Coef_WrData  : std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
    signal Coef_RdEna   : std_logic                                                       := '0';
    signal Coef_RdData  : std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0);
    signal Coef_RdValid : std_logic;
    signal In_Valid     : std_logic                                                       := '0';
    signal In_Data      : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)   := (others => '0');
    signal In_Last      : std_logic                                                       := '0';
    signal Out_Valid    : std_logic;
    signal Out_Data     : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
    signal Out_Last     : std_logic;

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
        file CoefFile_v : text;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset and apply config
            wait until rising_edge(Clk);
            Rst <= '1';
            if RuntimeCfg_g then
                Cfg_Ratio <= toUslv(Ratio_g - 1, Cfg_Ratio'length);
                Cfg_Taps  <= toUslv(Taps_g - 1, Cfg_Taps'length);
            end if;
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Write coefficients into the coefficient RAM via the Cfg port (when not initialized through Init_g)
            if WriteCoefs_g then
                file_open(CoefFile_v, CoefFile_c, read_mode);
                fixFileCheckHeader(CoefFile_v, CoefFmt_c);

                for i in 0 to Taps_g - 1 loop
                    Coef_Addr   <= toUslv(i, Coef_Addr'length);
                    Coef_WrData <= fixFileReadSample(CoefFile_v, CoefFmt_c);
                    Coef_WrEna  <= '1';
                    wait until rising_edge(Clk);
                end loop;

                file_close(CoefFile_v);
                Coef_WrEna  <= '0';
                Coef_Addr   <= (others => '0');
                Coef_WrData <= (others => '0');
                wait until rising_edge(Clk);
            end if;

            -- *** Rate-limited test: one TDM frame every Taps_g clocks ***
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

            -- *** Coefficient readback test ***
            -- Skipped if readback is not enabled (CoefRamReadback_g=false or CoefStorageType_g=ROM)
            if run("CoefReadback") then
                if CoefRamReadback_g and CoefStorageType_g = "RAM" then
                    file_open(CoefFile_v, CoefFile_c, read_mode);
                    fixFileCheckHeader(CoefFile_v, CoefFmt_c);

                    for i in 0 to Taps_g - 1 loop
                        -- Issue the readback request
                        Coef_Addr  <= toUslv(i, Coef_Addr'length);
                        Coef_RdEna <= '1';
                        wait until rising_edge(Clk);
                        Coef_Addr  <= (others => '0');
                        Coef_RdEna <= '0';
                        -- Wait for the readback data to become valid and compare against the expected coefficient
                        wait until rising_edge(Clk) and Coef_RdValid = '1';
                        check_equal(Coef_RdData, fixFileReadSample(CoefFile_v, CoefFmt_c),
                                    "Coefficient readback mismatch at address " & to_string(i));
                    end loop;

                    file_close(CoefFile_v);
                end if;
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
    i_dut : entity olo.olo_fix_fir_dec_ser_chtdm
        generic map (
            InFmt_g           => InFmt_g,
            OutFmt_g          => OutFmt_g,
            CoefFmt_g         => CoefFmt_g,
            CoefInit_g        => CoefInitTb_c,
            CoefStorageType_g => CoefStorageType_g,
            CoefRamReadback_g => CoefRamReadback_g,
            CoefRamBehavior_g => CoefRamBehavior_c,
            Channels_g        => Channels_g,
            MaxRatio_g        => MaxRatio_c,
            MaxTaps_g         => MaxTaps_c,
            RuntimeCfg_g      => RuntimeCfg_g,
            MultRegs_g        => MultRegs_g,
            Round_g           => Round_g,
            Saturate_g        => Saturate_g
        )
        port map (
            Clk              => Clk,
            Rst              => Rst,
            Cfg_Ratio        => Cfg_Ratio,
            Cfg_Taps         => Cfg_Taps,
            Coef_Addr        => Coef_Addr,
            Coef_WrEna       => Coef_WrEna,
            Coef_WrData      => Coef_WrData,
            Coef_RdEna       => Coef_RdEna,
            Coef_RdData      => Coef_RdData,
            Coef_RdValid     => Coef_RdValid,
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
