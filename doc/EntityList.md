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

Clock crossings are a key topic and they all follow the same [clock crossing principles](./base/clock_crossing_principles.md). 

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_cc_reset](./base/olo_base_cc_reset.md)     | Synchronization of resets between two clock domains (bi-directional) |
| [olo_base_cc_bits](./base/olo_base_cc_bits.md)       | Transfer a group of individual single bit signals from one clock domain to another clock domain |
| [olo_base_cc_pulse](./base/olo_base_cc_pulse.md)     | Transfer single-cycle pulses from one clock domain to another clock domain |
| [olo_base_cc_simple](./base/olo_base_cc_simple.md)   | Transfer selectively valid data from one clock domain to another clock domain (data/valid pair) |
| [olo_base_cc_status](./base/olo_base_cc_status.md)   | Transfer status and configuration information from one clock domain to another clock domain. The update rate is relatively low but consistency is guaranteed |
| [olo_base_cc_n2xn](./base/olo_base_cc_n2xn.md)       | Transfer data from a slower clock to a faster phase aligned clock (output clock frequency is an exact integer multiple of the input clock frequency and the clocks are phase aligned). |
| [olo_base_cc_xn2n](./base/olo_base_cc_xn2n.md)       | Transfer data from a faster clock to a slower phase aligned clock (input clock frequency is an exact integer multiple of the output clock frequency and the clocks are phase aligned). |
| [olo_base_fifo_async](./base/olo_base_fifo_async.md) | Asynchronous FIFO (separate write and read clocks)<br />This is not a pure clock-crossing entity but it can be used as such. |

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
| [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Increase word width by an integer factor (*OutWidth = InWidth x N*)<br />Convert from TDM to parallel (see [Conventions](./Conventions.md)) |
| [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Decrease word width by an integer factor (*OutWidth = InWidth / N*)<br />Convert from parallel to TDM (see [Conventions](./Conventions.md)) |

### Arbiters (olo_base_arb_\<...\>)

| Entity                                           | Description                                                  |
| ------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_arb_prio](./base/olo_base_arb_prio.md) | Priority arbiter - Always selects the highest priority requester with a pending request. |
| [olo_base_arb_rr](./base/olo_base_arb_rr.md)     | Round robin arbiter - iterate through all requesters with a pending request. |

### TDM (olo_base_tdm_<...>)

See [Conventions](./Conventions.md) for a description about TDM (time-division-multiplexing).

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_tdm_mux](./base/olo_base_tdm_mux.md)       | Select one specific channel from a TDM signal.               |
| [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Convert from TDM to parallel (see [Conventions](./Conventions.md))<br />This is not a pure TDM entity but it can be used for TDM purposes. |
| [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Convert from parallel to TDM (see [Conventions](./Conventions.md))<br />This is not a pure TDM entity but it can be used for TDM purposes. |

### Miscellaneous 

| Entity                                                       | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_pl_stage](./base/olo_base_pl_stage.md)             | Implements one or more pipeline stages (register stages) - with or without support for backpressure (Ready) |
| [olo_base_delay](./base/olo_base_delay.md)                   | Fixed duration delay (fixed number of data-beats)            |
| [olo_base_delay_cfg](./base/olo_base_delay_cfg.md)           | Configurable duration delay (runtime configurable number of data-beats) |
| [olo_base_dyn_sft](./base/olo_base_dyn_sft.md)               | Dynamic barrel shifter (number of bits to shift is configurable per sample at runtime) |
| [olo_base_prbs](./base/olo_base_brbs.md)                     | PRBS (pseudo random binary sequence) generator based on linear feedback shift register (LFSR) implementation. |
| [olo_base_strobe_gen](./base/olo_base_strobe_gen.md)         | Strobe generator. Generate pulses at a fixed frequency       |
| [olo_base_strobe_div](./base/olo_base_strobe_div.md)         | Strobe divider. Only forward every N'th pulse (divide event frequency). <br />Can also be used to convert single-cycle pulses to acknowledged events (pulse stays active until acknowledged). |
| [olo_base_reset_gen](./base/olo_base_reset_gen.md)           | Reset generator - Generates reset pulses of specified duration after configuration and upon request |
| [olo_base_flowctrl_handler](./base/olo_base_flowctrl_handler.md) | Inplements full flow-control (including Ready/back-pressure) around processing entities that do not support Ready/back-pressure natively. |

## axi

| Entity                                                  | Description                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| [olo_axi_pl_stage](./axi/olo_axi_pl_stage.md)           | Implements a AXI4 pipeline stage, registering all signals of an AXI4 interface.<br />Can be used for AXI4-Lite as well. |
| [olo_axi_lite_slave](./axi/olo_axi_lite_slave.md)       | Interface to attach user register banks and memories to the AXI4-Lite bus. |
| [olo_axi_master_simple](./axi/olo_axi_master_simple.md) | AXI4 master - does execute arbitrarily sized transfer over AXI4. The *_simple* version of the master does only allow access to word-aligned addresses and sizes. |
| [olo_axi_master_full](./axi/olo_axi_master_full.md)     | AXI4 master - Same as [olo_axi_master_simple](./axi/olo_axi_master_simple.md) but does allow access that are not word-aligned (in terms of start address, size or both). |

## intf

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_intf_sync](./intf/olo_intf_sync.md)             | Double stage synchronizer for external signals.              |
| [olo_intf_i2c_master](./intf/olo_intf_i2c_master.md) | I2C Master - Supports the full standard including arbitration (multi-master I2C) and clock stretching. |
| [olo_intf_spi_master](./intf/olo_intf_spi_master.md) | SPI Master - Supports handling multiple slaves and variable width transactions. |
| [olo_intf_debounce](./intf/olo_intf_debounce.md)     | Debouncer (for bouncing signals from buttons and switches) - Includes double-stage synchronizers. |
| [olo_intf_clk_meas](./intf/olo_intf_clk_meas.md)     | Measure the frequency of a clock.                            |

