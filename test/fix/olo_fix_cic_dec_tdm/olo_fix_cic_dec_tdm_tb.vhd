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
    use olo.olo_base_pkg_math.all;

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_cic_dec_tdm_tb is
    generic (
        Channels_g        : positive := 1;
        Order_g           : positive := 3;
        Ratio_g           : positive := 4;
        FixedRatio_g      : boolean  := true;
        DiffDelay_g       : positive := 1;
        InFmt_g           : string   := "(1,0,15)";
        OutFmt_g          : string   := "(1,0,12)";
        GainCorrCoefFmt_g : string   := "(0,1,16)";
        Round_g           : string   := "NonSymPos_s";
        Saturate_g        : string   := "Sat_s";
        runner_cfg        : string
    );
end entity;

architecture sim of olo_fix_cic_dec_tdm_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                                                       := '0';
    signal Rst          : std_logic                                                                       := '0';
    signal Cfg_Ratio    : std_logic_vector(log2ceil(Ratio_g) - 1 downto 0)                                := (others => 'X');
    signal Cfg_Shift    : std_logic_vector(7 downto 0)                                                    := (others => 'X');
    signal Cfg_GainCorr : std_logic_vector(fixFmtWidthFromStringTolerant(GainCorrCoefFmt_g) - 1 downto 0) := (others => 'X');
    signal In_Valid     : std_logic                                                                       := '0';
    signal In_Data      : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)                   := (others => '0');
    signal In_Last      : std_logic                                                                       := '0';
    signal Out_Valid    : std_logic;
    signal Out_Data     : std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
    signal Out_Last     : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant Stimuli_c : olo_test_fix_stimuli_t := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_t := new_olo_test_fix_checker;

    -- *** Constants ***
    constant InFile_c      : string := output_path(runner_cfg) & "In_Interleaved.fix";
    constant Outfile_c     : string := output_path(runner_cfg) & "Out_Interleaved.fix";
    constant OutFileMin1_c : string := output_path(runner_cfg) & "Out_Rminus1_Interleaved.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
        variable Ratio_v     : real := real(Ratio_g);
        variable CicGain_v   : real;
        variable CicGrowth_v : real;
        variable GainCorr_v  : real;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            -- During Reset set config ports (if not fixed)
            Ratio_v := real(Ratio_g);
            if not FixedRatio_g then
                CicGain_v    := (Ratio_v * real(DiffDelay_g))**real(Order_g);
                CicGrowth_v  := ceil(log2(CicGain_v));
                GainCorr_v   := 2.0**CicGrowth_v / CicGain_v;
                Cfg_Shift    <= toUslv(integer(CicGrowth_v), Cfg_Shift'length);
                Cfg_GainCorr <= cl_fix_from_real(GainCorr_v, fixFmtFromStringTolerant(GainCorrCoefFmt_g));
                Cfg_Ratio    <= toUslv(integer(Ratio_v) - 1, Cfg_Ratio'length);
            end if;
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** First Run ***
            if run("FullSpeed") then
                fix_stimuli_play_file (net, Stimuli_c, InFile_c, Mode => stimuli_mode_tdm, Tdm_Slots => Channels_g);
                fix_checker_check_file (net, Checker_c, Outfile_c, Mode => checker_mode_tdm, Tdm_Slots => Channels_g);
            end if;

            -- *** Second run with delay ***
            if run("Throttled") then
                fix_stimuli_play_file (net, Stimuli_c, InFile_c); -- Using streaming mode should also be fine
                fix_checker_check_file (net, Checker_c, Outfile_c, Mode => checker_mode_tdm, Tdm_Slots => Channels_g);
            end if;

            -- *** Test different reatio ***
            if run("RatioChange") then
                -- Cosimulation creates ratio R-1
                if not FixedRatio_g then
                    Ratio_v      := real(Ratio_g - 1);
                    wait until rising_edge(Clk);
                    Rst          <= '1';
                    CicGain_v    := (Ratio_v * real(DiffDelay_g))**real(Order_g);
                    CicGrowth_v  := ceil(log2(CicGain_v));
                    GainCorr_v   := 2.0**CicGrowth_v / CicGain_v;
                    Cfg_Shift    <= toUslv(integer(CicGrowth_v), Cfg_Shift'length);
                    Cfg_GainCorr <= cl_fix_from_real(GainCorr_v, fixFmtFromStringTolerant(GainCorrCoefFmt_g));
                    Cfg_Ratio    <= toUslv(integer(Ratio_v) - 1, Cfg_Ratio'length);
                    wait for 1 us;
                    wait until rising_edge(Clk);
                    Rst          <= '0';
                    wait until rising_edge(Clk);
                end if;
                -- This only can be tested for runtime configurable ratio
                -- For Ratio_g=1 R-1 des not apply
                if FixedRatio_g = false and Ratio_g > 1 then
                    fix_stimuli_play_file (net, Stimuli_c, InFile_c, Mode => stimuli_mode_tdm, Tdm_Slots => Channels_g);
                    fix_checker_check_file (net, Checker_c, OutFileMin1_c, Mode => checker_mode_tdm, Tdm_Slots => Channels_g);
                end if;
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
    i_dut : entity olo.olo_fix_cic_dec_tdm
        generic map (
            Channels_g        => Channels_g,
            Order_g           => Order_g,
            Ratio_g           => Ratio_g,
            FixedRatio_g      => FixedRatio_g,
            DiffDelay_g       => DiffDelay_g,
            InFmt_g           => InFmt_g,
            OutFmt_g          => OutFmt_g,
            GainCorrCoefFmt_g => GainCorrCoefFmt_g,
            Round_g           => Round_g,
            Saturate_g        => Saturate_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            Cfg_Ratio    => Cfg_Ratio,
            Cfg_Shift    => Cfg_Shift,
            Cfg_GainCorr => Cfg_GainCorr,
            In_Valid     => In_Valid,
            In_Data      => In_Data,
            In_Last      => In_Last,
            Out_Valid    => Out_Valid,
            Out_Data     => Out_Data,
            Out_Last     => Out_Last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity work.olo_test_fix_stimuli_vc
        generic map (
            Instance         => Stimuli_c,
            Fmt              => cl_fix_format_from_string(InFmt_g)
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Last     => In_Last,
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
            Last     => Out_Last,
            Data     => Out_Data
        );

end architecture;
