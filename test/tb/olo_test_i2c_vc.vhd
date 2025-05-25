---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- VC Package
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

package olo_test_i2c_pkg is

    -- *** Constants ***
    constant i2c_ack  : std_logic := '0';
    constant i2c_nack : std_logic := '1';

    type i2c_transaction_t is (i2c_read, i2c_write);

    -- *** VUnit instance type ***
    type olo_test_i2c_t is record
        p_actor       : actor_t;
        bus_frequency : real;
    end record;

    -- *** Master Operations ***

    -- Send start (and switch to master operation mode)
    procedure i2c_push_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "");

    -- Send repeated start
    procedure i2c_push_repeated_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "");

    -- Send stop (and switch to idle operation mode)
    procedure i2c_push_stop (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "");

    -- Send address
    procedure i2c_push_addr_start (
        signal net   : inout network_t;
        i2c          : olo_test_i2c_t;
        address      : integer;
        is_read      : boolean;
        addr_bits    : natural range 7 to 10 := 7;
        expected_ack : std_logic             := i2c_ack;
        delay        : time                  := 0 ns;
        msg          : string                := "");

    -- *** Slave Operations ***
    -- Wait for start (and switch to slave operation mode)
    procedure i2c_expect_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        timeout    : time   := 1 ms;
        msg        : string := "");

    -- Wait for repeated start
    procedure i2c_expect_repeated_start (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        timeout     : time   := 1 ms;
        clk_stretch : time   := 0 ns;
        msg         : string := "");

    -- Wait for stop (and switch to idle operation mode)
    procedure i2c_expect_stop (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        timeout     : time   := 1 ms;
        clk_stretch : time   := 0 ns;
        msg         : string := "");

    -- Expect address
    procedure i2c_expect_addr (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        address     : integer;
        is_read     : boolean;
        addr_bits   : natural range 7 to 10 := 7;
        ack_output  : std_logic             := i2c_ack;
        timeout     : time                  := 1 ms;
        clk_stretch : time                  := 0 ns;
        msg         : string                := "");

    -- *** General Operations ***

    -- Send TX Byte
    procedure i2c_push_tx_byte (
        signal net   : inout network_t;
        i2c          : olo_test_i2c_t;
        data         : integer range -128 to 255;
        expected_ack : std_logic := i2c_ack;
        clk_stretch  : time      := 0 ns; -- only allowed in slave mode
        delay        : time      := 0 ns; -- only allowed in master mode
        msg          : string    := "");

    -- Receive RX Byte
    procedure i2c_expect_rx_byte (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        expData     : integer range -128 to 255;
        ack_output  : std_logic := i2c_ack;
        clk_stretch : time      := 0 ns; -- only allowed in slave mode
        msg         : string    := "");

    -- Force I2C VC in slave mode to master operation mode
    procedure i2c_force_master_mode (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        msg        : string := "");

    -- Force releasing of the bus
    procedure i2c_force_bus_release (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        msg        : string := "");

    -- *** VUnit Operations ***

    -- Message Types
    constant i2c_push_start_msg            : msg_type_t := new_msg_type("I2C Push Start");
    constant i2c_push_repeated_start_msg   : msg_type_t := new_msg_type("I2C Push Repeated Start");
    constant i2c_push_stop_msg             : msg_type_t := new_msg_type("I2C Push Stop");
    constant i2c_push_addr_msg             : msg_type_t := new_msg_type("I2C Push Address Start");
    constant i2c_expect_start_msg          : msg_type_t := new_msg_type("I2C Expect Start");
    constant i2c_expect_repeated_start_msg : msg_type_t := new_msg_type("I2C Expect Repeated Start");
    constant i2c_expect_stop_msg           : msg_type_t := new_msg_type("I2C Expect Stop");
    constant i2c_expect_addr_msg           : msg_type_t := new_msg_type("I2C Expect Address");
    constant i2c_push_tx_byte_msg          : msg_type_t := new_msg_type("I2C Push TX Byte");
    constant i2c_expect_rx_byte_msg        : msg_type_t := new_msg_type("I2C Expect RX Byte");
    constant i2c_force_master_mode_msg     : msg_type_t := new_msg_type("I2C Force Master Mode");
    constant i2c_force_bus_release_msg     : msg_type_t := new_msg_type("I2C Force Bus Release");

    -- Constructor
    impure function new_olo_test_i2c (bus_frequency : real    := 100.0e3) return olo_test_i2c_t;

    -- Casts
    impure function as_sync (instance : olo_test_i2c_t) return sync_handle_t;

    -- I2c Pullup
    procedure i2c_pull_up (
        signal scl : inout std_logic;
        signal sda : inout std_logic);

end package;

package body olo_test_i2c_pkg is

    -- *** Master Operations ***

    -- Send start (and switch to master operation mode)
    procedure i2c_push_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_push_start_msg);
    begin
        push(msg_v, delay);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Send repeated start (and switch to master operation mode)
    procedure i2c_push_repeated_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_push_repeated_start_msg);
    begin
        push(msg_v, delay);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Send stop (and switch to idle operation mode)
    procedure i2c_push_stop (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        delay      : time   := 0 ns;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_push_stop_msg);
    begin
        push(msg_v, delay);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Send address
    procedure i2c_push_addr_start (
        signal net   : inout network_t;
        i2c          : olo_test_i2c_t;
        address      : integer;
        is_read      : boolean;
        addr_bits    : natural range 7 to 10 := 7;
        expected_ack : std_logic             := i2c_ack;
        delay        : time                  := 0 ns;
        msg          : string                := "") is
        variable msg_v : msg_t := new_msg(i2c_push_addr_msg);
    begin
        push(msg_v, address);
        push(msg_v, is_read);
        push(msg_v, addr_bits);
        push(msg_v, expected_ack);
        push(msg_v, delay);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- *** Slave Operations ***

    -- Wait for start (and switch to slave operation mode)
    procedure i2c_expect_start (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        timeout    : time   := 1 ms;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_expect_start_msg);
    begin
        push(msg_v, timeout);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Wait for repeated start
    procedure i2c_expect_repeated_start (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        timeout     : time   := 1 ms;
        clk_stretch : time   := 0 ns;
        msg         : string := "") is
        variable msg_v : msg_t := new_msg(i2c_expect_repeated_start_msg);
    begin
        push(msg_v, timeout);
        push(msg_v, clk_stretch);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Wait for stop (and switch to idle operation mode)
    procedure i2c_expect_stop (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        timeout     : time   := 1 ms;
        clk_stretch : time   := 0 ns;
        msg         : string := "") is
        variable msg_v : msg_t := new_msg(i2c_expect_stop_msg);
    begin
        push(msg_v, timeout);
        push(msg_v, clk_stretch);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Expect address
    procedure i2c_expect_addr (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        address     : integer;
        is_read     : boolean;
        addr_bits   : natural range 7 to 10 := 7;
        ack_output  : std_logic             := i2c_ack;
        timeout     : time                  := 1 ms;
        clk_stretch : time                  := 0 ns;
        msg         : string                := "") is
        variable msg_v : msg_t := new_msg(i2c_expect_addr_msg);
    begin
        push(msg_v, address);
        push(msg_v, is_read);
        push(msg_v, addr_bits);
        push(msg_v, ack_output);
        push(msg_v, timeout);
        push(msg_v, clk_stretch);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- *** General Operations ***

    -- Send TX Byte
    procedure i2c_push_tx_byte (
        signal net   : inout network_t;
        i2c          : olo_test_i2c_t;
        data         : integer range -128 to 255;
        expected_ack : std_logic := i2c_ack;
        clk_stretch  : time      := 0 ns;  -- only allowed in slave mode
        delay        : time      := 0 ns; -- only allowed in master mode
        msg          : string    := "") is
        variable msg_v : msg_t := new_msg(i2c_push_tx_byte_msg);
    begin
        push(msg_v, data);
        push(msg_v, expected_ack);
        push(msg_v, clk_stretch);
        push(msg_v, delay);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Receive RX Byte
    procedure i2c_expect_rx_byte (
        signal net  : inout network_t;
        i2c         : olo_test_i2c_t;
        expData     : integer range -128 to 255;
        ack_output  : std_logic := i2c_ack;
        clk_stretch : time      := 0 ns;  -- only allowed in slave mode
        msg         : string    := "") is
        variable msg_v : msg_t := new_msg(i2c_expect_rx_byte_msg);
    begin
        push(msg_v, expData);
        push(msg_v, ack_output);
        push(msg_v, clk_stretch);
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Force I2C VC in slave mode to master operation mode
    procedure i2c_force_master_mode (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_force_master_mode_msg);
    begin
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- Force releasing of the bus
    procedure i2c_force_bus_release (
        signal net : inout network_t;
        i2c        : olo_test_i2c_t;
        msg        : string := "") is
        variable msg_v : msg_t := new_msg(i2c_force_bus_release_msg);
    begin
        push_string(msg_v, msg);
        send(net, i2c.p_actor, msg_v);
    end procedure;

    -- *** Infrastructure ***

    -- Pull Up
    procedure i2c_pull_up (
        signal scl : inout std_logic;
        signal sda : inout std_logic) is
    begin
        scl <= 'H';
        sda <= 'H';
    end procedure;

    -- Constructor
    impure function new_olo_test_i2c (
        bus_frequency : real    := 100.0e3) return olo_test_i2c_t is
    begin
        return (p_actor => new_actor,
                bus_frequency => bus_frequency);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_i2c_t) return sync_handle_t is
    begin
        return instance.p_actor;
    end function;

end package body;

---------------------------------------------------------------------------------------------------
-- Component Implementation
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.stream_master_pkg.all;
    use vunit_lib.sync_pkg.all;

library work;
    use work.olo_test_i2c_pkg.all;
    use work.olo_test_activity_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_test_i2c_vc is
    generic (
        instance                 : olo_test_i2c_t
    );
    port (
        scl          : inout std_logic;
        sda          : inout std_logic
    );
end entity;

architecture a of olo_test_i2c_vc is

    -- **** Local procedures and functions ***
    procedure level_check (
        signal sig : std_logic;
        expected   : std_logic;
        msg        : string) is
        variable sig_v : std_logic;
    begin
        sig_v := to01X(sig);
        check_equal(sig_v, expected, msg);
    end procedure;

    procedure level_wait (
        signal sig : std_logic;
        expected   : std_logic;
        msg        : string;
        timeout    : time := 1 ms) is
        variable correct : boolean;
    begin
        if expected = '0' then
            if sig /= '0' then
                wait until sig = '0' for timeout;
            end if;
            correct := (sig = '0');
        else
            if sig /= '1' and sig /= 'H' then
                wait until ((sig = '1') or (sig = 'H')) for timeout;
            end if;
            correct := ((sig = '1') or (sig = 'H'));
        end if;
        check_true(correct, msg);
    end procedure;

    -- *** Time Calculations ***
    impure function clk_half_period return time is
    begin
        return (0.5 sec) / instance.bus_frequency;
    end function;

    impure function clk_quart_period return time is
    begin
        return (0.25 sec) / instance.bus_frequency;
    end function;

    -- *** Bit Transfers ***
    procedure send_bit_incl_clock (
        data       : in    std_logic;
        signal scl : inout std_logic;
        signal sda : inout std_logic;
        msg        : in    string;
        timeout    : in    time := 1 ms) is
    begin
        -- Initial Check
        level_check(scl, '0', msg & " - SCL is HIGH but was expected LOW here [send_bit_incl_clock]");

        -- Assert data
        if data = '0' then
            sda <= '0';
        else
            sda <= 'Z';
        end if;
        wait for clk_quart_period;

        -- Send clk Pulse
        scl <= 'Z';
        level_wait(scl, '1', msg & " - SCL held low by other device [send_bit_incl_clock]", timeout);
        wait for clk_half_period;
        check_last_activity(scl, clk_half_period*0.9, -1, msg & " - SCL high period too short [send_bit_incl_clock]");
        level_check(sda, data, msg & " - SDA readback does not match SDA transmit value during SCL pulse [send_bit_incl_clock]");
        check_last_activity(sda, clk_half_period, -1, msg & " - SDA not stable during SCL pulse [send_bit_incl_clock]");
        scl <= '0';
        wait for clk_quart_period;
    end procedure;

    procedure receive_bit_incl_clock (
        variable data : out   std_logic;
        signal scl    : inout std_logic;
        signal sda    : inout std_logic;
        msg           : in    string;
        timeout       : in    time := 1 ms) is
    begin
        -- Initial Check
        level_check(scl, '0', msg & " - SCL is HIGH but was expected LOW here [receive_bit_incl_clock]");

        -- Wait for assertion
        wait for clk_quart_period;

        -- Send clk Pulse
        scl  <= 'Z';
        level_wait(scl, '1', msg & " - SCL held low by other device [receive_bit_incl_clock]", timeout);
        wait for clk_half_period;
        check_last_activity(scl, clk_half_period*0.9, -1, msg & " - SCL high period too short [receive_bit_incl_clock]");
        check_last_activity(sda, clk_half_period, -1, msg & " - SDA not stable during SCL pulse [receive_bit_incl_clock]");
        data := to01X(sda);
        scl  <= '0';
        wait for clk_quart_period;
    end procedure;

    procedure send_bit_excl_clock (
        data        : in    std_logic;
        signal scl  : inout std_logic;
        signal sda  : inout std_logic;
        msg         : in    string;
        timeout     : in    time := 1 ms;
        clk_stretch : in    time := 0 ns) is
        variable stretched : boolean := false;
    begin
        -- Initial Check
        level_check(scl, '0', msg & " - SCL is HIGH but was expected LOW here [receive_bit_incl_clock]");

        -- Clock stretching
        if clk_stretch > 0 ns then
            scl       <= '0';
            wait for clk_stretch;
            stretched := true;
        end if;

        -- Assert data
        if data = '0' then
            sda <= '0';
        else
            sda <= 'Z';
        end if;
        if stretched then
            wait for clk_quart_period;
            scl <= 'Z';
        end if;

        -- Wait clock rising edge
        level_wait(scl, '1', msg & " - SCL did not go high [receive_bit_incl_clock]", timeout);

        -- wait clock falling edge
        level_wait(scl, '0', msg & " - SCL did not go low [receive_bit_incl_clock]", timeout);
        level_check(sda, data, msg & " - SDA readback does not match SDA transmit value during SCL pulse [receive_bit_incl_clock]");
        check_last_activity(sda, clk_half_period, -1, msg & " - SDA not stable during SCL pulse [receive_bit_incl_clock]");

        -- wait until center of low
        wait for clk_quart_period;
    end procedure;

    procedure receive_bit_excl_clock (
        data        : out   std_logic;
        signal scl  : inout std_logic;
        signal sda  : inout std_logic;
        msg         : in    string;
        timeout     : in    time := 1 ms;
        clk_stretch : in    time := 0 ns) is
    begin
        -- Initial Check
        level_check(scl, '0', msg & " - SCL is HIGH but was expected LOW here [receive_bit_excl_clock]");

        -- Clock stretching
        if clk_stretch > 0 ns then
            scl <= '0';
            wait for clk_stretch;
            scl <= 'Z';
        end if;

        -- Wait clock rising edge
        level_wait(scl, '1', msg & " - SCL did not go high [receive_bit_excl_clock]", timeout);

        -- wait clock falling edge
        level_wait(scl, '0', msg & " - SCL did not go low [receive_bit_excl_clock]", timeout);
        check_last_activity(sda, clk_half_period, -1, msg & " - SDA not stable during SCL pulse [receive_bit_excl_clock]");
        data := to01X(sda);

        -- wait until center of low
        wait for clk_quart_period;
    end procedure;

    -- *** Byte Transfers ***
    procedure send_byte_incl_clock (
        data       : in    std_logic_vector(7 downto 0);
        signal scl : inout std_logic;
        signal sda : inout std_logic;
        msg        : in    string) is
    begin

        -- Do bits
        for i in 7 downto 0 loop
            send_bit_incl_clock(data(i), scl, sda, msg & " - Bit " & integer'image(7-i));
        end loop;

    end procedure;

    procedure send_byte_excl_clock (
        data        : in    std_logic_vector(7 downto 0);
        signal scl  : inout std_logic;
        signal sda  : inout std_logic;
        msg         : in    string;
        clk_stretch : in    time := 0 ns) is
    begin

        -- Do bits
        for i in 7 downto 0 loop
            send_bit_excl_clock(data(i), scl, sda, msg & " - Bit " & integer'image(7-i), clk_stretch => clk_stretch);
        end loop;

    end procedure;

    procedure expect_byte_incl_clock (
        ExpData    : in    std_logic_vector(7 downto 0);
        signal scl : inout std_logic;
        signal sda : inout std_logic;
        msg        : in    string) is
        variable rx_byte : std_logic_vector(7 downto 0) := (others => 'X');
    begin

        -- Do bits
        for i in 7 downto 0 loop
            receive_bit_incl_clock(rx_byte(i), scl, sda, msg & " - Bit " & integer'image(7-i));
        end loop;

        check_equal(rx_byte, ExpData, msg & " - Received wrong byte");
    end procedure;

    procedure expect_byte_excl_clock (
        ExpData     : in    std_logic_vector(7 downto 0);
        signal scl  : inout std_logic;
        signal sda  : inout std_logic;
        msg         : in    string;
        clk_stretch : in    time := 0 ns) is
        variable rx_byte : std_logic_vector(7 downto 0) := (others => 'X');
    begin

        -- Do bits
        for i in 7 downto 0 loop
            receive_bit_excl_clock(rx_byte(i), scl, sda, msg & " - Bit " & integer'image(7-i), clk_stretch => clk_stretch);
        end loop;

        check_equal(rx_byte, ExpData, msg & " - Received wrong byte");
    end procedure;

    -- *** Utilities ***

    -- Free Bus
    procedure i2c_bus_free (
        signal scl : inout std_logic;
        signal sda : inout std_logic) is
    begin
        scl <= 'Z';
        sda <= 'Z';
    end procedure;

begin

    -- PullUp
    i2c_pull_up(scl, sda);

    -- Main Process
    main : process is
        -- Messaging
        variable request_msg  : msg_t;
        variable msg_type     : msg_type_t;
        variable delay        : time;
        variable timeout      : time;
        variable clk_stretch  : time;
        variable address      : integer;
        variable is_read      : boolean;
        variable addr_bits    : natural;
        variable expected_ack : std_logic;
        variable ack_output   : std_logic;
        variable data         : integer;
        variable msg_p        : string_ptr_t;

        -- Operation Mode
        type i2c_operation_mode_t is (i2c_idle, i2c_master, i2c_slave);

        variable opmode : i2c_operation_mode_t := i2c_idle;

        -- Variables
        variable ack      : std_logic;
        variable data_slv : std_logic_vector(7 downto 0);
    begin
        -- Initialization
        i2c_bus_free(scl, sda);

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Master Messages ***
            if msg_type = i2c_push_start_msg then
                -- Push Start
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = i2c_idle, to_string(msg_p) & " - I2C must be idle before I2C-START can be sent [I2cPushStart]");
                opmode := i2c_master;
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 before I2C-START can be sent [I2cPushStart]");
                level_check(scl, '1', to_string(msg_p) & " - SDA must be 1 before I2C-START can be sent [I2cPushStart]");

                -- Do start condition
                wait for clk_quart_period;
                sda <= '0';
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cPushStart]");
                wait for clk_quart_period;

                -- Go to center of clk low period
                scl <= '0';
                wait for clk_quart_period;

            elsif msg_type = i2c_push_repeated_start_msg then
                -- Push Repeated Start
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = i2c_master, to_string(msg_p) & " - I2C must be in master mode before I2C-REPEATED-START can be sent [I2cPushRepeatedStart]");
                if to01X(scl) = '1' then
                    level_check(sda, '1', to_string(msg_p) & " - SDA must be 1 before procedure is called if SCL = 1 [I2cPushRepeatedStart]");
                end if;

                -- Do repeated start
                if scl = '0' then
                    sda <= 'Z';
                    wait for clk_quart_period;
                    level_check(sda, '1', to_string(msg_p) & " - SDA held low by other device [I2cPushRepeatedStart]");
                    scl <= 'Z';
                    wait for clk_quart_period;
                    level_check(scl, '1', to_string(msg_p) & " - SCL held low by other device [I2cPushRepeatedStart]");
                end if;
                wait for clk_quart_period;
                sda <= '0';
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cPushRepeatedStart]");
                wait for clk_quart_period;

                -- Go to center of clk low period
                scl <= '0';
                wait for clk_quart_period;

            elsif msg_type = i2c_push_stop_msg then
                -- Push Stop
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = i2c_master, to_string(msg_p) & " - I2C must be in master mode before I2C-STOP can be sent [I2cPushStop]");
                if to01X(scl) = '1' then
                    level_check(sda, '0', to_string(msg_p) & " - SDA must be 0 before procedure is called if SCL = 1 [I2cPushStop]");
                end if;

                -- Do stop
                if scl = '0' then
                    sda <= '0';
                    wait for clk_quart_period;
                    scl <= 'Z';
                    wait for clk_quart_period;
                    level_check(scl, '1', to_string(msg_p) & " - SCL held low by other device [I2cPushStop]");
                else
                    wait for clk_quart_period;
                end if;
                sda <= 'Z';
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA rising edge [I2cPushStop]");

                -- Go to center of clk high period
                wait for clk_quart_period;
                opmode := i2c_idle;

            elsif msg_type = i2c_push_addr_msg then
                -- Push Address
                address      := pop(request_msg);
                is_read      := pop(request_msg);
                addr_bits    := pop(request_msg);
                expected_ack := pop(request_msg);
                delay        := pop(request_msg);
                msg_p        := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = i2c_master, to_string(msg_p) & " - I2C must be in master mode before I2C-ADDRESS can be sent [I2cPushAddr]");

                -- 7 Bit addressing
                if addr_bits = 7 then
                    send_byte_incl_clock(toUslv(Address, 7) & choose(is_read, '1', '0'), scl, sda,
                                         to_string(msg_p) & " - 7bit Address Transmission [I2cPushAddr]");
                    sda <= 'Z';
                    receive_bit_incl_clock(ack, scl, sda, to_string(msg_p) & " - 7bit Addres ACK reception [I2cPushAddr]");
                    check_equal(ack, expected_ack, to_string(msg_p) & " - 7bit Address ACK [I2cPushAddr]");
                -- 10 Bit addressing
                elsif addr_bits = 10 then
                    -- First beat
                    send_byte_incl_clock("11110" & toUslv(Address, 10)(9 downto 8) & choose(is_read, '1', '0'), scl, sda,
                                         to_string(msg_p) & " - 10bit Address Transmission, first beat [I2cPushAddr]");
                    sda <= 'Z';
                    receive_bit_incl_clock(ack, scl, sda, to_string(msg_p) & " - 7bit Addres ACK reception for first address beat [I2cPushAddr]");
                    check_equal(ack, expected_ack, to_string(msg_p) & " - 10bit Address ACK for first address beat [I2cPushAddr]");
                    -- Second beat
                    send_byte_incl_clock(toUslv(Address, 10)(7 downto 0), scl, sda,
                                         to_string(msg_p) & " - 10bit Address Transmission, second beat [I2cPushAddr]");
                    sda <= 'Z';
                    receive_bit_incl_clock(ack, scl, sda, to_string(msg_p) & " - 7bit Addres ACK reception for second address beat [I2cPushAddr]");
                    check_equal(ack, expected_ack, to_string(msg_p) & " - 10bit Address ACK for first second beat [I2cPushAddr]");
                else
                    error(to_string(msg_p) & " - I2cMasterSendAddr - Illegal addr_bits (must be 7 or 10)");
                end if;

            -- *** Handle Slave Messages ***
            elsif msg_type = i2c_expect_start_msg then
                -- Expect Start
                timeout := pop(request_msg);
                msg_p   := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_idle, to_string(msg_p) & " - I2C must be idle before I2C-START can be expected [I2cExpectStart]");
                opmode := i2c_slave;
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 before I2C-START can be received [I2cExpectStart]");
                level_check(sda, '1', to_string(msg_p) & " - SDA must be 1 before I2C-START can be received [I2cExpectStart]");

                -- Do start checking
                level_wait(sda, '0', to_string(msg_p) & " - SDA did not go low [I2cExpectStart]", timeout);
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cExpectStart]");
                level_wait(scl, '0', to_string(msg_p) & " - SCL did not go low [I2cExpectStart]", timeout);
                level_check(sda, '0', to_string(msg_p) & " - SDA must be 0 during SCL falling edge [I2cExpectStart]");

                -- Wait for center of SCL low
                wait for clk_quart_period;

            elsif msg_type = i2c_expect_repeated_start_msg then
                -- Expect Repeated Start
                timeout     := pop(request_msg);
                clk_stretch := pop(request_msg);
                msg_p       := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_slave, to_string(msg_p) & " - I2C must be in slave mode before I2C-REPEATED-START can be expected [I2cExpectRepeatedStart]");
                if to01X(scl) = '1' then
                    level_check(sda, '1', to_string(msg_p) & " - SDA must be 1 if SCL = 1 when waiting for a I2C-REPEATED-START [I2cExpectRepeatedStart]");
                end if;

                -- Do Check
                if to01X(scl) = '0' then
                    -- Clock stretching
                    if clk_stretch > 0 ns then
                        scl <= '0';
                        wait for clk_stretch;
                        scl <= 'Z';
                    end if;
                    level_wait(scl, '1', to_string(msg_p) & " - SCL did not go high [I2cExpectRepeatedStart]", timeout);
                    level_check(sda, '1', to_string(msg_p) & " - SDA must be 1 before SCL goes high [I2cExpectRepeatedStart]");
                end if;
                level_wait(sda, '0', to_string(msg_p) & " - SDA did not go low [I2cExpectRepeatedStart]", timeout);
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cExpectRepeatedStart]");
                level_wait(scl, '0', to_string(msg_p) & " - SCL did not go low [I2cExpectRepeatedStart]", timeout);
                level_check(sda, '0', to_string(msg_p) & " - SDA must be 0 during SCL falling edge [I2cExpectRepeatedStart]");

                -- Wait for center of SCL low
                wait for clk_quart_period;

            elsif msg_type = i2c_expect_stop_msg then
                -- Expect Stop
                timeout     := pop(request_msg);
                clk_stretch := pop(request_msg);
                msg_p       := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_slave, to_string(msg_p) & " - I2C must be in slave mode before I2C-STOP can be expected [I2cExpectStop]");
                if to01X(scl) = '1' then
                    level_check(sda, '0', to_string(msg_p) & " - SDA must be 0 if SCL = 1 when waiting for a I2C-STOP [I2cExpectStop]");
                end if;

                -- Do Check
                if to01X(scl) = '0' then
                    -- Clock stretching
                    if clk_stretch > 0 ns then
                        scl <= '0';
                        wait for clk_stretch;
                        scl <= 'Z';
                    end if;
                    level_wait(scl, '1', to_string(msg_p) & " - SCL did not go high [I2cExpectStop]", timeout);
                    level_check(sda, '0', to_string(msg_p) & " - SDA must be 0 before SCL goes high [I2cExpectStop]");
                end if;
                level_wait(sda, '1', to_string(msg_p) & " - SDA did not go high [I2cExpectStop]", timeout);
                level_check(scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA rising edge [I2cExpectStop]");

                -- Go to center of clk high period
                wait for clk_quart_period;
                opmode := i2c_idle;

            elsif msg_type = i2c_expect_addr_msg then
                -- Expect Address
                address     := pop(request_msg);
                is_read     := pop(request_msg);
                addr_bits   := pop(request_msg);
                ack_output  := pop(request_msg);
                timeout     := pop(request_msg);
                clk_stretch := pop(request_msg);
                msg_p       := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_slave, to_string(msg_p) & " - I2C must be in slave mode before I2C-ADDRESS can be expected [I2cExpectAddr]");

                -- 7 Bit addressing
                if addr_bits = 7 then
                    expect_byte_excl_clock(toUslv(Address, 7) & choose(is_read, '1', '0'), scl, sda,
                                           to_string(msg_p) & " - 7bit Address Reception [I2cExpectAddr]",
                                           clk_stretch => clk_stretch);
                    send_bit_excl_clock(ack_output, scl, sda,
                                        to_string(msg_p) & " - 7bit Address ACK Transmission [I2cExpectAddr]",
                                        clk_stretch => clk_stretch);
                -- 10 Bit addressing
                elsif addr_bits = 10 then
                    -- First beat
                    expect_byte_excl_clock("11110" & toUslv(Address, 10)(9 downto 8) & choose(is_read, '1', '0'), scl, sda,
                                           to_string(msg_p) & " - 10bit Address Reception, first beat [I2cExpectAddr]",
                                           clk_stretch);
                    send_bit_excl_clock(ack_output, scl, sda,
                                        to_string(msg_p) & " - 10bit Address ACK Transmission, first beat [I2cExpectAddr]",
                                        clk_stretch => clk_stretch);
                    -- Second beat
                    expect_byte_excl_clock(toUslv(Address, 10)(7 downto 0), scl, sda,
                                           to_string(msg_p) & " - 10bit Address Reception, second beat [I2cExpectAddr]",
                                           clk_stretch => clk_stretch);
                    send_bit_excl_clock(ack_output, scl, sda,
                                        to_string(msg_p) & " - 10bit Address ACK Transmission, second beat [I2cExpectAddr]",
                                        clk_stretch => clk_stretch);
                else
                    error(to_string(msg_p) & " - I2cExpectAddr - Illegal addr_bits (must be 7 or 10)");
                end if;

            -- *** Handle General Messages ***
            elsif msg_type = i2c_push_tx_byte_msg then
                -- Push TX Byte
                data         := pop(request_msg);
                expected_ack := pop(request_msg);
                clk_stretch  := pop(request_msg);
                delay        := pop(request_msg);
                msg_p        := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_master or opmode = i2c_slave,
                      to_string(msg_p) & " - I2C must be in master or slave mode before I2C-TX-BYTE can be sent [I2cPushTxByte]");
                check(opmode = i2c_slave or clk_stretch = 0 ns,
                      to_string(msg_p) & " - Clock stretching is only allowed in slave mode [I2cPushTxByte]");
                check(opmode = i2c_master or delay = 0 ns,
                      to_string(msg_p) & " - Delay is only allowed in master mode [I2cPushTxByte]");

                -- Do data
                if data < 0 then
                    data_slv := toSslv(data, 8);
                else
                    data_slv := toUslv(data, 8);
                end if;
                if opmode = i2c_master then
                    wait for delay;
                    send_byte_incl_clock(data_slv, scl, sda,
                                         to_string(msg_p) & " - Send byte in master mode [I2cPushTxByte]");
                    sda <= 'Z';
                    receive_bit_incl_clock(ack, scl, sda,
                                          to_string(msg_p) & " - data ACK in master mode [I2cPushTxByte]");
                else
                    send_byte_excl_clock(data_slv, scl, sda,
                                         to_string(msg_p) & " - Send byte in slave mode [I2cPushTxByte]",
                                         clk_stretch => clk_stretch);
                    i2c_bus_free(scl, sda);
                    receive_bit_excl_clock(ack, scl, sda,
                                           to_string(msg_p) & " - data ACK in slave mode [I2cPushTxByte]",
                                           clk_stretch => clk_stretch);
                end if;
                check_equal(ack, expected_ack, to_string(msg_p) & " - data ACK [I2cPushTxByte]");

            elsif msg_type = i2c_expect_rx_byte_msg then
                -- Expect RX Byte
                data        := pop(request_msg);
                ack_output  := pop(request_msg);
                clk_stretch := pop(request_msg);
                msg_p       := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = i2c_master or opmode = i2c_slave,
                      to_string(msg_p) & " - I2C must be in master or slave mode before I2C-RX-BYTE can be expected [I2cExpectRxByte]");
                check(opmode = i2c_slave or clk_stretch = 0 ns,
                      to_string(msg_p) & " - Clock stretching is only allowed in slave mode [I2cExpectRxByte]");

                -- Do data
                if data < 0 then
                    data_slv := toSslv(data, 8);
                else
                    data_slv := toUslv(data, 8);
                end if;
                if opmode = i2c_master then
                    sda <= 'Z';
                    expect_byte_incl_clock(data_slv, scl, sda,
                                           to_string(msg_p) & " - Receive byte in master mode [I2cExpectRxByte]");
                    send_bit_incl_clock(ack_output, scl, sda,
                                        to_string(msg_p) & " - ACK in master mode [I2cExpectRxByte]");
                else
                    expect_byte_excl_clock(data_slv, scl, sda,
                                           to_string(msg_p) & " - Receive byte in slave mode [I2cExpectRxByte]",
                                           clk_stretch => clk_stretch);
                    send_bit_excl_clock(ack_output, scl, sda,
                                        to_string(msg_p) & " - ACK in slave mode [I2cExpectRxByte]",
                                        clk_stretch => clk_stretch);
                    i2c_bus_free(scl, sda);
                end if;

            elsif msg_type = i2c_force_master_mode_msg then
                -- Pop message
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Force Master Mode
                check(opmode = i2c_slave, to_string(msg_p) & " - I2C must be in slave mode before I2C-MASTER-MODE can be forced [I2cForceMasterMode]");
                opmode := i2c_master;

            elsif msg_type = i2c_force_bus_release_msg then
                -- Pop message
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Force Bus Release
                i2c_bus_free(scl, sda);
                opmode := i2c_idle;

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

end architecture;
