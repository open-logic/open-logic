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

package olo_test_axi_slave_pkg is

    -- Instance type
    type olo_test_axi_slave_t is record
        p_actor        : actor_t;
        DataWidth      : natural;
        AddrWidth      : natural;
        IdWidth        : natural;
        UserWidth      : natural;
        DataBytes      : natural;
    end record;

    -- Message Types
    constant AxiAwMsg : msg_type_t := new_msg_type("axi expect aw");
    constant AxiArMsg : msg_type_t := new_msg_type("axi expect ar");
    constant AxiWMsg : msg_type_t := new_msg_type("axi expect w");
    constant AxiBMsg : msg_type_t := new_msg_type("axi apply b");
    constant AxiRMsg : msg_type_t := new_msg_type("axi apply r");

    -- AW State
    constant AwQueue : queue_t := new_queue;
    shared variable AwInitiated : natural := 0;
    shared variable AwCompleted : natural := 0;

    -- AR State
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

    -- *** Push Individual Messages ***
    -- Expect AW transaction
    procedure expect_aw (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- delay from valid to ready
    );

    -- Expect AR transaction
    procedure expect_ar (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- delay from valid to ready
    );

    -- Expect W transaction (counter based)
    procedure expect_w (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        firstStrb       : std_logic_vector      := "X";
        lastStrb        : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay from valid to ready
        beatDelay       : time                  := 0 ns     -- delay between beats
    );

    -- Expect W transaction (arbitrary data)
    -- allData and allStrb must have the correct length and contain all data and strobes for all beats concatenated.
    -- The data and strobes at the right end (low index) are transferred first.
    procedure expect_w_arbitrary (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        beats           : natural               := 1;
        allData         : unsigned;
        allStrb         : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay from valid to ready
        beatDelay       : time                  := 0 ns     -- delay between beats
    );

    -- Push B transaction
    procedure push_b (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns    -- delay before executing transaction
    );

    -- Push R transaction (counter based)
    procedure push_r (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay before executing transaction
        beatDelay       : time                  := 0 ns     -- delay between beats
    );

    -- Push R transaction (arbitrary data)
    -- allData must have the correct length and contain all data for all beats concatenated.
    -- The data at the right end (low index) are transferred first.
    procedure push_r_arbitrary (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        beats           : natural               := 1;
        allData         : unsigned;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay before executing transaction
        beatDelay       : time                  := 0 ns     -- delay between beats
    );

    -- *** Push Compount Messages ***
    -- Single beat write
    procedure expect_single_write (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        data            : unsigned;
        strb            : std_logic_vector := "X";
        AwReadyDelay    : time := 0 ns;
        WReadyDelay     : time := 0 ns;
        BValidDelay     : time := 0 ns
    );

    -- Single beat read
    procedure push_single_read (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        data            : unsigned;
        ArReadyDelay    : time := 0 ns;
        RValidDelay     : time := 0 ns
    );

    -- Burst write (aligned)
    procedure expect_burst_write_aligned (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural       := 1;
        beats           : natural;
        AwReadyDelay    : time := 0 ns;
        WReadyDelay     : time := 0 ns;
        BValidDelay     : time := 0 ns;
        beatDelay       : time := 0 ns
    );

    -- Burst read (aligned)
    procedure push_burst_read_aligned (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural       := 1;
        beats           : natural;
        ArReadyDelay    : time := 0 ns;
        RValidDelay     : time := 0 ns;
        beatDelay       : time := 0 ns
    );


    -- Constructor
    impure function new_olo_test_axi_slave( dataWidth : natural;
                                            addrWidth : natural;
                                            idWidth   : natural := 0;
                                            userWidth : natural := 0) return olo_test_axi_slave_t;
    -- Casts
    impure function as_sync(instance : olo_test_axi_slave_t) return sync_handle_t;

end package;

package body olo_test_axi_slave_pkg is 
  
    -- *** Push Individual Messages ***
    -- Expect AW transaction
    procedure expect_aw (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- delay from valid to ready
    ) is
        variable msg : msg_t;
        variable id_v : std_logic_vector(AxiSlave.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, AxiSlave.IdWidth, "expect_aw: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(AxiAwMsg);
        push(msg, resize(addr, AxiSlave.AddrWidth));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);        
        push(msg, delay);
        send(net, AxiSlave.p_actor, msg);
    end;

    -- Expect AR transaction
    procedure expect_ar (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        id              : std_logic_vector      := "X";
        len             : positive              := 1;       -- lenght of the transfer in beats (1 = 1 beat)
        burst           : Burst_t               := xBURST_INCR_c;
        delay           : time                  := 0 ns    -- delay from valid to ready
    ) is
        variable msg : msg_t;
        variable id_v : std_logic_vector(AxiSlave.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, AxiSlave.IdWidth, "expect_ar: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(AxiArMsg);
        push(msg, resize(addr, AxiSlave.AddrWidth));
        push(msg, id_v);
        push(msg, len);
        push(msg, burst);        
        push(msg, delay);
        send(net, AxiSlave.p_actor, msg);
    end;

    -- Expect W transaction
    procedure expect_w (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        firstStrb       : std_logic_vector      := "X";
        lastStrb        : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay from valid to ready
        beatDelay       : time                  := 0 ns     -- delay between beats
    ) is
        variable allData_v : unsigned(AxiSlave.DataWidth*beats-1 downto 0);
        variable allStrb_v : std_logic_vector(AxiSlave.DataBytes*beats-1 downto 0) := (others => '1');
        variable Data_v : unsigned(AxiSlave.DataWidth-1 downto 0) := resize(startValue, AxiSlave.DataWidth);
    begin
        -- checks
        if firstStrb /= "X" then
            check_equal(firstStrb'length, AxiSlave.DataBytes, "expect_w: firstStrb has wrong length");
            allStrb_v(AxiSlave.DataBytes-1 downto 0) := firstStrb;
        end if;
        if lastStrb /= "X" then
            check_equal(lastStrb'length, AxiSlave.DataWidth/8, "expect_w: lastStrb has wrong length");
            allStrb_v(allStrb_v'high downto allStrb_v'length-AxiSlave.DataBytes) := lastStrb;
        end if;
        -- assemble data
        for i in 0 to beats-1 loop
            allData_v(AxiSlave.DataWidth*(i+1)-1 downto AxiSlave.DataWidth*i) := Data_v;
            Data_v := Data_v + increment;
            if i = 0 and firstStrb /= "X" then
                allStrb_v(AxiSlave.DataBytes*(i+1)-1 downto AxiSlave.DataBytes*i) := firstStrb;
            elsif i = beats-1 and lastStrb /= "X" then
                allStrb_v(AxiSlave.DataBytes*(i+1)-1 downto AxiSlave.DataBytes*i) := lastStrb;
            end if;
        end loop;
        -- implementation
        expect_w_arbitrary(net, AxiSlave, beats, allData_v, allStrb_v, delay, beatDelay);
    end;

    procedure expect_w_arbitrary (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        beats           : natural               := 1;
        allData         : unsigned;
        allStrb         : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay from valid to ready
        beatDelay       : time                  := 0 ns     -- delay between beats
    ) is
        variable msg : msg_t;
        variable allStrb_v : std_logic_vector(AxiSlave.DataWidth/8*beats-1 downto 0) := (others => '1');
        variable Data_v : unsigned(AxiSlave.DataWidth-1 downto 0);
        variable Strb_v : std_logic_vector(AxiSlave.DataWidth/8-1 downto 0);
        variable Last_v : std_logic;
    begin
        -- checks
        if allStrb /= "X" then
            check_equal(allStrb'length, allStrb_v'length, "expect_w_arbitrary: allStrb has wrong length");
            allStrb_v := allStrb;
        end if;
        check_equal(allData'length, AxiSlave.DataWidth*beats, "expect_w_arbitrary: allData has wrong length");
        -- implementation
        msg := new_msg(AxiWMsg);
        push(msg, delay);
        push(msg, beatDelay);
        for i in 0 to beats-1 loop
            Data_v := allData(AxiSlave.DataWidth*(i+1)-1 downto AxiSlave.DataWidth*i);
            Strb_v := allStrb_v(AxiSlave.DataWidth/8*(i+1)-1 downto AxiSlave.DataWidth/8*i);
            Last_v := '0';
            if i = beats-1 then
                Last_v := '1';
            end if;
            push(msg, Data_v);
            push(msg, Strb_v);
            push(msg, Last_v);
        end loop;
        send(net, AxiSlave.p_actor, msg);
    end;

    -- Push B transaction
    procedure push_b (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns    -- delay before executing transaction
    ) is
        variable msg : msg_t;
        variable id_v : std_logic_vector(AxiSlave.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, AxiSlave.IdWidth, "push_b: id has wrong length");
            id_v := id;
        end if;
        -- implementation
        msg := new_msg(AxiBMsg);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        send(net, AxiSlave.p_actor, msg);
    end;

    -- Push R transaction
    procedure push_r (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        startValue      : unsigned;
        increment       : natural               := 1; 
        beats           : natural               := 1;       -- number of beats to write
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay before executing transaction
        beatDelay       : time                  := 0 ns     -- delay between beats
    ) is
        variable allData_v : unsigned(AxiSlave.DataWidth*beats-1 downto 0);
        variable Data_v : unsigned(AxiSlave.DataWidth-1 downto 0) := resize(startValue, AxiSlave.DataWidth);
        variable id_v : std_logic_vector(AxiSlave.IdWidth-1 downto 0) := (others => '0');
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, AxiSlave.IdWidth, "push_r: id has wrong length");
            id_v := id;
        end if;
        -- assemble data
        for i in 0 to beats-1 loop
            allData_v(AxiSlave.DataWidth*(i+1)-1 downto AxiSlave.DataWidth*i) := Data_v;
            Data_v := Data_v + increment;
        end loop;
        -- implementation
        push_r_arbitrary(net, AxiSlave, beats, allData_v, resp, id_v, delay, beatDelay);
    end;   
    
    procedure push_r_arbitrary (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        beats           : natural               := 1;
        allData         : unsigned;
        resp            : Resp_t                := xRESP_OKAY_c;
        id              : std_logic_vector      := "X";
        delay           : time                  := 0 ns;    -- delay before executing transaction
        beatDelay       : time                  := 0 ns     -- delay between beats
    ) is
        variable msg : msg_t;
        variable id_v : std_logic_vector(AxiSlave.IdWidth-1 downto 0) := (others => '0');
        variable Data_v : unsigned(AxiSlave.DataWidth-1 downto 0);
        variable Last_v : std_logic;
    begin
        -- checks
        if id /= "X" then
            check_equal(id'length, AxiSlave.IdWidth, "push_r_arbitrary: id has wrong length");
            id_v := id;
        end if;
        check_equal(allData'length, AxiSlave.DataWidth*beats, "push_r_arbitrary: allData has wrong length");
        -- implementation
        msg := new_msg(AxiRMsg);
        push(msg, resp);
        push(msg, id_v);
        push(msg, delay);
        push(msg, beatDelay);
        for i in 0 to beats-1 loop
            Data_v := allData(AxiSlave.DataWidth*(i+1)-1 downto AxiSlave.DataWidth*i);
            Last_v := '0';
            if i = beats-1 then
                Last_v := '1';
            end if;
            push(msg, Data_v);
            push(msg, Last_v);
        end loop;
        send(net, AxiSlave.p_actor, msg);
    end;
    

    -- *** Push Compount Messages ***
    -- Single beat write
    procedure expect_single_write (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        data            : unsigned;
        strb            : std_logic_vector := "X";
        AwReadyDelay    : time := 0 ns;
        WReadyDelay     : time := 0 ns;
        BValidDelay     : time := 0 ns
    ) is
    begin
        expect_aw(net, AxiSlave, addr, delay => AwReadyDelay);
        expect_w(net, AxiSlave, data, firstStrb => strb, delay => WReadyDelay);
        push_b(net, AxiSlave, resp => xRESP_OKAY_c, delay => BValidDelay);
    end;

    -- Single beat read
    procedure push_single_read (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        data            : unsigned;
        ArReadyDelay    : time := 0 ns;
        RValidDelay     : time := 0 ns
    ) is
    begin
        expect_ar(net, AxiSlave, addr, delay => ArReadyDelay);
        push_r(net, AxiSlave, data, resp => xRESP_OKAY_c, delay => RValidDelay);
    end;

    -- Burst write (aligned)
    procedure expect_burst_write_aligned (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural       := 1;
        beats           : natural;
        AwReadyDelay    : time := 0 ns;
        WReadyDelay     : time := 0 ns;
        BValidDelay     : time := 0 ns;
        beatDelay       : time := 0 ns
    ) is
    begin
        expect_aw(net, AxiSlave, addr, len => beats, delay => AwReadyDelay);
        expect_w(net, AxiSlave, dataStart, dataIncrement, beats, delay => WReadyDelay, beatDelay => beatDelay);
        push_b(net, AxiSlave, resp => xRESP_OKAY_c, delay => BValidDelay);
    end;

    -- Burst read (aligned)
    procedure push_burst_read_aligned (
        signal net      : inout network_t;
        AxiSlave        : olo_test_axi_slave_t;
        addr            : unsigned;
        dataStart       : unsigned;
        dataIncrement   : natural       := 1;
        beats           : natural;
        ArReadyDelay    : time := 0 ns;
        RValidDelay     : time := 0 ns;
        beatDelay       : time := 0 ns
    ) is
    begin
        expect_ar(net, AxiSlave, addr, len => beats, delay => ArReadyDelay);
        push_r(net, AxiSlave, dataStart, dataIncrement, beats, resp => xRESP_OKAY_c, delay => RValidDelay, beatDelay => beatDelay);
    end;
    

    -- Constructor
    impure function new_olo_test_axi_slave(dataWidth : natural;
                                addrWidth : natural;
                                idWidth   : natural := 0;
                                userWidth : natural := 0 ) return olo_test_axi_slave_t is
    begin
        return (p_actor => new_actor, 
                DataWidth => dataWidth, 
                AddrWidth => addrWidth,
                IdWidth => idWidth,
                UserWidth => userWidth,
                DataBytes => dataWidth/8);
    end;
        
    -- Casts
    impure function as_sync(instance : olo_test_axi_slave_t) return sync_handle_t is
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
        Clk          : in  std_logic;
        Rst          : in  std_logic;
        AxiMs        : in  AxiMs_r;
        AxiSm        : out AxiSm_r
    );
end entity;

architecture a of olo_test_axi_slave_vc is
begin
    -- Main Process
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
    end process;

    -- AW Process
    p_aw : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable addr : unsigned(instance.AddrWidth-1 downto 0);
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable len : positive;
        variable burst : Burst_t;
        variable delay : time;
    begin
        -- Initalize
        AxiSm.AwReady <= '0';
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
                    wait until rising_edge(Clk) and AxiMs.AwValid = '1';
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiSm.AwReady   <= '1';
                wait until rising_edge(Clk) and AxiMs.AwValid = '1';
                check_equal(AxiMs.AwAddr, addr, "expect_aw: AwAddr not as expected");
                if id /= "X" then
                    check_equal(AxiMs.AwId, id, "expect_aw: AwId not as expected");
                end if;
                check_equal(AxiMs.AwLen, len-1, "expect_aw: AwLen not as expected");
                check_equal(AxiMs.AwBurst, burst, "expect_aw: AwBurst not as expected");
                AxiSm.AwReady    <= '0';
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
        -- Initalize
        AxiSm.ArReady <= '0';
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
                    wait until rising_edge(Clk) and AxiMs.ArValid = '1';
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiSm.ArReady   <= '1';
                wait until rising_edge(Clk) and AxiMs.ArValid = '1';
                check_equal(AxiMs.ArAddr, addr, "expect_ar: ArAddr not as expected");
                if id /= "X" then
                    check_equal(AxiMs.ArId, id, "expect_ar: ArId not as expected");
                end if;
                check_equal(AxiMs.ArLen, len-1, "expect_ar: ArLen not as expected");
                check_equal(AxiMs.ArBurst, burst, "expect_ar: ArBurst not as expected");
                AxiSm.ArReady    <= '0';
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
        variable strb : std_logic_vector(instance.DataWidth/8-1 downto 0);
        variable last : std_logic;
        variable delay : time;
        variable data : unsigned(instance.DataWidth-1 downto 0);
        variable beatDelay : time;
    begin
        -- Initalize
        AxiSm.WReady <= '0';
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(WQueue) then
                wait until not is_empty(WQueue) and rising_edge(Clk);
            end if;
            -- wait until address received
            if WCompleted = AwCompleted then
                wait until WCompleted < AwCompleted and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(WQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiWMsg then
                -- Pop delays
                delay := pop(msg);
                beatDelay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait until rising_edge(Clk) and AxiMs.WValid = '1';
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiSm.WReady   <= '1';
                loop
                    -- Pop Information
                    data := pop(msg);
                    strb := pop(msg);
                    last := pop(msg);
                    wait until rising_edge(Clk) and AxiMs.WValid = '1';
                    -- Data
                    if signed(AxiMs.WStrb) = -1 then -- compare wordwise is all strobes are set
                        check_equal(AxiMs.WData, data, "expect_w: WData not as expected");
                    else -- compare bytewise otherwise
                        for i in 0 to AxiMs.WData'length/8-1 loop
                            if AxiMs.WStrb(i) = '1' then
                                check_equal(AxiMs.WData(8*(i+1)-1 downto 8*i), data(8*(i+1)-1 downto 8*i), "expect_w: Wrong WData[" & integer'image(i) & "]");
                            end if;
                        end loop;
                    end if;
                    -- Strobe
                    check_equal(AxiMs.WStrb, strb, "expect_w: WStrb not as expected");
                    -- Last
                    check_equal(AxiMs.WLast, last, "expect_w: WLast not as expected");
                    -- Add delay
                    if beatDelay > 0 ns then
                        AxiSm.WReady   <= '0';
                        wait for beatDelay;
                        wait until rising_edge(Clk);
                        AxiSm.WReady   <= '1';
                    end if;
                    -- Abort loop after last word
                    if last = '1' then
                        exit;
                    end if;
                end loop;
                AxiSm.WReady    <= '0';
                WCompleted := WCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;
    
    -- B process
    b_process : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable resp : Resp_t;
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable delay : time;
    begin
        -- Initalize
        AxiSm.BValid <= '0';
        AxiSm.BResp <= xRESP_OKAY_c;
        AxiSm.BId <= toUslv(0, instance.IdWidth);
        AxiSm.BUser <= toUslv(0, AxiSm.BUser'length);
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(BQueue) then
                wait until not is_empty(BQueue) and rising_edge(Clk);
            end if;
            -- Wait until W completed
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
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                AxiSm.BValid   <= '1';
                AxiSm.BResp    <= resp;
                AxiSm.BId      <= id;
                wait until rising_edge(Clk) and AxiMs.BReady = '1';
                AxiSm.BValid    <= '0';
                AxiSm.BResp     <= xRESP_OKAY_c;
                AxiSm.BId       <= toUslv(0, instance.IdWidth);
                BCompleted := BCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;

    -- R process
    r_process : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable resp : Resp_t;
        variable id : std_logic_vector(instance.IdWidth-1 downto 0);
        variable delay : time;
        variable data : unsigned(instance.DataWidth-1 downto 0);
        variable last : std_logic;
        variable beatDelay : time;
    begin
        -- Initalize
        AxiSm.RValid <= '0';
        AxiSm.RResp <= xRESP_OKAY_c;
        AxiSm.RId <= toUslv(0, instance.IdWidth);
        AxiSm.RData <= toUslv(0, instance.DataWidth);
        AxiSm.RUser <= toUslv(0, AxiSm.RUser'length);
        AxiSm.RLast <= '0';
        wait until rising_edge(Clk);
        -- loop messages
        loop
            -- wait until message available
            if is_empty(RQueue) then
                wait until not is_empty(RQueue) and rising_edge(Clk);
            end if;
            -- Wait until AR received
            if RCompleted = ArCompleted then
                wait until RCompleted < ArCompleted and rising_edge(Clk);
            end if;
            -- get message
            msg := pop(RQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = AxiRMsg then
                -- Pop per transfer information
                resp := pop(msg);
                id := pop(msg);
                delay := pop(msg);
                beatDelay := pop(msg);
                -- Execute
                if delay > 0 ns then
                    wait for delay;
                    wait until rising_edge(Clk);
                end if;
                loop
                    -- Pop Information
                    data := pop(msg);
                    last := pop(msg);
                    -- Data
                    AxiSm.RData <= std_logic_vector(data);
                    -- Last
                    AxiSm.RLast <= last;
                    -- Resp
                    AxiSm.RResp <= resp;
                    -- Id
                    AxiSm.RId <= id;
                    -- HAnshake
                    AxiSm.RValid   <= '1';
                    wait until rising_edge(Clk) and AxiMs.RReady = '1';
                    AxiSm.RValid    <= '0';
                    if beatDelay > 0 ns then
                        wait for beatDelay;
                        wait until rising_edge(Clk);
                    end if;
                    -- Abort loop after last word
                    if last = '1' then
                        exit;
                    end if;
                end loop;
                AxiSm.RData <= toUslv(0, instance.DataWidth);
                AxiSm.RLast <= '0';
                Axism.RResp <= xRESP_OKAY_c;
                Axism.RId <= toUslv(0, instance.IdWidth);
                RCompleted := RCompleted + 1;
            else
                unexpected_msg_type(msg_type);
            end if;
            delete(msg);
        end loop;
        wait;
    end process;
end;