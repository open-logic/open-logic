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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_latency_comp_lolevel_tb is
    generic (
        runner_cfg       : string;
        Mode_g           : string                            := "FIXED_BEATS";
        Latency_g        : positive range 2 to positive'high := 4
    );
end entity;

architecture sim of olo_base_latency_comp_lolevel_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c          : integer := 16;
    constant AssertsName_c    : string  := "Inst-Name";
    constant AssertsDisable_c : boolean := false;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => Width_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic := '0';
    signal In_Data      : std_logic_vector(Width_c-1 downto 0);
    signal In_Valid     : std_logic := '0';
    signal In_Ready     : std_logic := '0';
    signal Out_Data     : std_logic_vector(Width_c-1 downto 0);
    signal Out_Valid    : std_logic := '0';
    signal Out_Ready    : std_logic := '0';
    signal Err_Overrun  : std_logic;
    signal Err_Underrun : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v : std_logic_vector(Width_c-1 downto 0);
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

            -- Initial Handshake Signals
            Out_Ready <= '1';
            In_Ready  <= '1';
            Out_Valid <= '0';

            -- Error Cases
            if run("ReadSampleTwice") then
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    -- Wait for latency and consume sample once
                    wait until rising_edge(Clk) and In_Valid = '1';

                    for i in 1 to Latency_g loop
                        wait until rising_edge(Clk);
                    end loop;

                    Out_Valid <= '1';
                    check_equal(Out_Data, Data_v, "Data Mismatch");
                    wait until rising_edge(Clk);
                    Out_Ready <= '0';
                    Out_Valid <= '0';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    -- Consume sample second time --> should trigger underrun
                    info("-- Expected Underrun START --");
                    wait until rising_edge(Clk);
                    Out_Valid <= '1';
                    Out_Ready <= '1';
                    wait until rising_edge(Clk);
                    Out_Valid <= '0';
                    Out_Ready <= '0';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '1', "Underrun Error Detected");
                    info("-- Expected Underrun END --");
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            if run("ReadWithoutData") then
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    -- Directly consume sample without input --> should trigger underrun
                    info("-- Expected Underrun START --");
                    wait until rising_edge(Clk);
                    Out_Valid <= '1';
                    wait until rising_edge(Clk);
                    Out_Valid <= '0';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '1', "Underrun Error Detected");
                    info("-- Expected Underrun END --");
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            -- Output Handshaking
            if run("OutputHandshaking-OneSample-Ready") then
                Out_Ready <= '0';
                Out_Valid <= '1';
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    -- Wait for latency and consume sample once - but after it was available
                    wait until rising_edge(Clk) and In_Valid = '1';

                    for i in 1 to 2*Latency_g loop
                        wait until rising_edge(Clk);
                    end loop;

                    Out_Ready <= '1';
                    check_equal(Out_Data, Data_v, "Data Mismatch");
                    wait until rising_edge(Clk);
                    Out_Ready <= '0';
                    Out_Valid <= '0';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            if run("OutputHandshaking-OneSample-Valid") then
                Out_Ready <= '1';
                Out_Valid <= '0';
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    -- Wait for latency and consume sample once - but after it was available
                    wait until rising_edge(Clk) and In_Valid = '1';

                    for i in 1 to 2*Latency_g loop
                        wait until rising_edge(Clk);
                    end loop;

                    Out_Valid <= '1';
                    check_equal(Out_Data, Data_v, "Data Mismatch");
                    wait until rising_edge(Clk);
                    Out_Ready <= '0';
                    Out_Valid <= '0';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            if run("OutputHandshaking-TwoSamples-Ready") then
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    Out_Ready <= '0';
                    Out_Valid <= '1';

                    -- This test only works for latency > 3
                    if Latency_g > 3 then

                        -- Prepare data
                        In_Ready <= '0';
                        push_axi_stream(net, AxisMaster_c, toUslv(5, Width_c));
                        push_axi_stream(net, AxisMaster_c, toUslv(6, Width_c));
                        -- Push in data one cycle apart
                        wait until rising_edge(Clk) and In_Valid = '1';
                        In_Ready <= '1';
                        wait until rising_edge(Clk);
                        In_Ready <= '0';
                        wait until rising_edge(Clk);
                        In_Ready <= '1';

                        -- Wait until sample at output
                        for i in 1 to Latency_g-2 loop
                            wait until rising_edge(Clk);
                        end loop;

                        wait for 1 ns;
                        check_equal(Out_Data, 5, "Data Mismatch 1.1");
                        -- Consume sample late
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Ready <= '1';
                        check_equal(Out_Data, 5, "Data Mismatch 1.2");
                        -- Second sample (not consumed yet
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Ready <= '0';
                        check_equal(Out_Data, 6, "Data Mismatch 2.1");
                        -- Consume sample late
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Ready <= '1';
                        check_equal(Out_Data, 6, "Data Mismatch 2.2");
                        -- End test
                        wait until rising_edge(Clk);
                        Out_Ready <= '0';
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                        check_equal(Err_Overrun, '0', "Overrun Error Detected");
                        check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    end if;
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            if run("OutputHandshaking-TwoSamples-Valid") then
                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" then
                    Out_Ready <= '1';
                    Out_Valid <= '0';

                    -- This test only works for latency > 3
                    if Latency_g > 3 then

                        -- Prepare data
                        In_Ready <= '0';
                        push_axi_stream(net, AxisMaster_c, toUslv(5, Width_c));
                        push_axi_stream(net, AxisMaster_c, toUslv(6, Width_c));
                        -- Push in data one cycle apart
                        wait until rising_edge(Clk) and In_Valid = '1';
                        In_Ready <= '1';
                        wait until rising_edge(Clk);
                        In_Ready <= '0';
                        wait until rising_edge(Clk);
                        In_Ready <= '1';

                        -- Wait until sample at output
                        for i in 1 to Latency_g-2 loop
                            wait until rising_edge(Clk);
                        end loop;

                        wait for 1 ns;
                        check_equal(Out_Data, 5, "Data Mismatch 1.1");
                        -- Consume sample late
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Valid <= '1';
                        check_equal(Out_Data, 5, "Data Mismatch 1.2");
                        -- Second sample (not consumed yet
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Valid <= '0';
                        check_equal(Out_Data, 6, "Data Mismatch 2.1");
                        -- Consume sample late
                        wait until rising_edge(Clk);
                        wait for 1 ns;
                        Out_Valid <= '1';
                        check_equal(Out_Data, 6, "Data Mismatch 2.2");
                        -- End test
                        wait until rising_edge(Clk);
                        Out_Valid <= '0';
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                        check_equal(Err_Overrun, '0', "Overrun Error Detected");
                        check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    end if;
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
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
    i_dut : entity olo.olo_base_latency_comp
        generic map (
            Width_g          => Width_c,
            Mode_g           => Mode_g,
            Latency_g        => Latency_g,
            AssertsDisable_g => AssertsDisable_c,
            AssertsName_g    => AssertsName_c
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            In_Valid     => In_Valid,
            In_Ready     => In_Ready,
            In_Data      => In_Data,
            Out_Valid    => Out_Valid,
            Out_Ready    => Out_Ready,
            Out_Data     => Out_Data,
            Err_Overrun  => Err_Overrun,
            Err_Underrun => Err_Underrun
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data
        );

end architecture;
