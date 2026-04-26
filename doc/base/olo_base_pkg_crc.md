<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_logic

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_pkg_crc.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_pkg_crc.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_crc.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_crc](../../src/base/vhdl/olo_base_pkg_crc.vhd)

## Description

This package contains utility definitions related to CRC not defined in IEEE
packages but used  by _Open Logic_ internally or on its interfaces to the user
(e.g. for port-widths depending on generics). The package is written mainly for
these purposes and does not aim for completeness - nevertheless as a user you
are free to use it for your code of course.

## Definitions

### CRC Algorithm Constants

All CRC Algorithm Constants are of type _CrcSettings_r_, as defined in this package.

The table below lists the CRC Algorithms currently provided by this package.
Their parameter definitions were sourced from
[crccalc.com](https://crccalc.com/?crc=Open-Logic&method=&datatype=ascii&outtype=hex).
Additional standard CRC definitions can also be found on the same site.

| CRC Constant Name    | CRC Standard    | polynomial   | initialValue   | bitOrder    | bitflipOutput   | xorOutput   |
| -------------------- | --------------- | ------------ | -------------- | ----------- | --------------- | ----------- |
| Crc8_DvbS2_c         | CRC-8/DVB-S2    | 0xD5         | 0x00           | "MSB_FIRST" | false           | 0x00        |
| Crc8_Autosar_c       | CRC-8/AUTOSAR   | 0x2F         | 0xFF           | "MSB_FIRST" | false           | 0xFF        |
| Crc8_Bluetooth_c     | CRC-8/BLUETOOTH | 0xA7         | 0x00           | "LSB_FIRST" | true            | 0x00        |
| Crc16_DectR_c        | CRC-16/DECT-R   | 0x0589       | 0x0000         | "MSB_FIRST" | false           | 0x0001      |
| Crc16_DectX_c        | CRC-16/DECT-X   | 0x0589       | 0x0000         | "MSB_FIRST" | false           | 0x0000      |
| Crc16_Dds110_c       | CRC-16/DDS-110  | 0x8005       | 0x800D         | "MSB_FIRST" | false           | 0x0000      |
| Crc32_IsoHdlc_c      | CRC-32/ISO-HDLC | 0x04C11DB7   | 0xFFFFFFFF     | "LSB_FIRST" | true            | 0xFFFFFFFF  |

## Functions

None
