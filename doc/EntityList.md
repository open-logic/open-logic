<img src="./Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Entity List

Note that components are split into categories.

## base

### Packages (olo_base_pkg_\<...\>)

Packages with type declarations and functions used in *Open Logic* internally or on its interfaces. 

| Package                                            | Description                                                |
| -------------------------------------------------- | ---------------------------------------------------------- |
| [olo_base_pkg_array](./base/olo_base_pkg_array.md) | Array type definitions (e.g. arrays of *std_logic_vector*) |
| [olo_base_pkg_math](./base/olo_base_pkg_math.md)   | Mathematic functions (e.g. *log2*)                         |
| [olo_base_pkg_logic](./base/olo_base_pkg_logic.md) | Mathematic functions (e.g. *binaryToGray*)                 |

### Clock Crossings (*olo_base_cc_\<...\>*)

Clock crossings are a key topic and they all follow the same [clock crossing principles](./base/clock_crossing_principles.md)

| Entity                                           | Description                                                  |
| ------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_cc_reset](./base/olo_base_cc_reset.md) | Synchronization of resets between two clock domains (bi-directional) |
| [olo_base_cc_bits](./base/olo_base_cc_bits.md)   | Transfer a group of individual single bit signals from one clock domain to another clock domain |
| [olo_base_cc_pulse](./base/olo_base_cc_pulse.md) | Transfer single-cycle pulses from one clock domain to another clock domain |
| [olo_base_cc_simple](./base/olo_base_cc_simple.md)      | Transfer selectively valid data from one clock domain to another clock domain (data/valid pair) |
| [olo_base_cc_status](./base/olo_base_cc_status.md)      | Transfer status and configuration information from one clock domain to another clock domain. The update rate is relatively low but consistency is guaranteed |

### RAM Implementations (olo_base_ram_\<...\>)

| Entity                                         | Description          |
| ---------------------------------------------- | -------------------- |
| [olo_base_ram_sp](./base/olo_base_ram_sp.md)   | Single port RAM      |
| [olo_base_ram_sdp](./base/olo_base_ram_sdp.md) | Simple dual-port RAM |
| [olo_base_ram_tdp](./base/olo_base_ram_tdp.md) | True dual-port RAM   |

### FIFO Implementations (olo_base_fifo_\<...\>)

| Entity                                               | Description                                        |
| ---------------------------------------------------- | -------------------------------------------------- |
| [olo_base_fifo_sync](./base/olo_base_fifo_sync.md)   | Synchronous FIFO (single clock)                    |
| [olo_base_fifo_async](./base/olo_base_fifo_async.md) | Asynchronous FIFO (separate write and read clocks) |

### Width Conversions (olo_base_wconv_\<...\>)

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Increase word width by an integer factor (*OutWidth = InWidth x N*) |
| [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Decrease word width by an integer factor (*OutWidth = InWidth / N*) |

### 

## axi

No content yet.

## interface

No content yet.

