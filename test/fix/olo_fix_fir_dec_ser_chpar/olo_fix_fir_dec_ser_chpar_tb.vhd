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
entity olo_fix_fir_dec_ser_chpar_tb is
    generic (
        InFmt_g           : string   := "(1,0,15)";
        OutFmt_g          : string   := "(1,0,15)";
        CoefFmt_g         : string   := "(1,0,17)";
        GuardBits_g       : natural  := 1;
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

architecture sim of olo_fix_fir_dec_ser_chpar_tb is

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

    -- Configuration Generics
    constant MaxRatio_c : positive := choose(RuntimeCfg_g, Ratio_g+5, Ratio_g);
    constant MaxTaps_c  : positive := choose(RuntimeCfg_g, Taps_g*3, Taps_g);

    -- Port Widths
    constant InWidth_c  : natural := fixFmtWidthFromString(InFmt_g);
    constant OutWidth_c : natural := fixFmtWidthFromString(OutFmt_g);

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
    signal In_Data      : std_logic_vector(InWidth_c * Channels_g - 1 downto 0)           := (others => '0');
    signal Out_Valid    : std_logic;
    signal Out_Data     : std_logic_vector(OutWidth_c * Channels_g - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant Stimuli_c : olo_test_fix_stimuli_array_t(0 to Channels_g-1) := new_olo_test_fix_stimuli_array(Channels_g);
    constant Checker_c : olo_test_fix_checker_array_t(0 to Channels_g-1) := new_olo_test_fix_checker_array(Channels_g);

    -- *** File Names ***
    impure function inFile (channel : natural) return string is
    begin
        return output_path(runner_cfg) & "In_Ch" & to_string(channel) & ".fix";
    end function;

    impure function outFile (channel : natural) return string is
    begin
        return output_path(runner_cfg) & "Out_Ch" & to_string(channel) & ".fix";
    end function;

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

            -- *** Rate-limited test: full multiplier utilization ***
            if run("RateLimited") then

                for ch in 0 to Channels_g - 1 loop
                    fix_stimuli_play_file(net, Stimuli_c(ch), inFile(ch),
                                          stall_probability => 1.0,
                                          stall_min_cycles  => RateLimitStall_c,
                                          stall_max_cycles  => RateLimitStall_c);
                    fix_checker_check_file(net, Checker_c(ch), outFile(ch));
                end loop;

            end if;

            -- *** Throttled test: more (deterministic) stalls on top of the rate limit ***
            -- Stalls must be deterministic so all parallel channels stay synchronized on In_Valid.
            if run("Throttled") then

                for ch in 0 to Channels_g - 1 loop
                    fix_stimuli_play_file(net, Stimuli_c(ch), inFile(ch),
                                          stall_probability => 1.0,
                                          stall_min_cycles  => RateLimitStall_c + 3,
                                          stall_max_cycles  => RateLimitStall_c + 3);
                    fix_checker_check_file(net, Checker_c(ch), outFile(ch));
                end loop;

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
            for ch in 0 to Channels_g - 1 loop
                wait_until_idle(net, as_sync(Stimuli_c(ch)));
                wait_until_idle(net, as_sync(Checker_c(ch)));
            end loop;

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
    i_dut : entity olo.olo_fix_fir_dec_ser_chpar
        generic map (
            InFmt_g           => InFmt_g,
            OutFmt_g          => OutFmt_g,
            CoefFmt_g         => CoefFmt_g,
            GuardBits_g       => GuardBits_g,
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
            Clk          => Clk,
            Rst          => Rst,
            Cfg_Ratio    => Cfg_Ratio,
            Cfg_Taps     => Cfg_Taps,
            Coef_Addr    => Coef_Addr,
            Coef_WrEna   => Coef_WrEna,
            Coef_WrData  => Coef_WrData,
            Coef_RdEna   => Coef_RdEna,
            Coef_RdData  => Coef_RdData,
            Coef_RdValid => Coef_RdValid,
            In_Valid     => In_Valid,
            In_Data      => In_Data,
            Out_Valid    => Out_Valid,
            Out_Data     => Out_Data
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    g_channels : for i in 0 to Channels_g - 1 generate

        vc_stimuli : entity work.olo_test_fix_stimuli_vc
            generic map (
                Instance         => Stimuli_c(i),
                Fmt              => cl_fix_format_from_string(InFmt_g),
                Is_Timing_Master => (i = 0)
            )
            port map (
                Clk   => Clk,
                Rst   => Rst,
                Valid => In_Valid,
                Ready => In_Valid,
                Data  => In_Data(InWidth_c*(i+1) - 1 downto InWidth_c*i)
            );

        vc_checker : entity work.olo_test_fix_checker_vc
            generic map (
                Instance => Checker_c(i),
                Fmt      => cl_fix_format_from_string(OutFmt_g)
            )
            port map (
                Clk   => Clk,
                Valid => Out_Valid,
                Data  => Out_Data(OutWidth_c*(i+1) - 1 downto OutWidth_c*i)
            );

    end generate;

end architecture;
