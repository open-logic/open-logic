---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
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
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_intf_i2c_master_pkg.all;

library work;
    use work.olo_test_i2c_pkg.all;
    use work.olo_test_activity_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_i2c_master_tb is
    generic (
        BusFrequency_g              : integer := 100_000;
        InternalTriState_g          : boolean := true;
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_intf_i2c_master_tb is

    -----------------------------------------------------------------------------------------------
    -- Fixed Generics
    -----------------------------------------------------------------------------------------------
    constant Scl_Period_c     : time := (1 sec) / real(BusFrequency_g);
    constant BusBusyTimeout_c : real := 200.0/ real(BusFrequency_g);
    constant CmdTimeout_c     : real := 50.0/ real(BusFrequency_g);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 1.0e6*16.0;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    -- Contral Sginal
    signal Clk            : std_logic := '0';
    signal Rst            : std_logic := '0';
    -- Command Interface
    signal Cmd_Ready      : std_logic;
    signal Cmd_Valid      : std_logic := '0';
    signal Cmd_Command    : std_logic_vector(2 downto 0);
    signal Cmd_Data       : std_logic_vector(7 downto 0);
    signal Cmd_Ack        : std_logic;
    -- Response Interface
    signal Resp_Valid     : std_logic;
    signal Resp_Command   : std_logic_vector(2 downto 0);
    signal Resp_Data      : std_logic_vector(7 downto 0);
    signal Resp_Ack       : std_logic;
    signal Resp_ArbLost   : std_logic;
    signal Resp_SeqErr    : std_logic;
    -- Status Interface
    signal Status_BusBusy : std_logic;
    signal Status_CmdTo   : std_logic;
    -- I2c Interface with internal Tri-State
    signal I2c_Scl        : std_logic := 'Z';
    signal I2c_Sda        : std_logic := 'Z';
    -- I2c Interface with external Tri-State
    signal I2c_Scl_i      : std_logic := '0';
    signal I2c_Scl_o      : std_logic;
    signal I2c_Scl_t      : std_logic;
    signal I2c_Sda_i      : std_logic := '0';
    signal I2c_Sda_o      : std_logic;
    signal I2c_Sda_t      : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant I2cSlave_c : olo_test_i2c_t := new_olo_test_i2c (
        bus_frequency => real(BusFrequency_g)
    );

    constant I2cMaster_c : olo_test_i2c_t := new_olo_test_i2c (
        bus_frequency => real(BusFrequency_g)
    );

    -- *** Internal Messaging ***
    constant CmdQueue_c : queue_t    := new_queue;
    constant CmdMsg_c   : msg_type_t := new_msg_type("I2C Command");

    procedure pushCommand (
        Command : std_logic_vector(2 downto 0);
        SetData : boolean                      := false;
        Data    : std_logic_vector(7 downto 0) := (others => '0');
        SetAck  : boolean                      := false;
        Ack     : std_logic                    := '1';
        Delay   : time                         := 0 ns) is
        variable Msg_v : msg_t := new_msg(CmdMsg_c);
    begin
        push(Msg_v, Command);
        push(Msg_v, SetData);
        push(Msg_v, Data);
        push(Msg_v, SetAck);
        push(Msg_v, Ack);
        push(Msg_v, Delay);
        push(CmdQueue_c, Msg_v);
    end procedure;

    constant NoData_c : std_logic_vector(7 downto 0) := (others => 'X');

    procedure checkResp (
        Command : std_logic_vector(2 downto 0);
        Data    : std_logic_vector(7 downto 0) := NoData_c;
        Ack     : std_logic                    := 'X';
        ArbLost : std_logic                    := '0';
        SeqErr  : std_logic                    := '0';
        Msg     : string                       := "") is
    begin
        wait until rising_edge(Clk) and Resp_Valid = '1';
        check_equal(Resp_Command, Command, "Wrong Resp_Command - " & Msg);
        if Data /= NoData_c then
            check_equal(Resp_Data, Data, "Wrong Resp_Data - " & Msg);
        end if;
        if Ack /= 'X' then
            check_equal(Resp_Ack, Ack, "Wrong Resp_Ack - " & Msg);
        end if;
        check_equal(Resp_ArbLost, ArbLost, "Wrong Resp_ArbLost - " & Msg);
        check_equal(Resp_SeqErr, SeqErr, "Wrong Resp_SeqErr - " & Msg);
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
        variable StartTime_v : time;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst         <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst         <= '0';
            wait until rising_edge(Clk);
            StartTime_v := now;

            -- *** Basics ***
            if run("ResetValues") then
                wait for 1 us;
                check_equal(Cmd_Ready, '1', "Cmd_Ready");
                check_equal(Resp_Valid, '0', "Cmd_Valid");
                check_equal(Status_BusBusy, '0', "Status_BusBusy");
                check_equal(Status_CmdTo, '0', "Status_CmdTo");
                check_equal(I2c_Scl, 'H', "I2c_Scl");
                check_equal(I2c_Sda, 'H', "I2c_Sda");
            end if;

            if run("StartRepstartStop") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_repeated_start(net, I2cSlave_c);
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_RepStart_c);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_RepStart_c);
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Write ***
            if run("Write1bAck") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_rx_byte(net, I2cSlave_c, 16#42#);
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, X"42", '1');
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("Write2bAckNack") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_rx_byte(net, I2cSlave_c, 16#42#, msg => "byte 0");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#53#, I2c_NACK, msg => "byte 1");
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42", true);
                pushCommand(I2cCmd_Send_c, true, X"53", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_Send_c, Ack => '0');
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Read ***
            if run("Read1bAck") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_push_tx_byte(net, I2cSlave_c, 16#36#);
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Receive_c, false, SetAck => true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Receive_c, Data => X"36");
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("Read2bAckNack") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_push_tx_byte(net, I2cSlave_c, 16#36#, msg => "byte 0");
                i2c_push_tx_byte(net, I2cSlave_c, 16#47#, I2c_NACK, msg => "byte 1");
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Receive_c, false, SetAck => true, Ack => '1');
                pushCommand(I2cCmd_Receive_c, false, SetAck => true, Ack => '0');
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Receive_c, Data => X"36");
                checkResp(I2cCmd_Receive_c, Data => X"47");
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Test Write then Read ***
            if run("WriteThenRead") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_rx_byte(net, I2cSlave_c, 16#42#, msg => "byte rx");
                i2c_expect_repeated_start(net, I2cSlave_c);
                i2c_push_tx_byte(net, I2cSlave_c, 16#36#, I2c_NACK, msg => "byte tx");
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42");
                pushCommand(I2cCmd_RepStart_c);
                pushCommand(I2cCmd_Receive_c, false, SetAck => true, Ack => '0');
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_RepStart_c);
                checkResp(I2cCmd_Receive_c, Data => X"36");
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Test Clock Stretching ***
            if run("ClockStretching") then
                -- Write then read case
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_rx_byte(net, I2cSlave_c, 16#52#, clk_stretch => 2*Scl_Period_c, msg => "byte rx");
                i2c_expect_repeated_start(net, I2cSlave_c, clk_stretch => 2*Scl_Period_c);
                i2c_push_tx_byte(net, I2cSlave_c, 16#46#, I2c_NACK, clk_stretch => 2*Scl_Period_c, msg => "byte tx");
                i2c_expect_stop(net, I2cSlave_c, clk_stretch => 2*Scl_Period_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"52");
                pushCommand(I2cCmd_RepStart_c);
                pushCommand(I2cCmd_Receive_c, false, SetAck => true, Ack => '0');
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_RepStart_c);
                checkResp(I2cCmd_Receive_c, Data => X"46");
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Test delayed command ***
            if run("CmdDelayed") then
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_rx_byte(net, I2cSlave_c, 16#42#);
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42", true, Delay => CmdTimeout_c * (0.5 sec));
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("CmdTimeout") then
                -- Timeout after start, other commands ignored
                -- I2C Endpoint
                i2c_expect_start(net, I2cSlave_c);
                i2c_expect_stop(net, I2cSlave_c);
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42", true, Delay => CmdTimeout_c * (1.5 sec));
                pushCommand(I2cCmd_Send_c, true, X"55", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                wait_for_value_stdl(Status_CmdTo, '1', CmdTimeout_c*(1.1 sec), "Status_BusBusy 0");
                wait_for_value_stdl(Status_BusBusy, '0', 100 us, "Status_BusBusy 0");
                checkResp(I2cCmd_Send_c, SeqErr => '1');
                checkResp(I2cCmd_Send_c, SeqErr => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
            end if;

            -- *** Test Sequence Error ***
            if run("SequenceError-SendWithoutStart") then
                -- Commands
                pushCommand(I2cCmd_Send_c, true, X"55", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Send_c, SeqErr => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                check_equal(Status_BusBusy, '0', "Status_BusBusy 0");
            end if;

            if run("SequenceError-DoubleStart") then
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                checkResp(I2cCmd_Start_c, SeqErr => '1');
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
            end if;

            -- *** Test Arbitration ***
            if run("MultiMaster-SameWrite") then
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#42#, msg => "data slave");
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#42#, delay => 100 ns, msg => "data master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"42", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_Stop_c);
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostWrite") then
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#87#, msg => "data slave");
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#87#, delay => 100 ns, msg => "data master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"A3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, ArbLost => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1'); -- Sequence error because of lost arbitration
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostStop") then
                -- Arbitration lost during stop (other master continues writing)
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#A3#, msg => "byte 0 slave"); -- from both masters
                i2c_expect_rx_byte(net, I2cSlave_c, 16#12#, msg => "byte 1 slave"); -- from VC master
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#A3#, delay => 100 ns, msg => "byte 0 master");
                i2c_push_tx_byte(net, I2cMaster_c, 16#12#, delay => 100 ns, msg => "byte 1 master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"A3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_Stop_c, ArbLost => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10*Scl_Period_c, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostRepStartContinue") then
                -- Arbitration lost during repeated start (other master continues writing)
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#A3#, msg => "byte 0 slave"); -- from both masters
                i2c_expect_rx_byte(net, I2cSlave_c, 16#12#, msg => "byte 1 slave"); -- from VC master
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#A3#, delay => 100 ns, msg => "byte 0 master");
                i2c_push_tx_byte(net, I2cMaster_c, 16#12#, delay => 100 ns, msg => "byte 1 master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"A3", true);
                pushCommand(I2cCmd_RepStart_c);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_RepStart_c, ArbLost => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10*Scl_Period_c, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostRepStartStop") then
                -- Arbitration lost during repeated start (other master sends stop)
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#A3#, msg => "data slave"); -- from both masters
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");            -- from VC master
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#A3#, delay => 100 ns, msg => "data master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"A3", true);
                pushCommand(I2cCmd_RepStart_c);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, Ack => '1');
                checkResp(I2cCmd_RepStart_c, ArbLost => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostBit1") then
                -- Arbitration lost during bit 1 (other master sends a '0')
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_rx_byte(net, I2cSlave_c, 16#C3#, msg => "data slave");
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_tx_byte(net, I2cMaster_c, 16#C3#, delay => 100 ns, msg => "data master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"E3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, ArbLost => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10*Scl_Period_c, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostByRepstart") then
                -- Arbitration lost due to other master sending a repeated start during first data bit
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_repeated_start(net, I2cSlave_c, msg => "repstart slave");
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_expect_start(net, I2cMaster_c, msg => "start master");
                i2c_force_master_mode(net, I2cMaster_c);
                i2c_push_repeated_start(net, I2cMaster_c, delay => 100 ns, msg => "repstart master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"E3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Send_c, ArbLost => '1');
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10*Scl_Period_c, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostOtherStart") then
                -- Arbitration lost due to other master sending a start before own start
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_expect_stop(net, I2cSlave_c, msg => "stop slave");
                -- I2C Master
                i2c_push_start(net, I2cMaster_c, delay => 100 ns, msg => "start master");
                i2c_push_stop(net, I2cMaster_c, delay => 100 ns, msg => "stop master");
                -- Commands
                pushCommand(I2cCmd_Start_c, delay => 0.25 * Scl_Period_c);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c, ArbLost => '1');
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', 10 us, "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostIllegalSdaPulldown-EarlyInScl") then
                -- Arbitration lost during bit 1 (other master pulls down SDA during SCL='1')
                -- ... This should never happen as long as the other master is a proper I2C master. However
                -- ... it could happen if a non-multi-master-cabalbe master is connected to the bus.
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_force_bus_release(net, I2cSlave_c); -- return to idle state
                -- data not checked because its not relevant
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"E3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                -- ... Pull down SDA during the first bit while SCL = '1'
                wait until I2c_Scl = 'H' or I2c_Scl = '1';
                wait for 0.1 * Scl_Period_c;
                I2c_Sda <= '0';
                checkResp(I2cCmd_Send_c, ArbLost => '1');
                wait for 5 * Scl_Period_c;
                I2c_Sda <= 'Z';
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', BusBusyTimeout_c * 1.1 * (1 sec), "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            if run("MultiMaster-ArbLostIllegalSdaPulldown-LateInScl") then
                -- Arbitration lost during bit 1 (other master pulls down SDA during SCL='1')
                -- ... This should never happen as long as the other master is a proper I2C master. However
                -- ... it could happen if a non-multi-master-cabalbe master is connected to the bus.
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                i2c_force_bus_release(net, I2cSlave_c); -- return to idle state
                -- data not checked because its not relevant
                -- Commands
                pushCommand(I2cCmd_Start_c);
                pushCommand(I2cCmd_Send_c, true, X"E3", true);
                pushCommand(I2cCmd_Stop_c);
                -- Check responses (blocking)
                checkResp(I2cCmd_Start_c);
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                -- ... Pull down SDA during the first bit while SCL = '1'
                wait until I2c_Scl = 'H' or I2c_Scl = '1';
                wait for 0.4 * Scl_Period_c;
                I2c_Sda <= '0';
                checkResp(I2cCmd_Send_c, ArbLost => '1');
                wait for 5 * Scl_Period_c;
                I2c_Sda <= 'Z';
                checkResp(I2cCmd_Stop_c, SeqErr => '1');
                wait_for_value_stdl(Status_BusBusy, '0', BusBusyTimeout_c * 1.1 * (1 sec), "Status_BusBusy 0");
                check_last_activity(Status_CmdTo, now-StartTime_v, 0, "Status_CmdTo");
            end if;

            -- *** Test Bus Busy Timeout ***
            if run("BusBusyTimeout") then
                -- I2C Slave
                i2c_expect_start(net, I2cSlave_c, msg => "start slave");
                -- I2C Master
                i2c_push_start(net, I2cMaster_c, msg => "start master");
                i2c_force_bus_release(net, I2cMaster_c);
                -- Check Status
                check_equal(Status_BusBusy, '0', "Status_BusBusy 0 start");
                wait for 2*Scl_Period_c;
                check_equal(Status_BusBusy, '1', "Status_BusBusy 1");
                wait for BusBusyTimeout_c * 1.1 * (1 sec);
                check_equal(Status_BusBusy, '0', "Status_BusBusy 0 end");
            end if;

            -- Wait for idle
            wait_until_idle(net, as_sync(I2cSlave_c));
            wait_until_idle(net, as_sync(I2cMaster_c));
            wait for 50 us;

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
    g_internal_tristate : if InternalTriState_g = true generate

        i_dut : entity olo.olo_intf_i2c_master
            generic map (
                ClkFrequency_g      => Clk_Frequency_c,
                I2cFrequency_g      => real(BusFrequency_g),
                BusBusyTimeout_g    => BusBusyTimeout_c,
                CmdTimeout_g        => CmdTimeout_c,
                InternalTriState_g  => InternalTriState_g,
                DisableAsserts_g    => true
            )
            port map (
                -- Control Signals
                Clk             => Clk,
                Rst             => Rst,
                -- Command Interface
                Cmd_Ready       => Cmd_Ready,
                Cmd_Valid       => Cmd_Valid,
                Cmd_Command     => Cmd_Command,
                Cmd_Data        => Cmd_Data,
                Cmd_Ack         => Cmd_Ack,
                -- Response Interface
                Resp_Valid      => Resp_Valid,
                Resp_Command    => Resp_Command,
                Resp_Data       => Resp_Data,
                Resp_Ack        => Resp_Ack,
                Resp_ArbLost    => Resp_ArbLost,
                Resp_SeqErr     => Resp_SeqErr,
                -- Status Interface
                Status_BusBusy  => Status_BusBusy,
                Status_CmdTo    => Status_CmdTo,
                -- I2c Interface with internal Tri-State
                I2c_Scl         => I2c_Scl,
                I2c_Sda         => I2c_Sda
            );

    end generate;

    g_external_tristate : if InternalTriState_g = false generate

        i_dut : entity olo.olo_intf_i2c_master
            generic map (
                ClkFrequency_g      => Clk_Frequency_c,
                I2cFrequency_g      => real(BusFrequency_g),
                BusBusyTimeout_g    => BusBusyTimeout_c,
                CmdTimeout_g        => CmdTimeout_c,
                InternalTriState_g  => InternalTriState_g,
                DisableAsserts_g    => true
            )
            port map (
                -- Control Signals
                Clk             => Clk,
                Rst             => Rst,
                -- Command Interface
                Cmd_Ready       => Cmd_Ready,
                Cmd_Valid       => Cmd_Valid,
                Cmd_Command     => Cmd_Command,
                Cmd_Data        => Cmd_Data,
                Cmd_Ack         => Cmd_Ack,
                -- Response Interface
                Resp_Valid      => Resp_Valid,
                Resp_Command    => Resp_Command,
                Resp_Data       => Resp_Data,
                Resp_Ack        => Resp_Ack,
                Resp_ArbLost    => Resp_ArbLost,
                Resp_SeqErr     => Resp_SeqErr,
                -- Status Interface
                Status_BusBusy  => Status_BusBusy,
                Status_CmdTo    => Status_CmdTo,
                -- I2c Interface with internal Tri-State
                I2c_Scl_i       => I2c_Scl_i,
                I2c_Scl_t       => I2c_Scl_t,
                I2c_Scl_o       => I2c_Scl_o,
                I2c_Sda_i       => I2c_Sda_i,
                I2c_Sda_t       => I2c_Sda_t,
                I2c_Sda_o       => I2c_Sda_o
            );

        I2c_Scl   <= 'Z' when I2c_Scl_t = '1' else I2c_Scl_o;
        I2c_Sda   <= 'Z' when I2c_Sda_t = '1' else I2c_Sda_o;
        I2c_Scl_i <= to01X(I2c_Scl);
        I2c_Sda_i <= to01X(I2c_Sda);

    end generate;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_slave : entity work.olo_test_i2c_vc
        generic map (
            Instance => I2cSlave_c
        )
        port map (
            Scl   => I2c_Scl,
            Sda   => I2c_Sda
        );

    vc_master : entity work.olo_test_i2c_vc
        generic map (
            Instance => I2cMaster_c
        )
        port map (
            Scl   => I2c_Scl,
            Sda   => I2c_Sda
        );

    p_vc_cm : process is
        variable Msg_v     : msg_t;
        variable MsgType_v : msg_type_t;
        variable Command_v : std_logic_vector(2 downto 0);
        variable SetData_v : boolean;
        variable Data_v    : std_logic_vector(7 downto 0);
        variable SetAck_v  : boolean;
        variable Ack_v     : std_logic;
        variable Delay_v   : time;
    begin
        -- Initialize
        Cmd_Valid   <= '0';
        Cmd_Command <= (others => 'X');
        Cmd_Data    <= (others => 'X');
        Cmd_Ack     <= 'X';

        -- loop messages
        loop
            -- wait until message available
            if is_empty(CmdQueue_c) then
                wait until not is_empty(CmdQueue_c) and rising_edge(Clk);
            end if;
            -- get message
            Msg_v     := pop(CmdQueue_c);
            MsgType_v := message_type(Msg_v);
            -- process message
            if MsgType_v = CmdMsg_c then
                -- pop information
                Command_v := pop(Msg_v);
                SetData_v := pop(Msg_v);
                Data_v    := pop(Msg_v);
                SetAck_v  := pop(Msg_v);
                Ack_v     := pop(Msg_v);
                Delay_v   := pop(Msg_v);

                -- Send command
                if Delay_v > 0 ns then
                    wait for Delay_v;
                    wait until rising_edge(Clk);
                end if;
                Cmd_Valid   <= '1';
                Cmd_Command <= Command_v;
                if SetData_v then
                    Cmd_Data <= Data_v;
                end if;
                if SetAck_v then
                    Cmd_Ack <= Ack_v;
                end if;
                wait until rising_edge(Clk) and Cmd_Ready = '1';
                Cmd_Valid   <= '0';
                Cmd_Command <= (others => 'X');
                Cmd_Data    <= (others => 'X');
                Cmd_Ack     <= 'X';
            else
                error("Unexpected message type in vc_cmd");
            end if;
        end loop;

    end process;

end architecture;
