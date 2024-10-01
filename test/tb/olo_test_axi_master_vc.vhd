------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- VC Package
------------------------------------------------------------------------------------------------------------------------
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
        p_actor        : actor_t;
        DataWidth      : natural;
        AddrWidth      : natural;
        IdWidth        : natural;
        UserWidth      : natural;
    end record;

    -- individual channel messages
    constant AxiAwMsg : msg_type_t := new_msg_type("axi aw");
    constant AxiArMsg : msg_type_t := new_msg_type("axi ar");
    constant AxiWMsg : msg_type_t := new_msg_type("axi w");
    constant AxiBMsg : msg_type_t := new_msg_type("axi b");
    constant AxiRMsg : msg_type_t := new_msg_type("axi r");    

    -- Aw State
    constant AwQueue : queue_t := new_queue;
    shared variable AwInitiated : natural := 0;
    shared variable AwCompleted : natural := 0;

    -- Ar State
    constant ArQueue : queue_t := new_queue;
    shared variable ArInitiated : natural := 0;
    shared variable ArCompleted : natural := 0;

    -- W State
    constant WQueue : queue_t := new_queue;
    shared variable WInitiated : natural := 0;
    shared variable WCompleted : natural := 0;

    -- B State
    constant BQueue : queue_t := new_queue;
    shared variable BInitiated : natural := 0;
    shared variable BCompleted : natural := 0;

    -- R State
    constant RQueue : queue_t := new_queue;
    shared variable RInitiated : natural := 0;
    shared variable RCompleted : natural := 0;

    -- *** Push individual messages ***
    -- Push AW message
    procedure push_aw (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- Delay before sending the message
    );

    -- Push AR message
    procedure push_ar (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- delay before sending the message
    );

    -- Push write message
    procedure push_w (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        firstStrb       : std_logic_vector      := "X";
        lastStrb        : std_logic_vector      := "X";
        delay           : time                  := 0 ns     -- delay before sending the message
    );
    
    -- Expect b message (write response)
    procedure expect_b (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns     -- delay eady after valid
    );

    -- Expect r message (read response)
    procedure expect_r (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;   -- delay ready after valid
        ignoreData      : boolean               := false
    );

    -- *** Push Compount Messages ***
    -- Single beat write
    procedure push_single_write (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        data            : unsigned;
        id              : std_logic_vector      := "X";
        strb            : std_logic_vector      := "X";
        awValidDelay    : time := 0 ns;
        wValidDelay     : time := 0 ns;
        bReadyDelay     : time := 0 ns
    );

    -- Single beat read & check read data
    procedure expect_single_read (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        data            : unsigned;
        id              : std_logic_vector      := "X";
        arValidDelay    : time := 0 ns;
        rReadyDelay     : time := 0 ns
    );

    -- Burst write (aligned)
    procedure push_burst_write_aligned (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural             := 1;
        beats           : natural;
        id              : std_logic_vector    := "X";
        burst           : Burst_t             := xBURST_INCR_c;
        awValidDelay    : time := 0 ns;
        wValidDelay     : time := 0 ns;
        bReadyDelay     : time := 0 ns
    );

    -- Burst read (aligned)
    procedure expect_burst_read_aligned (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural             := 1;
        beats           : natural;
        id              : std_logic_vector    := "X";
        burst           : Burst_t             := xBURST_INCR_c;
        arValidDelay    : time := 0 ns;
        rReadyDelay     : time := 0 ns
    );

    -- Constructor
    impure function new_olo_test_axi_master(dataWidth : natural;
                                            addrWidth : natural;
                                            idWidth   : natural := 0;
                                            userWidth : natural := 0) return olo_test_axi_master_t;
    -- Casts
    impure function as_sync(instance : olo_test_axi_master_t) return sync_handle_t;

end package;

package body olo_test_axi_master_pkg is 
    -- *** Push individual messages ***
    -- Push AW message
    procedure push_aw (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns
    ) is
        variable msg : msg_t := new_msg(AxiAwMsg);
        variable id_v : std_logic_vector(axiMaster.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axiMaster.IdWidth, "push_aw: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(addr, axiMaster.AddrWidth));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axiMaster.p_actor, msg);
    end procedure;

    -- Push AR message
    procedure push_ar (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns
    ) is
        variable msg : msg_t := new_msg(AxiArMsg);
        variable id_v : std_logic_vector(axiMaster.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axiMaster.IdWidth, "push_ar: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(addr, axiMaster.AddrWidth));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);
        push(msg, delay);
        send(net, axiMaster.p_actor, msg);
    end procedure;

    -- Push W message
    procedure push_w (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        startValue      : unsigned;
        increment       : natural               := 1;
        beats           : natural               := 1;
        firstStrb       : std_logic_vector      := "X";
        lastStrb        : std_logic_vector      := "X";
        delay           : time                  := 0 ns
    ) is
        variable msg : msg_t := new_msg(AxiWMsg);
        variable firstStrb_v : std_logic_vector(axiMaster.DataWidth/8-1 downto 0) := (others => '1');
        variable lastStrb_v : std_logic_vector(axiMaster.DataWidth/8-1 downto 0) := (others => '1');
    begin
        -- checks
        if firstStrb /= "X" then
            check_equal(firstStrb'length, axiMaster.DataWidth/8, "push_w: firstStrb width mismatch");
            firstStrb_v := firstStrb;
        end if;
        if lastStrb /= "X" then
            check_equal(lastStrb'length, axiMaster.DataWidth/8, "push_w: lastStrb width mismatch");
            lastStrb_v := lastStrb;
        end if;
        -- implementation
        push(msg, resize(startValue, axiMaster.DataWidth));
        push(msg, increment);
        push(msg, beats);
        push(msg, firstStrb_v);
        push(msg, lastStrb_v);
        push(msg, delay);
        send(net, axiMaster.p_actor, msg);
    end procedure;

    -- Expect B message
    procedure expect_b (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns                 -- Delay ready after valid
    ) is
        variable msg : msg_t := new_msg(AxiBMsg);
        variable id_v : std_logic_vector(axiMaster.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axiMaster.IdWidth, "expect_b: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        send(net, axiMaster.p_actor, msg);
    end procedure;
    

    -- Expect R message
    procedure expect_r (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        startValue      : unsigned;
        increment       : natural               := 1;
        beats           : natural               := 1;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;                 -- Delay ready after valid
        ignoreData      : boolean               := false
    ) is
        variable msg : msg_t := new_msg(AxiRMsg);
        variable id_v : std_logic_vector(axiMaster.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, axiMaster.IdWidth, "expect_r: id width mismatch");
            id_v := id;
        end if;
        -- implementation
        push(msg, resize(startValue, axiMaster.DataWidth));
        push(msg, increment);
        push(msg, beats);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        push(msg, ignoreData);
        send(net, axiMaster.p_actor, msg);
    end procedure;

    -- *** Push Compount Messages ***
    -- signgle beat write
    procedure push_single_write (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        data            : unsigned;
        id              : std_logic_vector      := "X";
        strb            : std_logic_vector      := "X";
        awValidDelay    : time := 0 ns;
        wValidDelay     : time := 0 ns;
        bReadyDelay     : time := 0 ns
    ) is
    begin
        -- implementation
        push_aw(net, axiMaster, addr, id => id, delay => awValidDelay);
        push_w(net, axiMaster, data, delay => wValidDelay, firstStrb => strb);
        expect_b(net, axiMaster, resp => xRESP_OKAY_c, id => id, delay => bReadyDelay);
    end procedure;

    -- Burst beat read
    procedure expect_single_read (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        data            : unsigned; 
        id              : std_logic_vector      := "X";
        arValidDelay    : time := 0 ns;
        rReadyDelay     : time := 0 ns
    ) is
    begin
        -- implementation
        push_ar(net, axiMaster, addr, id => id, delay => arValidDelay);
        expect_r(net, axiMaster, data, resp => xRESP_OKAY_c, id => id, delay => rReadyDelay);
    end procedure;

    -- Burst write (aligned)
    procedure push_burst_write_aligned (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural            := 1;
        beats           : natural;
        id              : std_logic_vector      := "X";
        burst           : Burst_t               := xBURST_INCR_c;
        awValidDelay    : time := 0 ns;
        wValidDelay     : time := 0 ns;
        bReadyDelay     : time := 0 ns
    ) is
    begin
        -- implementation
        push_aw(net, axiMaster, addr, len => beats, id => id, burst => burst, delay => awValidDelay);
        push_w(net, axiMaster, dataStart, dataIncrement, beats, delay => wValidDelay);
        expect_b(net, axiMaster, resp => xRESP_OKAY_c, id => id, delay => bReadyDelay);
    end procedure;

    -- Burst read (aligned)
    procedure expect_burst_read_aligned (
        signal net      : inout network_t;
        axiMaster       : olo_test_axi_master_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural            := 1;
        beats           : natural;
        id              : std_logic_vector      := "X";
        burst           : Burst_t               := xBURST_INCR_c;
        arValidDelay    : time := 0 ns;
        rReadyDelay     : time := 0 ns
    ) is
    begin
        -- implementation
        push_ar(net, axiMaster, addr, len => beats, id => id, burst => burst, delay => arValidDelay);
        expect_r(net, axiMaster, dataStart, dataIncrement, beats, resp => xRESP_OKAY_c, id => id, delay => rReadyDelay);
    end procedure;

    -- Constructor
    impure function new_olo_test_axi_master(    dataWidth : natural;
                                                addrWidth : natural;
                                                idWidth   : natural := 0;
                                                userWidth : natural := 0 ) return olo_test_axi_master_t is
    begin
        return (p_actor => new_actor, 
                DataWidth => dataWidth, 
                AddrWidth => addrWidth,
                IdWidth => idWidth,
                UserWidth => userWidth);
    end;
        
    -- Casts
    impure function as_sync(instance : olo_test_axi_master_t) return sync_handle_t is
    begin
        return instance.p_actor;
    end;

end;

------------------------------------------------------------------------------------------------------------------------
-- Component Implementation
------------------------------------------------------------------------------------------------------------------------
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
        Clk          : in  std_logic;
        Rst          : in  std_logic;
        AxiMs        : out AxiMs_r;
        AxiSm        : in  AxiSm_r
    );
end entity;

architecture a of olo_test_axi_master_vc is
begin

    -- Main process
    main : process
        variable request_msg    : msg_t;
        variable reply_msg      : msg_t;
        variable copy_msg       : msg_t;
        variable msg_type       : msg_type_t;
    begin
        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);
            copy_msg := copy(request_msg);
            -- Handle Message
            if msg_type = AxiAwMsg then
                -- AW
                push(AwQueue, copy_msg);
                AwInitiated := AwInitiated + 1;
            elsif msg_type = AxiArMsg then
                -- AR
                push(ArQueue, copy_msg);
                ArInitiated := ArInitiated + 1;
            elsif msg_type = AxiWMsg then
                -- W
                push(WQueue, copy_msg);
                WInitiated := WInitiated + 1;
            elsif msg_type = AxiBMsg then
                -- B
                push(BQueue, copy_msg);
                BInitiated := BInitiated + 1;
            elsif msg_type = AxiRMsg then
                -- R
                push(RQueue, copy_msg);
                RInitiated := RInitiated + 1;
            elsif msg_type = wait_until_idle_msg then
                while AwInitiated /= AwCompleted or
                      ArInitiated /= ArCompleted or
                      WInitiated /= WCompleted or
                      BInitiated /= BCompleted or
                      RInitiated /= RCompleted loop
                    wait until rising_edge(Clk);
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
    p_aw : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable addr : unsigned(instance.AddrWidth-1 downto 0);
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable len : positive;
        variable burst : Burst_t;
        variable delay : time;
    begin
        -- Initialize
        AxiMs.AwId     <= toUslv(0, AxiMs.AwId'length);
        AxiMs.AwAddr   <= toUslv(0, AxiMs.AwAddr'length);
        AxiMs.AwLen    <= toUslv(0, 8);
        AxiMs.AwSize   <= toUslv(0, 3);
        AxiMs.AwBurst  <= "01";
        AxiMs.AWValid  <= '0';
        AxiMs.AwLock   <= '0';
        AxiMs.AwCache  <= toUslv(0, 4);
        AxiMs.AwProt   <= toUslv(0, 3);
        AxiMs.AwQos    <= toUslv(0, 4);
        AxiMs.AwRegion <= toUslv(0, 4);
        AxiMs.AWUser   <= toUslv(0, AxiMs.AWUser'length);
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(AwQueue) then
                wait until not is_empty(AwQueue) and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(AwQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiAwMsg then
                -- Pop Information
                addr := pop(msg);
                id := pop(msg);
                len := pop(msg);
                burst := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiMs.AwId      <= id;
                AxiMs.AwAddr    <= std_logic_vector(addr);
                AxiMs.AwLen     <= toUslv(len-1, 8);
                AxiMs.AwSize    <= toUslv(log2(instance.DataWidth/8), 3);
                AxiMs.AwBurst   <= burst;
                AxiMs.AWValid   <= '1';
                wait until rising_edge(Clk) and AxiSm.AwReady = '1';
                AxiMs.AWValid   <= '0';
                AxiMs.AwId      <= toUslv(0, AxiMs.AwId'length);
                AxiMs.AwAddr    <= toUslv(0, AxiMs.AwAddr'length);
                AxiMs.AwLen     <= toUslv(0, 8);
                AxiMs.AwSize    <= toUslv(0, 3);
                AxiMs.AwBurst   <= xBURST_INCR_c;
                AwCompleted := AwCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;

    -- AR process
    p_ar : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable addr : unsigned(instance.AddrWidth-1 downto 0);
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable len : positive;
        variable burst : Burst_t;
        variable delay : time;
    begin
        -- Initialize
        AxiMs.ArId     <= toUslv(0, AxiMs.ArId'length);
        AxiMs.ArAddr   <= toUslv(0, AxiMs.ArAddr'length);
        AxiMs.ArLen    <= toUslv(0, 8);
        AxiMs.ArSize   <= toUslv(0, 3);
        AxiMs.ArBurst  <= "01";
        AxiMs.ArValid  <= '0';
        AxiMs.ArLock   <= '0';
        AxiMs.ArCache  <= toUslv(0, 4);
        AxiMs.ArProt   <= toUslv(0, 3);
        AxiMs.ArQos    <= toUslv(0, 4);
        AxiMs.ArRegion <= toUslv(0, 4);
        AxiMs.ArUser   <= toUslv(0, AxiMs.ArUser'length);
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(ArQueue) then
                wait until not is_empty(ArQueue) and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(ArQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiArMsg then
                -- Pop Information
                addr := pop(msg);
                id := pop(msg);
                len := pop(msg);
                burst := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiMs.ArId      <= id;
                AxiMs.ArAddr    <= std_logic_vector(addr);
                AxiMs.ArLen     <= toUslv(len-1, 8);
                AxiMs.ArSize    <= toUslv(log2(instance.DataWidth/8), 3);
                AxiMs.ArBurst   <= burst;
                AxiMs.ArValid   <= '1';
                wait until rising_edge(Clk) and AxiSm.ArReady = '1';
                AxiMs.ArValid   <= '0';
                AxiMs.ArId      <= toUslv(0, AxiMs.ArId'length);
                AxiMs.ArAddr    <= toUslv(0, AxiMs.ArAddr'length);
                AxiMs.ArLen     <= toUslv(0, 8);
                AxiMs.ArSize    <= toUslv(0, 3);
                AxiMs.ArBurst   <= xBURST_INCR_c;
                ArCompleted := ArCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);   
        end loop;
        wait;
    end process;

    -- W process
    p_w : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable startValue : unsigned(instance.DataWidth-1 downto 0);
        variable increment : natural;
        variable beats : natural;
        variable firstStrb : std_logic_vector(instance.DataWidth/8-1 downto 0);
        variable lastStrb : std_logic_vector(instance.DataWidth/8-1 downto 0);
        variable delay : time;
        variable data : unsigned(instance.DataWidth-1 downto 0);
    begin
        -- Initialize
        AxiMs.WData    <= toUslv(0, AxiMs.WData'length);
        AxiMs.WStrb    <= toUslv(0, AxiMs.WStrb'length);
        AxiMs.WLast    <= '0';
        AxiMs.WValid   <= '0';
        AxiMs.WUser    <= toUslv(0, AxiMs.WUser'length);
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(WQueue) then
                wait until not is_empty(WQueue) and rising_edge(Clk);
            end if;
            -- wait until address is sent
            if WCompleted = AwCompleted then
                wait until WCompleted < AwCompleted and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(WQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiWMsg then
                -- Pop Information
                startValue := pop(msg);
                increment := pop(msg);
                beats := pop(msg);
                firstStrb := pop(msg);
                lastStrb := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                data := startValue;
                for i in 0 to beats-1 loop
                    -- Data
                    AxiMs.WData    <= std_logic_vector(data);
                    -- Strobe
                    if i = 0 then
                        Axims.WStrb    <= firstStrb;
                    elsif i = beats-1 then
                        AxiMs.WStrb    <= lastStrb;
                    else
                        AxiMs.WStrb    <= onesVector(AxiMs.WStrb'length);
                    end if;
                    -- Last
                    if i = beats-1 then
                        AxiMs.WLast    <= '1';
                    else
                        AxiMs.WLast    <= '0';
                    end if;
                    -- Valid
                    AxiMs.WValid   <= '1';
                    wait until rising_edge(Clk) and AxiSm.WReady = '1';
                    AxiMs.WValid   <= '0';
                    data := data + increment;
                end loop;
                AxiMs.WData    <= toUslv(0, AxiMs.WData'length);
                AxiMs.WStrb    <= toUslv(0, AxiMs.WStrb'length);
                AxiMs.WLast    <= '0';
                WCompleted := WCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;

    -- B process
    p_b : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable resp : Resp_t;
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable delay : time;
    begin
        -- Initialize
        AxiMs.BReady  <= '0';
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(BQueue) then
                wait until not is_empty(BQueue) and rising_edge(Clk);
            end if;
            -- Wait until write is completed
            if BCompleted = WCompleted then
                wait until BCompleted < WCompleted and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(BQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiBMsg then
                -- Pop Information
                resp := pop(msg);
                id := pop(msg);
                delay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(Clk) and AxiSm.BValid = '1';
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiMs.BReady   <= '1';
                wait until rising_edge(Clk) and AxiSm.BValid = '1';
                check_equal(AxiSm.BResp, resp, "expect_b: BResp not as expected");
                if id /= "X" then 
                    check_equal(AxiSm.BId, id, "expect_b: BId not as expected");
                end if;
                AxiMs.BReady    <= '0';
                BCompleted := BCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;

    -- R process
    p_r : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable startValue : unsigned(instance.DataWidth-1 downto 0);
        variable increment : natural;
        variable beats : natural;
        variable resp : Resp_t;
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable delay : time;
        variable data : unsigned(instance.DataWidth-1 downto 0);
        variable ignoreData : boolean;
    begin
        -- Initialize
        AxiMs.RReady   <= '0';
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(RQueue) then
                wait until not is_empty(RQueue) and rising_edge(Clk);
            end if;
            -- wait until address is sent
            if RCompleted = ArCompleted then
                wait until RCompleted < ArCompleted and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(RQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiRMsg then
                -- Pop Information
                startValue := pop(msg);
                increment := pop(msg);
                beats := pop(msg);
                resp := pop(msg);
                id := pop(msg);
                delay := pop(msg);
                ignoreData := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(Clk) and AxiSm.RValid = '1';
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiMs.RReady   <= '1';
                data := startValue;
                for i in 0 to beats-1 loop
                    wait until rising_edge(Clk) and AxiSm.RValid = '1';
                    if not ignoreData then
                        check_equal(AxiSm.RData, data, "expect_r: RData not as expected");
                    end if;
                    check_equal(AxiSm.RResp, resp, "expect_r: RResp not as expected");
                    if id /= "X" then
                        check_equal(AxiSm.RId, id, "expect_r: RId not as expected");
                    end if;
                    data := data + increment;
                    AxiMs.Rready <= '0';
                    wait until rising_edge(Clk);
                    AxiMs.RReady   <= '1';
                end loop;
                AxiMs.RReady   <= '0';
                RCompleted := RCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;

end architecture;

------------------------------------------------------------------------------------------------------------------------
-- AXI Lite Master Verification Component
------------------------------------------------------------------------------------------------------------------------
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
        Clk          : in  std_logic;
        Rst          : in  std_logic;
        AxiMs        : out AxiMs_r;
        AxiSm        : in  AxiSm_r
    );
end entity;

architecture a of olo_test_axi_lite_master_vc is

    subtype IdRange_r   is natural range instance.IdWidth - 1 downto 0;
    subtype AddrRange_r is natural range instance.AddrWidth - 1 downto 0;
    subtype UserRange_r is natural range instance.UserWidth - 1 downto 0;
    subtype DataRange_r is natural range instance.DataWidth - 1 downto 0;
    subtype ByteRange_r is natural range instance.DataWidth/8 - 1 downto 0;

    signal AxiMs_i  : AxiMs_r ( ArId(IdRange_r), AwId(IdRange_r),
                                ArAddr(AddrRange_r), AwAddr(AddrRange_r),
                                ArUser(UserRange_r), AwUser(UserRange_r), WUser(UserRange_r),
                                WData(DataRange_r),
                                WStrb(ByteRange_r));

    signal AxiSm_i  : AxiSm_r ( RId(IdRange_r), BId(IdRange_r),
                                RUser(UserRange_r), BUser(UserRange_r),
                                RData(DataRange_r));

begin

    AxiMs.ArAddr   <= AxiMs_i.ArAddr;
    AxiMs.ArValid  <= AxiMs_i.ArValid;
    AxiMs.RReady   <= AxiMs_i.RReady;
    AxiMs.AwAddr   <= AxiMs_i.AwAddr;
    AxiMs.AwValid  <= AxiMs_i.AwValid;
    AxiMs.WData    <= AxiMs_i.WData;
    AxiMs.WStrb    <= AxiMs_i.WStrb;
    AxiMs.WValid   <= AxiMs_i.WValid;
    AxiMs.BReady   <= AxiMs_i.BReady;

    AxiSm_i.ArReady <= AxiSm.ArReady;
    AxiSm_i.RId     <= toUslv(0, instance.IdWidth);
    AxiSm_i.RData   <= AxiSm.RData;
    AxiSm_i.RResp   <= AxiSm.RResp;
    AxiSm_i.RLast   <= '1';
    AxiSm_i.RUser   <= toUslv(0, instance.UserWidth);
    AxiSm_i.RValid  <= AxiSm.RValid;
    AxiSm_i.AWReady <= AxiSm.AwReady;
    AxiSm_i.WReady  <= AxiSm.WReady;
    AxiSm_i.BId     <= toUslv(0, instance.IdWidth);
    AxiSm_i.BResp   <= AxiSm.BResp;
    AxiSm_i.BUser   <= toUslv(0, instance.UserWidth);
    AxiSm_i.BValid  <= AxiSm.BValid;



    i_full_master : entity work.olo_test_axi_master_vc
        generic map (
            instance => instance
        )
        port map (
            Clk     => Clk,
            Rst     => Rst,
            -- AXI MS
            AxiMs   => AxiMs_i,
            AxiSm   => AxiSm_i
        );
end;
