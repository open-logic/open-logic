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
entity olo_fix_cic_intp_tdm_par_tb is
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

architecture sim of olo_fix_cic_intp_tdm_par_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real     := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time     := (1 sec) / Clk_Frequency_c;
    constant OutWidth_c      : positive := fixFmtWidthFromString(OutFmt_g);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                                                       := '0';
    signal Rst          : std_logic                                                                       := '0';
    signal Cfg_Ratio    : std_logic_vector(log2ceil(Ratio_g) - 1 downto 0)                                := (others => 'X');
    signal Cfg_Shift    : std_logic_vector(7 downto 0)                                                    := (others => 'X');
    signal Cfg_GainCorr : std_logic_vector(fixFmtWidthFromStringTolerant(GainCorrCoefFmt_g) - 1 downto 0) := (others => 'X');
    signal In_Valid     : std_logic                                                                       := '0';
    signal In_Ready     : std_logic;
    signal In_Data      : std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)                   := (others => '0');
    signal In_Last      : std_logic                                                                       := '0';
    signal Out_Valid    : std_logic;
    signal Out_Data     : std_logic_vector(OutWidth_c*Channels_g - 1 downto 0);

    -- Checker ready signals (unused, DUT has no output backpressure)
    signal CheckerRdy : std_logic_vector(0 to Channels_g-1);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents **
    constant Stimuli_c : olo_test_fix_stimuli_t                          := new_olo_test_fix_stimuli;
    constant Checker_c : olo_test_fix_checker_array_t(0 to Channels_g-1) := new_olo_test_fix_checker_array(Channels_g);

    -- *** File Names ***
    constant InFile_c : string := output_path(runner_cfg) & "In_Interleaved.fix";

    impure function outFile (channel : natural; rminus1 : boolean := false) return string is
    begin
        if rminus1 then
            return output_path(runner_cfg) & "Out_Rminus1_Ch" & to_string(channel) & ".fix";
        else
            return output_path(runner_cfg) & "Out_Ch" & to_string(channel) & ".fix";
        end if;
    end function;

    -- *** Procedures ***
    procedure applyConfig (
        Ratio               : positive;
        signal Cfg_Ratio    : out std_logic_vector;
        signal Cfg_Shift    : out std_logic_vector;
        signal Cfg_GainCorr : out std_logic_vector) is
        variable CicGain_v   : real;
        variable CicGrowth_v : natural;
        variable GainCorr_v  : real;
    begin
        CicGain_v    := (real(Ratio) * real(DiffDelay_g))**real(Order_g) / real(Ratio);
        CicGrowth_v  := log2ceil(CicGain_v);
        GainCorr_v   := 2.0**real(CicGrowth_v) / CicGain_v;
        Cfg_Shift    <= toUslv(CicGrowth_v, Cfg_Shift'length);
        Cfg_GainCorr <= cl_fix_from_real(GainCorr_v, fixFmtFromStringTolerant(GainCorrCoefFmt_g));
        Cfg_Ratio    <= toUslv(Ratio - 1, Cfg_Ratio'length);
    end procedure;

    procedure checkAll (
        signal net : inout network_t;
        rminus1    : boolean := false) is
    begin

        for ch in 0 to Channels_g - 1 loop
            fix_checker_check_file (net, Checker_c(ch), outFile(ch, rminus1));
        end loop;

    end procedure;

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
            -- During Reset set config ports (if not fixed)
            if not FixedRatio_g then
                applyConfig(Ratio_g, Cfg_Ratio, Cfg_Shift, Cfg_GainCorr);
            end if;
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** Full speed input (In_Ready is the limiting factor) ***
            if run("FullSpeed") then
                fix_stimuli_play_file (net, Stimuli_c, InFile_c, mode => stimuli_mode_tdm, tdm_slots => Channels_g);
                checkAll(net);
            end if;

            -- *** Input slower than output can handle ***
            if run("Throttled") then
                fix_stimuli_play_file (net, Stimuli_c, InFile_c,
                                       mode              => stimuli_mode_tdm,
                                       tdm_slots         => Channels_g,
                                       stall_probability => 1.0,
                                       stall_max_cycles  => Ratio_g+3,
                                       stall_min_cycles  => Ratio_g+3);
                checkAll(net);
            end if;

            -- *** Random gaps on the input ***
            if run("RandomStall") then
                fix_stimuli_play_file (net, Stimuli_c, InFile_c,
                                       mode              => stimuli_mode_tdm,
                                       tdm_slots         => Channels_g,
                                       stall_probability => 0.3,
                                       stall_max_cycles  => 2*Ratio_g,
                                       stall_min_cycles  => 1);
                checkAll(net);
            end if;

            -- *** Test different ratio ***
            -- This only can be tested for runtime configurable ratio (for Ratio_g=1 R-1 does not apply)
            if run("RatioChange") then
                if FixedRatio_g = false and Ratio_g > 1 then
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    applyConfig(Ratio_g-1, Cfg_Ratio, Cfg_Shift, Cfg_GainCorr);
                    wait for 1 us;
                    wait until rising_edge(Clk);
                    Rst <= '0';
                    wait until rising_edge(Clk);

                    fix_stimuli_play_file (net, Stimuli_c, InFile_c,
                                           mode      => stimuli_mode_tdm,
                                           tdm_slots => Channels_g);
                    checkAll(net, rminus1 => true);
                end if;
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(Stimuli_c));

            for ch in 0 to Channels_g - 1 loop
                wait_until_idle(net, as_sync(Checker_c(ch)));
            end loop;

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
    i_dut : entity olo.olo_fix_cic_intp_tdm_par
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
            In_Ready     => In_Ready,
            In_Data      => In_Data,
            In_Last      => In_Last,
            Out_Valid    => Out_Valid,
            Out_Data     => Out_Data
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
            Ready    => In_Ready,
            Valid    => In_Valid,
            Last     => In_Last,
            Data     => In_Data
        );

    g_checker : for i in 0 to Channels_g - 1 generate

        vc_checker : entity work.olo_test_fix_checker_vc
            generic map (
                Instance => Checker_c(i),
                Fmt      => cl_fix_format_from_string(OutFmt_g)
            )
            port map (
                Clk      => Clk,
                Ready    => CheckerRdy(i),
                Valid    => Out_Valid,
                Data     => Out_Data(OutWidth_c*(i+1) - 1 downto OutWidth_c*i)
            );

    end generate;

end architecture;
