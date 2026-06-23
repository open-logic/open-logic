---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler, Switzerland
-- Authors: Rene Brglez
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

library olo;
    use olo.olo_base_pkg_crc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_crc_tb is
    generic (
        runner_cfg : string;
        CrcName_g  : string
    );
end entity;

architecture sim of olo_base_pkg_crc_tb is
    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : natural := 8; 

    -----------------------------------------------------------------------------------------------
    -- Functions
    -----------------------------------------------------------------------------------------------
    -- Get crc algorithms from https://crccalc.com
    function getCrcSettings (crcName : in string) return CrcSettings_r is
    begin
        if crcName = "Crc8_DvbS2_c" then
            return Crc8_DvbS2_c;
        elsif crcName = "Crc8_Autosar_c" then
            return Crc8_Autosar_c;
        elsif crcName = "Crc8_Bluetooth_c" then
            return Crc8_Bluetooth_c;
        elsif crcName = "Crc16_DectR_c" then
            return Crc16_DectR_c;
        elsif crcName = "Crc16_DectX_c" then
            return Crc16_DectX_c;
        elsif crcName = "Crc16_Dds110_c" then
            return Crc16_Dds110_c;
        elsif crcName = "Crc32_IsoHdlc_c" then
            return Crc32_IsoHdlc_c;
        else
            assert false
                report "Error: Unsupported crcName"
                severity error;
        end if;
    end function;

    -- Get expected crc from https://crccalc.com
    function getExpectedCrc (
        input   : in string;
        crcName : in string) return std_logic_vector is
    begin
        if (input = "02") then

            if crcName = "Crc8_DvbS2_c" then
                return x"7F";
            elsif crcName = "Crc8_Autosar_c" then
                return x"E3";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"D6";
            elsif crcName = "Crc16_DectR_c" then
                return x"0B13";
            elsif crcName = "Crc16_DectX_c" then
                return x"0B12";
            elsif crcName = "Crc16_Dds110_c" then
                return x"0E0C";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"3C0C8EA1";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "53AF") then

            if crcName = "Crc8_DvbS2_c" then
                return x"24";
            elsif crcName = "Crc8_Autosar_c" then
                return x"E8";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"F3";
            elsif crcName = "Crc16_DectR_c" then
                return x"647D";
            elsif crcName = "Crc16_DectX_c" then
                return x"647C";
            elsif crcName = "Crc16_Dds110_c" then
                return x"69C3";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"9626A211";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "3B7EC8") then

            if crcName = "Crc8_DvbS2_c" then
                return x"1E";
            elsif crcName = "Crc8_Autosar_c" then
                return x"FF";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"C9";
            elsif crcName = "Crc16_DectR_c" then
                return x"297D";
            elsif crcName = "Crc16_DectX_c" then
                return x"297C";
            elsif crcName = "Crc16_Dds110_c" then
                return x"A1E9";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"F37CCD99";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "924CA7F1") then

            if crcName = "Crc8_DvbS2_c" then
                return x"F0";
            elsif crcName = "Crc8_Autosar_c" then
                return x"22";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"65";
            elsif crcName = "Crc16_DectR_c" then
                return x"0265";
            elsif crcName = "Crc16_DectX_c" then
                return x"0264";
            elsif crcName = "Crc16_Dds110_c" then
                return x"3D3D";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"64716A33";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        else
            assert false
                report "getExpectedCrc(): Unsupported input = " & input
                severity error;
        end if;
    end function;

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    constant CrcSettings_c : CrcSettings_r := getCrcSettings(CrcName_g);

    -- *** Verification Components ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
            data_length  => DataWidth_c,
            stall_config => new_stall_config(0.0, 5, 10)
        );

    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length  => CrcSettings_c.polynomial'length,
            stall_config => new_stall_config(0.0, 5, 10)
        );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '1';

    signal In_Valid : std_logic;
    signal In_Ready : std_logic;
    signal In_Data  : std_logic_vector(DataWidth_c - 1 downto 0);
    signal In_Last  : std_logic;

    signal Out_Ready : std_logic;
    signal Out_Valid : std_logic;
    signal Out_Crc   : std_logic_vector(CrcSettings_c.polynomial'length - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable ExpectedCrc_v : std_logic_vector(CrcSettings_c.polynomial'length - 1 downto 0);
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

            if run("Test-OneByte") then
                ----------------------------------------------------------------
                -- 02
                push_axi_stream(net, AxisMaster_c, x"02", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("02", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(02)");

            elsif run("Test-TwoBytes") then
                ----------------------------------------------------------------
                -- 53AF
                push_axi_stream(net, AxisMaster_c, x"53", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"AF", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("53AF", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(53AF)");

            elsif run("Test-ThreeBytes") then
                ----------------------------------------------------------------
                -- 3B7EC8
                push_axi_stream(net, AxisMaster_c, x"3B", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"7E", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"C8", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("3B7EC8", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(3B7EC8)");

            elsif run("Test-FourBytes") then
                ----------------------------------------------------------------
                -- 924CA7F1
                push_axi_stream(net, AxisMaster_c, x"92", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"4C", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"A7", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"F1", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("924CA7F1", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(924CA7F1)");

            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_crc
        generic map (
            DataWidth_g     => DataWidth_c,
            Polynomial_g    => CrcSettings_c.polynomial,
            InitialValue_g  => CrcSettings_c.initialValue,
            BitOrder_g      => CrcSettings_c.bitOrder,
            BitflipOutput_g => CrcSettings_c.bitFlipOutput,
            XorOutput_g     => CrcSettings_c.xorOutput
        )
        port map (
            Clk => Clk,
            Rst => Rst,

            In_Data  => In_Data,
            In_Valid => In_Valid,
            In_Ready => In_Ready,
            In_Last  => In_Last,

            Out_Crc   => Out_Crc,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data,
            TLast  => In_Last
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TReady => Out_Ready,
            TValid => Out_Valid,
            TData  => Out_Crc
        );

end architecture;
