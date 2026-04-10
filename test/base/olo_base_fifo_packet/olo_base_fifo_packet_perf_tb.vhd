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
        use vunit_lib.signal_checker_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_packet_perf_tb is
    generic(
        MaxPackets_g                    : integer := 8;
        Depth_g                         : integer := 32;
        -- Maximum throughput is only possible when MaxPacketSize = Depth / 2
        MaxPacketSize_g                 : integer := Depth_g / 2;
        runner_cfg                      : string
    );
end entity;

architecture sim of olo_base_fifo_packet_perf_tb is

    -----------------------------------------------------------------------------------------------
    -- Functions
    -----------------------------------------------------------------------------------------------

    -- Function that accepts the whole AXI4-Stream beat in one argument.
    procedure push_axi_stream(
        signal net                      : inout network_t;
        axi_stream                      : axi_stream_master_t;
        variable axi_beat               : in axi_stream_transaction_t
    ) is
    begin
        push_axi_stream(net, axi_stream, axi_beat.tdata, choose(axi_beat.tlast, '1', '0'), axi_beat.tkeep,
            axi_beat.tstrb, axi_beat.tid, axi_beat.tdest, axi_beat.tuser);
    end procedure push_axi_stream;

    -- Function that accepts the whole AXI4-Stream beat in one argument.
    procedure check_axi_stream(
        signal net                      : inout network_t;
        axi_stream                      : axi_stream_slave_t;
        variable exp_axi_beat           : in axi_stream_transaction_t;
        msg                             : string           := "";
        blocking                        : boolean          := true
    ) is
    begin
        check_axi_stream(net, axi_stream, exp_axi_beat.tdata, choose(exp_axi_beat.tlast, '1', '0'),
            exp_axi_beat.tkeep, exp_axi_beat.tstrb, exp_axi_beat.tid, exp_axi_beat.tdest,
            exp_axi_beat.tuser, msg, blocking);
    end procedure check_axi_stream;

    function choose(s : boolean; t : integer_vector; f : integer_vector) return integer_vector is
    begin
        if s then
            return t;
        else
            return f;
        end if;
    end function choose;

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------

    constant Width_c                    : integer := 16;
    constant FeatureSet_c               : string  := "FULL";

    constant ClockFrequency_c           : real := 100.0e6;
    constant ClockPeriod_c              : time := (1 sec) / ClockFrequency_c;

    -- Testbench logger and checker handle constructors.
    constant Logger_c                   : logger_t  := get_logger("tb");
    constant Checker_c                  : checker_t := new_checker(get_name(Logger_c));

    -- AXI4-Stream Models general settings.
    constant StallPercentageMaster_c    : natural range 0 to 100 := 0;
    constant StallPercentageSlave_c     : natural range 0 to 100 := 0;
    constant MinStallCycles_c           : natural   := 1;
    constant MaxStallCycles_c           : natural   := 4;

    constant MasterStallConfig_c        : stall_config_t := new_stall_config(
        stall_probability               => real(StallPercentageMaster_c) / 100.0,
        min_stall_cycles                => MinStallCycles_c,
        max_stall_cycles                => MaxStallCycles_c);

    constant SlaveStallConfig_c         : stall_config_t := new_stall_config(
        stall_probability               => real(StallPercentageSlave_c) / 100.0,
        min_stall_cycles                => MinStallCycles_c,
        max_stall_cycles                => MaxStallCycles_c);

    -- Generation of AXI4-Stream models handles.
    constant AxisMaster_c               : axi_stream_master_t := new_axi_stream_master(
        data_length                     => Width_c,
        id_length                       => 1,
        dest_length                     => 1,
        user_length                     => 1,
        stall_config                    => MasterStallConfig_c,
        logger                          => get_logger("tb:axis_master"));

    constant AxisSlave_c                : axi_stream_slave_t := new_axi_stream_slave(
        data_length                     => Width_c,
        id_length                       => 1,
        dest_length                     => 1,
        user_length                     => 1,
        stall_config                    => SlaveStallConfig_c,
        logger                          => get_logger("tb:axis_slave"));

    -- Input TREADY Signal Checker VC handle.
    constant TReady_Checker_c           : signal_checker_t := new_signal_checker(
        logger                          => get_logger("tb:tready_checker"));

    -- Test throughput specific constants

    -- The legacy implementation (MaxPacketSize_g = -1) will never achieve full-throughput due to
    -- the reasons explained in https://github.com/open-logic/open-logic/issues/284. Therefore,
    -- for this test to pass in "legacy" mode the packet size in beats is at maximum Depth_g/2.
    constant LegacyTest_PacketSizeInBeats_c : integer_vector := (2, Depth_g/4, Depth_g/2);

    -- In the extended implementation (MaxPacketSize_g > 0), the full-throughput is only achieved
    -- when the maximum packet size is half of the depth, allowing half of the FIFO to be written
    -- while the other half is being read at the same time.
    constant ExtendedTest_PacketSizeInBeats_c : integer_vector := (2, MaxPacketSize_g/2, MaxPacketSize_g);

    constant PacketSizeInBeats_c        : integer_vector := choose(MaxPacketSize_g = -1, LegacyTest_PacketSizeInBeats_c, ExtendedTest_PacketSizeInBeats_c);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk                          : std_logic := '0';
    signal Rst                          : std_logic;
    signal In_Valid                     : std_logic := '0';
    signal In_Ready                     : std_logic;
    signal In_Data                      : std_logic_vector(Width_c-1 downto 0);
    signal In_Last                      : std_logic := '0';
    signal In_Drop                      : std_logic := '0';
    signal In_IsDropped                 : std_logic;
    signal PacketLevel                  : std_logic_vector(log2ceil(MaxPackets_g+1)-1 downto 0);
    signal FreeWords                    : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0);
    signal Out_Valid                    : std_logic;
    signal Out_Ready                    : std_logic := '0';
    signal Out_Data                     : std_logic_vector(Width_c-1 downto 0);
    signal Out_Size                     : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0);
    signal Out_Last                     : std_logic;
    signal Out_Next                     : std_logic := '0';
    signal Out_Repeat                   : std_logic := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- General
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 20 ms);

    -- Setup logging
    set_format(display_handler, verbose, true, ns);
    show(Logger_c, display_handler, trace);

    -----------------------------------------------------------------------------------------------
    -- Test process
    -----------------------------------------------------------------------------------------------

    p_control : process is

        subtype axis_transaction_t is axi_stream_transaction_t(
            TData(Width_c-1 downto 0),
            TKeep(Width_c/8-1 downto 0),
            TStrb(Width_c/8-1 downto 0),
            TId(0 downto 0),
            TDest(0 downto 0),
            TUser(0 downto 0));
        constant axis_transaction_init_c : axis_transaction_t := (
            TData                       => (others => '0'),
            Tlast                       => false,
            TKeep                       => (others => '1'),
            TStrb                       => (others => '1'),
            TId                         => (others => '0'),
            TDest                       => (others => '0'),
            TUser                       => (others => '0')
        );

        variable AxisBeat_v             : axis_transaction_t;
        variable ExpAxisBeat_v          : axis_transaction_t := axis_transaction_init_c;

    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            expect(net, TReady_Checker_c, "0", now + 5 ns, 0 ns);
            Rst <= '1';
            wait for 100 ns;
            wait until rising_edge(Clk);
            Rst <= '0';

            ---------------------------------------------------------------------------------------
            if run("test_throughput") then
            ---------------------------------------------------------------------------------------
                -- A previous version of the Packet FIFO from Open-Logic required the FIFO depth or
                -- size to be equal to the maximum allowed packet size in order to automatically drop
                -- packets above the maximum size. This creates a bottleneck in the throughput because
                -- when a packet with the maximum size is received by the Packet FIFO, the Packet FIFO
                -- will de-assert the input TREADY until the packet is consumed on the output interface
                -- since the FIFO is full at that moment. This is explained in more detail in:
                -- https://github.com/open-logic/open-logic/issues/284
                -- This test case shall detect when the throughput is not 100% when the packet size is
                -- equal to the maximum packet size. The idea is that when the Open-Logic Packet FIFO
                -- gets fixed, this test case shall then pass. It can also be used for future regressions.

                AxisBeat_v.TData := (others => '0');
                AxisBeat_v.TLast := false;
                AxisBeat_v.TKeep := (others => '1');

                -- Monitor input TREADY to ensure the Packet FIFO does not apply back-pressure, i.e.,
                -- a throughput of 100% can be achieved. Expect TREADY to be asserted once, then the
                -- signal checker will report an error in case TREADY is de-asserted unexpectedly.
                expect(net, TReady_Checker_c, "1", now, 0 ns);

                for packet in PacketSizeInBeats_c'range loop
                    -- Send 8 times each packet size.
                    for repeat in 0 to 7 loop
                        trace(Logger_c, "Pushing packet " & to_string(packet) & "." & to_string(repeat) & " with " & to_string(PacketSizeInBeats_c(packet)) & " beats");
                        for beat in 0 to PacketSizeInBeats_c(packet)-1 loop
                            AxisBeat_v.TLast := true when beat = PacketSizeInBeats_c(packet)-1 else false;
                            push_axi_stream(net, AxisMaster_c, AxisBeat_v);
                            AxisBeat_v.TData := std_logic_vector(unsigned(AxisBeat_v.TData) + 1);
                        end loop;
                    end loop;
                end loop;

                ExpAxisBeat_v.TData := (others => '0');
                ExpAxisBeat_v.TLast := false;
                ExpAxisBeat_v.TKeep := (others => '1');
                ExpAxisBeat_v.TStrb := (others => '1');

                for packet in PacketSizeInBeats_c'range loop
                    -- Send 8 times each packet size.
                    for repeat in 0 to 7 loop
                        trace(Logger_c, "Popping packet " & to_string(packet) & "." & to_string(repeat) & " with " & to_string(PacketSizeInBeats_c(packet)) & " beats");
                        for beat in 0 to PacketSizeInBeats_c(packet)-1 loop
                            ExpAxisBeat_v.TLast := true when beat = PacketSizeInBeats_c(packet)-1 else false;
                            check_axi_stream(net, AxisSlave_c, ExpAxisBeat_v);
                            ExpAxisBeat_v.TData := std_logic_vector(unsigned(ExpAxisBeat_v.TData) + 1);
                            -- The Out_Size port shall be monitored while popping data from the AXI4-Stream interface.
                            check_equal(Checker_c, to_integer(unsigned(Out_Size)), PacketSizeInBeats_c(packet), "Packet " & to_string(packet) & " has wrong size.");
                        end loop;
                    end loop;
                end loop;

            end if;

        end loop;
        wait for 100 ns;
        test_runner_cleanup(runner);    -- Simulation ends here
    end process;
    -----------------------------------------------------------------------------------------------
    -- Clock generation
    -----------------------------------------------------------------------------------------------

    Clk <= not Clk after ClockPeriod_c / 2;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------

    i_dut : entity olo.olo_base_fifo_packet
    generic map(
        Width_g                         => Width_c,
        Depth_g                         => Depth_g,
        MaxPacketSize_g                 => MaxPacketSize_g,
        FeatureSet_g                    => FeatureSet_c,
        RamStyle_g                      => "auto",
        RamBehavior_g                   => "RBW",
        SmallRamStyle_g                 => "same",
        SmallRamBehavior_g              => "same",
        MaxPackets_g                    => MaxPackets_g
    )
    port map(
        Clk                             => Clk,
        Rst                             => Rst,
        In_Valid                        => In_Valid,
        In_Ready                        => In_Ready,
        In_Data                         => In_Data,
        In_Last                         => In_Last,
        In_Drop                         => In_Drop,
        In_IsDropped                    => In_IsDropped,
        Out_Valid                       => Out_Valid,
        Out_Ready                       => Out_Ready,
        Out_Data                        => Out_Data,
        Out_Size                        => Out_Size,
        Out_Last                        => Out_Last,
        Out_Next                        => Out_Next,
        Out_Repeat                      => Out_Repeat,
        PacketLevel                     => PacketLevel,
        FreeWords                       => FreeWords
    );

    -----------------------------------------------------------------------------------------------
    -- AXI4-Stream Slave Model
    -----------------------------------------------------------------------------------------------

    vc_stimuli : entity vunit_lib.axi_stream_master
    generic map(
        Master                          => AxisMaster_c
    )
    port map(
        Aclk                            => Clk,
        TValid                          => In_Valid,
        TReady                          => In_Ready,
        TData                           => In_Data,
        TLast                           => In_Last
    );

    -----------------------------------------------------------------------------------------------
    -- AXI4-Stream Slave Model
    -----------------------------------------------------------------------------------------------

    vc_response : entity vunit_lib.axi_stream_slave
    generic map(
        slave                           => AxisSlave_c
    )
    port map(
        aclk                            => Clk,
        tvalid                          => Out_Valid,
        tready                          => Out_Ready,
        tdata                           => Out_Data,
        tlast                           => Out_Last
    );

    -----------------------------------------------------------------------------------------------
    -- TReady Signal Checker VC
    -----------------------------------------------------------------------------------------------

    i_tready_checker : entity vunit_lib.std_logic_checker
    generic map(
        signal_checker                  => TReady_Checker_c
    )
    port map(
        value(0)                        => In_Ready
    );

end architecture;
