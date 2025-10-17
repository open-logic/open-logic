---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bruendler, Switzerland
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
entity olo_intf_uart_clkdrift_tb is
    generic (
        BaudRate_g                  : integer := 2_000_000; -- default is fast for short sim-times
        DataBits_g                  : integer := 8;
        StopBits_g                  : string  := "1";
        Parity_g                    : string  := "odd";
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_intf_uart_clkdrift_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkA_Frequency_c : real := 101.9e6;
    constant ClkA_Period_c    : time := (1 sec) / ClkA_Frequency_c;
    constant ClkB_Frequency_c : real := 100.0e6; -- Slightly slower clock to create drift
    constant ClkB_Period_c    : time := (1 sec) / ClkB_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    -- Instance A
    signal A_Clk            : std_logic := '1';
    signal A_Rst            : std_logic;
    signal A_Tx_Valid       : std_logic := '0';
    signal A_Tx_Ready       : std_logic;
    signal A_Tx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal A_Rx_Valid       : std_logic;
    signal A_Rx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal A_Rx_ParityError : std_logic;

    -- Instance B
    signal B_Clk            : std_logic := '1';
    signal B_Rst            : std_logic;
    signal B_Tx_Valid       : std_logic := '0';
    signal B_Tx_Ready       : std_logic;
    signal B_Tx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal B_Rx_Valid       : std_logic;
    signal B_Rx_Data        : std_logic_vector(DataBits_g - 1 downto 0);
    signal B_Rx_ParityError : std_logic;

    -- UART
    signal Uart_A2b : std_logic;
    signal Uart_B2a : std_logic := '1';

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Components ***
    constant A_TxAxis_c : axi_stream_master_t := new_axi_stream_master (
		data_length => DataBits_g,
        stall_config => new_stall_config(0.8, 500, 600)
	);
    constant B_TxAxis_c : axi_stream_master_t := new_axi_stream_master (
		data_length => DataBits_g,
        stall_config => new_stall_config(0.8, 500, 600)
	);

    constant A_RxAxis_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => DataBits_g,
        user_length => 1
    );
    constant B_RxAxis_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => DataBits_g,
        user_length => 1
    );

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
        variable Data_v : std_logic_vector(DataBits_g-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(A_Clk);
            A_Rst <= '1';
            wait until rising_edge(B_Clk);
            B_Rst <= '1';
            wait for 1 us;
            wait until rising_edge(A_Clk);
            A_Rst <= '0';
            wait until rising_edge(B_Clk);
            B_Rst <= '0';
            wait until rising_edge(A_Clk);
            wait until rising_edge(B_Clk);

            -- *** Transmit***
            if run("200Bytes") then

                for i in 0 to 199 loop
                    -- A2B
                    Data_v := toUslv(16#AB#, DataBits_g);
                    push_axi_stream(net, A_TxAxis_c, Data_v);
                    check_axi_stream(net, B_RxAxis_c, Data_v, tuser => "0", blocking => false, msg => "A->B");
                    -- B2A
                    Data_v := toUslv(16#12#, DataBits_g);
                    push_axi_stream(net, B_TxAxis_c, Data_v);
                    check_axi_stream(net, A_RxAxis_c, Data_v, tuser => "0", blocking => false, msg => "B->A");
                end loop;

            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(A_RxAxis_c));
            wait_until_idle(net, as_sync(B_RxAxis_c));
            wait_until_idle(net, as_sync(A_TxAxis_c));
            wait_until_idle(net, as_sync(B_TxAxis_c));
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    A_Clk <= not A_Clk after 0.5*ClkA_Period_c;
    B_Clk <= not B_Clk after 0.5*ClkB_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut_a : entity olo.olo_intf_uart
        generic map (
            ClkFreq_g       => ClkA_Frequency_c,
            BaudRate_g      => real(BaudRate_g),
            DataBits_g      => DataBits_g,
            StopBits_g      => StopBits_g,
            Parity_g        => Parity_g
        )
        port map (
            Clk             => A_Clk,
            Rst             => A_Rst,
            Tx_Valid        => A_Tx_Valid,
            Tx_Ready        => A_Tx_Ready,
            Tx_Data         => A_Tx_Data,
            Rx_Valid        => A_Rx_Valid,
            Rx_Data         => A_Rx_Data,
            Rx_ParityError  => A_Rx_ParityError,
            Uart_Tx         => Uart_A2b,
            Uart_Rx         => Uart_B2a
        );

    i_dut_b : entity olo.olo_intf_uart
        generic map (
            ClkFreq_g       => ClkA_Frequency_c,    -- This is A Frequency, to make sure i_dut_b has a slightly drifting sampling point
            BaudRate_g      => real(BaudRate_g),
            DataBits_g      => DataBits_g,
            StopBits_g      => StopBits_g,
            Parity_g        => Parity_g
        )
        port map (
            Clk             => B_Clk,
            Rst             => B_Rst,
            Tx_Valid        => B_Tx_Valid,
            Tx_Ready        => B_Tx_Ready,
            Tx_Data         => B_Tx_Data,
            Rx_Valid        => B_Rx_Valid,
            Rx_Data         => B_Rx_Data,
            Rx_ParityError  => B_Rx_ParityError,
            Uart_Tx         => Uart_B2a,
            Uart_Rx         => Uart_A2b
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_a_tx_data : entity vunit_lib.axi_stream_master
        generic map (
            Master => A_TxAxis_c
        )
        port map (
            Aclk   => A_Clk,
            TValid => A_Tx_Valid,
            TReady => A_Tx_Ready,
            TData  => A_Tx_Data
        );

    vc_a_rx_data : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => A_RxAxis_c
        )
        port map (
            Aclk        => A_Clk,
            TValid      => A_Rx_Valid,
            TData       => A_Rx_Data,
            TUser(0)    => A_Rx_ParityError
        );

    vc_b_tx_data : entity vunit_lib.axi_stream_master
        generic map (
            Master => B_TxAxis_c
        )
        port map (
            Aclk   => B_Clk,
            TValid => B_Tx_Valid,
            TReady => B_Tx_Ready,
            TData  => B_Tx_Data
        );

    vc_b_rx_data : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => B_RxAxis_c
        )
        port map (
            Aclk        => B_Clk,
            TValid      => B_Rx_Valid,
            TData       => B_Rx_Data,
            TUser(0)    => B_Rx_ParityError
        );

end architecture;
