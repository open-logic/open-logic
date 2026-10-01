---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Rene Brglez
-- Authors: Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_arb_wrr_tb is
    generic (
        runner_cfg    : string;
        RandomStall_g : boolean              := false;
        Latency_g     : natural range 0 to 1 := 0
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_wrr_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant GrantWidth_c  : positive := 5;
    constant WeightWidth_c : positive := 4;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- *** Verification Components ***
    -- Slave VC
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length => GrantWidth_c,
            stall_config => new_stall_config(0.0, 0, 0)
        );

    -- Master VC
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
            data_length  => GrantWidth_c,
            stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 5, 10)
        );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                   := '0';
    signal Rst       : std_logic                                   := '1';
    signal Weights   : std_logic_vector(WeightWidth_c * GrantWidth_c - 1 downto 0);
    signal In_Valid  : std_logic;
    signal In_Req    : std_logic_vector(GrantWidth_c - 1 downto 0);
    signal Out_Valid : std_logic                                   := '0';
    signal Out_Grant : std_logic_vector(GrantWidth_c - 1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- *** Procedures  and Functions ***

    -- Writes Weights and Request to DUT and compares received Grant with the ExpectedGrant
    procedure testSample (
        signal net    : inout network_t;
        Request       : in    std_logic_vector;
        ExpectedGrant : in    std_logic_vector;
        Check         : in    boolean := true;
        Msg           : in    string  := "") is
    begin
        push_axi_stream(net, AxisMaster_c, Request);

        -- Option to disable AXI stream checking, useful for development and debugging
        if Check then
            check_axi_stream(net, AxisSlave_c, ExpectedGrant, blocking => false, msg => Msg);
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_wrr
        generic map (
            GrantWidth_g  => GrantWidth_c,
            WeightWidth_g => WeightWidth_c,
            Latency_g     => Latency_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            Weights    => Weights,
            In_Valid   => In_Valid,
            In_Req     => In_Req,
            Out_Valid  => Out_Valid,
            Out_Grant  => Out_Grant
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            Aclk   => Clk,
            Tvalid => In_Valid,
            Tdata  => In_Req
        );

    vc_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TData  => Out_Grant
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable WeightsArray_v : StlvArray_t(GrantWidth_c - 1 downto 0)(WeightWidth_c - 1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            Rst <= '1';
            wait for Clk_Period_c * 5;
            Rst <= '0';

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RoundRobinWeights") then

                WeightsArray_v := (others => x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                for i in 0 to 2 - 1 loop
                    testSample(net, "11111", "10000");
                    testSample(net, "11111", "01000");
                    testSample(net, "11111", "00100");
                    testSample(net, "11111", "00010");
                    testSample(net, "11111", "00001");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_ZeroWeights") then

                WeightsArray_v := (others => x"0");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "11111", "00000");
                testSample(net, "11111", "00000");
                testSample(net, "11111", "00000");
                testSample(net, "11111", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RandomNonZeroWeights") then

                WeightsArray_v := (x"4",
                                   x"1",
                                   x"1",
                                   x"4",
                                   x"3");
                Weights        <= flattenStlvArray(WeightsArray_v);

                for i in 0 to 2 - 1 loop
                    testSample(net, "11111", "10000", Msg => "0");
                    testSample(net, "11111", "10000", Msg => "1");
                    testSample(net, "11111", "10000", Msg => "2");
                    testSample(net, "11111", "10000", Msg => "3");

                    testSample(net, "11111", "01000", Msg => "4");

                    testSample(net, "11111", "00100", Msg => "5");

                    testSample(net, "11111", "00010", Msg => "6");
                    testSample(net, "11111", "00010", Msg => "7");
                    testSample(net, "11111", "00010", Msg => "8");
                    testSample(net, "11111", "00010", Msg => "9");

                    testSample(net, "11111", "00001", Msg => "10");
                    testSample(net, "11111", "00001", Msg => "11");
                    testSample(net, "11111", "00001", Msg => "12");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllHighReq_RandomWeights") then

                WeightsArray_v := (x"1",
                                   x"0",
                                   x"2",
                                   x"3",
                                   x"0");
                Weights        <= flattenStlvArray(WeightsArray_v);

                for i in 0 to 2 - 1 loop
                    testSample(net, "11111", "10000", Msg => "0");

                    testSample(net, "11111", "00100", Msg => "1");
                    testSample(net, "11111", "00100", Msg => "2");

                    testSample(net, "11111", "00010", Msg => "3");
                    testSample(net, "11111", "00010", Msg => "4");
                    testSample(net, "11111", "00010", Msg => "5");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_AllLowReq_RandomNonZeroWeights") then

                WeightsArray_v := (x"1",
                                   x"4",
                                   x"3",
                                   x"4",
                                   x"4");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "00000", "00000");
                testSample(net, "00000", "00000");
                testSample(net, "00000", "00000");
                testSample(net, "00000", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_RandomNonZeroReq_RandomNonZeroWeights") then

                WeightsArray_v := (x"3",
                                   x"3",
                                   x"1",
                                   x"4",
                                   x"3");
                Weights        <= flattenStlvArray(WeightsArray_v);

                for i in 0 to 2 - 1 loop
                    testSample(net, "10010", "10000");
                    testSample(net, "10010", "10000");
                    testSample(net, "10010", "10000");

                    testSample(net, "10010", "00010");
                    testSample(net, "10010", "00010");
                    testSample(net, "10010", "00010");
                    testSample(net, "10010", "00010");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Static_RandomReq_RandomWeights") then

                WeightsArray_v := (x"3",
                                   x"4",
                                   x"3",
                                   x"0",
                                   x"2");
                Weights        <= flattenStlvArray(WeightsArray_v);

                for i in 0 to 2 - 1 loop
                    testSample(net, "11011", "10000");
                    testSample(net, "11011", "10000");
                    testSample(net, "11011", "10000");

                    testSample(net, "11011", "01000");
                    testSample(net, "11011", "01000");
                    testSample(net, "11011", "01000");
                    testSample(net, "11011", "01000");

                    testSample(net, "11011", "00001");
                    testSample(net, "11011", "00001");
                end loop;

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("SemiStatic_RandomNonZeroReq_RandomNonZeroWeights") then

                -- First "Complete Grant Cycle"
                WeightsArray_v := (x"1",
                                   x"4",
                                   x"3",
                                   x"3",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "10111", "10000");

                testSample(net, "10111", "00100");
                testSample(net, "10111", "00100");
                testSample(net, "10111", "00100");

                testSample(net, "10111", "00010");
                testSample(net, "10111", "00010");
                testSample(net, "10111", "00010");

                testSample(net, "10111", "00001");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                -- Second "Complete Grant Cycle"
                WeightsArray_v := (x"4",
                                   x"3",
                                   x"1",
                                   x"4",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "11100", "10000");
                testSample(net, "11100", "10000");
                testSample(net, "11100", "10000");
                testSample(net, "11100", "10000");

                testSample(net, "11100", "01000");
                testSample(net, "11100", "01000");
                testSample(net, "11100", "01000");

                testSample(net, "11100", "00100");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                -- Third "Complete Grant Cycle"
                WeightsArray_v := (x"4",
                                   x"1",
                                   x"3",
                                   x"2",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "01100", "01000");

                testSample(net, "01100", "00100");
                testSample(net, "01100", "00100");
                testSample(net, "01100", "00100");
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("SemiStatic_RandomReq_RandomWeights") then

                -- First "Complete Grant Cycle"
                WeightsArray_v := (x"0",
                                   x"2",
                                   x"1",
                                   x"4",
                                   x"3");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "11001", "01000");
                testSample(net, "11001", "01000");

                testSample(net, "11001", "00001");
                testSample(net, "11001", "00001");
                testSample(net, "11001", "00001");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                -- Second "Complete Grant Cycle"
                WeightsArray_v := (x"2",
                                   x"3",
                                   x"0",
                                   x"3",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "00100", "00000");
                testSample(net, "00100", "00000");
                testSample(net, "00100", "00000");
                testSample(net, "00100", "00000");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                -- Third "Complete Grant Cycle"
                WeightsArray_v := (x"0",
                                   x"0",
                                   x"0",
                                   x"0",
                                   x"0");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "01101", "00000");
                testSample(net, "01101", "00000");
                testSample(net, "01101", "00000");
                testSample(net, "01101", "00000");
                testSample(net, "01101", "00000");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Dynamic_RandomReq_RandomNonZeroWeights") then

                WeightsArray_v := (x"2",
                                   x"1",
                                   x"3",
                                   x"2",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "10101", "10000", Msg => "0");
                testSample(net, "00010", "00010", Msg => "1");
                testSample(net, "01100", "01000", Msg => "2");
                testSample(net, "11011", "00010", Msg => "3");
                testSample(net, "00010", "00010", Msg => "4");
                testSample(net, "11101", "00001", Msg => "5");
                testSample(net, "01011", "01000", Msg => "6");
                testSample(net, "10000", "10000", Msg => "7");
                testSample(net, "00101", "00100", Msg => "8");
                testSample(net, "01111", "00100", Msg => "9");
                testSample(net, "10110", "00100", Msg => "10");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                WeightsArray_v := (x"1",
                                   x"3",
                                   x"3",
                                   x"4",
                                   x"3");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "11010", "00010", Msg => "11");
                testSample(net, "00111", "00010", Msg => "12");
                testSample(net, "10100", "10000", Msg => "13");
                testSample(net, "01101", "01000", Msg => "14");
                testSample(net, "00011", "00010", Msg => "15");
                testSample(net, "11100", "10000", Msg => "16");
                testSample(net, "01010", "01000", Msg => "17");
                testSample(net, "10011", "00010", Msg => "18");
                testSample(net, "00100", "00100", Msg => "19");
                testSample(net, "11001", "00001", Msg => "20");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                WeightsArray_v := (x"1",
                                   x"1",
                                   x"4",
                                   x"1",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "00101", "00001", Msg => "21"); -- "00100" or "00001", both OK
                testSample(net, "11000", "10000", Msg => "22");
                testSample(net, "11110", "01000", Msg => "23");
                testSample(net, "00110", "00100", Msg => "24");
                testSample(net, "10011", "00010", Msg => "25");
                testSample(net, "01010", "01000", Msg => "26");
                testSample(net, "11111", "00100", Msg => "27");
                testSample(net, "00001", "00001", Msg => "28");
                testSample(net, "10010", "10000", Msg => "29");
                testSample(net, "01101", "01000", Msg => "30");
                testSample(net, "01111", "00100", Msg => "31");
                testSample(net, "11011", "00010", Msg => "32");
                testSample(net, "01001", "00001", Msg => "33");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                WeightsArray_v := (x"3",
                                   x"1",
                                   x"2",
                                   x"3",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "10100", "10000", Msg => "34");
                testSample(net, "01001", "01000", Msg => "35");
                testSample(net, "11100", "00100", Msg => "36");
                testSample(net, "00011", "00010", Msg => "37");
                testSample(net, "00100", "00100", Msg => "38");
                testSample(net, "11010", "00010", Msg => "39");
                testSample(net, "01110", "00010", Msg => "40");
                testSample(net, "10001", "00001", Msg => "41");
                testSample(net, "00111", "00100", Msg => "42");
                testSample(net, "01000", "01000", Msg => "43");
                testSample(net, "11111", "00100", Msg => "44");
                testSample(net, "10101", "00100", Msg => "45");
                testSample(net, "00100", "00100", Msg => "46");
                testSample(net, "10010", "00010", Msg => "47");
                testSample(net, "11001", "00001", Msg => "48");
                testSample(net, "01101", "01000", Msg => "49");
                testSample(net, "10111", "00100", Msg => "50");
                testSample(net, "00110", "00100", Msg => "51");
                testSample(net, "10110", "00010", Msg => "52");
                testSample(net, "01011", "00010", Msg => "53");
                testSample(net, "11111", "00010", Msg => "54");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                WeightsArray_v := (x"2",
                                   x"4",
                                   x"1",
                                   x"3",
                                   x"2");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "00000", "00000", Msg => "55");
                testSample(net, "00110", "00100", Msg => "56");
                testSample(net, "00000", "00000", Msg => "57");
                testSample(net, "01101", "00001", Msg => "58");
                testSample(net, "11100", "10000", Msg => "59");
                testSample(net, "01010", "01000", Msg => "60");
                testSample(net, "11101", "01000", Msg => "61");
                testSample(net, "11011", "01000", Msg => "62");
                testSample(net, "11001", "01000", Msg => "63");
                testSample(net, "01100", "00100", Msg => "64");
                testSample(net, "00011", "00010", Msg => "65");
                testSample(net, "10101", "00001", Msg => "66");
                testSample(net, "11010", "10000", Msg => "67");
                testSample(net, "00110", "00100", Msg => "68");
                testSample(net, "11111", "00010", Msg => "69");
                testSample(net, "10000", "10000", Msg => "70");
                testSample(net, "01001", "01000", Msg => "71");
                testSample(net, "00000", "00000", Msg => "72");
                testSample(net, "11101", "00100", Msg => "73");
                testSample(net, "00000", "00000", Msg => "74");
                testSample(net, "00000", "00000", Msg => "75");
                testSample(net, "01010", "00010", Msg => "76");

            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("ExampleFromDoc_Static") then

                WeightsArray_v := (x"1",
                                   x"3",
                                   x"2",
                                   x"0",
                                   x"1");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "10111", "10000", Msg => "0");
                testSample(net, "10111", "00100", Msg => "1");
                testSample(net, "10111", "00100", Msg => "2");
                testSample(net, "10111", "00001", Msg => "3");

            end if;

            wait_until_idle(net, as_sync(AxisSlave_c));
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait for Clk_Period_c*10;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("ExampleFromDoc_RequestsChange") then

                WeightsArray_v := (x"0",
                                   x"0",
                                   x"0",
                                   x"3",
                                   x"2");
                Weights        <= flattenStlvArray(WeightsArray_v);

                testSample(net, "00011", "00010", Msg => "0");
                testSample(net, "00011", "00010", Msg => "1");
                testSample(net, "00001", "00001", Msg => "2");
                testSample(net, "00001", "00001", Msg => "3");

            end if;

            wait_until_idle(net, as_sync(AxisSlave_c));
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait for Clk_Period_c*10;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
