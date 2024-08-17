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
        CPHA            : integer range 0 to 1;
        CPOL            : integer range 0 to 1;
    end record;

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_slave_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        timeout             : time              := 1 ms;
        msg                 : string                := ""
    );

    -- *** VUnit Operations ***
    -- Message Types
    constant SpiSlavePushTransactionMsg  : msg_type_t := new_msg_type("SpiSlavePushTransaction");

    -- Constructor
    impure function new_olo_test_spi_slave( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth   : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_slave_t;
        
    -- Casts
    impure function as_sync(instance : olo_test_spi_slave_t) return sync_handle_t;

end;

package body olo_test_spi_slave_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_slave_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        timeout             : time              := 1 ms;
        msg                 : string            := ""
    ) is
        variable Msg_v : msg_t := new_msg(SpiSlavePushTransactionMsg);
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
        push(Msg_v, transaction_bits);
        push(Msg_v, mosi_v);
        push(Msg_v, miso_v);
        push(Msg_v, timeout);
        push_string(Msg_v, msg);
        
        -- Send message
        send(net, spi.p_actor, Msg_v);
    end;

    -- Constructor
    impure function new_olo_test_spi_slave( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth   : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_slave_t is
    begin
        return (p_actor => new_actor, 
                LsbFirst => lsbFirst,
                MaxTransWidth => maxTransWidth,
                BusFrequency => busFrequency,
                CPHA => cpha,
                CPOL => cpol);
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

        -- Shift Registers
        variable ShiftRegRx_v : std_logic_vector(instance.MaxTransWidth-1 downto 0);
        variable ShiftRegTx_v : std_logic_vector(instance.MaxTransWidth-1 downto 0);

        -- Others
        variable LastEdge_v   : time;

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

                -- Wait for CSn
                WaitForValueStdl(Cs_n, '0', timeout, to_string(msg_p));
                ShiftRegTx_v := data_miso;
                ShiftRegRx_v := (others => 'U');              

                -- loop over bits
                for i in 0 to transaction_bits - 1 loop

                    -- Wait for apply edge 
                    if (instance.CPHA = 1) and (i /= transaction_bits - 1) then
                        if instance.CPOL = 0 then
                            wait until rising_edge(Sclk);
                        else
                            wait until falling_edge(Sclk);
                        end if;
                    elsif (instance.CPHA = 0) and (i /= 0) then
                        if instance.CPOL = 0 then
                            wait until falling_edge(Sclk);
                        else
                            wait until rising_edge(Sclk);
                        end if;
                    end if;

                    -- shift TX
                    if instance.LsbFirst then
                        Miso <= ShiftRegTx_v(0);
                        ShiftRegTx_v := 'U' & ShiftRegTx_v(instance.MaxTransWidth - 1 downto 1);
                    else
                        Miso <= ShiftRegTx_v(transaction_bits - 1);
                        ShiftRegTx_v := ShiftRegTx_v(instance.MaxTransWidth - 2 downto 0) & 'U';
                    end if;

                    -- Wait for transfer edge
                    if ((instance.CPOL = 0) and (instance.CPHA = 0)) or ((instance.CPOL = 1) and (instance.CPHA = 1)) then
                        wait until rising_edge(Sclk);
                    else
                        wait until falling_edge(Sclk);
                    end if;
                    -- Check sclk timing
                    if i /= 0 then
                        check_equal(real((now-LastEdge_v)/(1.0 ps))/1.0e12, 1.0/instance.BusFrequency, max_diff => 0.1/instance.BusFrequency, msg => "Sclk timing");
                    end if;
                    LastEdge_v := now;

                    -- Shift RX
                    if instance.LsbFirst then
                        ShiftRegRx_v := 'U' & ShiftRegRx_v(instance.MaxTransWidth - 1 downto 1);
                        ShiftRegRx_v(transaction_bits - 1) := Mosi;
                    else
                        ShiftRegRx_v := ShiftRegRx_v(instance.MaxTransWidth - 2 downto 0) & Mosi;
                    end if;

                end loop;

                -- wait fir CS going high
                WaitForValueStdl(Cs_n, '1', timeout, to_string(msg_p));
                Miso <= 'Z';

                -- checks
                check_equal(ShiftRegRx_v(transaction_bits - 1 downto 0), data_mosi(transaction_bits - 1 downto 0), "SPI slave received wrong data");	

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;                
        end loop;
    end process;

end;
