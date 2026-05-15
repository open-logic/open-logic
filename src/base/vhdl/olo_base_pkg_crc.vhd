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
    constant Crc8_DvbS2_c : CrcSettings_r := (
            polynomial    => x"D5",
            initialValue  => x"00",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"00"
        );

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

    constant Crc16_Dds110_c : CrcSettings_r := (
            polynomial    => x"8005",
            initialValue  => x"800D",
            bitOrder      => "MSB_FIRST",
            bitFlipOutput => false,
            xorOutput     => x"0000"
        );

    constant Crc32_IsoHdlc_c : CrcSettings_r := (
            polynomial    => x"04C11DB7",
            initialValue  => x"FFFFFFFF",
            bitOrder      => "LSB_FIRST",
            bitFlipOutput => true,
            xorOutput     => x"FFFFFFFF"
        );

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_crc is

end package body;
