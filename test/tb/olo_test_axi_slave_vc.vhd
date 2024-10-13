---------------------------------------------------------------------------------------------------
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

library work;
    use work.olo_test_pkg_axi.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_axi_pkg_protocol.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

package olo_test_axi_slave_pkg is

    -- Instance type
    type olo_test_axi_slave_t is record
        p_actor    : actor_t;
        data_width : natural;
        addr_width : natural;
        id_width   : natural;
        user_width : natural;
        data_bytes : natural;
    end record;

    -- Message Types
    constant axi_aw_msg : msg_type_t := new_msg_type("axi expect aw");
    constant axi_ar_msg : msg_type_t := new_msg_type("axi expect ar");
    constant axi_w_msg  : msg_type_t := new_msg_type("axi expect w");
    constant axi_b_msg  : msg_type_t := new_msg_type("axi apply b");
    constant axi_r_msg  : msg_type_t := new_msg_type("axi apply r");

    -- AW State
    constant aw_queue            : queue_t := new_queue;
    shared variable aw_initiated : natural := 0;
    shared variable aw_completed : natural := 0;

    -- AR State
    constant ar_queue            : queue_t := new_queue;
    shared variable ar_initiated : natural := 0;
    shared variable ar_completed : natural := 0;

    -- W State
    constant w_queue            : queue_t := new_queue;
    shared variable w_initiated : natural := 0;
    shared variable w_completed : natural := 0;

    -- B State
    constant b_queue            : queue_t := new_queue;
    shared variable b_initiated : natural := 0;
    shared variable b_completed : natural := 0;

    -- R State
    constant r_queue            : queue_t := new_queue;
    shared variable r_initiated : natural := 0;
    shared variable r_completed : natural := 0;

    -- *** Push Individual Messages ***
    -- Expect AW transaction
    procedure expect_aw (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;     -- length of the transfer in beats (1 = 1 beat)
            burst      : burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns); -- delay from valid to ready

    -- Expect AR transaction
    procedure expect_ar (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;     -- length of the transfer in beats (1 = 1 beat)
            burst      : burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns); -- delay from valid to ready

    -- Expect W transaction (counter based)
    procedure expect_w (
            signal net  : inout network_t;
            axi_slave   : olo_test_axi_slave_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;     -- number of beats to write
            first_strb  : std_logic_vector := "X";
            last_strb   : std_logic_vector := "X";
            delay       : time             := 0 ns;  -- delay from valid to ready
            beat_delay  : time             := 0 ns); -- delay between beats

    -- Expect W transaction (arbitrary data)
    -- all_data and all_strb must have the correct length and contain all data and strobes for all beats concatenated.
    -- The data and strobes at the right end (low index) are transferred first.
    procedure expect_w_arbitrary (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            beats      : natural          := 1;
            all_data   : unsigned;
            all_strb   : std_logic_vector := "X";
            delay      : time             := 0 ns;  -- delay from valid to ready
            beat_delay : time             := 0 ns); -- delay between beats

    -- Push B transaction
    procedure push_b (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            resp       : resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns); -- delay before executing transaction

    -- Push R transaction (counter based)
    procedure push_r (
            signal net  : inout network_t;
            axi_slave   : olo_test_axi_slave_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;     -- number of beats to write
            resp        : resp_t           := xRESP_OKAY_c;
            id          : std_logic_vector := "X";
            delay       : time             := 0 ns;  -- delay before executing transaction
            beat_delay  : time             := 0 ns); -- delay between beats

    -- Push R transaction (arbitrary data)
    -- all_data must have the correct length and contain all data for all beats concatenated.
    -- The data at the right end (low index) are transferred first.
    procedure push_r_arbitrary (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            beats      : natural          := 1;
            all_data   : unsigned;
            resp       : resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns;  -- delay before executing transaction
            beat_delay : time             := 0 ns); -- delay between beats

    -- *** Push Compound Messages ***
    -- Single beat write
    procedure expect_single_write (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data           : unsigned;
            strb           : std_logic_vector := "X";
            aw_ready_delay : time             := 0 ns;
            w_ready_delay  : time             := 0 ns;
            b_valid_delay  : time             := 0 ns);

    -- Single beat read
    procedure push_single_read (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data           : unsigned;
            ar_ready_delay : time := 0 ns;
            r_valid_delay  : time := 0 ns);

    -- Burst write (aligned)
    procedure expect_burst_write_aligned (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data_start     : unsigned;
            data_increment : natural := 1;
            beats          : natural;
            aw_ready_delay : time    := 0 ns;
            w_ready_delay  : time    := 0 ns;
            b_valid_delay  : time    := 0 ns;
            beat_delay     : time    := 0 ns);

    -- Burst read (aligned)
    procedure push_burst_read_aligned (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data_start     : unsigned;
            data_increment : natural := 1;
            beats          : natural;
            ar_ready_delay : time    := 0 ns;
            r_valid_delay  : time    := 0 ns;
            beat_delay     : time    := 0 ns);

    -- Constructor
    impure function new_olo_test_axi_slave (
            data_width : natural;
            addr_width : natural;
            id_width   : natural := 0;
            user_width : natural := 0) return olo_test_axi_slave_t;
    -- Casts
    impure function as_sync (instance : olo_test_axi_slave_t) return sync_handle_t;

end package;

package body olo_test_axi_slave_pkg is

    -- *** Push Individual Messages ***
    -- Expect AW transaction
    procedure expect_aw (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;       -- length of the transfer in beats (1 = 1 beat)
            burst      : burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns) is -- delay from valid to ready
        variable msg : msg_t;
        variable id_v : std_logic_vector(axi_slave.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_slave.id_width, "expect_aw: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(axi_aw_msg);
        push(msg, resize(addr, axi_slave.addr_width));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axi_slave.p_actor, msg);
    end procedure;

    -- Expect AR transaction
    procedure expect_ar (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;       -- length of the transfer in beats (1 = 1 beat)
            burst      : burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns) is -- delay from valid to ready
        variable msg : msg_t;
        variable id_v : std_logic_vector(axi_slave.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_slave.id_width, "expect_ar: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(axi_ar_msg);
        push(msg, resize(addr, axi_slave.addr_width));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axi_slave.p_actor, msg);
    end procedure;

    -- Expect W transaction
    procedure expect_w (
            signal net  : inout network_t;
            axi_slave   : olo_test_axi_slave_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;       -- number of beats to write
            first_strb  : std_logic_vector := "X";
            last_strb   : std_logic_vector := "X";
            delay       : time             := 0 ns;    -- delay from valid to ready
            beat_delay  : time             := 0 ns) is -- delay between beats
        variable all_data_v : unsigned(axi_slave.data_width*beats-1 downto 0);
        variable all_strb_v : std_logic_vector(axi_slave.data_bytes*beats-1 downto 0) := (others => '1');
        variable data_v     : unsigned(axi_slave.data_width-1 downto 0)               := resize(start_value, axi_slave.data_width);
    begin
        -- checks
        if first_strb /= "X" then
            check_equal(first_strb'length, axi_slave.data_bytes, "expect_w: first_strb has wrong length");
            all_strb_v(axi_slave.data_bytes-1 downto 0) := first_strb;
        end if;
        if last_strb /= "X" then
            check_equal(last_strb'length, axi_slave.data_width/8, "expect_w: last_strb has wrong length");
            all_strb_v(all_strb_v'high downto all_strb_v'length-axi_slave.data_bytes) := last_strb;
        end if;

        -- assemble data
        for i in 0 to beats-1 loop
            -- default value
            all_data_v(axi_slave.data_width*(i+1)-1 downto axi_slave.data_width*i) := data_v;

            -- execution
            data_v := data_v + increment;
            if i = 0 and first_strb /= "X" then
                all_strb_v(axi_slave.data_bytes*(i+1)-1 downto axi_slave.data_bytes*i) := first_strb;
            elsif i = beats-1 and last_strb /= "X" then
                all_strb_v(axi_slave.data_bytes*(i+1)-1 downto axi_slave.data_bytes*i) := last_strb;
            end if;
        end loop;

        -- implementation
        expect_w_arbitrary(net, axi_slave, beats, all_data_v, all_strb_v, delay, beat_delay);
    end procedure;

    procedure expect_w_arbitrary (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            beats      : natural          := 1;
            all_data   : unsigned;
            all_strb   : std_logic_vector := "X";
            delay      : time             := 0 ns;    -- delay from valid to ready
            beat_delay : time             := 0 ns) is -- delay between beats
        variable msg        : msg_t;
        variable all_strb_v : std_logic_vector(axi_slave.data_width/8*beats-1 downto 0) := (others => '1');
        variable data_v     : unsigned(axi_slave.data_width-1 downto 0);
        variable strb_v     : std_logic_vector(axi_slave.data_width/8-1 downto 0);
        variable last_v     : std_logic;
    begin
        -- checks
        if all_strb /= "X" then
            check_equal(all_strb'length, all_strb_v'length, "expect_w_arbitrary: all_strb has wrong length");
            all_strb_v := all_strb;
        end if;
        check_equal(all_data'length, axi_slave.data_width*beats, "expect_w_arbitrary: all_data has wrong length");
        -- implementation
        msg := new_msg(axi_w_msg);
        push(msg, delay);
        push(msg, beat_delay);

        -- loop through beats
        for i in 0 to beats-1 loop
            data_v := all_data(axi_slave.data_width*(i+1)-1 downto axi_slave.data_width*i);
            strb_v := all_strb_v(axi_slave.data_width/8*(i+1)-1 downto axi_slave.data_width/8*i);
            last_v := '0';
            if i = beats-1 then
                last_v := '1';
            end if;
            push(msg, data_v);
            push(msg, strb_v);
            push(msg, last_v);
        end loop;

        send(net, axi_slave.p_actor, msg);
    end procedure;

    -- Push B transaction
    procedure push_b (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            resp       : resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns) is -- delay before executing transaction
        variable msg  : msg_t;
        variable id_v : std_logic_vector(axi_slave.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_slave.id_width, "push_b: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(axi_b_msg);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        send(net, axi_slave.p_actor, msg);
    end procedure;

    -- Push R transaction
    procedure push_r (
            signal net  : inout network_t;
            axi_slave   : olo_test_axi_slave_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;       -- number of beats to write
            resp        : resp_t           := xRESP_OKAY_c;
            id          : std_logic_vector := "X";
            delay       : time             := 0 ns;    -- delay before executing transaction
            beat_delay  : time             := 0 ns) is -- delay between beats
        variable all_data_v : unsigned(axi_slave.data_width*beats-1 downto 0);
        variable data_v     : unsigned(axi_slave.data_width-1 downto 0)       := resize(start_value, axi_slave.data_width);
        variable id_v       : std_logic_vector(axi_slave.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_slave.id_width, "push_r: id has wrong length");
            id_v := id;
        end if;

        -- assemble data
        for i in 0 to beats-1 loop
            -- Default value
            all_data_v(axi_slave.data_width*(i+1)-1 downto axi_slave.data_width*i) := data_v;

            -- Actual data
            data_v := data_v + increment;
        end loop;

        -- implementation
        push_r_arbitrary(net, axi_slave, beats, all_data_v, resp, id_v, delay, beat_delay);
    end procedure;

    procedure push_r_arbitrary (
            signal net : inout network_t;
            axi_slave  : olo_test_axi_slave_t;
            beats      : natural          := 1;
            all_data   : unsigned;
            resp       : resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns;    -- delay before executing transaction
            beat_delay : time             := 0 ns) is -- delay between beats
        variable msg    : msg_t;
        variable id_v   : std_logic_vector(axi_slave.id_width-1 downto 0) := (others => '0');
        variable data_v : unsigned(axi_slave.data_width-1 downto 0);
        variable last_v : std_logic;
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_slave.id_width, "push_r_arbitrary: id has wrong length");
            id_v := id;
        end if;
        check_equal(all_data'length, axi_slave.data_width*beats, "push_r_arbitrary: all_data has wrong length");

        -- implementation
        msg := new_msg(axi_r_msg);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        push(msg, beat_delay);

        -- loop through beats
        for i in 0 to beats-1 loop
            data_v := all_data(axi_slave.data_width*(i+1)-1 downto axi_slave.data_width*i);
            last_v := '0';
            if i = beats-1 then
                last_v := '1';
            end if;
            push(msg, data_v);
            push(msg, last_v);
        end loop;

        send(net, axi_slave.p_actor, msg);
    end procedure;

    -- *** Push Compound Messages ***
    -- Single beat write
    procedure expect_single_write (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data           : unsigned;
            strb           : std_logic_vector := "X";
            aw_ready_delay : time             := 0 ns;
            w_ready_delay  : time             := 0 ns;
            b_valid_delay  : time             := 0 ns) is
    begin
        expect_aw(net, axi_slave, addr, delay => aw_ready_delay);
        expect_w(net, axi_slave, data, first_strb => strb, delay => w_ready_delay);
        push_b(net, axi_slave, resp => xRESP_OKAY_c, delay => b_valid_delay);
    end procedure;

    -- Single beat read
    procedure push_single_read (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data           : unsigned;
            ar_ready_delay : time := 0 ns;
            r_valid_delay  : time := 0 ns) is
    begin
        expect_ar(net, axi_slave, addr, delay => ar_ready_delay);
        push_r(net, axi_slave, data, resp => xRESP_OKAY_c, delay => r_valid_delay);
    end procedure;

    -- Burst write (aligned)
    procedure expect_burst_write_aligned (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data_start     : unsigned;
            data_increment : natural := 1;
            beats          : natural;
            aw_ready_delay : time    := 0 ns;
            w_ready_delay  : time    := 0 ns;
            b_valid_delay  : time    := 0 ns;
            beat_delay     : time    := 0 ns) is
    begin
        expect_aw(net, axi_slave, addr, len => beats, delay => aw_ready_delay);
        expect_w(net, axi_slave, data_start, data_increment, beats, delay => w_ready_delay, beat_delay => beat_delay);
        push_b(net, axi_slave, resp => xRESP_OKAY_c, delay => b_valid_delay);
    end procedure;

    -- Burst read (aligned)
    procedure push_burst_read_aligned (
            signal net     : inout network_t;
            axi_slave      : olo_test_axi_slave_t;
            addr           : unsigned;
            data_start     : unsigned;
            data_increment : natural := 1;
            beats          : natural;
            ar_ready_delay : time    := 0 ns;
            r_valid_delay  : time    := 0 ns;
            beat_delay     : time    := 0 ns) is
    begin
        expect_ar(net, axi_slave, addr, len => beats, delay => ar_ready_delay);
        push_r(net, axi_slave, data_start, data_increment, beats, resp => xRESP_OKAY_c, delay => r_valid_delay, beat_delay => beat_delay);
    end procedure;

    -- Constructor
    impure function new_olo_test_axi_slave (
            data_width : natural;
            addr_width : natural;
            id_width   : natural := 0;
            user_width : natural := 0) return olo_test_axi_slave_t is
    begin
        return (p_actor => new_actor,
                data_width => data_width,
                addr_width => addr_width,
                id_width => id_width,
                user_width => user_width,
                data_bytes => data_width/8);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_axi_slave_t) return sync_handle_t is
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
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library work;
    use work.olo_test_axi_slave_pkg.all;
    use work.olo_test_pkg_axi.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_axi_pkg_protocol.all;

entity olo_test_axi_slave_vc is
    generic (
        instance                 : olo_test_axi_slave_t
    );
    port (
        clk          : in    std_logic;
        rst          : in    std_logic;
        axi_ms       : in    AxiMs_r;
        axi_sm       : out   AxiSm_r
    );
end entity;

architecture a of olo_test_axi_slave_vc is

begin

    -- Main Process
    main : process is
        variable request_msg : msg_t;
        variable reply_msg   : msg_t;
        variable copy_msg    : msg_t;
        variable msg_type    : msg_type_t;
    begin

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);
            copy_msg := copy(request_msg);
            -- Handle Message
            if msg_type = axi_aw_msg then
                -- AW
                push(aw_queue, copy_msg);
                aw_initiated := aw_initiated + 1;
            elsif msg_type = axi_ar_msg then
                -- AR
                push(ar_queue, copy_msg);
                ar_initiated := ar_initiated + 1;
            elsif msg_type = axi_w_msg then
                -- W
                push(w_queue, copy_msg);
                w_initiated := w_initiated + 1;
            elsif msg_type = axi_b_msg then
                -- B
                push(b_queue, copy_msg);
                b_initiated := b_initiated + 1;
            elsif msg_type = axi_r_msg then
                -- R
                push(r_queue, copy_msg);
                r_initiated := r_initiated + 1;
            elsif msg_type = wait_until_idle_msg then

                -- Wait until idle
                while aw_initiated /= aw_completed or
                      ar_initiated /= ar_completed or
                      w_initiated /= w_completed or
                      b_initiated /= b_completed or
                      r_initiated /= r_completed loop
                    wait until rising_edge(clk);
                end loop;

                handle_wait_until_idle(net, msg_type, request_msg);
            else
                delete(copy_msg);
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

    -- AW Process
    p_aw : process is
        variable msg      : msg_t;
        variable msg_type : msg_type_t;
        variable addr     : unsigned(instance.addr_width-1 downto 0);
        variable id       : std_logic_vector(instance.id_width-1 downto 0);
        variable len      : positive;
        variable burst    : Burst_t;
        variable delay    : time;
    begin
        -- Initalize
        axi_sm.AwReady <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(aw_queue) then
                wait until not is_empty(aw_queue) and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(aw_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_aw_msg then
                -- Pop Information
                addr  := pop(msg);
                id    := pop(msg);
                len   := pop(msg);
                burst := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(clk) and axi_ms.AwValid = '1';
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_sm.AwReady <= '1';
                wait until rising_edge(clk) and axi_ms.AwValid = '1';
                check_equal(axi_ms.AwAddr, addr, "expect_aw: AwAddr not as expected");
                if id /= "X" then
                    check_equal(axi_ms.AwId, id, "expect_aw: AwId not as expected");
                end if;
                check_equal(axi_ms.AwLen, len-1, "expect_aw: AwLen not as expected");
                check_equal(axi_ms.AwBurst, burst, "expect_aw: AwBurst not as expected");
                axi_sm.AwReady <= '0';
                aw_completed   := aw_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- AR process
    p_ar : process is
        variable msg      : msg_t;
        variable msg_type : msg_type_t;
        variable addr     : unsigned(instance.addr_width-1 downto 0);
        variable id       : std_logic_vector(instance.id_width-1 downto 0);
        variable len      : positive;
        variable burst    : Burst_t;
        variable delay    : time;
    begin
        -- Initalize
        axi_sm.ArReady <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(ar_queue) then
                wait until not is_empty(ar_queue) and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(ar_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_ar_msg then
                -- Pop Information
                addr  := pop(msg);
                id    := pop(msg);
                len   := pop(msg);
                burst := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(clk) and axi_ms.ArValid = '1';
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_sm.ArReady <= '1';
                wait until rising_edge(clk) and axi_ms.ArValid = '1';
                check_equal(axi_ms.ArAddr, addr, "expect_ar: ArAddr not as expected");
                if id /= "X" then
                    check_equal(axi_ms.ArId, id, "expect_ar: ArId not as expected");
                end if;
                check_equal(axi_ms.ArLen, len-1, "expect_ar: ArLen not as expected");
                check_equal(axi_ms.ArBurst, burst, "expect_ar: ArBurst not as expected");
                axi_sm.ArReady <= '0';
                ar_completed   := ar_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- W process
    p_w : process is
        variable msg        : msg_t;
        variable msg_type   : msg_type_t;
        variable strb       : std_logic_vector(instance.data_width/8-1 downto 0);
        variable last       : std_logic;
        variable delay      : time;
        variable data       : unsigned(instance.data_width-1 downto 0);
        variable beat_delay : time;
    begin
        -- Initalize
        axi_sm.WReady <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(w_queue) then
                wait until not is_empty(w_queue) and rising_edge(clk);
            end if;
            -- wait until address received
            if w_completed = aw_completed then
                wait until w_completed < aw_completed and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(w_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_w_msg then
                -- Pop delays
                delay      := pop(msg);
                beat_delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(clk) and axi_ms.WValid = '1';
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_sm.WReady <= '1';

                -- loop through beats
                loop
                    -- Pop Information
                    data := pop(msg);
                    strb := pop(msg);
                    last := pop(msg);
                    wait until rising_edge(clk) and axi_ms.WValid = '1';
                    -- Data
                    if signed(axi_ms.WStrb) = -1 then -- compare wordwise is all strobes are set
                        check_equal(axi_ms.WData, data, "expect_w: WData not as expected");
                    else -- compare bytewise otherwise

                        -- Loop through bytes
                        for i in 0 to axi_ms.WData'length/8-1 loop
                            if axi_ms.WStrb(i) = '1' then
                                check_equal(axi_ms.WData(8*(i+1)-1 downto 8*i), data(8*(i+1)-1 downto 8*i), "expect_w: Wrong WData[" & integer'image(i) & "]");
                            end if;
                        end loop;

                    end if;
                    -- Strobe
                    check_equal(axi_ms.WStrb, strb, "expect_w: WStrb not as expected");
                    -- Last
                    check_equal(axi_ms.WLast, last, "expect_w: WLast not as expected");
                    -- Add delay
                    if beat_delay > 0 ns then
                        axi_sm.WReady <= '0';
                        wait for beat_delay;
                        wait until rising_edge(clk);
                        axi_sm.WReady <= '1';
                    end if;
                    -- Abort loop after last word
                    if last = '1' then
                        exit;
                    end if;
                end loop;

                axi_sm.WReady <= '0';
                w_completed   := w_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- B process
    b_process : process is
        variable msg      : msg_t;
        variable msg_type : msg_type_t;
        variable resp     : Resp_t;
        variable id       : std_logic_vector(instance.id_width-1 downto 0);
        variable delay    : time;
    begin
        -- Initalize
        axi_sm.BValid <= '0';
        axi_sm.BResp  <= xRESP_OKAY_c;
        axi_sm.BId    <= toUslv(0, instance.id_width);
        axi_sm.BUser  <= toUslv(0, axi_sm.BUser'length);
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(b_queue) then
                wait until not is_empty(b_queue) and rising_edge(clk);
            end if;
            -- Wait until W completed
            if b_completed = w_completed then
                wait until b_completed < w_completed and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(b_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_b_msg then
                -- Pop Information
                resp  := pop(msg);
                id    := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_sm.BValid <= '1';
                axi_sm.BResp  <= resp;
                axi_sm.BId    <= id;
                wait until rising_edge(clk) and axi_ms.BReady = '1';
                axi_sm.BValid <= '0';
                axi_sm.BResp  <= xRESP_OKAY_c;
                axi_sm.BId    <= toUslv(0, instance.id_width);
                b_completed   := b_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- R process
    r_process : process is
        variable msg        : msg_t;
        variable msg_type   : msg_type_t;
        variable resp       : Resp_t;
        variable id         : std_logic_vector(instance.id_width-1 downto 0);
        variable delay      : time;
        variable data       : unsigned(instance.data_width-1 downto 0);
        variable last       : std_logic;
        variable beat_delay : time;
    begin
        -- Initalize
        axi_sm.RValid <= '0';
        axi_sm.RResp  <= xRESP_OKAY_c;
        axi_sm.RId    <= toUslv(0, instance.id_width);
        axi_sm.RData  <= toUslv(0, instance.data_width);
        axi_sm.RUser  <= toUslv(0, axi_sm.RUser'length);
        axi_sm.RLast  <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(r_queue) then
                wait until not is_empty(r_queue) and rising_edge(clk);
            end if;
            -- Wait until AR received
            if r_completed = ar_completed then
                wait until r_completed < ar_completed and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(r_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_r_msg then
                -- Pop per transfer information
                resp       := pop(msg);
                id         := pop(msg);
                delay      := pop(msg);
                beat_delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(clk);
                end if;

                -- Loop through beats
                loop
                    -- Pop Information
                    data := pop(msg);
                    last := pop(msg);
                    -- Apply AXI data
                    axi_sm.RData  <= std_logic_vector(data);
                    axi_sm.RLast  <= last;
                    axi_sm.RResp  <= resp;
                    axi_sm.RId    <= id;
                    axi_sm.RValid <= '1';
                    wait until rising_edge(clk) and axi_ms.RReady = '1';
                    axi_sm.RValid <= '0';
                    if beat_delay > 0 ns then
                        wait for beat_delay;
                        wait until rising_edge(clk);
                    end if;
                    -- Abort loop after last word
                    if last = '1' then
                        exit;
                    end if;
                end loop;

                -- Return to idle
                axi_sm.RData <= toUslv(0, instance.data_width);
                axi_sm.RLast <= '0';
                axi_sm.RResp <= xRESP_OKAY_c;
                axi_sm.RId   <= toUslv(0, instance.id_width);
                r_completed  := r_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

end architecture;