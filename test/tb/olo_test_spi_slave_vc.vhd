------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
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
    use ieee.math_real.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

package olo_test_spi_slave_pkg is  

    -- *** VUnit instance type ***
    type olo_test_spi_slave_t is record
        p_actor         : actor_t;
        LsbFirst        : boolean;
        MaxTransWidth   : positive;
        BusFrequency    : real;
    end record;

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        timeout             : time              := 1 ms;
        msg             : string                := ""
    );

    -- *** VUnit Operations ***
    -- Message Types
    constant SpiSlavePushTransactionMsg  : msg_type_t := new_msg_type("SpiSlavePushTransaction");

    -- Constructor
    impure function new_olo_test_spi_slave( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth   : natural := 32) return olo_test_spi_slave_t;
        
    -- Casts
    impure function as_sync(instance : olo_test_spi_slave_t) return sync_handle_t;

end;

package body olo_test_spi_slave_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        timeout             : time              := 1 ms;
        msg                 : string            := ""
    ) is
        variable request_msg    : msg_t;
        variable mosi_v : std_logic_vector(spi.MaxTransWidth-1 downto 0) := (others => '0');
        variable miso_v : std_logic_vector(spi.MaxTransWidth-1 downto 0) := (others => 'X');
    begin
        -- checks
        if data_mosi /= "X" then
            check_equal(data_mosi'length, transaction_bits, "data_mosi length must match transaction bits");
            mosi_v(transaction_bits-1 downto 0) := data_mosi;
        end if;
        if data_miso /= "X" then
            check_equal(data_miso'length, transaction_bits, "data_miso length must match transaction bits");
            miso_v(transaction_bits-1 downto 0) := data_miso;
        end if;

        -- Create message
        push(request_msg, transaction_bits);
        push(request_msg, mosi_v);
        push(request_msg, miso_v);
        push(request_msg, timeout);
        push_string(request_msg, msg);
        
        -- Send message
        send(net, spi.p_actor, SpiSlavePushTransactionMsg, request_msg);
    end;

    -- Constructor
    impure function new_olo_test_spi_slave( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth   : natural := 32) return olo_test_spi_slave_t is
    begin
        return (p_actor => new_actor, 
                LsbFirst => lsbFirst,
                MaxTransWidth => maxTransWidth,
                BusFrequency => busFrequency);
    end;
        
    -- Casts
    impure function as_sync(instance : olo_test_spi_slave_t) return sync_handle_t is
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
    use vunit_lib.sync_pkg.all;

library work;
    use work.olo_test_spi_slave_pkg.all;
    use work.olo_test_activity_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_test_spi_slave_vc is
    generic (
        instance                 : olo_test_spi_slave_t
    );
    port (
        Sclk     : in       std_logic;
        CS_n     : in       std_logic;
        Mosi     : in       std_logic;
        Miso     : out      std_logic
    );
end entity;

architecture rtl of olo_test_spi_slave_vc is

begin

    -- Main Process
    main : process
        -- Messaging
        variable request_msg        : msg_t;
        variable reply_msg          : msg_t;
        variable msg_type           : msg_type_t;
        variable transaction_bits   : positive;
        variable data_mosi          : std_logic_vector(instance.MaxTransWidth-1 downto 0);
        variable data_miso          : std_logic_vector(instance.MaxTransWidth-1 downto 0);
        variable timeout            : time;
        variable msg_p              : string_ptr_t;

    begin
        -- Initialization
        Miso <= 'Z';

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = SpiSlavePushTransactionMsg then
                -- Pop Transaction
                transaction_bits := pop(request_msg);
                data_mosi := pop(request_msg);
                data_miso := pop(request_msg);
                timeout := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Implement transaction

              
	

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;                
        end loop;
    end process;

end;