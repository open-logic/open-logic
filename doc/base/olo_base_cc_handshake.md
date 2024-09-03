<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cc_handshake

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cc_handshake.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cc_handshake.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cc_handshake.json?cacheSeconds=0)

VHDL Source: [olo_base_cc_handshake](../../src/base/vhdl/olo_base_cc_handshake.vhd)

## Description

This component implements a clock crossing with AXI-S handshaking for transferring data from one clock domain to another one that runs at a potentially completely asynchronous clock It can for example be used to transfer data from a 100 MHz clock domain to a 55.32 MHz clock domain.

This component implements full AXI-S handshaking but is not made for high performance. It can transfer one data-word every *4 x InputClockPeriods + 4 x OutputClockPeriods* .

Whenever distributed RAM can be used (i.e. LUTs can be used as small RAMs), [olo_base_fifo_async](./olo_base_fifo_async.md) is to be preferred over this entity. For small FIFO depths, it is more resource efficient. Hence *olo_base_cc_handshake* shall only be used in cases where distributed RAM is not an option (e.g. because it is in not supported by the target technology or because the design is short the related LUT resources).

This block follows the general [clock-crossing principles](clock_crossing_principles.md). Read through them for more information.

## Generics

| Name            | Type      | Default | Description                                                  |
| :-------------- | :-------- | ------- | :----------------------------------------------------------- |
| Width_g         | positive  | -       | Data width in bits.                                          |
| ReadyRstState_g | std_logic | '1'     | Controls the status of the *In_Ready* signal in during reset.<br>Choose '1' for minimal logic on the (often timing-critical) *In_Ready* path. <br |

## Interfaces

### Input Data

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Clk    | in     | 1         | -       | Input clock (must run at an integer multiple of *Out_Clk*)   |
| In_RstIn  | in     | 1         | '0'     | Reset input (high-active, synchronous to *In_Clk*)           |
| In_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to *In_Clk*) |
| In_Data   | in     | *Width_g* | -       | Input data                                                   |
| In_Valid  | in     | 1         | '1'     | AXI4-Stream handshaking signal for *In_Data*                 |
| In_Ready  | out    | 1         | N/A     | AXI4-Stream handshaking signal for *In_Data*                 |

### Output Data

| Name       | In/Out | Length    | Default | Description                                                  |
| :--------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Out_Clk    | in     | 1         | -       | Output clock                                                 |
| Out_RstIn  | in     | 1         | '0'     | Reset input (high-active, synchronous to *Out_Clk*)          |
| Out_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to *Out_Clk*) |
| Out_Data   | out    | *Width_g* | N/A     | Output data                                                  |
| Out_Valid  | out    | 1         | N/A     | AXI4-Stream handshaking signal for *Out_Data*                |
| Out_Ready  | in     | 1         | '1'     | AXI4-Stream handshaking signal for *Out_Data*                |

## Architecture

The architecture of of *olo_base_cc_handshake* is based on the idea of passing a request (*XxxTransaction*) from the source domain to the destination domain when data is applied and an acknowledge (*XxxAck*) back once it was accepted. The input logic only accepts new data after the acknowledge was received.

This architecture is built based on *olo_base_cc_simple* and *olo_base_cc_pulse*. 

Note that this architecture is optimized for simplicity and not for throughput.



![architecture](/home/oli/work/olo/open-logic/doc/base/clock_crossings/olo_base_cc_handshake.svg)

Regarding timing constraints, refer to [clock-crossing principles](clock_crossing_principles.md).





