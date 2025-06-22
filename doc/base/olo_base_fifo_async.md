<img src="../Logo.png" alt="Logo" width="400">

# olo_base_fifo_async

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_fifo_async.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_fifo_async.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_fifo_async.json?cacheSeconds=0)

VHDL Source: [olo_base_fifo_async](../../src/base/vhdl/olo_base_fifo_async.vhd)

## Description

This component implements an asynchronous FIFO (different clocks for write and read port).

The memory is described in a way that it utilizes RAM resources (Block-RAM or distributed RAM) available in FPGAs with
commonly used tools. For this purpose [olo_base_ram_sdp](./olo_base_ram_sdp.md) is used.

The FIFO is a fall-through FIFO and has AXI-S interfaces on read and write side.

The RAM behavior (read-before-write or write-before-read) can be selected. This allows efficiently implementing FIFOs
for different technologies (some technologies implement one, some the other behavior).

An asynchronous FIFO is a clock-crossing and hence this block follows the general
[clock-crossing principles](clock_crossing_principles.md). Read through them for more information.

**Note:** This is a symmetric FIFO.
To build an asymmetric n:xn FIFO (N-bits to a multiple of N-bits), the [olo_base_wconv_n2xn](./olo_base_wconv_n2xn.md)
can be added on the write side of the FIFO.
To create an xn:n FIFO (a multiple of N-bits to N-bits), the [olo_base_wconv_xn2n](./olo_base_wconv_xn2n.md)
can be added on the read side of the FIFO.

## Generics

| Name            | Type      | Default   | Description                                                  |
| :-------------- | :-------- | --------- | :----------------------------------------------------------- |
| Width_g         | positive  | -         | Number of bits per FIFO entry (word-width)                   |
| Depth_g         | positive  | -         | Number of FIFO entries. <br />This **must** be a power of two. See [Architecture](#architecture) for more details. |
| AlmFullOn_g     | boolean   | false     | If set to true, the _AlmFull_ (almost full) status flag is generated (otherwise it is omitted) |
| AlmFullLevel_g  | natural   | 0         | Level to generate _AlmFull_ flag at. <br>Has no effect if _AlmFullOn_g_ = false |
| AlmEmptyOn_g    | boolean   | false     | If set to true, the _AlmEmpty_ (almost empty) status flag is generated (otherwise it is omitted) |
| AlmEmptyLevel_g | natural   | 0         | Level to generate _AlmEmpty_ flag at. <br>Has no effect if _AlmEmptyOn_g_ = false |
| RamStyle_g      | string    | "auto"    | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes _ram_style_ and _ramstyle_ which vendors offer to control RAM implementation.<br>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| RamBehavior_g   | string    | "RBW"     | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| ReadyRstState_g | std_logic | '1'       | Controls the status of the _In_Ready_ signal in during reset.<br> Choose '1' for minimal logic on the (often timing-critical) _In_Ready_ path. |
| Optimization_g  | string    | "LATENCY" | "LATENCY" - optimize for minimum time until a word written is showing up at the output<br />"SPEED" - optimize for highest possible clock speed (at the cost of more latency) |
| SyncStages_g    | positive  | 2         | Number of synchronization stages. <br />Note that more synchronization stages also mean a higher latency until written data is visible on the read side.<br />Range: 2 ... 4 |

## Interfaces

### Input Data

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Clk    | in     | 1         | -       | Input clock                                                  |
| In_Rst    | in     | 1         | -       | Reset input (high-active, synchronous to _In_Clk_)           |
| In_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _In_Clk_)) |
| In_Data   | in     | _Width_g_ | -       | Input data (synchronous to _In_Clk_)                         |
| In_Valid  | in     | 1         | '1'     | AXI4-Stream handshaking signal for _In_Data_ (synchronous to _In_Clk_) |
| In_Ready  | out    | 1         | N/A     | AXI4-Stream handshaking signal for _In_Data_ (synchronous to _In_Clk_) |

### Output Data

| Name       | In/Out | Length    | Default | Description                                                  |
| :--------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Out_Clk    | in     | 1         | -       | Output clock                                                 |
| Out_Rst    | in     | 1         | -       | Reset input (high-active, synchronous to _Out_Clk_)          |
| Out_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _Out_Clk_)) |
| Out_Data   | out    | _Width_g_ | N/A     | Output data (synchronous to _Out_Clk_)                       |
| Out_Valid  | out    | 1         | N/A     | AXI4-Stream handshaking signal for _Out_Data_ (synchronous to _Out_Clk_) |
| Out_Ready  | in     | 1         | '1'     | AXI4-Stream handshaking signal for _Out_Data_ (synchronous to _Out_Clk_) |

### Input Status

| Name        | In/Out | Length                  | Default | Description                                                  |
| :---------- | :----- | :---------------------- | ------- | :----------------------------------------------------------- |
| In_Full     | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is full (synchronous to _In_Clk_) |
| In_Empty    | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is empty (synchronous to _In_Clk_) |
| In_AlmFull  | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is >= _AlmFullLevel_g_ (synchronous to _In_Clk_)<br/>Output is undefined if _AlmFullOn_g_=false. |
| In_AlmEmpty | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is <= _AlmEmptyevel_g_ (synchronous to _In_Clk_)<br/>Output is undefined if _AlmEmptyOn_g_=false. |
| In_Level    | out    | ceil(log2(_Depth_g_+1)) | N/A     | FIFO fill level calculated on the write side (synchronous to _In_Clk_) |

### Output Status

| Name         | In/Out | Length                  | Default | Description                                                  |
| :----------- | :----- | :---------------------- | ------- | :----------------------------------------------------------- |
| Out_Full     | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is full (synchronous to _Out_Clk_) |
| Out_Empty    | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is empty (synchronous to _Out_Clk_) |
| Out_AlmFull  | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is >= _AlmFullLevel_g_ (synchronous to _Out_Clk_)<br/>Output is undefined if _AlmFullOn_g_=false. |
| Out_AlmEmpty | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is <= _AlmEmptyevel_g_ (synchronous to _Out_Clk_)<br/>Output is undefined if _AlmEmptyOn_g_=false. |
| Out_Level    | out    | ceil(log2(_Depth_g_+1)) | N/A     | FIFO fill level calculated on the write side (synchronous to _Out_Clk_) |

## Architecture

The rough architecture of the FIFO is shown in the figure below. Note that the figure does only depict the general
architecture and not each and every detail.

![Architecture](./fifo/olo_base_fifo_async.png)

Read and write address counters are handled in their corresponding clock domain. The current address counter value is
then transferred to the other clock-domain by converting it to gray code, synchronizing it using aa synchronizer (using
[olo_base_cc_bits](./olo_base_cc_bits.md)) and convert it back to a two's complement number. Because the data is
transferred in gray code, in this case either the correct value before an increment of the counter or the correct value
after the increment is received, so the result is always correct.

The gray-encoding approach only works for power of two FIFO depths. For any other FIFO depths, the gray encoded counter
value would toggle more than one bit during the overflow and hence the clock domain crossing would not work safely.

All status information is calculated separately in both clock domains to make it available synchronously to both clocks.

This architecture is independent of the FPGA technology used and can also be used to combine more than just one
Block-RAM into one big FIFO.

Regarding constraints, refer to  [clock-crossing principles](clock_crossing_principles.md). The FIFO is also
auto-constraints capable.
