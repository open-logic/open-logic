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

package olo_test_spi_slave_pkg is

    -- *** VUnit instance type ***
    type olo_test_spi_slave_t is record
        p_actor         : actor_t;
        lsb_first       : boolean;
        max_trans_width : positive;
        bus_frequency   : real;
        cpha            : integer range 0 to 1;
        cpol            : integer range 0 to 1;
    end record;

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net       : inout network_t;
        spi              : olo_test_spi_slave_t;
        transaction_bits : positive;
        data_mosi        : std_logic_vector := "X";
        data_miso        : std_logic_vector := "X";
        timeout          : time             := 1 ms;
        msg              : string           := "");

    -- *** VUnit Operations ***
    -- Message Types
    constant spi_slave_push_transaction_msg : msg_type_t := new_msg_type("spi_slave_push_transaction_msg");

    -- Constructor
    impure function new_olo_test_spi_slave (
        bus_frequency   : real                 := 1.0e6;
        lsb_first       : boolean              := false;
        max_trans_width : natural              := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_slave_t;

    -- Casts
    impure function as_sync (instance : olo_test_spi_slave_t) return sync_handle_t;

end package;

package body olo_test_spi_slave_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure spi_slave_push_transaction (
        signal net       : inout network_t;
        spi              : olo_test_spi_slave_t;
        transaction_bits : positive;
        data_mosi        : std_logic_vector := "X";
        data_miso        : std_logic_vector := "X";
        timeout          : time             := 1 ms;
        msg              : string           := "") is
        variable msg_v  : msg_t                                            := new_msg(spi_slave_push_transaction_msg);
        variable mosi_v : std_logic_vector(spi.max_trans_width-1 downto 0) := (others => '0');
        variable miso_v : std_logic_vector(spi.max_trans_width-1 downto 0) := (others => 'X');
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
        push(msg_v, transaction_bits);
        push(msg_v, mosi_v);
        push(msg_v, miso_v);
        push(msg_v, timeout);
        push_string(msg_v, msg);

        -- Send message
        send(net, spi.p_actor, msg_v);
    end procedure;

    -- Constructor
    impure function new_olo_test_spi_slave (
        bus_frequency    : real    := 1.0e6;
        lsb_first        : boolean := false;
        max_trans_width   : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_slave_t is
    begin
        return (p_actor => new_actor,
                lsb_first => lsb_first,
                max_trans_width => max_trans_width,
                bus_frequency => bus_frequency,
                cpha => cpha,
                cpol => cpol);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_spi_slave_t) return sync_handle_t is
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
        sclk     : in    std_logic;
        cs_n     : in    std_logic;
        mosi     : in    std_logic;
        miso     : out   std_logic
    );
end entity;

architecture a of olo_test_spi_slave_vc is

begin

    -- Main Process
    main : process is
        -- Messaging
        variable request_msg      : msg_t;
        variable msg_type         : msg_type_t;
        variable transaction_bits : positive;
        variable data_mosi        : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable data_miso        : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable timeout          : time;
        variable msg_p            : string_ptr_t;

        -- Shift Registers
        variable shift_reg_rx : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable shift_reg_tx : std_logic_vector(instance.max_trans_width-1 downto 0);

        -- Others
        variable last_edge : time;
    begin
        -- Initialization
        miso <= 'Z';

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = spi_slave_push_transaction_msg then
                -- Pop Transaction
                transaction_bits := pop(request_msg);
                data_mosi        := pop(request_msg);
                data_miso        := pop(request_msg);
                timeout          := pop(request_msg);
                msg_p            := new_string_ptr(pop_string(request_msg));

                -- Wait for CSn
                wait_for_value_stdl(cs_n, '0', timeout, to_string(msg_p));
                shift_reg_tx := data_miso;
                shift_reg_rx := (others => 'U');

                -- loop over bits
                for i in 0 to transaction_bits - 1 loop

                    -- Wait for apply edge
                    if (instance.cpha = 1) and (i /= transaction_bits - 1) then
                        if instance.cpol = 0 then
                            wait until rising_edge(sclk);
                        else
                            wait until falling_edge(sclk);
                        end if;
                    elsif (instance.cpha = 0) and (i /= 0) then
                        if instance.cpol = 0 then
                            wait until falling_edge(sclk);
                        else
                            wait until rising_edge(sclk);
                        end if;
                    end if;

                    -- shift TX
                    if instance.lsb_first then
                        miso         <= shift_reg_tx(0);
                        shift_reg_tx := 'U' & shift_reg_tx(instance.max_trans_width - 1 downto 1);
                    else
                        miso         <= shift_reg_tx(transaction_bits - 1);
                        shift_reg_tx := shift_reg_tx(instance.max_trans_width - 2 downto 0) & 'U';
                    end if;

                    -- Wait for transfer edge
                    if ((instance.cpol = 0) and (instance.cpha = 0)) or ((instance.cpol = 1) and (instance.cpha = 1)) then
                        wait until rising_edge(sclk);
                    else
                        wait until falling_edge(sclk);
                    end if;
                    -- Check sclk timing
                    if i /= 0 then
                        check_equal(real((now-last_edge)/(1.0 ps))/1.0e12, 1.0/instance.bus_frequency,
                                    max_diff => 0.1/instance.bus_frequency,
                                    msg      => "sclk timing");
                    end if;
                    last_edge := now;

                    -- Shift RX
                    if instance.lsb_first then
                        shift_reg_rx                       := 'U' & shift_reg_rx(instance.max_trans_width - 1 downto 1);
                        shift_reg_rx(transaction_bits - 1) := mosi;
                    else
                        shift_reg_rx := shift_reg_rx(instance.max_trans_width - 2 downto 0) & mosi;
                    end if;

                end loop;

                -- wait fir CS going high
                wait_for_value_stdl(cs_n, '1', timeout, to_string(msg_p));
                miso <= 'Z';

                -- checks
                check_equal(shift_reg_rx(transaction_bits - 1 downto 0), data_mosi(transaction_bits - 1 downto 0), "SPI slave received wrong data");

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

end architecture;
