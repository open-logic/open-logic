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

package olo_test_spi_master_pkg is  

    -- *** VUnit instance type ***
    type olo_test_spi_master_t is record
        p_actor         : actor_t;
        LsbFirst        : boolean;
        MaxTransWidth   : positive;
        ClkPeriod       : time;
        CPHA            : integer range 0 to 1;
        CPOL            : integer range 0 to 1;
    end record;

    -- *** Slave Operations ***

    -- Transaction
    procedure spi_master_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_master_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        csn_first           : boolean           := false; -- CSn is operated before Sclk at beginning/end of transaction
        timeout             : time              := 1 ms;
        msg                 : string             := ""
    );

    -- *** VUnit Operations ***
    -- Message Types
    constant SpiMasterPushTransactionMsg  : msg_type_t := new_msg_type("SpiMasterPushTransaction");

    -- Constructor
    impure function new_olo_test_spi_master( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth   : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_master_t;
        
    -- Casts
    impure function as_sync(instance : olo_test_spi_master_t) return sync_handle_t;

end;

package body olo_test_spi_master_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure spi_master_push_transaction (
        signal net          : inout network_t;
        spi                 : olo_test_spi_master_t;
        transaction_bits    : positive;
        data_mosi           : std_logic_vector  := "X";
        data_miso           : std_logic_vector  := "X";
        csn_first           : boolean           := false; 
        timeout             : time              := 1 ms;
        msg                 : string            := ""
    ) is
        variable Msg_v : msg_t := new_msg(SpiMasterPushTransactionMsg);
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
        push(Msg_v, csn_first);
        push(Msg_v, timeout);
        push_string(Msg_v, msg);
        
        -- Send message
        send(net, spi.p_actor, Msg_v);
    end;

    -- Constructor
    impure function new_olo_test_spi_master( 
        busFrequency    : real    := 1.0e6;
        lsbFirst        : boolean := false;
        maxTransWidth    : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_master_t is
    begin
        return (p_actor => new_actor, 
                LsbFirst => lsbFirst,
                MaxTransWidth => maxTransWidth,
                ClkPeriod => (1 sec) / busFrequency,                
                CPHA => cpha,
                CPOL => cpol);
    end;
        
    -- Casts
    impure function as_sync(instance : olo_test_spi_master_t) return sync_handle_t is
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
    use work.olo_test_spi_master_pkg.all;
    use work.olo_test_activity_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_test_spi_master_vc is
    generic (
        instance                 : olo_test_spi_master_t
    );
    port (
        Sclk     : out       std_logic;
        CS_n     : out       std_logic;
        Mosi     : out       std_logic;
        Miso     : in        std_logic
    );
end entity;

architecture rtl of olo_test_spi_master_vc is
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
        variable csn_first          : boolean;
        variable timeout            : time;
        variable msg_p              : string_ptr_t;

        -- Shift Registers
        variable ShiftRegRx_v : std_logic_vector(instance.MaxTransWidth-1 downto 0);
        variable ShiftRegTx_v : std_logic_vector(instance.MaxTransWidth-1 downto 0);
        variable TxIdx_v      : integer;

        -- Others
        variable LastEdge_v   : time;

    begin
        -- Initialization
        Mosi <= '0';
        Sclk <= choose(instance.Cpol = 0, '1', '0'); -- Clock by default in wrong state
        CS_n <= '1';

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = SpiMasterPushTransactionMsg then
                -- Pop Transaction
                transaction_bits := pop(request_msg);
                data_mosi := pop(request_msg);
                data_miso := pop(request_msg);
                csn_first := pop(request_msg);
                timeout := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Select tx bit index
                TxIdx_v := choose(instance.LsbFirst, 0, transaction_bits - 1);

                -- Start transaction
                if csn_first then
                    CS_n <= '0';
                    wait for 0.5*instance.ClkPeriod;
                    Sclk <= choose(instance.Cpol = 0, '0', '1');
                else
                    Sclk <= choose(instance.Cpol = 0, '0', '1');
                    wait for 0.5*instance.ClkPeriod;
                    CS_n <= '0';
                end if;
                wait for 0.5*instance.ClkPeriod;

                -- Load data into shift register
                ShiftRegTx_v := data_mosi;
                ShiftRegRx_v := (others => 'U'); 
                
                -- For CPHA0 apply data immediately
                if instance.CPHA = 0 then
                    Mosi <= ShiftRegTx_v(TxIdx_v);
                end if;

                -- loop over bits
                for i in 0 to transaction_bits - 1 loop

                    -- First edge
                    wait for 0.5*instance.ClkPeriod;
                    Sclk <= not Sclk;
                    if instance.CPHA = 0 then
                        if instance.LsbFirst = False then
                            ShiftRegRx_v(transaction_bits-1 downto 0) := ShiftRegRx_v(transaction_bits - 2 downto 0) & Miso;
                            ShiftRegTx_v(transaction_bits-1 downto 0) := ShiftRegTx_v(transaction_bits - 2 downto 0) & 'U';
                        else
                            ShiftRegRx_v(transaction_bits-1 downto 0) := Miso & ShiftRegRx_v(transaction_bits - 1 downto 1);
                            ShiftRegTx_v(transaction_bits-1 downto 0) := 'U' & ShiftRegTx_v(transaction_bits - 1 downto 1);
                        end if;
                    else
                        Mosi <= ShiftRegTx_v(TxIdx_v);
                    end if;

                    -- Second edge
                    wait for 0.5*instance.ClkPeriod;
                    Sclk <= not Sclk;
                    if instance.CPHA = 1 then
                        if instance.LsbFirst = False then
                            ShiftRegRx_v(transaction_bits-1 downto 0) := ShiftRegRx_v(transaction_bits - 2 downto 0) & Miso;
                            ShiftRegTx_v(transaction_bits-1 downto 0) := ShiftRegTx_v(transaction_bits - 2 downto 0) & 'U';
                        else
                            ShiftRegRx_v(transaction_bits-1 downto 0) := Miso & ShiftRegRx_v(transaction_bits - 1 downto 1);
                            ShiftRegTx_v(transaction_bits-1 downto 0) := 'U' & ShiftRegTx_v(transaction_bits - 1 downto 1);
                        end if;
                    else
                        Mosi <= ShiftRegTx_v(TxIdx_v);
                    end if;

                end loop;

                -- End transaction
                wait for 0.5*instance.ClkPeriod;
                if csn_first then
                    CS_n <= '1';
                    wait for 0.5*instance.ClkPeriod;
                    Sclk <= choose(instance.Cpol = 0, '1', '0');
                else
                    Sclk <= choose(instance.Cpol = 0, '1', '0');
                    wait for 0.5*instance.ClkPeriod;
                    CS_n <= '1';
                end if;

                -- checks
                check_equal(ShiftRegRx_v(transaction_bits - 1 downto 0), data_miso(transaction_bits - 1 downto 0), "SPI master received wrong data: " & to_string(msg_p));	

                -- Wait for minimum CSn high time
                wait for 0.5*instance.ClkPeriod;
                check_equal(Miso, 'Z', "Miso must be tri-stated after transaction: " & to_string(msg_p));

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;                
        end loop;
    end process;

end;
