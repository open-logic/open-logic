<img src="../Logo.png" alt="Logo" width="400">

# olo_intf_sync

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_intf_sync.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_intf_sync.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_intf_sync.json?cacheSeconds=0)

VHDL Source: [olo_intf_sync](../../src/intf/vhdl/olo_intf_sync.vhd)

## Description

This component implements a N-stage synchronizer for synchronizing external signals to the internal clock. It also sets
all the attributes required for proper synthesis.

Note that this synchronizer does not guarantee that all bits arrive in the same clock cycle at the destination clock
domain, therefore it can only be used for independent single-bit signals. Do not use it to transfer multi-bit signals
(e.g. numbers) where it is important that all the bits are updated in the same clock cycle.

It is suggested to use this entity only for synchronizing external signals. For synchronizing FPGA internal signals
between clocks, the clock crossings in _base_ shall be used (_olo_base_cc_..._).

For _AMD_ tools (_Vivado_) an automatic constraint file exists, which automatically identifies all _olo_intf_sync_
instances and constrains them correctly. To use the automatic constraints file, follow the steps described in
[clock crossing principles](../base/clock_crossing_principles.md) but use the constraints file
`source <path-to-open-logic>/src/intf/tcl/constraints_amd.tcl`

**Note:** Automatic constraining currently only works for _AMD_ tools (_Vivado_) and the usage in VHDL. Manual
constraints are required for Verilog or other tools.

## Generics

| Name         | Type      | Default | Description                                                  |
| :----------- | :-------- | ------- | :----------------------------------------------------------- |
| Width_g      | positive  | 1       | Number of data bits to implement the synchronizer for        |
| RstLevel_g   | std_logic | '0'     | Value to set the synchronizer registers to upon reset. <br />Usually this does not play any role but if the value does not match the idle-state of the synchronized signal, a pulse is observed in the first two clock cycles after reset. This can be avoided by setting _RstLevel_g_ to the idle-state of the signals synchronized. |
| SyncStages_g | positive  | 2       | Number of synchronization stages. <br />Range: 2 ... 4       |

## Interfaces

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Clk       | in     | 1         | -       | Clock                                                        |
| Rst       | in     | 1         | '0'     | Reset input (high-active, synchronous to _Clk_)<br />For synchronizers the reset is normally not required. |
| DataAsync | in     | _Width_g_ | -       | Vector of independent input bits (asynchronous external input). |
| DataSync  | out    | _Width_g_ | N/A     | Vector of synchronized output bits (synchronous to _Clk_)    |

## Architecture

The signal is synchronized using an ordinary N-stage synchronizer.

In most cases, the default value of two synchronization stages is fine. However, in special cases more stages might be
required to increase MTBF.

The VHDL code contains all synthesis attributes required to ensure correct behavior of tools (e.g. avoid mapping of the
synchronizer FFs into shift registers) for all supported tools.
