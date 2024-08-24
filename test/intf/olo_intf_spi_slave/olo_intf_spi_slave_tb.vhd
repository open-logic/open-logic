------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

library work;
    use work.olo_test_spi_master_pkg.all;
    use work.olo_test_activity_pkg.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_spi_slave_tb is
    generic (
        ClkFrequency_g              : integer := 100_000_000;
        BusFrequency_g              : integer := 10_000_000;
        TransWidth_g                : integer range 8 to 16 := 8;
        LsbFirst_g                  : boolean := true;
        SpiCpha_g                   : integer range 0 to 1 := 0;
        SpiCpol_g                   : integer range 0 to 1 := 0;
        ConsecutiveTransactions_g   : boolean := false;
        InternalTriState_g          : boolean := true;
        runner_cfg                  : string  
    );
end entity olo_intf_spi_slave_tb;

architecture sim of olo_intf_spi_slave_tb is

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant SclkFreq_c        : real    := real(BusFrequency_g);
    constant Clk_Frequency_c   : real    := real(ClkFrequency_g);
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk             : std_logic := '0'; 
    signal Rst             : std_logic;
    signal Rx_Valid        : std_logic;
    signal Rx_RxData       : std_logic_vector(TransWidth_g - 1 downto 0);
    signal Tx_Valid        : std_logic   := '0';
    signal Tx_Ready        : std_logic;
    signal Tx_TxData       : std_logic_vector(TransWidth_g - 1 downto 0) := (others => '0');
    signal Resp_Valid      : std_logic;
    signal Resp_Sent       : std_logic;
    signal Resp_Aborted    : std_logic;
    signal Spi_Sclk        : std_logic := choose(SpiCpol_g = 0, '0', '1');
    signal Spi_Mosi        : std_logic := '0';  
    signal Spi_Cs_n        : std_logic := '1'; 
    signal Spi_Miso        : std_logic;
    signal Spi_Miso_o      : std_logic;
    signal Spi_Miso_t      : std_logic;

    -- shorthand for range
    signal D               : std_logic_vector(TransWidth_g - 1 downto 0);

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant master : olo_test_spi_master_t := new_olo_test_spi_master( 
        busFrequency    => SclkFreq_c,
        lsbFirst        => LsbFirst_g,
        maxTransWidth   => TransWidth_g,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

    -- *** Internal Messaging ***
    constant RxQueue : queue_t := new_queue;
    constant RxMsg : msg_type_t := new_msg_type("Rx Message");
    signal RxCheckOngoing : boolean := false;

    procedure ExpectRx (
        Data    : std_logic_vector(TransWidth_g - 1 downto 0)
    ) is
        variable msg : msg_t := new_msg(RxMsg);
    begin
        push(msg, Data);
        push(RxQueue, msg);
    end procedure;

    procedure WaitUntilRxDone is
    begin
        if (not is_empty(RxQueue)) or RxCheckOngoing then
            wait until is_empty(RxQueue) and (not RxCheckOngoing) and rising_edge(Clk);
        end if;
    end procedure;

    procedure AwaitResp(
        Sent    : std_logic := '0';
        Aborted : std_logic := '0'
    ) is
    begin
        WaitForValueStdl(Resp_Valid, '1', 1 ms, "Resp_Valid not asserted");
        check_equal(Resp_Sent, Sent, "Resp_Sent wrong");
        check_equal(Resp_Aborted, Aborted, "Resp_Aborted wrong");
        wait until rising_edge(Clk);
        wait until falling_edge(Clk);
        check_equal(Resp_Valid, '0', "Resp_Valid not deasserted");
    end procedure;    


begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);
    p_control : process
        variable Mosi16_v, Miso16_v : std_logic_vector(15 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);
            
            -- *** Basics ***
            if run("ResetValues") then
                check_equal(Rx_Valid, '0', "Rx_Valid wrong after reset");
                check_equal(Tx_Ready, '0', "Tx_Ready wrong after reset");
                check_equal(Resp_Valid, '0', "Resp_Valid wrong after reset");
                check_equal(Spi_Miso, 'Z', "Spi_Miso wrong after reset");
            end if;

            -- *** Simple Transaction ***
            if run("SimpleTransactions") then
                for i in 0 to 1 loop
                    -- Define Data
                    Mosi16_v := toUslv(16#1234#+i, 16);
                    Miso16_v := toUslv(16#5678#+i, 16);
                    
                    -- Start Transaction
                    spi_master_push_transaction (net, master, TransWidth_g, Mosi16_v(D'Range), Miso16_v(D'Range), msg => "SimpleTransaction");

                    -- Expect RX Data
                    ExpectRx(Mosi16_v(D'Range));

                    -- Wait for data latch
                    Tx_Valid <= '1';
                    Tx_TxData <= Miso16_v(D'Range);
                    WaitForValueStdl(Tx_Ready, '1', 1 ms, "Tx_Ready not asserted");
                    wait until rising_edge(Clk);
                    Tx_Valid <= '0';

                    -- Wait for Response
                    AwaitResp(Sent => '1');
                    WaitUntilRxDone;
                end loop;
            end if;

            if run("DelayedDataForCpha1") then
                if SpiCpha_g = 1 then
                    -- Define Data
                    Mosi16_v := X"ABCD";
                    Miso16_v := X"1357";
                    
                    -- Start Transaction
                    spi_master_push_transaction (net, master, TransWidth_g, Mosi16_v(D'Range), Miso16_v(D'Range), msg => "SimpleTransaction");

                    -- Expect RX Data
                    ExpectRx(Mosi16_v(D'Range));

                    -- Wait for data latch
                    WaitForValueStdl(Tx_Ready, '1', 1 ms, "Tx_Ready not asserted");
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    Tx_Valid <= '1';
                    Tx_TxData <= Miso16_v(D'Range);
                    wait until rising_edge(Clk);
                    Tx_Valid <= '0';

                    -- Wait for Response
                    AwaitResp(Sent => '1');
                end if;
            end if;

            -- *** Wait until done ***
            WaitUntilRxDone;
            wait_until_idle(net, as_sync(master));
            wait for 1 us;

        end loop;
        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_spi_slave
        generic map (
            TransWidth_g                => TransWidth_g,
            SpiCPOL_g                   => SpiCpol_g,
            SpiCPHA_g                   => SpiCpha_g,
            LsbFirst_g                  => LsbFirst_g,
            ConsecutiveTransactions_g   => ConsecutiveTransactions_g,
            DisableAsserts_g            => true,
            InternalTriState_g          => InternalTriState_g
        )
        port map (
            -- Control Signals
            Clk             => Clk, 
            Rst             => Rst,
            -- RX Data      
            Rx_Valid        => Rx_Valid,
            Rx_RxData       => Rx_RxData,
            -- TX Data
            Tx_Valid        => Tx_Valid,
            Tx_Ready        => Tx_Ready,
            Tx_TxData       => Tx_TxData,
            -- Response Interface
            Resp_Valid      => Resp_Valid,
            Resp_Sent       => Resp_Sent,
            Resp_Aborted    => Resp_Aborted,
            -- SPI 
            Spi_Sclk        => Spi_Sclk,
            Spi_Mosi        => Spi_Mosi,  
            Spi_Cs_n        => Spi_Cs_n, 
            -- Miso with internal Tristate
            Spi_Miso        => Spi_Miso,
            -- Miso with external Tristate
            Spi_Miso_o      => Spi_Miso_o,
            Spi_Miso_t      => Spi_Miso_t
        );
    g_tristate : if not InternalTriState_g generate
        Spi_Miso <= 'Z' when Spi_Miso_t = '1' else Spi_Miso_o;
    end generate;

    ------------------------------------------------------------
    -- Verification Components
    ------------------------------------------------------------
    vc_master : entity work.olo_test_spi_master_vc
        generic map (
            instance => master
        )
        port map (
            Sclk     => Spi_Sclk,
            CS_n     => Spi_Cs_n,
            Mosi     => Spi_Mosi,
            Miso     => Spi_Miso
        );

    vc_rx : process
        variable msg : msg_t;
        variable msg_type : msg_type_t;
        variable Data : std_logic_vector(TransWidth_g - 1 downto 0);
    begin
        -- loop messages
        loop
            -- wait until message available
            if is_empty(RxQueue) then
                wait until not is_empty(RxQueue) and rising_edge(Clk);
            end if;
            RxCheckOngoing <= true;
            -- get message
            msg := pop(RxQueue);
            msg_type := message_type(msg);
            -- process message
            if msg_type = RxMsg then
                -- pop information
                Data := pop(msg);

                -- Wait for RX data
                WaitForValueStdl(Rx_Valid, '1', 1 ms, "Rx_Valid not asserted");
                wait until rising_edge(Clk);
                check_equal(Rx_RxData, Data(D'Range), "Rx_RxData wrong");
            else
                error("Unexpected message type in vc_rx");
            end if;
            RxCheckOngoing <= false;
        end loop;
    end process;

end sim;
