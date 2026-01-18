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
entity olo_base_latency_comp_tb is
    generic (
        runner_cfg       : string;
        Mode_g           : string                            := "DYNAMIC"; -- This TB only valid for "DYNAMIC" and "FIXED_CYCLES"
        Latency_g        : positive range 2 to positive'high := 4
    );
end entity;

architecture sim of olo_base_latency_comp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c          : integer  := 16;
    constant AssertsName_c    : string   := "Inst-Name";
    constant AssertsDisable_c : boolean  := false;
    constant ProcLatency_c    : positive := choose(Mode_g = "DYNAMIC", max(Latency_g/2, 2), Latency_g);

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
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => Width_c*2,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -- TB Signals
    signal ProcOut_Data : std_logic_vector(Width_c-1 downto 0);
    signal TbOutReady   : std_logic := '1';
    signal VcOutReady   : std_logic := '1';

    -- Check Procedure
    procedure expectOutput (
        signal net    : inout network_t;
        expected_data : in std_logic_vector(Width_c-1 downto 0);
        msg           : in string := "NoMsg") is
    begin
        check_axi_stream(net, AxisSlave_c, expected_data & expected_data, blocking => false, msg => msg);
    end procedure;

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
            TbOutReady <= '1';
            In_Ready   <= '1';

            -- Standard Cases
            if run("SingleSample") then
                if Mode_g = "FIXED_CYCLES" or Mode_g = "DYNAMIC" then
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    expectOutput(net, Data_v);
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;

                -- Check error bits
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                check_equal(Err_Overrun, '0', "Overrun Error Detected");
                check_equal(Err_Underrun, '0', "Underrun Error Detected");
            end if;

            if run("MultiSamples-Spaced") then
                if Mode_g = "FIXED_CYCLES" or Mode_g = "DYNAMIC" then

                    for i in 1 to 2*Latency_g loop
                        Data_v := toUslv(i, Width_c);
                        push_axi_stream(net, AxisMaster_c, Data_v);
                        expectOutput(net, Data_v);
                        wait for 2*Clk_Period_c;
                    end loop;

                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;

                -- Check error bits
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                check_equal(Err_Overrun, '0', "Overrun Error Detected");
                check_equal(Err_Underrun, '0', "Underrun Error Detected");
            end if;

            if run("MultiSamples-BackToBack") then
                if Mode_g = "FIXED_CYCLES" or Mode_g = "DYNAMIC" then

                    for i in 1 to 2*Latency_g loop
                        Data_v := toUslv(i, Width_c);
                        push_axi_stream(net, AxisMaster_c, Data_v);
                        expectOutput(net, Data_v);
                    end loop;

                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;

                -- Check error bits
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                check_equal(Err_Overrun, '0', "Overrun Error Detected");
                check_equal(Err_Underrun, '0', "Underrun Error Detected");
            end if;

            -- Backpressure Handling
            if run("Backpressure-Input") then
                if Mode_g = "FIXED_CYCLES" or Mode_g = "DYNAMIC" then
                    In_Ready <= '0';

                    -- Setup samples
                    for i in 1 to 2*Latency_g loop
                        Data_v := toUslv(i, Width_c);
                        push_axi_stream(net, AxisMaster_c, Data_v);
                        expectOutput(net, Data_v);
                    end loop;

                    -- Execute with input backpressure
                    for i in 1 to 2*Latency_g loop
                        wait until rising_edge(Clk);
                        In_Ready <= '1';
                        wait for 5*Clk_Period_c;
                        wait until rising_edge(Clk);
                        In_Ready <= '0';
                    end loop;

                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;

                -- Check error bits
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                check_equal(Err_Overrun, '0', "Overrun Error Detected");
                check_equal(Err_Underrun, '0', "Underrun Error Detected");
            end if;

            -- Special Cases
            if run("OutputNotRead") then
                if Mode_g = "FIXED_CYCLES" then
                    TbOutReady <= '0';
                    -- First sample is retained in the latency compensation, this is OK
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    wait for 2*Latency_g*Clk_Period_c;
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    -- When a second sample arrives, an overrun is detected
                    info("-- Expected Overrun START --");
                    Data_v := toUslv(1, Width_c);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    wait for 2*Latency_g*Clk_Period_c;
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '1', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    info("-- Expected Overrun END --");
                elsif Mode_g = "DYNAMIC" then
                    TbOutReady <= '0';

                    -- Fill up to latency is tolerated
                    for i in 1 to Latency_g loop
                        Data_v := toUslv(i, Width_c);
                        push_axi_stream(net, AxisMaster_c, Data_v);
                    end loop;

                    wait for 2*Latency_g*Clk_Period_c;
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    -- After that an overrun is detected
                    Data_v := toUslv(100, Width_c);
                    -- Due to internal implementation some more samples can be tolerated
                    info("-- Expected Overrun START --");
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    wait for 2*Latency_g*Clk_Period_c;
                    wait until rising_edge(Clk);
                    check_equal(Err_Overrun, '1', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                    info("-- Expected Overrun END --");
                else
                    error("TB only valid for FIXED_CYCLES and DYNAMIC modes");
                end if;
            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));
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
    Out_Ready <= TbOutReady and VcOutReady;

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
    -- Dummy of processing block
    b_proc : block is
        signal ProcIn_Valid : std_logic;
        signal ProcIn_Data  : std_logic_vector(Width_c downto 0);
        signal Proc_Data    : std_logic_vector(Width_c downto 0);
    begin
        ProcIn_Valid <= '1';
        ProcIn_Data  <= In_Valid and In_Ready & In_Data;

        i_proc : entity olo.olo_base_delay
            generic map (
                Width_g         => Width_c+1,
                Delay_g         => ProcLatency_c,
                RstState_g      => true
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => ProcIn_Valid,
                In_Data     => ProcIn_Data,
                Out_Data    => Proc_Data
            );

        Out_Valid    <= Proc_Data(Width_c);
        ProcOut_Data <= Proc_Data(Width_c-1 downto 0);
    end block;

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

    b_resp : block is
        signal Data  : std_logic_vector(Width_c*2-1 downto 0);
        signal Valid : std_logic;
    begin
        Data  <= ProcOut_Data & Out_Data;
        Valid <= Out_Valid and TbOutReady;

        vc_response_dut : entity vunit_lib.axi_stream_slave
            generic map (
                Slave => AxisSlave_c
            )
            port map (
                AClk   => Clk,
                TValid => Valid,
                TReady => VcOutReady,
                TData  => Data
            );

    end block;

end architecture;
