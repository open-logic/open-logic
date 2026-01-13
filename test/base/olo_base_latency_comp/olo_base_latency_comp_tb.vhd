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
        Mode_g           : string                            := "FIXED_BEATS";
        Latency_g        : positive range 2 to positive'high := 4
    );
end entity;

architecture sim of olo_base_latency_comp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c          : integer := 16;
    constant AssertsName_c    : string := "Inst-Name";
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
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
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

    -- TODO: Test Logs (Underflow/Overflow  )
    -- TODO: Update docs with new range + exact behavior (e.g. FIFO size)

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v : std_logic_vector(Width_c-1 downto 0);
        variable Last_v : std_logic;
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
            In_Ready  <= '1';
            Out_Valid <= '1';

            -- Standard Cases

            if run("Test-Data") then
                if Mode_g = "DYNAMIC" then
                    -- Push Data In
                    for i in 1 to Latency_g loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Consume data
                    for i in 1 to Latency_g loop
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");

                elsif Mode_g = "FIXED_CYCLES" then
                    -- Push 3 samples through
                    for i in 1 to 3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to Latency_g-1 loop
                            wait until rising_edge(Clk);
                        end loop;
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");

                elsif Mode_g = "FIXED_BEATS" then
                    -- Push 3 samples through
                    for i in 1 to Latency_g+3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to 3 loop
                            wait until rising_edge(Clk);
                        end loop;
                        if i >= Latency_g then
                            check_axi_stream(net, AxisSlave_c, toUslv(i-Latency_g+1, Width_c), blocking => false);
                        end if;
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");

                else
                    error("Unknown Mode_g: " & Mode_g);
                end if;
            end if;

            if run("Test-Underflow") then
                if Mode_g = "DYNAMIC" then
                    -- Push Data In
                    for i in 1 to 2 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Consume data
                    for i in 1 to 2 loop
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Underflow
                    info("Expect Underflow START");
                    pop_axi_stream(net, AxisSlave_c, Data_v, Last_v);
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    info("Expect Underflow END");
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                elsif Mode_g = "FIXED_CYCLES" then
                    -- Push 3 samples through
                    for i in 1 to 3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to Latency_g-2 loop
                            wait until rising_edge(Clk);
                        end loop;
                        pop_axi_stream(net, AxisSlave_c, Data_v, Last_v);
                        wait until rising_edge(Clk);
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                elsif Mode_g = "FIXED_BEATS" then
                    -- Push 3 samples through
                    for i in 1 to Latency_g+3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to 3 loop
                            wait until rising_edge(Clk);
                        end loop;
                        if i >= Latency_g then
                            check_axi_stream(net, AxisSlave_c, toUslv(i-Latency_g+1, Width_c), blocking => false);
                            wait until rising_edge(Clk);
                            pop_axi_stream(net, AxisSlave_c, Data_v, Last_v); -- Read the same sample twice procudes underflow
                        end if;
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                else
                    error("Unknown Mode_g: " & Mode_g);
                end if;
            end if;

            if run("Test-Overflow") then
                if Mode_g = "DYNAMIC" then
                    -- Push Data In
                    for i in 1 to Latency_g loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Overflow
                    info("Expect Overflow START");
                    push_axi_stream(net, AxisMaster_c, toUslv(100, Width_c));
                    push_axi_stream(net, AxisMaster_c, toUslv(101, Width_c));
                    push_axi_stream(net, AxisMaster_c, toUslv(102, Width_c));
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    info("Expect Overflow END");
                    -- Consume data
                    for i in 1 to Latency_g loop
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    check_equal(Err_Underrun, '0', "Underflow Error Detected");
                    check_equal(Err_Overrun, '1', "No Overrun Error Detected");

                elsif Mode_g = "FIXED_CYCLES" then
                    -- Push Data In
                    for i in 1 to Latency_g loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        wait until rising_edge(Clk);
                    end loop;
                    -- Overflow
                    info("Expect Overflow START");
                    push_axi_stream(net, AxisMaster_c, toUslv(100, Width_c));
                    wait until rising_edge(Clk);
                    info("Expect Overflow END");
                    -- Consume data
                    for i in 2 to Latency_g loop -- one was lost due to overflow
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                    end loop;
                    wait until rising_edge(Clk);
                    check_equal(Err_Underrun, '0', "Underflow Error Detected");
                    check_equal(Err_Overrun, '1', "No Overrun Error Detected");

                elsif Mode_g = "FIXED_BEATS" then
                    -- Push 3 samples through
                    for i in 1 to Latency_g+3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to 3 loop
                            wait until rising_edge(Clk);
                        end loop;
                        if i >= Latency_g+1 then
                            check_axi_stream(net, AxisSlave_c, toUslv(i-Latency_g+1, Width_c), blocking => false);
                        end if;
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Check no errors
                    check_equal(Err_Underrun, '0', "Underflow Error Detected");
                    check_equal(Err_Overrun, '1', "No Overrun Error Detected");

                else
                    error("Unknown Mode_g: " & Mode_g);
                end if;

            end if;

            -- Test Handshaking
            -- FIXED CYCLES consume late
            -- FIXED SAMPLES consume twice
            -- Test no throughput due to out-valid low
            -- Test no throughput due to in-ready low

            -- Corner Cases
            if run("Test-Underflow-Start") then
                if Mode_g = "DYNAMIC" then
                    -- Underflow
                    info("Expect Underflow START");
                    pop_axi_stream(net, AxisSlave_c, Data_v, Last_v);
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    info("Expect Underflow END");

                    -- Correct Functionality after
                    for i in 1 to 2 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c));
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Consume data
                    for i in 1 to 2 loop
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                elsif Mode_g = "FIXED_CYCLES" then
                    -- Underflow
                    info("Expect Underflow START");
                    pop_axi_stream(net, AxisSlave_c, Data_v, Last_v);
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    info("Expect Underflow END");

                    -- Correct Functionality after
                    for i in 1 to 3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to Latency_g-1 loop
                            wait until rising_edge(Clk);
                        end loop;
                        check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                elsif Mode_g = "FIXED_BEATS" then
                    -- Underflow
                    info("Expect Underflow START");
                    pop_axi_stream(net, AxisSlave_c, Data_v, Last_v);
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    info("Expect Underflow END");

                    -- Correct Functionality after
                    for i in 1 to Latency_g+3 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        for j in 0 to 3 loop
                            wait until rising_edge(Clk);
                        end loop;
                        if i >= Latency_g then
                            check_axi_stream(net, AxisSlave_c, toUslv(i-Latency_g+1, Width_c), blocking => false);
                        end if;
                        wait until rising_edge(Clk);
                        wait until rising_edge(Clk);
                    end loop;
                    check_equal(Err_Underrun, '1', "No Underflow Error Detected");
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");

                else
                    error("Unknown Mode_g: " & Mode_g);
                end if;
            end if;

            if run("Test-Back-to-Back") then

                if Mode_g = "DYNAMIC" or Mode_g = "FIXED_CYCLES" or Mode_g = "FIXED_BEATS" then
                    -- Push in Data without consuming to fill pipeline
                    for i in 0 to Latency_g-1 loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c));
                        wait until rising_edge(Clk);
                    end loop;
                    -- Push and consume in parallel
                    for i in Latency_g to (Latency_g * 2 - 1) loop
                        push_axi_stream(net, AxisMaster_c, toUslv(i, Width_c) );
                        check_axi_stream(net, AxisSlave_c, toUslv(i - Latency_g, Width_c), blocking => false);
                        wait until rising_edge(Clk);
                    end loop;
                    -- Drain remaining data
                    -- By definition in the "FIXED_BEATS" mode this does not apply. TODO: Document
                    if Mode_g /= "FIXED_BEATS" then
                        for i in Latency_g to (Latency_g * 2 - 1) loop
                            check_axi_stream(net, AxisSlave_c, toUslv(i, Width_c), blocking => false);
                            wait until rising_edge(Clk);
                        end loop;
                    end if;
                    -- Check no errors
                    check_equal(Err_Overrun, '0', "Overrun Error Detected");
                    check_equal(Err_Underrun, '0', "Underrun Error Detected");
                else
                    error("Unknown Mode_g: " & Mode_g);
                end if;
            end if;

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
            Width_g         => Width_c,
            Mode_g          => Mode_g,
            Latency_g       => Latency_g,
            AssertsDisable_g=> AssertsDisable_c,
            AssertsName_g   => AssertsName_c
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

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data
        );

end architecture;
