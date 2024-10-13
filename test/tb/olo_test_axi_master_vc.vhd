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

package olo_test_axi_master_pkg is

    -- Instance type
    type olo_test_axi_master_t is record
        p_actor    : actor_t;
        data_width : natural;
        addr_width : natural;
        id_width   : natural;
        user_width : natural;
    end record;

    -- individual channel messages
    constant axi_aw_msg : msg_type_t := new_msg_type("axi aw");
    constant axi_ar_msg : msg_type_t := new_msg_type("axi ar");
    constant axi_w_msg  : msg_type_t := new_msg_type("axi w");
    constant axi_b_msg  : msg_type_t := new_msg_type("axi b");
    constant axi_r_msg  : msg_type_t := new_msg_type("axi r");

    -- Aw State
    constant aw_queue            : queue_t := new_queue;
    shared variable aw_initiated : natural := 0;
    shared variable aw_completed : natural := 0;

    -- Ar State
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

    -- *** Push individual messages ***
    -- Push AW message
    procedure push_aw (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;     -- lenght of the transfer in beats (1 = 1 beat)
            burst      : Burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns); -- Delay before sending the message

    -- Push AR message
    procedure push_ar (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;     -- lenght of the transfer in beats (1 = 1 beat)
            burst      : Burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns); -- delay before sending the message

    -- Push write message
    procedure push_w (
            signal net  : inout network_t;
            axi_master  : olo_test_axi_master_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;     -- number of beats to write
            first_strb  : std_logic_vector := "X";
            last_strb   : std_logic_vector := "X";
            delay       : time             := 0 ns); -- delay before sending the message

    -- Expect b message (write response)
    procedure expect_b (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            resp       : Resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns); -- delay eady after valid

    -- Expect r message (read response)
    procedure expect_r (
            signal net  : inout network_t;
            axi_master  : olo_test_axi_master_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;    -- number of beats to write
            resp        : Resp_t           := xRESP_OKAY_c;
            id          : std_logic_vector := "X";
            delay       : time             := 0 ns; -- delay ready after valid
            ignore_data : boolean          := false);

    -- *** Push Compount Messages ***
    -- Single beat write
    procedure push_single_write (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            data           : unsigned;
            id             : std_logic_vector := "X";
            strb           : std_logic_vector := "X";
            aw_valid_delay : time             := 0 ns;
            w_valid_delay  : time             := 0 ns;
            b_ready_delay  : time             := 0 ns);

    -- Single beat read & check read data
    procedure expect_single_read (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            data           : unsigned;
            id             : std_logic_vector := "X";
            ar_valid_delay : time             := 0 ns;
            r_ready_delay  : time             := 0 ns);

    -- Burst write (aligned)
    procedure push_burst_write_aligned (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            dataStart      : unsigned;
            dataIncrement  : natural          := 1;
            beats          : natural;
            id             : std_logic_vector := "X";
            burst          : Burst_t          := xBURST_INCR_c;
            aw_valid_delay : time             := 0 ns;
            w_valid_delay  : time             := 0 ns;
            b_ready_delay  : time             := 0 ns);

    -- Burst read (aligned)
    procedure expect_burst_read_aligned (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            dataStart      : unsigned;
            dataIncrement  : natural          := 1;
            beats          : natural;
            id             : std_logic_vector := "X";
            burst          : Burst_t          := xBURST_INCR_c;
            ar_valid_delay : time             := 0 ns;
            r_ready_delay  : time             := 0 ns);

    -- Constructor
    impure function new_olo_test_axi_master (
            data_width : natural;
            addr_width : natural;
            id_width   : natural := 0;
            user_width : natural := 0) return olo_test_axi_master_t;

    -- Casts
    impure function as_sync (instance : olo_test_axi_master_t) return sync_handle_t;

end package;

package body olo_test_axi_master_pkg is

    -- *** Push individual messages ***
    -- Push AW message
    procedure push_aw (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;
            burst      : Burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns) is
        variable msg  : msg_t                                            := new_msg(axi_aw_msg);
        variable id_v : std_logic_vector(axi_master.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_master.id_width, "push_aw: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(addr, axi_master.addr_width));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axi_master.p_actor, msg);
    end procedure;

    -- Push AR message
    procedure push_ar (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            addr       : unsigned;
            id         : std_logic_vector := "X";
            len        : positive         := 1;
            burst      : Burst_t          := xBURST_INCR_c;
            delay      : time             := 0 ns) is
        variable msg  : msg_t                                            := new_msg(axi_ar_msg);
        variable id_v : std_logic_vector(axi_master.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_master.id_width, "push_ar: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(addr, axi_master.addr_width));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axi_master.p_actor, msg);
    end procedure;

    -- Push W message
    procedure push_w (
            signal net  : inout network_t;
            axi_master  : olo_test_axi_master_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;
            first_strb  : std_logic_vector := "X";
            last_strb   : std_logic_vector := "X";
            delay       : time             := 0 ns) is
        variable msg         : msg_t                                                := new_msg(axi_w_msg);
        variable frst_strb_v : std_logic_vector(axi_master.data_width/8-1 downto 0) := (others => '1');
        variable last_strb_v : std_logic_vector(axi_master.data_width/8-1 downto 0) := (others => '1');
    begin
        -- checks
        if first_strb /= "X" then
            check_equal(first_strb'length, axi_master.data_width/8, "push_w: first_strb width mismatch");
            frst_strb_v := first_strb;
        end if;
        if last_strb /= "X" then
            check_equal(last_strb'length, axi_master.data_width/8, "push_w: last_strb width mismatch");
            last_strb_v := last_strb;
        end if;
        -- implementation
        push(msg, resize(start_value, axi_master.data_width));
        push(msg, increment);
        push(msg, beats);
        push(msg, frst_strb_v);
        push(msg, last_strb_v);
        push(msg, delay);
        send(net, axi_master.p_actor, msg);
    end procedure;

    -- Expect B message
    procedure expect_b (
            signal net : inout network_t;
            axi_master : olo_test_axi_master_t;
            resp       : Resp_t           := xRESP_OKAY_c;
            id         : std_logic_vector := "X";
            delay      : time             := 0 ns) is
        variable msg  : msg_t                                            := new_msg(axi_b_msg);
        variable id_v : std_logic_vector(axi_master.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_master.id_width, "expect_b: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        send(net, axi_master.p_actor, msg);
    end procedure;

    -- Expect R message
    procedure expect_r (
            signal net  : inout network_t;
            axi_master  : olo_test_axi_master_t;
            start_value : unsigned;
            increment   : natural          := 1;
            beats       : natural          := 1;
            resp        : Resp_t           := xRESP_OKAY_c;
            id          : std_logic_vector := "X";
            delay       : time             := 0 ns;                 -- Delay ready after valid
            ignore_data : boolean          := false) is
        variable msg  : msg_t                                            := new_msg(axi_r_msg);
        variable id_v : std_logic_vector(axi_master.id_width-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axi_master.id_width, "expect_r: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(start_value, axi_master.data_width));
        push(msg, increment);
        push(msg, beats);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        push(msg, ignore_data);
        send(net, axi_master.p_actor, msg);
    end procedure;

    -- *** Push Compount Messages ***
    -- Single beat write
    procedure push_single_write (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            data           : unsigned;
            id             : std_logic_vector := "X";
            strb           : std_logic_vector := "X";
            aw_valid_delay : time             := 0 ns;
            w_valid_delay  : time             := 0 ns;
            b_ready_delay  : time             := 0 ns) is
    begin
        -- implementation
        push_aw(net, axi_master, addr, id => id, delay => aw_valid_delay);
        push_w(net, axi_master, data, delay => w_valid_delay, first_strb => strb);
        expect_b(net, axi_master, resp => xRESP_OKAY_c, id => id, delay => b_ready_delay);
    end procedure;

    -- Single beat read & check read data
    procedure expect_single_read (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            data           : unsigned;
            id             : std_logic_vector := "X";
            ar_valid_delay : time             := 0 ns;
            r_ready_delay  : time             := 0 ns) is
    begin
        -- implementation
        push_ar(net, axi_master, addr, id => id, delay => ar_valid_delay);
        expect_r(net, axi_master, data, resp => xRESP_OKAY_c, id => id, delay => r_ready_delay);
    end procedure;

    -- Burst write (aligned)
    procedure push_burst_write_aligned (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            dataStart      : unsigned;
            dataIncrement  : natural          := 1;
            beats          : natural;
            id             : std_logic_vector := "X";
            burst          : Burst_t          := xBURST_INCR_c;
            aw_valid_delay : time             := 0 ns;
            w_valid_delay  : time             := 0 ns;
            b_ready_delay  : time             := 0 ns) is
    begin
        -- implementation
        push_aw(net, axi_master, addr, len => beats, id => id, burst => burst, delay => aw_valid_delay);
        push_w(net, axi_master, dataStart, dataIncrement, beats, delay => w_valid_delay);
        expect_b(net, axi_master, resp => xRESP_OKAY_c, id => id, delay => b_ready_delay);
    end procedure;

    -- Burst read (aligned)
    procedure expect_burst_read_aligned (
            signal net     : inout network_t;
            axi_master     : olo_test_axi_master_t;
            addr           : unsigned;
            dataStart      : unsigned;
            dataIncrement  : natural          := 1;
            beats          : natural;
            id             : std_logic_vector := "X";
            burst          : Burst_t          := xBURST_INCR_c;
            ar_valid_delay : time             := 0 ns;
            r_ready_delay  : time             := 0 ns) is
    begin
        -- implementation
        push_ar(net, axi_master, addr, len => beats, id => id, burst => burst, delay => ar_valid_delay);
        expect_r(net, axi_master, dataStart, dataIncrement, beats, resp => xRESP_OKAY_c, id => id, delay => r_ready_delay);
    end procedure;

    -- Constructor
    impure function new_olo_test_axi_master (
            data_width : natural;
            addr_width : natural;
            id_width   : natural := 0;
            user_width : natural := 0) return olo_test_axi_master_t is
    begin
        return (p_actor => new_actor,
                data_width => data_width,
                addr_width => addr_width,
                id_width => id_width,
                user_width => user_width);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_axi_master_t) return sync_handle_t is
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
    use work.olo_test_axi_master_pkg.all;
    use work.olo_test_pkg_axi.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_axi_pkg_protocol.all;

entity olo_test_axi_master_vc is
    generic (
        instance                 : olo_test_axi_master_t
    );
    port (
        clk          : in    std_logic;
        rst          : in    std_logic;
        axi_ms       : out   AxiMs_r;
        axi_sm       : in    AxiSm_r
    );
end entity;

architecture a of olo_test_axi_master_vc is

begin

    -- Main process
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

        wait;
    end process;

    -- AW process
    p_aw : process is
        variable msg      : msg_t;
        variable msg_type : msg_type_t;
        variable addr     : unsigned(instance.addr_width-1 downto 0);
        variable id       : std_logic_vector(instance.id_width-1 downto 0);
        variable len      : positive;
        variable burst    : Burst_t;
        variable delay    : time;
    begin
        -- Initialize
        axi_ms.AwId     <= toUslv(0, axi_ms.AwId'length);
        axi_ms.AwAddr   <= toUslv(0, axi_ms.AwAddr'length);
        axi_ms.AwLen    <= toUslv(0, 8);
        axi_ms.AwSize   <= toUslv(0, 3);
        axi_ms.AwBurst  <= "01";
        axi_ms.AWValid  <= '0';
        axi_ms.AwLock   <= '0';
        axi_ms.AwCache  <= toUslv(0, 4);
        axi_ms.AwProt   <= toUslv(0, 3);
        axi_ms.AwQos    <= toUslv(0, 4);
        axi_ms.AwRegion <= toUslv(0, 4);
        axi_ms.AWUser   <= toUslv(0, axi_ms.AWUser'length);
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
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_ms.AwId    <= id;
                axi_ms.AwAddr  <= std_logic_vector(addr);
                axi_ms.AwLen   <= toUslv(len-1, 8);
                axi_ms.AwSize  <= toUslv(log2(instance.data_width/8), 3);
                axi_ms.AwBurst <= burst;
                axi_ms.AWValid <= '1';
                wait until rising_edge(clk) and axi_sm.AwReady = '1';
                axi_ms.AWValid <= '0';
                axi_ms.AwId    <= toUslv(0, axi_ms.AwId'length);
                axi_ms.AwAddr  <= toUslv(0, axi_ms.AwAddr'length);
                axi_ms.AwLen   <= toUslv(0, 8);
                axi_ms.AwSize  <= toUslv(0, 3);
                axi_ms.AwBurst <= xBURST_INCR_c;
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
        -- Initialize
        axi_ms.ArId     <= toUslv(0, axi_ms.ArId'length);
        axi_ms.ArAddr   <= toUslv(0, axi_ms.ArAddr'length);
        axi_ms.ArLen    <= toUslv(0, 8);
        axi_ms.ArSize   <= toUslv(0, 3);
        axi_ms.ArBurst  <= "01";
        axi_ms.ArValid  <= '0';
        axi_ms.ArLock   <= '0';
        axi_ms.ArCache  <= toUslv(0, 4);
        axi_ms.ArProt   <= toUslv(0, 3);
        axi_ms.ArQos    <= toUslv(0, 4);
        axi_ms.ArRegion <= toUslv(0, 4);
        axi_ms.ArUser   <= toUslv(0, axi_ms.ArUser'length);
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
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_ms.ArId    <= id;
                axi_ms.ArAddr  <= std_logic_vector(addr);
                axi_ms.ArLen   <= toUslv(len-1, 8);
                axi_ms.ArSize  <= toUslv(log2(instance.data_width/8), 3);
                axi_ms.ArBurst <= burst;
                axi_ms.ArValid <= '1';
                wait until rising_edge(clk) and axi_sm.ArReady = '1';
                axi_ms.ArValid <= '0';
                axi_ms.ArId    <= toUslv(0, axi_ms.ArId'length);
                axi_ms.ArAddr  <= toUslv(0, axi_ms.ArAddr'length);
                axi_ms.ArLen   <= toUslv(0, 8);
                axi_ms.ArSize  <= toUslv(0, 3);
                axi_ms.ArBurst <= xBURST_INCR_c;
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
        variable msg         : msg_t;
        variable msg_type    : msg_type_t;
        variable start_value : unsigned(instance.data_width-1 downto 0);
        variable increment   : natural;
        variable beats       : natural;
        variable first_strb  : std_logic_vector(instance.data_width/8-1 downto 0);
        variable last_strb   : std_logic_vector(instance.data_width/8-1 downto 0);
        variable delay       : time;
        variable data        : unsigned(instance.data_width-1 downto 0);
    begin
        -- Initialize
        axi_ms.WData  <= toUslv(0, axi_ms.WData'length);
        axi_ms.WStrb  <= toUslv(0, axi_ms.WStrb'length);
        axi_ms.WLast  <= '0';
        axi_ms.WValid <= '0';
        axi_ms.WUser  <= toUslv(0, axi_ms.WUser'length);
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(w_queue) then
                wait until not is_empty(w_queue) and rising_edge(clk);
            end if;
            -- wait until address is sent
            if w_completed = aw_completed then
                wait until w_completed < aw_completed and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(w_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_w_msg then
                -- Pop Information
                start_value := pop(msg);
                increment   := pop(msg);
                beats       := pop(msg);
                first_strb  := pop(msg);
                last_strb   := pop(msg);
                delay       := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                data := start_value;

                -- loop through beats
                for i in 0 to beats-1 loop
                    -- Data
                    axi_ms.WData <= std_logic_vector(data);
                    -- Strobe
                    if i = 0 then
                        axi_ms.WStrb <= first_strb;
                    elsif i = beats-1 then
                        axi_ms.WStrb <= last_strb;
                    else
                        axi_ms.WStrb <= onesVector(axi_ms.WStrb'length);
                    end if;
                    -- Last
                    if i = beats-1 then
                        axi_ms.WLast <= '1';
                    else
                        axi_ms.WLast <= '0';
                    end if;
                    -- Valid
                    axi_ms.WValid <= '1';
                    wait until rising_edge(clk) and axi_sm.WReady = '1';
                    axi_ms.WValid <= '0';
                    data          := data + increment;
                end loop;

                axi_ms.WData <= toUslv(0, axi_ms.WData'length);
                axi_ms.WStrb <= toUslv(0, axi_ms.WStrb'length);
                axi_ms.WLast <= '0';
                w_completed  := w_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- B process
    p_b : process is
        variable msg      : msg_t;
        variable msg_type : msg_type_t;
        variable resp     : Resp_t;
        variable id       : std_logic_vector(instance.id_width-1 downto 0);
        variable delay    : time;
    begin
        -- Initialize
        axi_ms.BReady <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(b_queue) then
                wait until not is_empty(b_queue) and rising_edge(clk);
            end if;
            -- Wait until write is completed
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
                    wait until rising_edge(clk) and axi_sm.BValid = '1';
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_ms.BReady <= '1';
                wait until rising_edge(clk) and axi_sm.BValid = '1';
                check_equal(axi_sm.BResp, resp, "expect_b: BResp not as expected");
                if id /= "X" then
                    check_equal(axi_sm.BId, id, "expect_b: BId not as expected");
                end if;
                axi_ms.BReady <= '0';
                b_completed   := b_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

    -- R process
    p_r : process is
        variable msg         : msg_t;
        variable msg_type    : msg_type_t;
        variable start_value : unsigned(instance.data_width-1 downto 0);
        variable increment   : natural;
        variable beats       : natural;
        variable resp        : Resp_t;
        variable id          : std_logic_vector(instance.id_width-1 downto 0);
        variable delay       : time;
        variable data        : unsigned(instance.data_width-1 downto 0);
        variable ignore_data : boolean;
    begin
        -- Initialize
        axi_ms.RReady <= '0';
        wait until rising_edge(clk);

        -- loop messages
        loop
            -- wait until message available
            if is_empty(r_queue) then
                wait until not is_empty(r_queue) and rising_edge(clk);
            end if;
            -- wait until address is sent
            if r_completed = ar_completed then
                wait until r_completed < ar_completed and rising_edge(clk);
            end if;
            -- get message
            msg      := pop(r_queue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = axi_r_msg then
                -- Pop Information
                start_value := pop(msg);
                increment   := pop(msg);
                beats       := pop(msg);
                resp        := pop(msg);
                id          := pop(msg);
                delay       := pop(msg);
                ignore_data := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(clk) and axi_sm.RValid = '1';
                    wait for delay;
                    wait until rising_edge(clk);
                end if;
                axi_ms.RReady <= '1';
                data          := start_value;

                -- loop through beats
                for i in 0 to beats-1 loop
                    wait until rising_edge(clk) and axi_sm.RValid = '1';
                    if not ignore_data then
                        check_equal(axi_sm.RData, data, "expect_r: RData not as expected");
                    end if;
                    check_equal(axi_sm.RResp, resp, "expect_r: RResp not as expected");
                    if id /= "X" then
                        check_equal(axi_sm.RId, id, "expect_r: RId not as expected");
                    end if;
                    data          := data + increment;
                    axi_ms.Rready <= '0';
                    wait until rising_edge(clk);
                    axi_ms.RReady <= '1';
                end loop;

                axi_ms.RReady <= '0';
                r_completed   := r_completed + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;

        wait;
    end process;

end architecture;

---------------------------------------------------------------------------------------------------
-- AXI Lite Master Verification Component
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_test_axi_master_pkg.all;
    use work.olo_test_pkg_axi.all;

library olo;
    use olo.olo_base_pkg_math.all;

entity olo_test_axi_lite_master_vc is
    generic (
        instance                 : olo_test_axi_master_t
    );
    port (
        clk           : in    std_logic;
        rst           : in    std_logic;
        axi_ms        : out   AxiMs_r;
        axi_sm        : in    AxiSm_r
    );
end entity;

architecture a of olo_test_axi_lite_master_vc is

    subtype id_range_c   is natural range instance.id_width - 1 downto 0;
    subtype addr_range_c is natural range instance.addr_width - 1 downto 0;
    subtype user_range_c is natural range instance.user_width - 1 downto 0;
    subtype data_range_c is natural range instance.data_width - 1 downto 0;
    subtype byte_range_c is natural range instance.data_width/8 - 1 downto 0;

    signal axi_ms_i : AxiMs_r (ArId(id_range_c), AwId(id_range_c),
                                ArAddr(addr_range_c), AwAddr(addr_range_c),
                                ArUser(user_range_c), AwUser(user_range_c), WUser(user_range_c),
                                WData(data_range_c),
                                WStrb(byte_range_c));

    signal axi_sm_i : AxiSm_r (RId(id_range_c), BId(id_range_c),
                                RUser(user_range_c), BUser(user_range_c),
                                RData(data_range_c));

begin

    axi_ms.ArAddr  <= axi_ms_i.ArAddr;
    axi_ms.ArValid <= axi_ms_i.ArValid;
    axi_ms.RReady  <= axi_ms_i.RReady;
    axi_ms.AwAddr  <= axi_ms_i.AwAddr;
    axi_ms.AwValid <= axi_ms_i.AwValid;
    axi_ms.WData   <= axi_ms_i.WData;
    axi_ms.WStrb   <= axi_ms_i.WStrb;
    axi_ms.WValid  <= axi_ms_i.WValid;
    axi_ms.BReady  <= axi_ms_i.BReady;

    axi_sm_i.ArReady <= axi_sm.ArReady;
    axi_sm_i.RId     <= toUslv(0, instance.id_width);
    axi_sm_i.RData   <= axi_sm.RData;
    axi_sm_i.RResp   <= axi_sm.RResp;
    axi_sm_i.RLast   <= '1';
    axi_sm_i.RUser   <= toUslv(0, instance.user_width);
    axi_sm_i.RValid  <= axi_sm.RValid;
    axi_sm_i.AWReady <= axi_sm.AwReady;
    axi_sm_i.WReady  <= axi_sm.WReady;
    axi_sm_i.BId     <= toUslv(0, instance.id_width);
    axi_sm_i.BResp   <= axi_sm.BResp;
    axi_sm_i.BUser   <= toUslv(0, instance.user_width);
    axi_sm_i.BValid  <= axi_sm.BValid;

    i_full_master : entity work.olo_test_axi_master_vc
        generic map (
            instance => instance
        )
        port map (
            clk      => clk,
            rst      => rst,
            -- AXI MS
            axi_ms   => axi_ms_i,
            axi_sm   => axi_sm_i
        );

end architecture;
