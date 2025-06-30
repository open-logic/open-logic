---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Rene Brglez
-- All rights reserved.
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

library OSVVM ;
use OSVVM.RandomBasePkg.all ;
use OSVVM.RandomPkg.all ;

library olo;
use olo.olo_base_pkg_math.all;
use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_arb_wrr_tb is
    generic (
        runner_cfg        : string;
        GrantWidth_g      : positive;
        WeightWidth_g     : positive;
        RandomStall_g     : boolean;
        Seed_g            : positive;
        MaxRandomWeight_g : positive := 8
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_wrr_tb is

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                                   := '0';
    signal Rst        : std_logic                                                   := '0';
    signal In_Weights : std_logic_vector(WeightWidth_g * GrantWidth_g - 1 downto 0) := (others => '0');
    signal In_Req     : std_logic_vector(GrantWidth_g - 1 downto 0)                 := (others => '0');
    signal Out_Ready  : std_logic                                                   := '0';
    signal Out_Valid  : std_logic                                                   := '0';
    signal Out_Grant  : std_logic_vector(GrantWidth_g - 1 downto 0)                 := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real     := 100.0e6;
    constant Clk_Period_c    : time     := (1 sec) / Clk_Frequency_c;
    constant Tpd_c           : time     := Clk_Period_c / 10;
    constant NumCycles       : positive := 4;

    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length  => GrantWidth_g,
            stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 2)
        );

    -----------------------------------------------------------------------------------------------
    -- Procedures
    -----------------------------------------------------------------------------------------------
    -- *** Procedures ***
    procedure checkAxiStreamData (
            signal net   : inout network_t;
            expectedData :       std_logic_vector
        ) is
    begin
        check_axi_stream(
            net,
            AxisSlave_c,
            expectedData,
            blocking => true,
            msg      => "data " & to_string(expectedData)
        );
    end procedure;

    function getWeightAtIdx (
            weightVec   : std_logic_vector;
            weightIdx   : integer;
            WeightWidth : integer := WeightWidth_g
        ) return integer is
    begin
        return fromUslv(weightVec((weightIdx + 1) * WeightWidth - 1 downto weightIdx * WeightWidth));
    end function getWeightAtIdx;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_wrr
        generic map (
            GrantWidth_g  => GrantWidth_g,
            WeightWidth_g => WeightWidth_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Weights => In_Weights,
            In_Req     => In_Req,
            Out_Grant  => Out_Grant,
            Out_Ready  => Out_Ready,
            Out_Valid  => Out_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
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
        variable Rand_v          : RandomPType;
        variable Weight_v        : integer;
        variable WeightStdlv_v   : std_logic_vector(WeightWidth_g - 1 downto 0);
        variable In_Req_v        : std_logic_vector(In_Req'range);
        variable In_Weights_v    : std_logic_vector(In_Weights'range);
        variable ExpectedGrant_v : std_logic_vector(Out_Grant'range);
        variable HighIdx_v       : integer;
        variable LowIdx_v        : integer;

        variable tdata_v : std_logic_vector(Out_Grant'range);
        variable tlast_v : std_logic;

        procedure configureWeights(
                config : string
            ) is
        begin
            --------------------------------------------------------------------
            if (config = "RoundRobinWeights") then
                info("Set Weights to behave as Round Robin arbiter");
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights_v((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) :=
                        toUslv(1, WeightWidth_g);
                end loop;
                In_Weights <= In_Weights_v;

            --------------------------------------------------------------------
            elsif (config = "IncrementingWeights") then
                info("Set Incrementing Weights");
                for i in 0 to GrantWidth_g - 1 loop
                    WeightStdlv_v := toUslv(i + 1, WeightWidth_g);
                    if (unsigned(WeightStdlv_v) = 0) then
                        WeightStdlv_v := toUslv(1, WeightWidth_g);
                    end if;
                    In_Weights_v((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) :=
                        WeightStdlv_v;
                    info("Weight(" & to_string(i) & ") = " & to_string(fromUslv(WeightStdlv_v)));
                end loop;
                In_Weights <= In_Weights_v;

            --------------------------------------------------------------------
            elsif (config = "RandomPositiveWeights") then
                info("Set Random Positive Weights");
                for i in 0 to GrantWidth_g - 1 loop
                    WeightStdlv_v := toUslv(Rand_v.RandInt(1, MaxRandomWeight_g), WeightWidth_g);
                    if (unsigned(WeightStdlv_v) = 0) then
                        WeightStdlv_v := toUslv(1, WeightWidth_g);
                    end if;
                    In_Weights_v((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) :=
                        WeightStdlv_v;
                    info("Weight(" & to_string(i) & ") = " & to_string(fromUslv(WeightStdlv_v)));
                end loop;
                In_Weights <= In_Weights_v;
            end if;
        end procedure;

        procedure testAllBitsRequests is
            variable Check : boolean := True;
        begin
            -- Set All Bits in Request Vector
            In_Req_v := (others => '1');
            In_Req   <= In_Req_v;
            info("In_Req_v = " & to_string(In_Req_v));

            -- Simulate arbitration over two cycles
            for CycleIdx in 0 to 2 - 1 loop
                -- Iterate through all unique one-hot expected grant values
                for GrantIdx in GrantWidth_g - 1 downto 0 loop
                    Weight_v := getWeightAtIdx(In_Weights_v, GrantIdx);

                    ExpectedGrant_v           := (others => '0');
                    ExpectedGrant_v(GrantIdx) := '1';
                    for i in 0 to Weight_v - 1 loop
                        if Check then
                            checkAxiStreamData(net, ExpectedGrant_v);
                        else
                            pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                            info("tdata = " & to_string(tdata_v));
                        end if;
                    end loop;
                end loop;
            end loop;
            -- Wait before moving to the next test
            wait for Clk_Period_c * 5;
        end procedure;

        procedure testSlidigWindowRequests (
                WindowWidth : positive;
                Check       : boolean := True
            ) is
        begin
            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if (WindowWidth = 1) then
                -- Slide the window over the vector of width GrantWidth_g
                for WindowBaseIdx in 0 to GrantWidth_g - WindowWidth loop
                    HighIdx_v := WindowBaseIdx + WindowWidth - 1;
                    LowIdx_v  := WindowBaseIdx;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "1";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "1";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;
                    -- Wait before sliding to the next window
                    wait for Clk_Period_c;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            elsif (WindowWidth = 2) then
                -- Slide the window over the vector of width GrantWidth_g
                for WindowBaseIdx in 0 to GrantWidth_g - WindowWidth loop
                    HighIdx_v := WindowBaseIdx + WindowWidth - 1;
                    LowIdx_v  := WindowBaseIdx;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "11";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "10";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 1);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "01";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;
                    -- Wait before sliding to the next window
                    wait for Clk_Period_c;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            elsif (WindowWidth = 3) then
                -- Slide the window over the vector of width GrantWidth_g
                for WindowBaseIdx in 0 to GrantWidth_g - WindowWidth loop
                    HighIdx_v := WindowBaseIdx + WindowWidth - 1;
                    LowIdx_v  := WindowBaseIdx;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "111";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "100";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 1);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "010";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 2);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "101";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "100";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 2);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;
                    -- Wait before sliding to the next window
                    wait for Clk_Period_c;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            elsif (WindowWidth = 4) then
                -- Slide the window over the vector of width GrantWidth_g
                for WindowBaseIdx in 0 to GrantWidth_g - WindowWidth loop
                    HighIdx_v := WindowBaseIdx + WindowWidth - 1;
                    LowIdx_v  := WindowBaseIdx;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "1111";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "1000";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 1);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0100";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 2);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0010";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 3);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "1101";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "1000";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 1);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0100";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 3);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "1011";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "1000";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 2);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0010";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 3);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;

                    ------------------------------------------------------------
                    -- Set Request Pattern
                    In_Req_v                            := (others => '0');
                    In_Req_v(HighIdx_v downto LowIdx_v) := "1001";
                    In_Req                              <= In_Req_v;
                    info("In_Req_v = " & to_string(In_Req_v));

                    ExpectedGrant_v := (others => '0');
                    -- Simulate arbitration over two cycles
                    for CycleIdx in 0 to 2 - 1 loop
                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 0);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "1000";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                        --------------------------------------------------------
                        Weight_v := getWeightAtIdx(In_Weights_v, HighIdx_v - 3);

                        ExpectedGrant_v(HighIdx_v downto LowIdx_v) := "0001";
                        for i in 0 to Weight_v - 1 loop
                            if Check then
                                checkAxiStreamData(net, ExpectedGrant_v);
                            else
                                pop_axi_stream(net, AxisSlave_c, tdata_v, tlast_v);
                                info("tdata = " & to_string(tdata_v));
                            end if;
                        end loop;
                        --------------------------------------------------------

                    end loop;
                    -- Wait before sliding to the next window
                    wait for Clk_Period_c;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;
            end if;
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);

        -- Initialize the random generator with a fixed seed for reproducible test results
        Rand_v.InitSeed(Seed_g);

        while test_suite loop

            -- Reset
            Rst <= '1';
            wait for Clk_Period_c * 5;
            Rst <= '0';

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("ValidInactive_BecauseRequests") then
                -- Set All Weights high
                In_Weights_v := (others => '1');
                In_Weights   <= In_Weights_v;

                for CycleIdx in 0 to 2 - 1 loop
                    ------------------------------------------------------------
                    -- Set all requests low
                    -- Check if Out_Valid = '0'
                    In_Req_v := (others => '0');
                    In_Req   <= In_Req_v;

                    for i in 0 to 16 - 1 loop
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '0', "Out_Valid high unexpectedly (all requests low)");
                    end loop;

                    ------------------------------------------------------------
                    -- Set all requests high
                    -- Check if Out_Valid = '1'
                    In_Req_v := (others => '1');
                    In_Req   <= In_Req_v;

                    for i in 0 to 16 - 1 loop
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '1', "Out_Valid low unexpectedly (all requests high)");
                    end loop;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("ValidInactive_BecauseWeights") then
                -- Set all Requests high
                In_Req_v := (others => '1');
                In_Req   <= In_Req_v;

                for CycleIdx in 0 to 2 - 1 loop
                    ------------------------------------------------------------
                    -- Set all Weights low
                    -- Check if Out_Valid = '0'
                    In_Weights_v := (others => '0');
                    In_Weights   <= In_Weights_v;

                    for i in 0 to 16 - 1 loop
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '0', "Out_Valid low unexpectedly (all weights low)");
                    end loop;

                    ------------------------------------------------------------
                    -- Set all Weights high
                    -- Check if Out_Valid = '1'
                    In_Weights_v := (others => '1');
                    In_Weights   <= In_Weights_v;

                    for i in 0 to 16 - 1 loop
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '1', "Out_Valid low unexpectedly (all weights high)");
                    end loop;
                end loop;
                -- Wait before moving to the next test
                wait for Clk_Period_c * 5;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RoundRobinWeights_AllBitsRequests") then
                configureWeights("RoundRobinWeights");
                testAllBitsRequests;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_AllBitsRequests") then
                configureWeights("IncrementingWeights");
                testAllBitsRequests;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomPositiveWeights_AllBitsRequests") then
                configureWeights("RandomPositiveWeights");
                testAllBitsRequests;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RoundRobinWeights_OneBitRequests") then
                configureWeights("RoundRobinWeights");
                testSlidigWindowRequests(WindowWidth => 1);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RoundRobinWeights_TwoBitRequests") and GrantWidth_g >= 2 then
                configureWeights("RoundRobinWeights");
                testSlidigWindowRequests(WindowWidth => 2);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RoundRobinWeights_ThreeBitRequests") and GrantWidth_g >= 3 then
                configureWeights("RoundRobinWeights");
                testSlidigWindowRequests(WindowWidth => 3);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RoundRobinWeights_FourBitRequests") and GrantWidth_g >= 4 then
                configureWeights("RoundRobinWeights");
                testSlidigWindowRequests(WindowWidth => 4);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_OneBitRequests") then
                configureWeights("IncrementingWeights");
                testSlidigWindowRequests(WindowWidth => 1);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_TwoBitRequests") and GrantWidth_g >= 2 then
                configureWeights("IncrementingWeights");
                testSlidigWindowRequests(WindowWidth => 2);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_ThreeBitRequests") and GrantWidth_g >= 3 then
                configureWeights("IncrementingWeights");
                testSlidigWindowRequests(WindowWidth => 3);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_FourBitRequests") and GrantWidth_g >= 4 then
                configureWeights("IncrementingWeights");
                testSlidigWindowRequests(WindowWidth => 4);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomPositiveWeights_OneBitRequests") then
                configureWeights("RandomPositiveWeights");
                testSlidigWindowRequests(WindowWidth => 1);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomPositiveWeights_TwoBitRequests") and GrantWidth_g >= 2 then
                configureWeights("RandomPositiveWeights");
                testSlidigWindowRequests(WindowWidth => 2);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomPositiveWeights_ThreeBitRequests") and GrantWidth_g >= 3 then
                configureWeights("RandomPositiveWeights");
                testSlidigWindowRequests(WindowWidth => 3);
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomPositiveWeights_FourBitRequests") and GrantWidth_g >= 4 then
                configureWeights("RandomPositiveWeights");
                testSlidigWindowRequests(WindowWidth => 4);
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
