---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler, Switzerland
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

library olo;
use olo.olo_base_pkg_math.all;
use olo.olo_base_pkg_array.all;
use olo.olo_base_pkg_logic.all;
use olo.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_crc_append_be_tb is
    generic (
        runner_cfg    : string;
        CrcName_g     : string;
        RandomStall_g : boolean

    );
end entity;

architecture sim of olo_base_crc_append_be_tb is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------
    constant DataWidth_c : natural := 16;
    constant BeWidth_c   : natural := DataWidth_c/8;

    constant ClkFrequency_c : real := 100.0e6;
    constant ClkPeriod_c    : time := (1 sec)/ClkFrequency_c;

    -- *** Verification Components ***
    -- Slave VC
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length  => DataWidth_c,
            user_length  => BeWidth_c,
            stall_config => new_stall_config(choose(RandomStall_g, 1.0, 0.0), 0, 5)
        );

    -- Master VC
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
            data_length  => DataWidth_c,
            user_length  => BeWidth_c,
            stall_config => new_stall_config(choose(RandomStall_g, 1.0, 0.0), 0, 5)

        );

    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    -- TODO: Use CrcSettings_r from package
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------
    -- Types
    -----------------------------------------------------------------------------------------------
    type CrcName_t is (
            Crc8_DvbS2,
            Crc16_DectX,
            Crc32_IsoHdlc
        );

    type CrcSettings_r is record
        name          : CrcName_t;
        polynomial    : std_logic_vector;
        initialValue  : std_logic_vector;
        bitOrder      : string;
        bitFlipOutput : boolean;
        xorOutput     : std_logic_vector;
    end record;

    -----------------------------------------------------------------------------------------------
    -- Functions
    -----------------------------------------------------------------------------------------------
    -- Get crc algorithms from https://crccalc.com
    function getCrcSettings (crcName : in string) return CrcSettings_r is
    begin
        if toUpper(crcName) = "CRC-8/DVB-S2" then
            return CrcSettings_r'(
                name          => Crc8_DvbS2,
                polynomial    => x"D5",
                initialValue  => x"00",
                bitOrder      => "MSB_FIRST",
                bitFlipOutput => false,
                xorOutput     => x"00"
            );
        elsif toUpper(crcName) = "CRC-16/DECT-X" then
            return CrcSettings_r'(
                name          => Crc16_DectX,
                polynomial    => x"0589",
                initialValue  => x"0000",
                bitOrder      => "MSB_FIRST",
                bitFlipOutput => false,
                xorOutput     => x"0000"
            );
        elsif toUpper(crcName) = "CRC-32/ISO-HDLC" then
            return CrcSettings_r'(
                name          => Crc32_IsoHdlc,
                polynomial    => x"04C11DB7",
                initialValue  => x"FFFFFFFF",
                bitOrder      => "LSB_FIRST",
                bitFlipOutput => true,
                xorOutput     => x"FFFFFFFF"
            );
        else
            assert false
                report "Error: Unsupported crcName"
                severity error;
        end if;
    end function;

    constant CrcSettings_c : CrcSettings_r := getCrcSettings(CrcName_g);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk : std_logic := '0';
    signal Rst : std_logic;

    signal In_Ready : std_logic;
    signal In_Valid : std_logic;
    signal In_Last  : std_logic;
    signal In_Be    : std_logic_vector(DataWidth_c/8-1 downto 0);
    signal In_Data  : std_logic_vector(DataWidth_c-1 downto 0);

    signal Out_Ready : std_logic;
    signal Out_Valid : std_logic;
    signal Out_Last  : std_logic;
    signal Out_Be    : std_logic_vector(DataWidth_c/8 - 1 downto 0);
    signal Out_Data  : std_logic_vector(DataWidth_c-1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Ref_v : axi_stream_reference_t;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for ClkPeriod_c;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("Test") then
                ----------------------------------------------------------------
                -- Packet 1: 
                --     Data:  0xCE
                --     CRC8:  0xDA
                --     CRC16: 0x9925
                --     CRC32: 0xAEDE00CE
                ----------------------------------------------------------------
                push_axi_stream(net, AxisMaster_c, x"00CE", tuser => "01", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"DACE", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"25CE", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"0099", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"3ACE", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"DE00", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"00AE", tuser => "01", tlast => '1', blocking => false);

                end if;

                ----------------------------------------------------------------
                -- Packet 2: 
                --     Data:  0x5AAD
                --     CRC8:  0x08
                --     CRC16: 0x368F
                --     CRC32: 0xA9EA7874
                ----------------------------------------------------------------

                push_axi_stream(net, AxisMaster_c, x"AD5A", tuser => "11", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"AD5A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"0008", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"AD5A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"368F", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"AD5A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"7874", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"A9EA", tuser => "11", tlast => '1', blocking => false);

                end if;

                ----------------------------------------------------------------
                -- Packet 3: 
                --     Data:  0x5DBFB6
                --     CRC8:  0x34
                --     CRC16: 0xA1D8
                --     CRC32: 0xDA7AC03F
                ----------------------------------------------------------------

                push_axi_stream(net, AxisMaster_c, x"BF5D", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"00B6", tuser => "01", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"BF5D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"34B6", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"BF5D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"D8B6", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"00A1", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"BF5D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"3FB6", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"7AC0", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"00DA", tuser => "01", tlast => '1', blocking => false);

                end if;

                ----------------------------------------------------------------
                -- Packet 4: 
                --     Data:  0x4CDD2DBC
                --     CRC8:  0xF6
                --     CRC16: 0x4CD0
                --     CRC32: 0x972A3BB2
                ----------------------------------------------------------------
                push_axi_stream(net, AxisMaster_c, x"DD4C", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"BC2D", tuser => "11", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"DD4C", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"BC2D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"00F6", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"DD4C", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"BC2D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"4CD0", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"DD4C", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"BC2D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"3BB2", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"972A", tuser => "11", tlast => '1', blocking => false);

                end if;

                ----------------------------------------------------------------
                -- TODO
                -- Packet 5: 
                --     Data:  0xA2293FC275
                --     CRC8:  0xD1
                --     CRC16: 0x424B
                --     CRC32: 0xE76B498D
                ----------------------------------------------------------------
                push_axi_stream(net, AxisMaster_c, x"29A2", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"C23F", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"0075", tuser => "01", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"29A2", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C23F", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"D175", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"29A2", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C23F", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"4B75", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"0042", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"29A2", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C23F", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"8D75", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"6B49", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"00E7", tuser => "01", tlast => '1', blocking => false);

                end if;

                ----------------------------------------------------------------
                -- TODO:
                -- Packet 6: 
                --     Data:  0x2A3401B421C8
                --     CRC8:  0x44
                --     CRC16: 0xC563
                --     CRC32: 0x209FF77D
                ----------------------------------------------------------------
                push_axi_stream(net, AxisMaster_c, x"342A", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"B401", tuser => "11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"C821", tuser => "11", tlast => '1');

                if (CrcName_g = "CRC-8/DVB-S2") then
                    check_axi_stream(net, AxisSlave_c, x"342A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"B401", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C821", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"0044", tuser => "01", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-16/DECT-X") then
                    check_axi_stream(net, AxisSlave_c, x"342A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"B401", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C821", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C563", tuser => "11", tlast => '1', blocking => false);

                elsif (CrcName_g = "CRC-32/ISO-HDLC") then
                    check_axi_stream(net, AxisSlave_c, x"342A", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"B401", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"C821", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"F77D", tuser => "11", tlast => '0', blocking => false);
                    check_axi_stream(net, AxisSlave_c, x"209F", tuser => "11", tlast => '1', blocking => false);

                end if;
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
    i_dut : entity olo.olo_base_crc_append
        generic map (
            DataWidth_g    => DataWidth_c,
            CrcByteOrder_g => "LSB_FIRST",

            CrcPolynomial_g    => CrcSettings_c.polynomial,
            CrcInitialValue_g  => CrcSettings_c.initialValue,
            CrcBitOrder_g      => CrcSettings_c.bitOrder,
            CrcBitflipOutput_g => CrcSettings_c.bitFlipOutput,
            CrcXorOutput_g     => CrcSettings_c.xorOutput
        )
        port map (
            Clk => Clk,
            Rst => Rst,

            In_Ready => In_Ready,
            In_Valid => In_Valid,
            In_Last  => In_Last,
            In_Be    => In_Be,
            In_Data  => In_Data,

            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready,
            Out_Last  => Out_Last,
            Out_Be    => Out_Be,
            Out_Data  => Out_Data
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
            TUser  => In_Be,
            TLast  => In_Last
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data,
            TUser  => Out_Be,
            TLast  => Out_Last
        );

end architecture;
