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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_uart_tb is
    generic (
        BaudRate_g                  : integer := 2_000_000; -- default is fast for short sim-times
        DataBits_g                  : integer := 8;
        StopBits_g                  : string  := "1";
        Parity_g                    : string  := "odd";
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_intf_uart_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real    := 105.0e6;
    constant Clk_Period_c    : time    := (1 sec) / Clk_Frequency_c;
    constant TotalBits_c     : integer := choose(Parity_g = "none", DataBits_g, DataBits_g+1);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic := '1';
    signal Rst            : std_logic;
    signal Tx_Valid       : std_logic := '0';
    signal Tx_Ready       : std_logic;
    signal Tx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal Rx_Valid       : std_logic;
    signal Rx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal Rx_ParityError : std_logic;
    signal Uart_Tx        : std_logic;
    signal Uart_Rx        : std_logic := '1';
    signal Uart_RxVc      : std_logic;
    signal Uart_RxPull    : std_logic := '1';

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant MasterUart_c   : uart_master_t   := new_uart_master(
        initial_baud_rate => BaudRate_g
    );
    constant MasterStream_c : stream_master_t := as_stream(MasterUart_c);

    constant SlaveUart_c   : uart_slave_t   := new_uart_slave(
        initial_baud_rate => BaudRate_g,
        data_length => TotalBits_c
    );
    constant SlaveStream_c : stream_slave_t := as_stream(SlaveUart_c);

    constant TxAxis_c : axi_stream_master_t := new_axi_stream_master (
		data_length => DataBits_g
	);

    constant RxAxis_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => DataBits_g,
        user_length => 1
    );

    -- Get all bits including parity
    function getBits (Data : std_logic_vector(DataBits_g-1 downto 0)) return std_logic_vector is
        variable Result_v  : std_logic_vector(TotalBits_c-1 downto 0);
        variable OddOnes_v : std_logic := '0';
    begin
        Result_v(DataBits_g-1 downto 0) := Data;

        -- Loop through data bits
        for i in 0 to DataBits_g-1 loop
            OddOnes_v := OddOnes_v xor Data(i);
        end loop;

        if Parity_g = "even" then
            Result_v(DataBits_g) := OddOnes_v;
        elsif Parity_g = "odd" then
            Result_v(DataBits_g) := not OddOnes_v;
        end if;
        return Result_v;
    end function;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
        variable Data_v          : std_logic_vector(DataBits_g-1 downto 0);
        variable DataAndParity_v : std_logic_vector(TotalBits_c-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            Uart_RxPull <= '1';

            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** Basics ***
            if run("ResetValues") then
                check_equal(Tx_Ready, '0', "Tx_Ready not low after reset");
                check_equal(Rx_Valid, '0', "Rx_Valid not low after reset");
                check_equal(Uart_Tx, '1', "Uart_Tx not high after reset");
                wait until rising_edge(Clk);
                check_equal(Tx_Ready, '1', "Tx_Ready not high after reset");
            end if;

            -- *** Transmit***
            if run("TxSingle") then
                Data_v := toUslv(16#7A#, DataBits_g);
                push_axi_stream(net, TxAxis_c, Data_v);
                check_stream(net, SlaveStream_c, getBits(Data_v));
            end if;

            if run("TxConsecutive") then

                -- Set up transmissions
                for i in 0 to 3 loop
                    push_axi_stream(net, TxAxis_c, toUslv(16#58#+i, DataBits_g));
                end loop;

                -- Check receptions
                for i in 0 to 3 loop
                    check_stream(net, SlaveStream_c, getBits(toUslv(16#58#+i, DataBits_g)));
                end loop;

            end if;

            if run("TxWithGaps") then

                -- 4 transmissions with gaps
                for i in 0 to 3 loop
                    Data_v := toUslv(16#68#+i, DataBits_g);
                    push_axi_stream(net, TxAxis_c, Data_v);
                    check_stream(net, SlaveStream_c, getBits(Data_v));
                    wait for (1 sec)/real(BaudRate_g)*0.63;
                    wait until rising_edge(Clk);
                end loop;

            end if;

            -- *** Receive 1 Transcaction ***
            if run("RxSingle") then
                Data_v := toUslv(16#7A#, DataBits_g);
                push_stream(net, MasterStream_c, getBits(Data_v));
                check_axi_stream(net, RxAxis_c, Data_v, tuser => "0", blocking => false);
            end if;

            if run("RxConsecutive") then

                -- 4 consecutive rececptions
                for i in 0 to 3 loop
                    Data_v := toUslv(16#58#+i, DataBits_g);
                    push_stream(net, MasterStream_c, getBits(Data_v));
                    check_axi_stream(net, RxAxis_c, Data_v, tuser => "0", blocking => false);
                end loop;

            end if;

            if run("ParityError") then
                -- Skip if no parity
                if Parity_g /= "none" then
                    -- Odd Bits
                    Data_v                      := toUslv(16#7A#, DataBits_g);
                    DataAndParity_v             := getBits(Data_v);
                    DataAndParity_v(DataBits_g) := not DataAndParity_v(DataBits_g); -- Flip parity
                    push_stream(net, MasterStream_c, DataAndParity_v);
                    check_axi_stream(net, RxAxis_c, Data_v, tuser => "1", blocking => false);
                    -- Even Bits
                    Data_v                      := toUslv(16#78#, DataBits_g);
                    DataAndParity_v             := getBits(Data_v);
                    DataAndParity_v(DataBits_g) := not DataAndParity_v(DataBits_g); -- Flip parity
                    push_stream(net, MasterStream_c, DataAndParity_v);
                    check_axi_stream(net, RxAxis_c, Data_v, tuser => "1", blocking => false);
                    -- Check Successful transaction after errors
                    Data_v          := toUslv(16#77#, DataBits_g);
                    DataAndParity_v := getBits(Data_v);
                    push_stream(net, MasterStream_c, DataAndParity_v);
                    check_axi_stream(net, RxAxis_c, Data_v, tuser => "0", blocking => false);
                end if;
            end if;

            if run("RxSpike") then
                -- Short spike on Rx
                wait until rising_edge(Clk);
                Uart_RxPull <= '0';
                wait for 0.2*(1 sec)/real(BaudRate_g);
                Uart_RxPull <= '1';
                wait until rising_edge(Clk);
                wait for 2*(1 sec)/real(BaudRate_g);
                -- Send data
                Data_v := toUslv(16#7A#, DataBits_g);
                push_stream(net, MasterStream_c, getBits(Data_v));
                check_axi_stream(net, RxAxis_c, Data_v, tuser => "0", blocking => false);

            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(MasterUart_c));
            wait_until_idle(net, as_sync(RxAxis_c));
            wait_until_idle(net, as_sync(TxAxis_c));
            wait until rising_edge(Clk) and Tx_Ready = '1';
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
    i_dut : entity olo.olo_intf_uart
        generic map (
            ClkFreq_g       => Clk_Frequency_c,
            BaudRate_g      => real(BaudRate_g),
            DataBits_g      => DataBits_g,
            StopBits_g      => StopBits_g,
            Parity_g        => Parity_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Tx_Valid        => Tx_Valid,
            Tx_Ready        => Tx_Ready,
            Tx_Data         => Tx_Data,
            Rx_Valid        => Rx_Valid,
            Rx_Data         => Rx_Data,
            Rx_ParityError  => Rx_ParityError,
            Uart_Tx         => Uart_Tx,
            Uart_Rx         => Uart_Rx
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_uart_master : entity vunit_lib.uart_master
        generic map (
            Uart => MasterUart_c
        )
        port map (
            Tx => Uart_RxVc
        );

    Uart_Rx <= Uart_RxVc and Uart_RxPull;

    vc_uart_slave : entity vunit_lib.uart_slave
        generic map (
            Uart => SlaveUart_c
        )
        port map (
            Rx => Uart_Tx
        );

    vc_tx_data : entity vunit_lib.axi_stream_master
        generic map (
            Master => TxAxis_c
        )
        port map (
            Aclk   => Clk,
            TValid => Tx_Valid,
            TReady => Tx_Ready,
            TData  => Tx_Data
        );

    vc_rx_data : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => RxAxis_c
        )
        port map (
            Aclk        => Clk,
            TValid      => Rx_Valid,
            TData       => Rx_Data,
            TUser(0)    => Rx_ParityError
        );

end architecture;
