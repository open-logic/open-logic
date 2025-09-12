<img src="./Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Entity List

Note that components are split into categories.

## base

This area contains all base functionality that is required in most FPGA designs.

### Packages (olo_base_pkg_\<...\>)

Packages with type declarations and functions used in _Open Logic_ internally or on its interfaces.

| Package                                                    | Description                                                  |
| ---------------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_pkg_array](./base/olo_base_pkg_array.md)         | Array type definitions (e.g. arrays of _std_logic_vector_)   |
| [olo_base_pkg_math](./base/olo_base_pkg_math.md)           | Mathematic functions (e.g. _log2_)                           |
| [olo_base_pkg_logic](./base/olo_base_pkg_logic.md)         | Mathematic functions (e.g. _binaryToGray_)                   |
| [olo_base_pkg_string](./base/olo_base_pkg_string.md)       | String functions (e.g. _toLower_)                            |
| [olo_base_pkg_attribute](./base/olo_base_pkg_attribute.md) | Definition of synthesis attributes for different tools. **For internal use within Open Logic only** |

### Clock Crossings (_olo_base_cc_\<...\>_)

Clock crossings are a key topic and they all follow the same
[clock crossing principles](./base/clock_crossing_principles.md).

A selection table summarizing the pros and cons of all the different clock crossings is also provided in
[clock crossing principles](./base/clock_crossing_principles.md). If unsure which entity to select, refer to this table.

| Entity                                                   | Description                                                  |
| -------------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_cc_reset](./base/olo_base_cc_reset.md)         | Synchronization of resets between two clock domains (bi-directional) |
| [olo_base_cc_bits](./base/olo_base_cc_bits.md)           | Transfer a group of individual single bit signals from one clock domain to another clock domain |
| [olo_base_cc_pulse](./base/olo_base_cc_pulse.md)         | Transfer single-cycle pulses from one clock domain to another clock domain |
| [olo_base_cc_simple](./base/olo_base_cc_simple.md)       | Transfer selectively valid data from one clock domain to another clock domain (data/valid pair) |
| [olo_base_cc_status](./base/olo_base_cc_status.md)       | Transfer status and configuration information from one clock domain to another clock domain. The update rate is relatively low but consistency is guaranteed |
| [olo_base_cc_n2xn](./base/olo_base_cc_n2xn.md)           | Transfer data from a slower clock to a faster phase aligned clock (output clock frequency is an exact integer multiple of the input clock frequency and the clocks are phase aligned). |
| [olo_base_cc_xn2n](./base/olo_base_cc_xn2n.md)           | Transfer data from a faster clock to a slower phase aligned clock (input clock frequency is an exact integer multiple of the output clock frequency and the clocks are phase aligned). |
| [olo_base_cc_handshake](./base/olo_base_cc_handshake.md) | Transfer data from one clock domain to another clock domain using the standard _Valid/Ready_ handshaking.<br />For technologies with distributed RAM (LUT can be used as small RAM), [olo_base_fifo_async](./base/olo_base_fifo_async.md) in most cases is preferred over this entity. |
| [olo_base_fifo_async](./base/olo_base_fifo_async.md)     | Asynchronous FIFO (separate write and read clocks)<br />This is not a pure clock-crossing entity but it can be used as such. |

### RAM Implementations (olo_base_ram_\<...\>)

| Entity                                         | Description          |
| ---------------------------------------------- | -------------------- |
| [olo_base_ram_sp](./base/olo_base_ram_sp.md)   | Single port RAM      |
| [olo_base_ram_sdp](./base/olo_base_ram_sdp.md) | Simple dual-port RAM |
| [olo_base_ram_tdp](./base/olo_base_ram_tdp.md) | True dual-port RAM   |

### FIFO Implementations (olo_base_fifo_\<...\>)

| Entity                                                 | Description                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_fifo_sync](./base/olo_base_fifo_sync.md)     | Synchronous FIFO (single clock)                              |
| [olo_base_fifo_async](./base/olo_base_fifo_async.md)   | Asynchronous FIFO (separate write and read clocks)           |
| [olo_base_fifo_packet](./base/olo_base_fifo_packet.md) | Packet FIFO (store and forward) with the ability to drop packets on the write side and skip or repeat packets on the read side |

### Width Conversions (olo_base_wconv_\<...\>)

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Increase word width by an integer factor (_OutWidth = InWidth x N_)<br />Convert from TDM to parallel (see [Conventions](./Conventions.md)) |
| [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Decrease word width by an integer factor (_OutWidth = InWidth / N_)<br />Convert from parallel to TDM (see [Conventions](./Conventions.md)) |
| [olo_base_wconv_n2m](./base/olo_base_wconv_n2m.md)  | Arbitrary word width converter  |

### Arbiters (olo_base_arb_\<...\>)

| Entity                                           | Description                                                  |
| ------------------------------------------------ | ------------------------------------------------------------ |
| [olo_base_arb_prio](./base/olo_base_arb_prio.md) | Priority arbiter - Always selects the highest priority requester with a pending request. |
| [olo_base_arb_rr](./base/olo_base_arb_rr.md)     | Round robin arbiter - iterate through all requesters with a pending request. |
| [olo_base_arb_wrr](./base/olo_base_arb_wrr.md)   | Weighted Round robin arbiter - iterate through all requesters based on assigned weights with a pending request. |

### TDM (olo_base_tdm_\<...\>)

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
| [olo_base_prbs](./base/olo_base_prbs.md)                     | PRBS (pseudo random binary sequence) generator based on linear feedback shift register (LFSR) implementation. |
| [olo_base_strobe_gen](./base/olo_base_strobe_gen.md)         | Strobe generator. Generate pulses at a fixed frequency       |
| [olo_base_strobe_div](./base/olo_base_strobe_div.md)         | Strobe divider. Only forward every N'th pulse (divide event frequency). <br />Can also be used to convert single-cycle pulses to acknowledged events (pulse stays active until acknowledged). |
| [olo_base_reset_gen](./base/olo_base_reset_gen.md)           | Reset generator - Generates reset pulses of specified duration after configuration and upon request |
| [olo_base_cam](./base/olo_base_cam.md)                       | Content addressable memory                                   |
| [olo_base_flowctrl_handler](./base/olo_base_flowctrl_handler.md) | Implements full flow-control (including Ready/back-pressure) around processing entities that do not support Ready/back-pressure natively. |
| [olo_base_decode_firstbit](./base/olo_base_decode_firstbit.md) | Implements a first-bit decoder (finds the index of the first bit set in a vector). Allows pipelining for operating on very wide vectors at high clock frequencies. |
| [olo_base_crc](./base/olo_base_crc.md) | CRC calculation engine |
| [olo_base_crc_append](./base/olo_base_crc_append.md) | Append CRC to AXI4-Stream packets |
| [olo_base_crc_check](./base/olo_base_crc_check.md) | Check CRC of AXI4-Stream packets and drop invalid packets |

## axi

This area contains AXI4 related elements.

| Entity                                                  | Description                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| [olo_axi_pl_stage](./axi/olo_axi_pl_stage.md)           | Implements a AXI4 pipeline stage, registering all signals of an AXI4 interface.<br />Can be used for AXI4-Lite as well. |
| [olo_axi_lite_slave](./axi/olo_axi_lite_slave.md)       | Interface to attach user register banks and memories to the AXI4-Lite bus. |
| [olo_axi_master_simple](./axi/olo_axi_master_simple.md) | AXI4 master - does execute arbitrarily sized transfer over AXI4. The __simple_ version of the master does only allow access to word-aligned addresses and sizes. |
| [olo_axi_master_full](./axi/olo_axi_master_full.md)     | AXI4 master - Same as [olo_axi_master_simple](./axi/olo_axi_master_simple.md) but does allow access that are not word-aligned (in terms of start address, size or both). |

**Note:** _Open Logic_ focuses on providing utilities for development of AXI endpoints (masters and slaves).
_Open Logic_ does not aim to provide AXI interconnect infrastructure (e.g. crossbars, interconnects, ...). Often the
vendor IPs are used (for tool integration reasons) for these aspects. If you are looking for a pure VHDL implementation
of AXI interconnects, it's suggested that you use one of the following libraries:

- [hdl-modules](https://github.com/hdl-modules)
  - hdl-modules utilizes VHDL-2008 which has limited support in some tools (namely the Standard and Lite versions of
    Quartus Prime)
  - hdl-modules currently does only contain synthesis attributes for AMD (Vivado)
- [SURF](https://github.com/slaclab/surf)
  - SURF currently does only target AMD (Vivado) and Altera (Quartus Prime)

## intf

This area contains components related to interfacing to external components.

| Entity                                               | Description                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| [olo_intf_sync](./intf/olo_intf_sync.md)             | Double stage synchronizer for external signals.              |
| [olo_intf_i2c_master](./intf/olo_intf_i2c_master.md) | I2C Master - Supports the full standard including arbitration (multi-master I2C) and clock stretching. |
| [olo_intf_spi_master](./intf/olo_intf_spi_master.md) | SPI Master - Supports handling multiple slaves and variable width transactions as well as all clock phases and poloarities and LSB/MSB first. |
| [olo_intf_spi_slave](./intf/olo_intf_spi_slave.md)   | SPI Slave - Supports all clock phases and poloarities and LSB/MSB first. |
| [olo_intf_uart](./intf/olo_intf_uart.md)             | UART                                                         |
| [olo_intf_debounce](./intf/olo_intf_debounce.md)     | Debouncer (for bouncing signals from buttons and switches) - Includes double-stage synchronizers. |
| [olo_intf_clk_meas](./intf/olo_intf_clk_meas.md)     | Measure the frequency of a clock.                            |

## fix

This area contains fixed point mathematic related functionality.

All fixed point mathematics functions in Open Logic follow a common cent of principles described in
[Open Logic Fixed-Point Principles](./fix/olo_fix_principles.md). Read through this document before using the
components.

### Packages

Below packages contain basic definitions like number format types etc.

| Entity                                           | Description                                                  |
| ------------------------------------------------ | ------------------------------------------------------------ |
| [en_cl_fix_pkg](../3rdParty/en_cl_fix/README.md) | 3rd Party Package for fixed-point mathematics. <br> Original source [Enclustra GitHub](https://github.com/enclustra/en_cl_fix) |
| [olo_fix_pkg](./fix/olo_fix_pkg.md)              | Package with various Open Logic specific definitions (e.g. common options of string-type generics) |

### Testbench Utilities

| Entity                                              | Description                                                  |
| --------------------------------------------------- | ------------------------------------------------------------ |
| [olo_fix_sim_stimuli](./fix/olo_fix_sim_stimuli.md) | Read co-simulation file generated by Python and apply its content to the DUT in a HDL simulation. |
| [olo_fix_sim_checker](./fix/olo_fix_sim_checker.md) | Read co-simulation file generated by Python and check outputs of the DUT in a HDL simulation against it. |

### Basic Operations

| Entity                                          | Description                                                  |
| ----------------------------------------------- | ------------------------------------------------------------ |
| [olo_fix_round](./fix/olo_fix_round.md)         | Rounding to a number format with less fractional bits.<br>Instead of this component, the _cl_fix_round()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_saturate](./fix/olo_fix_saturate.md)   | Saturate to a number format with less integer bits<br>Instead of this component, the _cl_fix_saturate()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_resize](./fix/olo_fix_resize.md)       | Resize to a different number format. <br>Instead of this component, the _cl_fix_resize()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_from_real](./fix/olo_fix_from_real.md) | Convert real number to fixed-point representation - for synthesis. <br>Instead of this component, the _cl_fix_from_real()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_sim_from_real](./fix/olo_fix_sim_from_real.md) | Convert real number to fixed-point representation - for simulations. <br>Instead of this component, the _cl_fix_from_real()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_to_real](./fix/olo_fix_to_real.md)     | Convert fixed-point number to real representation. <br>Instead of this component, the _cl_fix_to_real()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_add](./fix/olo_fix_add.md)             | Add two fixed point numbers. <br>Instead of this component, the _cl_fix_add()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_sub](./fix/olo_fix_sub.md)             | Subtract two fixed point numbers. <br>Instead of this component, the _cl_fix_sub()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_addsub](./fix/olo_fix_addsub.md)       | Selectively add or subtract two fixed point numbers. <br>Instead of this component, the _cl_fix_addsub()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_mult](./fix/olo_fix_mult.md)           | Multiply two fixed point numbers. <br>Instead of this component, the _cl_fix_mult()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_neg](./fix/olo_fix_neg.md)             | Negate a fixed point number. <br>Instead of this component, the _cl_fix_neg()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_abs](./fix/olo_fix_abs.md)             | Get the absolute value of a fixed point number. <br>Instead of this component, the _cl_fix_abs()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |
| [olo_fix_compare](./fix/olo_fix_compare.md)     | Compare two fixed point numbers. <br>Instead of this component, the _cl_fix_compare()_ function from _en_cl_fix_pkg_ can be used alternatively (for usage from VHDL) |

**Note:** For basic fixed point functionality either components from _Open Logic_ of functions from _en_cl_fix_pkg_ can
be used. For deciding which option to use, the following considerations shall be taken into account:

- Functions cannot be called from Verilog - hence _Open Logic_ components are the only option for Verilog
- _Open Logic_ components include pipeline register stages - for fast clock speeds, this can lead to more readable code
- _en_cl_fix_pkg_ functions allow packing several steps into one process, which can lead to more compact code

### Simple Mathematics

| Entity                                          | Description                                                  |
| ----------------------------------------------- | ------------------------------------------------------------ |
| [olo_fix_limit](./fix/olo_fix_limit.md)         | Limit a value between an upper and a lower bound             |
