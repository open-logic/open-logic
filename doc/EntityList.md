<img src="./Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Entity List

Note that components are split into categories.

## base

### Clock Crossings (*olo_base_cc_<...>*)

Clock crossings are a key topic and they all follow the same [clock crossing principles](./base/clock_crossing_principles.md)

| Entity                                           | Description                                                  |
| ------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_cc_reset](./base/olo_base_cc_reset.md) | Synchronization of resets between two clock domains (bi-directional) |
| [olo_base_cc_bits](./base/olo_base_cc_bits.md)   | Transfer a group of individual single bit signals from one clock domain to another clock domain |
| [olo_base_cc_pulse](./base/olo_base_cc_pulse.md) | Transfer single-cycle pulses from one clock domain to another clock domain |
| [olo_base_cc_simple](olo_base_cc_simple.md)      | Transfer selectively valid data from one clock domain to another clock domain (data/valid pair) |
| [olo_base_cc_status](olo_base_cc_status.md)      | Transfer status and configuration information from one clock domain to another clock domain. The update rate is relatively low but consistency is guaranteed |

## axi

## interface

