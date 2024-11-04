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
    use work.olo_test_spi_slave_pkg.all;
    use work.olo_test_activity_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_spi_master_tb is
    generic (
        BusFrequency_g              : integer              := 10_000_000;
        LsbFirst_g                  : boolean              := false;
        SpiCpha_g                   : integer range 0 to 1 := 0;
        SpiCpol_g                   : integer range 0 to 1 := 0;
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_intf_spi_master_tb is

    -----------------------------------------------------------------------------------------------
    -- Fixed Generics
    -----------------------------------------------------------------------------------------------
    constant SclkFreq_c      : real      := real(BusFrequency_g);
    constant MaxTransWidth_c : positive  := 32;
    constant CsHighTime_c    : real      := 100.0e-9;
    constant SlaveCnt_c      : positive  := 2;
    constant MosiIdleState_c : std_logic := '0';

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    -- Contral Sginal
    signal Clk            : std_logic                                                := '0';
    signal Rst            : std_logic                                                := '0';
    signal Cmd_Valid      : std_logic                                                := '0';
    signal Cmd_Ready      : std_logic;
    signal Cmd_Slave      : std_logic_vector(log2ceil(SlaveCnt_c) - 1 downto 0)      := (others => '0');
    signal Cmd_Data       : std_logic_vector(MaxTransWidth_c - 1 downto 0)           := (others => '0');
    signal Cmd_TransWidth : std_logic_vector(log2ceil(MaxTransWidth_c+1)-1 downto 0) := (others => '0');
    signal Resp_Valid     : std_logic;
    signal Resp_Data      : std_logic_vector(MaxTransWidth_c - 1 downto 0);
    signal Spi_Sclk       : std_logic;
    signal Spi_Mosi       : std_logic;
    signal Spi_Miso       : std_logic                                                := '0';
    signal Spi_Cs_n       : std_logic_vector(SlaveCnt_c - 1 downto 0)                := (others => '1');

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant Slave0_c : olo_test_spi_slave_t := new_olo_test_spi_slave(
        bus_frequency   => SclkFreq_c,
        lsb_first       => LsbFirst_g,
        max_trans_width => MaxTransWidth_c,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

    constant Slave1_c : olo_test_spi_slave_t := new_olo_test_spi_slave(
        bus_frequency   => SclkFreq_c,
        lsb_first       => LsbFirst_g,
        max_trans_width => MaxTransWidth_c,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

    procedure sendCommand (
        SlaveIdx              : integer;
        TxData                : std_logic_vector;
        signal Cmd_Slave      : out std_logic_vector;
        signal Cmd_Valid      : out std_logic;
        signal Cmd_Data       : out std_logic_vector;
        signal Cmd_TransWidth : out std_logic_vector) is
    begin
        wait until rising_edge(Clk);
        check_equal(Cmd_Ready, '1', "Cmd_Ready not asserted");
        Cmd_Slave                      <= toUslv(SlaveIdx, Cmd_Slave'length);
        Cmd_Valid                      <= '1';
        Cmd_Data(TxData'high downto 0) <= TxData;
        Cmd_TransWidth                 <= toUslv(TxData'length, Cmd_TransWidth'length);

        wait until rising_edge(Clk);
        Cmd_Valid <= '0';

        wait until falling_edge(Clk);
        check_equal(Cmd_Ready, '0', "Cmd_Ready not de-asserted");

    end procedure;

    procedure checkResponse (
        RxData : std_logic_vector) is
    begin
        wait until rising_edge(Clk) and Resp_Valid = '1';
        check_equal(Cmd_Ready, '1', "Cmd_Ready not asserted");
        check_equal(Resp_Data(RxData'high downto 0), RxData, "Unexpected RxData");
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);

    p_control : process is
        variable Tx32_v, Rx32_v : std_logic_vector(31 downto 0);
        variable Tx16_v, Rx16_v : std_logic_vector(15 downto 0);
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
                wait for 1 us;
                check_equal(Cmd_Ready, '1', "Cmd_Ready not asserted");
                check_equal(Resp_Valid, '0', "Resp_Valid");
                check_equal(Spi_Cs_n, onesVector(SlaveCnt_c), "Spi_Cs_n");
            end if;

            -- *** Transfers ***
            if run("FullWidthTransfer") then
                -- Cmd_Slave Expectation
                Tx32_v := x"12345678";
                Rx32_v := x"DEADBEEF";
                spi_slave_push_transaction (net, Slave0_c, MaxTransWidth_c, data_mosi => Tx32_v, data_miso => Rx32_v);

                -- Send command
                sendCommand(0, Tx32_v, Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                checkResponse(Rx32_v);
            end if;

            if run("ReducedWidthTransfer") then
                -- Cmd_Slave Expectation
                Tx16_v := x"11AA";
                Rx16_v := x"EE33";
                spi_slave_push_transaction (net, Slave0_c, 16, data_mosi => Tx16_v, data_miso => Rx16_v);

                -- Send command
                sendCommand(0, Tx16_v, Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                checkResponse(Rx16_v);
            end if;

            -- *** Cmd_Slave Selection ***
            if run("SlaveSelection") then
                -- Cmd_Slave Expectation
                spi_slave_push_transaction (net, Slave0_c, MaxTransWidth_c, data_mosi => x"11111111", data_miso => x"22222222");
                spi_slave_push_transaction (net, Slave1_c, MaxTransWidth_c, data_mosi => x"33333333", data_miso => x"44444444");

                -- Cmd_Slave 1 Transfer
                sendCommand(1, x"33333333", Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                checkResponse(x"44444444");

                -- Cmd_Slave 0 Transfer
                sendCommand(0, x"11111111", Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                checkResponse(x"22222222");
            end if;

            -- *** Edge Cases ***
            if run("Cmd_ValidWhileBusy") then
                -- Cmd_Slave Expectation
                spi_slave_push_transaction (net, Slave0_c, MaxTransWidth_c, data_mosi => x"AAAAAAAA", data_miso => x"BBBBBBBB");
                spi_slave_push_transaction (net, Slave0_c, MaxTransWidth_c, data_mosi => x"CCCCCCCC", data_miso => x"DDDDDDDD");

                -- Send command 1 (and start during busy)
                sendCommand(0, x"AAAAAAAA", Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                check_equal(Cmd_Ready, '0', "Cmd_Ready not de-asserted");
                wait until rising_edge(Clk);
                Cmd_Valid <= '1';
                wait until rising_edge(Clk);
                Cmd_Valid <= '0';
                checkResponse(x"BBBBBBBB");

                -- Send Command 2
                sendCommand(0, x"CCCCCCCC", Cmd_Slave, Cmd_Valid, Cmd_Data, Cmd_TransWidth);
                checkResponse(x"DDDDDDDD");
            end if;

            -- *** Wait until done ***
            wait_until_idle(net, as_sync(Slave0_c));
            wait_until_idle(net, as_sync(Slave1_c));
            wait for 10 us;

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
    i_dut : entity olo.olo_intf_spi_master
        generic map (
            ClkFreq_g       => Clk_Frequency_c,
            SclkFreq_g      => SclkFreq_c,
            MaxTransWidth_g => MaxTransWidth_c,
            CsHighTime_g    => CsHighTime_c,
            SpiCPol_g       => SpiCPOL_g,
            SpiCPha_g       => SpiCPHA_g,
            SlaveCnt_g      => SlaveCnt_c,
            LsbFirst_g      => LsbFirst_g,
            MosiIdleState_g => MosiIdleState_c
        )
        port map (
            -- Control Signals
            Clk             => Clk,
            Rst             => Rst,
            -- Command Interface
            Cmd_Valid       => Cmd_Valid,
            Cmd_Slave       => Cmd_Slave,
            Cmd_Ready       => Cmd_Ready,
            Cmd_TransWidth  => Cmd_TransWidth,
            Cmd_Data        => Cmd_Data,
            -- Response interface
            Resp_Valid      => Resp_Valid,
            Resp_Data       => Resp_Data,
            -- SPI
            Spi_Sclk        => Spi_Sclk,
            Spi_Mosi        => Spi_Mosi,
            Spi_Miso        => Spi_Miso,
            Spi_Cs_n        => Spi_Cs_n
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_slave0 : entity work.olo_test_spi_slave_vc
        generic map (
            Instance => Slave0_c
        )
        port map (
            Sclk     => Spi_Sclk,
            CS_n     => Spi_Cs_n(0),
            Mosi     => Spi_Mosi,
            Miso     => Spi_Miso
        );

    vc_slave1 : entity work.olo_test_spi_slave_vc
        generic map (
            Instance => Slave1_c
        )
        port map (
            Sclk     => Spi_Sclk,
            CS_n     => Spi_Cs_n(1),
            Mosi     => Spi_Mosi,
            Miso     => Spi_Miso
        );

end architecture;
