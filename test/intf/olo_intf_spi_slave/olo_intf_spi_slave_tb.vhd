---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_spi_slave_tb is
    generic (
        ClkFrequency_g              : integer               := 100_000_000;
        BusFrequency_g              : integer               := 10_000_000;
        TransWidth_g                : integer range 8 to 16 := 8;
        LsbFirst_g                  : boolean               := false;
        SpiCpha_g                   : integer range 0 to 1  := 0;
        SpiCpol_g                   : integer range 0 to 1  := 0;
        ConsecutiveTransactions_g   : boolean               := true;
        InternalTriState_g          : boolean               := true;
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_intf_spi_slave_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant SclkFreq_c      : real := real(BusFrequency_g);
    constant Clk_Frequency_c : real := real(ClkFrequency_g);
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk           : std_logic                                   := '0';
    signal Rst           : std_logic;
    signal Rx_Valid      : std_logic;
    signal Rx_Data       : std_logic_vector(TransWidth_g - 1 downto 0);
    signal Tx_Valid      : std_logic                                   := '0';
    signal Tx_Ready      : std_logic;
    signal Tx_Data       : std_logic_vector(TransWidth_g - 1 downto 0) := (others => '0');
    signal Resp_Valid    : std_logic;
    signal Resp_Sent     : std_logic;
    signal Resp_Aborted  : std_logic;
    signal Resp_CleanEnd : std_logic;
    signal Spi_Sclk      : std_logic                                   := choose(SpiCpol_g = 0, '0', '1');
    signal Spi_Mosi      : std_logic                                   := '0';
    signal Spi_Cs_n      : std_logic                                   := '1';
    signal Spi_Miso      : std_logic;
    signal Spi_Miso_Con  : std_logic;
    signal Spi_Miso_o    : std_logic;
    signal Spi_Miso_t    : std_logic;

    -- shorthand for range
    signal D : std_logic_vector(TransWidth_g - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant Master_c : olo_test_spi_master_t := new_olo_test_spi_master(
        bus_frequency   => SclkFreq_c,
        lsb_first       => LsbFirst_g,
        max_trans_width => TransWidth_g*3,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

    -- *** Internal Messaging ***
    -- Rx Handling
    constant RxQueue_c    : queue_t    := new_queue;
    constant RxMsg_c      : msg_type_t := new_msg_type("Rx Message");
    signal RxCheckOngoing : boolean    := false;

    procedure expectRx (
        Data : std_logic_vector(TransWidth_g - 1 downto 0);
        msg  : string := "") is
        variable Msg_v : msg_t := new_msg(RxMsg_c);
    begin
        push(Msg_v, Data);
        push_string(Msg_v, msg);
        push(RxQueue_c, Msg_v);
    end procedure;

    procedure waitUntilRxDone is
    begin
        if (not is_empty(RxQueue_c)) or RxCheckOngoing then
            wait until is_empty(RxQueue_c) and (not RxCheckOngoing) and rising_edge(Clk);
        end if;
    end procedure;

    -- Resp Handling
    constant RespQueue_c    : queue_t    := new_queue;
    constant RespMsg_c      : msg_type_t := new_msg_type("Resp Message");
    signal RespCheckOngoing : boolean    := false;

    procedure expectResp (
        Sent     : std_logic := '0';
        Aborted  : std_logic := '0';
        CleanEnd : std_logic := '0') is
        variable Msg_v : msg_t := new_msg(RespMsg_c);
    begin
        push(Msg_v, Sent);
        push(Msg_v, Aborted);
        push(Msg_v, CleanEnd);
        push(RespQueue_c, Msg_v);
    end procedure;

    procedure waitUntilRespDone is
    begin
        if (not is_empty(RespQueue_c)) or RespCheckOngoing then
            wait until is_empty(RespQueue_c) and (not RespCheckOngoing) and rising_edge(Clk);
        end if;
    end procedure;

    -- Tx Handling
    constant TxQueue_c    : queue_t    := new_queue;
    constant TxMsg_c      : msg_type_t := new_msg_type("Tx Message");
    signal TxCheckOngoing : boolean    := false;

    procedure applyTx (
        Data        : std_logic_vector(TransWidth_g - 1 downto 0);
        DelayCycles : integer := 0;
        msg         : string  := "") is
        variable Msg_v : msg_t := new_msg(TxMsg_c);
    begin
        push(Msg_v, Data);
        push(Msg_v, DelayCycles);
        push_string(Msg_v, msg);
        push(TxQueue_c, Msg_v);
    end procedure;

    procedure waitUntilTxDone is
    begin
        if (not is_empty(TxQueue_c)) or TxCheckOngoing then
            wait until is_empty(TxQueue_c) and (not TxCheckOngoing) and rising_edge(Clk);
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
        variable Mosi16_v, Miso16_v : std_logic_vector(15 downto 0);
        variable Mosi48_v, Miso48_v : std_logic_vector(47 downto 0);
        variable TxVldDelay_v       : integer;
        constant ClkRatio_c         : real := real(ClkFrequency_g) / real(BusFrequency_g);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            if ClkRatio_c < 6.0 then
                check(false, "ClkFrequency_g must be at least 6 times higher than BusFrequency_g");
            elsif ClkRatio_c < 8.0 then
                TxVldDelay_v := 1;
            elsif ClkRatio_c < 10.0 then
                TxVldDelay_v := 2;
            else
                TxVldDelay_v := 3;
            end if;

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

                -- Do two transactions
                for i in 0 to 1 loop
                    -- Define Data
                    Mosi16_v := toUslv(16#1234#+i, 16);
                    Miso16_v := toUslv(16#5678#+i, 16);

                    -- Start Transaction
                    spi_master_push_transaction (net, Master_c, TransWidth_g, Mosi16_v(D'Range), Miso16_v(D'Range), msg => "SimpleTransaction");

                    -- Expect RX Data
                    expectRx(Mosi16_v(D'Range));

                    -- Expect Responses
                    expectResp(Sent => '1');
                    expectResp(CleanEnd => '1');

                    -- Apply TX Data
                    applyTx(Miso16_v(D'Range), 0);

                    -- Wait for Response
                    waitUntilRespDone;
                    waitUntilRxDone;
                    waitUntilTxDone;
                end loop;

            end if;

            if run("DelayedDataForCpha1") then
                if SpiCpha_g = 1 then
                    -- Define Data
                    Mosi16_v := x"ABCD";
                    Miso16_v := x"1357";

                    -- Start Transaction
                    spi_master_push_transaction (net, Master_c, TransWidth_g, Mosi16_v(D'Range), Miso16_v(D'Range), msg => "SimpleTransaction");

                    -- Expect RX Data
                    expectRx(Mosi16_v(D'Range));

                    -- Expect Responses
                    expectResp(Sent => '1');
                    expectResp(CleanEnd => '1');

                    -- Apply TxData
                    applyTx(Miso16_v(D'Range), 1);

                end if;
            end if;

            -- *** Consecutive Transactions ***
            if run("3ConsecutiveTransactions-CleanEnd") then
                -- Only execute when enabled
                if ConsecutiveTransactions_g then
                    -- Define Data
                    Mosi48_v := x"81F13C81468F";
                    Miso48_v := x"3C183C8F6481";

                    -- Start Transaction
                    spi_master_push_transaction (net, Master_c, TransWidth_g*3,
                        Mosi48_v(TransWidth_g*3-1 downto 0), Miso48_v(TransWidth_g*3-1 downto 0),
                        msg => "3 Consecutive Transactions");

                    -- Expect RX Data
                    if LsbFirst_g then

                        -- Loop over three trasactions
                        for i in 0 to 2 loop
                            expectRx(Mosi48_v(TransWidth_g*(i+1)-1 downto TransWidth_g*i), "Word " & to_string(i));
                        end loop;

                    else

                        -- Loop over three trasactions
                        for i in 2 downto 0 loop
                            expectRx(Mosi48_v(TransWidth_g*(i+1)-1 downto TransWidth_g*i), "Word " & to_string(i));
                        end loop;

                    end if;

                    -- Expect Responses
                    for i in 0 to 2 loop
                        expectResp(Sent => '1');
                    end loop;

                    expectResp(CleanEnd => '1');

                    -- First word applied immediately
                    if LsbFirst_g then
                        applyTx(Miso48_v(TransWidth_g-1 downto 0), 0, "Word 0");
                    else
                        applyTx(Miso48_v(TransWidth_g*3-1 downto TransWidth_g*2), 0, "Word 0");
                    end if;

                    -- Other TX Data applied with delay (there should be at least one clock cycle of time)
                    for i in 1 to 2 loop
                        if LsbFirst_g then
                            applyTx(Miso48_v(TransWidth_g*(i+1)-1 downto TransWidth_g*i), TxVldDelay_v, "Word " & to_string(i));
                        else
                            applyTx(Miso48_v(TransWidth_g*(3-i)-1 downto TransWidth_g*(2-i)), TxVldDelay_v, "Word " & to_string(i));
                        end if;
                    end loop;

                end if;
            end if;

            if run("2ConsecutiveTransactions-AbortEnd") then
                -- Only execute when enabled
                if ConsecutiveTransactions_g then
                    -- Define Data
                    Mosi48_v := x"1A2B3C4D5E6F";
                    Miso48_v := x"112233445566";

                    -- Start Transaction
                    spi_master_push_transaction (net, Master_c, TransWidth_g*2,
                        Mosi48_v(TransWidth_g*2-1 downto 0), Miso48_v(TransWidth_g*2-1 downto 0),
                        msg => "2 Consecutive Transactions");

                    -- Expect RX Data
                    if LsbFirst_g then
                        expectRx(Mosi48_v(TransWidth_g-1 downto 0), "Word 0");
                        expectRx(Mosi48_v(TransWidth_g*2-1 downto TransWidth_g), "Word 1");
                    else
                        expectRx(Mosi48_v(TransWidth_g*2-1 downto TransWidth_g), "Word 0");
                        expectRx(Mosi48_v(TransWidth_g-1 downto 0), "Word 1");
                    end if;

                    -- Expect Responses
                    expectResp(Sent => '1');
                    expectResp(Sent => '1');
                    expectResp(Aborted => '1');

                    -- Apply TX Data
                    if LsbFirst_g then
                        applyTx(Miso48_v(TransWidth_g-1 downto 0), 0, "Word 0"); -- First one immediately
                        applyTx(Miso48_v(TransWidth_g*2-1 downto TransWidth_g), TxVldDelay_v, "Word 1");
                    else
                        applyTx(Miso48_v(TransWidth_g*2-1 downto TransWidth_g), 0, "Word 0");
                        applyTx(Miso48_v(TransWidth_g-1 downto 0), TxVldDelay_v, "Word 1"); -- First one immediately
                    end if;
                    applyTx(Miso48_v(TransWidth_g*3-1 downto TransWidth_g*2), 1, "Word 2"); -- aborted transaction;
                end if;
            end if;

            -- *** TX Data Timeout ***
            if run("DataTimeout") then
                if SpiCpha_g = 1 then
                    -- Define Data
                    Mosi16_v := x"1357";

                    -- Start Transaction (exect zero response due to no data)
                    spi_master_push_transaction (net, Master_c, TransWidth_g, Mosi16_v(D'Range), zerosVector(TransWidth_g));

                    -- Expect RX Data
                    expectRx(Mosi16_v(D'Range));

                    -- Expect Responses
                    expectResp(Sent => '1');
                    expectResp(CleanEnd => '1');
                end if;
            end if;

            -- *** CSn operated before Sclk at start/end of transaction ***
            if run("CSnFirst") then
                -- Define Data
                Mosi16_v := toUslv(16#1234#, 16);
                Miso16_v := toUslv(16#5678#, 16);

                -- Start Transaction
                spi_master_push_transaction (net, Master_c, TransWidth_g, Mosi16_v(D'Range), Miso16_v(D'Range), csn_first => true);

                -- Expect RX Data
                expectRx(Mosi16_v(D'Range));

                -- Expect Responses
                expectResp(Sent => '1');
                expectResp(CleanEnd => '1');

                -- Apply TX Data
                applyTx(Miso16_v(D'Range), 0);
            end if;

            -- *** CSn going high in the middle of a transaction ***
            if run("CSnHighDuringTransaction") then
                -- Failing Transaction

                -- Define Data
                Mosi16_v := toUslv(16#1234#, 16);
                Miso16_v := toUslv(16#5678#, 16);

                -- Start Transaction
                if LsbFirst_g then
                    spi_master_push_transaction (net, Master_c, TransWidth_g-2,
                        Mosi16_v(TransWidth_g-3 downto 0), Miso16_v(TransWidth_g-3 downto 0), msg => "Failing Transaction");
                else
                    spi_master_push_transaction (net, Master_c, TransWidth_g-2,
                        Mosi16_v(TransWidth_g-1 downto 2), Miso16_v(TransWidth_g-1 downto 2), msg => "Failing Transaction");
                end if;

                -- Expect Response (Aborted)
                expectResp(Aborted => '1');

                -- Apply TX Data
                applyTx(Miso16_v(D'Range), 0);

                -- Successful Transaction
                -- Define Data
                Mosi16_v := toUslv(16#1A1B#, 16);
                Miso16_v := toUslv(16#3E3F#, 16);

                -- Start Transaction
                spi_master_push_transaction (net, Master_c, TransWidth_g,
                    Mosi16_v(D'range), Miso16_v(D'range), msg => "Successful Transaction");

                -- Expect RX Data
                expectRx(Mosi16_v(D'Range));

                -- Expect Responses
                expectResp(Sent => '1');
                expectResp(CleanEnd => '1');

                -- Apply TX Data
                applyTx(Miso16_v(D'Range), 0);
            end if;

            -- *** Wait until done ***
            waitUntilRxDone;
            waitUntilRespDone;
            waitUntilTxDone;
            wait_until_idle(net, as_sync(Master_c));
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_spi_slave
        generic map (
            TransWidth_g                => TransWidth_g,
            SpiCPol_g                   => SpiCpol_g,
            SpiCPha_g                   => SpiCpha_g,
            LsbFirst_g                  => LsbFirst_g,
            ConsecutiveTransactions_g   => ConsecutiveTransactions_g,
            InternalTriState_g          => InternalTriState_g
        )
        port map (
            -- Control Signals
            Clk             => Clk,
            Rst             => Rst,
            -- RX Data
            Rx_Valid        => Rx_Valid,
            Rx_Data         => Rx_Data,
            -- TX Data
            Tx_Valid        => Tx_Valid,
            Tx_Ready        => Tx_Ready,
            Tx_Data         => Tx_Data,
            -- Response Interface
            Resp_Valid      => Resp_Valid,
            Resp_Sent       => Resp_Sent,
            Resp_Aborted    => Resp_Aborted,
            Resp_CleanEnd   => Resp_CleanEnd,
            -- SPI
            Spi_Sclk        => Spi_Sclk,
            Spi_Mosi        => Spi_Mosi,
            Spi_Cs_n        => Spi_Cs_n,
            -- Miso with internal Tristate
            Spi_Miso        => Spi_Miso_Con,
            -- Miso with external Tristate
            Spi_Miso_o      => Spi_Miso_o,
            Spi_Miso_t      => Spi_Miso_t
        );

    -- External Tri-State buffers
    g_tristate_ext : if not InternalTriState_g generate
        Spi_Miso <= 'Z' when Spi_Miso_t = '1' else Spi_Miso_o;
    end generate;

    -- Internal Tri-State buffer
    g_tristate_int : if InternalTriState_g generate
        Spi_Miso <= Spi_Miso_Con;
    end generate;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity work.olo_test_spi_master_vc
        generic map (
            Instance => Master_c
        )
        port map (
            Sclk     => Spi_Sclk,
            CS_n     => Spi_Cs_n,
            Mosi     => Spi_Mosi,
            Miso     => Spi_Miso
        );

    -- RX Data Checker
    p_vc_rx : process is
        variable Msg_v     : msg_t;
        variable MsgType_v : msg_type_t;
        variable Data_v    : std_logic_vector(TransWidth_g - 1 downto 0);
        variable MsgPtr_v  : string_ptr_t;
    begin

        -- loop messages
        loop
            -- wait until message available
            if is_empty(RxQueue_c) then
                wait until not is_empty(RxQueue_c) and rising_edge(Clk);
            end if;
            RxCheckOngoing <= true;

            -- get message
            Msg_v     := pop(RxQueue_c);
            MsgType_v := message_type(Msg_v);

            -- process message
            if MsgType_v = RxMsg_c then
                -- pop information
                Data_v   := pop(Msg_v);
                MsgPtr_v := new_string_ptr(pop_string(Msg_v));

                -- Wait for RX data
                wait_for_value_stdl(Rx_Valid, '1', 1 ms, "Rx_Valid not asserted: " & to_string(MsgPtr_v));
                wait until rising_edge(Clk);
                check_equal(Rx_Data, Data_v(D'Range), "Rx_Data wrong: " & to_string(MsgPtr_v));
                wait until falling_edge(Clk);
                check_equal(Rx_Valid, '0', "Rx_Valid not deasserted: " & to_string(MsgPtr_v));
            else
                error("Unexpected message type in vc_rx");
            end if;
            RxCheckOngoing <= false;
        end loop;

    end process;

    -- Resp Checker
    p_vc_resp : process is
        variable Msg_v      : msg_t;
        variable MsgType_v  : msg_type_t;
        variable Aborted_v  : std_logic;
        variable Sent_v     : std_logic;
        variable CleanEnd_v : std_logic;
    begin

        -- loop messages
        loop
            -- wait until message available
            if is_empty(RespQueue_c) then
                wait until not is_empty(RespQueue_c) and rising_edge(Clk);
            end if;
            RespCheckOngoing <= true;

            -- get message
            Msg_v     := pop(RespQueue_c);
            MsgType_v := message_type(Msg_v);

            -- process message
            if MsgType_v = RespMsg_c then
                -- pop information
                Sent_v     := pop(Msg_v);
                Aborted_v  := pop(Msg_v);
                CleanEnd_v := pop(Msg_v);

                -- Check Resp
                wait_for_value_stdl(Resp_Valid, '1', 1 ms, "Resp_Valid not asserted");
                check_equal(Resp_Sent, Sent_v, "Resp_Sent wrong");
                check_equal(Resp_Aborted, Aborted_v, "Resp_Aborted wrong");
                check_equal(Resp_CleanEnd, CleanEnd_v, "Resp_CleanEnd not deasserted");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Resp_Valid, '0', "Resp_Valid not deasserted");
            else
                error("Unexpected message type in vc_resp");
            end if;
            RespCheckOngoing <= false;
        end loop;

    end process;

    -- Tx Data
    p_vc_tx : process is
        variable Msg_v         : msg_t;
        variable MsgType_v     : msg_type_t;
        variable Data_v        : std_logic_vector(TransWidth_g - 1 downto 0);
        variable DelayCycles_v : integer;
        variable MsgPtr_v      : string_ptr_t;
    begin

        -- loop messages
        loop
            -- wait until message available
            if is_empty(TxQueue_c) then
                wait until not is_empty(TxQueue_c) and rising_edge(Clk);
            end if;
            TxCheckOngoing <= true;

            -- get message
            Msg_v     := pop(TxQueue_c);
            MsgType_v := message_type(Msg_v);

            -- process message
            if MsgType_v = TxMsg_c then
                -- pop information
                Data_v        := pop(Msg_v);
                DelayCycles_v := pop(Msg_v);
                MsgPtr_v      := new_string_ptr(pop_string(Msg_v));

                -- Apply Data
                wait_for_value_stdl(Tx_Ready, '1', 1 ms, "Tx_Ready not asserted: " & to_string(MsgPtr_v));

                for i in 1 to DelayCycles_v loop
                    wait until rising_edge(Clk);
                end loop;

                Tx_Valid <= '1';
                Tx_Data  <= Data_v;
                wait until rising_edge(Clk);
                Tx_Valid <= '0';
                wait until falling_edge(Clk);
                check_equal(Tx_Ready, '0', "Tx_Ready not de-asserted: " & to_string(MsgPtr_v));
            else
                error("Unexpected message type in vc_tx");
            end if;
            TxCheckOngoing <= false;
        end loop;

    end process;

end architecture;
