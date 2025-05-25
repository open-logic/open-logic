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

package olo_test_spi_master_pkg is

    -- *** VUnit instance type ***
    type olo_test_spi_master_t is record
        p_actor         : actor_t;
        lsb_first       : boolean;
        max_trans_width : positive;
        clk_period      : time;
        cpha            : integer range 0 to 1;
        cpol            : integer range 0 to 1;
    end record;

    -- *** Slave Operations ***

    -- Transaction
    procedure spi_master_push_transaction (
        signal net       : inout network_t;
        spi              : olo_test_spi_master_t;
        transaction_bits : positive;
        data_mosi        : std_logic_vector := "X";
        data_miso        : std_logic_vector := "X";
        csn_first        : boolean          := false; -- CSn is operated before sclk at beginning/end of transaction
        timeout          : time             := 1 ms;
        msg              : string           := "");

    -- *** VUnit Operations ***
    -- Message Types
    constant spi_master_push_transaction_msg : msg_type_t := new_msg_type("spi_master_push_transaction_msg");

    -- Constructor
    impure function new_olo_test_spi_master (
        bus_frequency   : real    := 1.0e6;
        lsb_first       : boolean := false;
        max_trans_width : natural := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_master_t;

    -- Casts
    impure function as_sync (instance : olo_test_spi_master_t) return sync_handle_t;

end package;

package body olo_test_spi_master_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure spi_master_push_transaction (
        signal net       : inout network_t;
        spi              : olo_test_spi_master_t;
        transaction_bits : positive;
        data_mosi        : std_logic_vector := "X";
        data_miso        : std_logic_vector := "X";
        csn_first        : boolean          := false;
        timeout          : time             := 1 ms;
        msg              : string           := "") is
        variable msg_v  : msg_t                                            := new_msg(spi_master_push_transaction_msg);
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
        push(msg_v, csn_first);
        push(msg_v, timeout);
        push_string(msg_v, msg);

        -- Send message
        send(net, spi.p_actor, msg_v);
    end procedure;

    -- Constructor
    impure function new_olo_test_spi_master (
        bus_frequency   : real                 := 1.0e6;
        lsb_first       : boolean              := false;
        max_trans_width : natural              := 32;
        cpha            : integer range 0 to 1 := 0;
        cpol            : integer range 0 to 1 := 0) return olo_test_spi_master_t is
    begin
        return (p_actor => new_actor,
                lsb_first => lsb_first,
                max_trans_width => max_trans_width,
                clk_period => (1 sec) / bus_frequency,
                cpha => cpha,
                cpol => cpol);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_spi_master_t) return sync_handle_t is
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
        sclk     : out   std_logic;
        cs_n     : out   std_logic;
        mosi     : out   std_logic;
        miso     : in    std_logic
    );
end entity;

architecture a of olo_test_spi_master_vc is

begin

    -- Main Process
    main : process is
        -- Messaging
        variable request_msg      : msg_t;
        variable msg_type         : msg_type_t;
        variable transaction_bits : positive;
        variable data_mosi        : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable data_miso        : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable csn_first        : boolean;
        variable timeout          : time;
        variable msg_p            : string_ptr_t;

        -- Shift Registers
        variable shift_reg_rx : std_logic_vector(instance.max_trans_width-1 downto 0);
        variable shift_reg_tx : std_logic_vector(instance.max_trans_width-1 downto 0);

        -- Others
        variable tx_id : integer;
    begin
        -- Initialization
        mosi <= '0';
        sclk <= choose(instance.Cpol = 0, '1', '0'); -- Clock by default in wrong state
        cs_n <= '1';

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = spi_master_push_transaction_msg then
                -- Pop Transaction
                transaction_bits := pop(request_msg);
                data_mosi        := pop(request_msg);
                data_miso        := pop(request_msg);
                csn_first        := pop(request_msg);
                timeout          := pop(request_msg);
                msg_p            := new_string_ptr(pop_string(request_msg));

                -- Select tx bit index
                tx_id := choose(instance.lsb_first, 0, transaction_bits - 1);

                -- Start transaction
                if csn_first then
                    cs_n <= '0';
                    wait for 0.5*instance.clk_period;
                    sclk <= choose(instance.Cpol = 0, '0', '1');
                else
                    sclk <= choose(instance.Cpol = 0, '0', '1');
                    wait for 0.5*instance.clk_period;
                    cs_n <= '0';
                end if;
                wait for 0.5*instance.clk_period;

                -- Load data into shift register
                shift_reg_tx := data_mosi;
                shift_reg_rx := (others => 'U');

                -- For CPHA0 apply data immediately
                if instance.cpha = 0 then
                    mosi <= shift_reg_tx(tx_id);
                end if;

                -- loop over bits
                for i in 0 to transaction_bits - 1 loop

                    -- First edge
                    wait for 0.5*instance.clk_period;
                    sclk <= not sclk;
                    if instance.cpha = 0 then
                        if instance.lsb_first = False then
                            shift_reg_rx(transaction_bits-1 downto 0) := shift_reg_rx(transaction_bits - 2 downto 0) & miso;
                            shift_reg_tx(transaction_bits-1 downto 0) := shift_reg_tx(transaction_bits - 2 downto 0) & 'U';
                        else
                            shift_reg_rx(transaction_bits-1 downto 0) := miso & shift_reg_rx(transaction_bits - 1 downto 1);
                            shift_reg_tx(transaction_bits-1 downto 0) := 'U' & shift_reg_tx(transaction_bits - 1 downto 1);
                        end if;
                    else
                        mosi <= shift_reg_tx(tx_id);
                    end if;

                    -- Second edge
                    wait for 0.5*instance.clk_period;
                    sclk <= not sclk;
                    if instance.cpha = 1 then
                        if instance.lsb_first = False then
                            shift_reg_rx(transaction_bits-1 downto 0) := shift_reg_rx(transaction_bits - 2 downto 0) & miso;
                            shift_reg_tx(transaction_bits-1 downto 0) := shift_reg_tx(transaction_bits - 2 downto 0) & 'U';
                        else
                            shift_reg_rx(transaction_bits-1 downto 0) := miso & shift_reg_rx(transaction_bits - 1 downto 1);
                            shift_reg_tx(transaction_bits-1 downto 0) := 'U' & shift_reg_tx(transaction_bits - 1 downto 1);
                        end if;
                    else
                        mosi <= shift_reg_tx(tx_id);
                    end if;

                end loop;

                -- End transaction
                wait for 0.5*instance.clk_period;
                if csn_first then
                    cs_n <= '1';
                    wait for 0.5*instance.clk_period;
                    sclk <= choose(instance.Cpol = 0, '1', '0');
                else
                    sclk <= choose(instance.Cpol = 0, '1', '0');
                    wait for 0.5*instance.clk_period;
                    cs_n <= '1';
                end if;

                -- checks
                check_equal(shift_reg_rx(transaction_bits - 1 downto 0), data_miso(transaction_bits - 1 downto 0),
                            "SPI master received wrong data: " & to_string(msg_p));

                -- Wait for minimum CSn high time
                wait for 0.5*instance.clk_period;
                check_equal(miso, 'Z', "miso must be tri-stated after transaction: " & to_string(msg_p));

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

end architecture;
