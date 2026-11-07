---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing crc constants.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pkg_crc.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_crc is

    -- *** Types ***
    type CrcSettings_r is record
        polynomial    : std_logic_vector;
        initialValue  : std_logic_vector;
        bitOrder      : string;
        bitFlipOutput : boolean;
        xorOutput     : std_logic_vector;
    end record;

    -- *** Constants ***
    constant Crc8_Autosar_c : CrcSettings_r := (
            polynomial    => x"2F",
            initialValue  => x"FF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FF"
        );

    constant Crc8_Bluetooth_c : CrcSettings_r := (
            polynomial    => x"A7",
            initialValue  => x"00",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc8_Cdma2000_c : CrcSettings_r := (
            polynomial    => x"9B",
            initialValue  => x"FF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Darc_c : CrcSettings_r := (
            polynomial    => x"39",
            initialValue  => x"00",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc8_DvbS2_c : CrcSettings_r := (
            polynomial    => x"D5",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_GsmA_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_GsmB_c : CrcSettings_r := (
            polynomial    => x"49",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FF"
        );

    constant Crc8_Hitag_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"FF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_I4321_c : CrcSettings_r := (
            polynomial    => x"07",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"55"
        );

    constant Crc8_ICode_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"FD",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Lte_c : CrcSettings_r := (
            polynomial    => x"9B",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_MaximDow_c : CrcSettings_r := (
            polynomial    => x"31",
            initialValue  => x"00",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc8_MifareMad_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"C7",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Nrsc5_c : CrcSettings_r := (
            polynomial    => x"31",
            initialValue  => x"FF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Opensafety_c : CrcSettings_r := (
            polynomial    => x"2F",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Rohc_c : CrcSettings_r := (
            polynomial    => x"07",
            initialValue  => x"FF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc8_SaeJ1850_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"FF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FF"
        );

    constant Crc8_Smbus_c : CrcSettings_r := (
            polynomial    => x"07",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

    constant Crc8_Tech3250_c : CrcSettings_r := (
            polynomial    => x"1D",
            initialValue  => x"FF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc8_Wcdma_c : CrcSettings_r := (
            polynomial    => x"9B",
            initialValue  => x"00",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00"
        );

    constant Crc16_Arc_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"0000",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Cdma2000_c : CrcSettings_r := (
            polynomial    => x"C867",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Cms_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Dds110_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"800D",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_DectR_c : CrcSettings_r := (
            polynomial    => x"0589",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0001"
        );

    constant Crc16_DectX_c : CrcSettings_r := (
            polynomial    => x"0589",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Dnp_c : CrcSettings_r := (
            polynomial    => x"3D65",
            initialValue  => x"0000",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFF"
        );

    constant Crc16_En13757_c : CrcSettings_r := (
            polynomial    => x"3D65",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Genibus_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Gsm_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Ibm3740_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_IbmSdlc_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"FFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFF"
        );

    constant Crc16_IsoIec144433A_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"C6C6",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Kermit_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"0000",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Lj1200_c : CrcSettings_r := (
            polynomial    => x"6F63",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_M17_c : CrcSettings_r := (
            polynomial    => x"5935",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_MaximDow_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"0000",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Mcrf4xx_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"FFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Modbus_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"FFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Nrsc5_c : CrcSettings_r := (
            polynomial    => x"080B",
            initialValue  => x"FFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_OpensafetyA_c : CrcSettings_r := (
            polynomial    => x"5935",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_OpensafetyB_c : CrcSettings_r := (
            polynomial    => x"755B",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Profibus_c : CrcSettings_r := (
            polynomial    => x"1DCF",
            initialValue  => x"FFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Riello_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"B2AA",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_SpiFujitsu_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"1D0F",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_T10Dif_c : CrcSettings_r := (
            polynomial    => x"8BB7",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Teledisk_c : CrcSettings_r := (
            polynomial    => x"A097",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Tms37157_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"89EC",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"0000"
        );

    constant Crc16_Umts_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc16_Usb_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"FFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFF"
        );

    constant Crc16_Xmodem_c : CrcSettings_r := (
            polynomial    => x"1021",
            initialValue  => x"0000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc32_Aixm_c : CrcSettings_r := (
            polynomial    => x"814141AB",
            initialValue  => x"00000000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00000000"
        );

    constant Crc32_Autosar_c : CrcSettings_r := (
            polynomial    => x"F4ACFB13",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_Base91D_c : CrcSettings_r := (
            polynomial    => x"A833982B",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_Bzip2_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_CdRomEdc_c : CrcSettings_r := (
            polynomial    => x"8001801B",
            initialValue  => x"00000000",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00000000"
        );

    constant Crc32_Cksum_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"00000000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_Iscsi_c : CrcSettings_r := (
            polynomial    => x"1EDC6F41",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_IsoHdlc_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFFFFFF"
        );

    constant Crc32_Jamcrc_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00000000"
        );

    constant Crc32_Mef_c : CrcSettings_r := (
            polynomial    => x"741B8CD7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"00000000"
        );

    constant Crc32_Mpeg2_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00000000"
        );

    constant Crc32_Xfer_c : CrcSettings_r := (
            polynomial    => x"000000AF",
            initialValue  => x"00000000",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00000000"
        );

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_crc is

end package body;
