<img src="../Logo.png" alt="Logo" width="400">

# olo_base_fifo_sync

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_fifo_sync.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_fifo_sync.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_fifo_sync.json?cacheSeconds=0)

VHDL Source: [olo_base_fifo_sync](../../src/base/vhdl/olo_base_fifo_sync.vhd)

## Description

This component implements a synchronous FIFO (same clock for write and read port). 

The memory is described in a way that it utilizes RAM resources (Block-RAM or distributed RAM) available in FPGAs with commonly used tools. For this purpose [olo_base_ram_sdp](./olo_base_ram_sdp.md) is used.

The FIFO is a fall-through FIFO and has AXI-S interfaces on read and write side.

The RAM behavior (read-before-write or write-before-read) can be selected. This allows efficiently implementing FIFOs for different technologies (some technologies implement one, some the other behavior).

## Generics

| Name            | Type      | Default | Description                                                  |
| :-------------- | :-------- | ------- | :----------------------------------------------------------- |
| Widht_g         | positive  | -       | Number of bits per FIFO entry (word-width)                   |
| Depth_g         | positive  | .       | Number of FIFO entries                                       |
| AlmFullOn_g     | boolean   | false   | If set to true, the *AlmFull* (almost full) status flag is generated (otherwise it is omitted) |
| AlmFullLevel_g  | natural   | 0       | Level to generate *AlmFull* flag at. <br>Has no effect if *AlmFullOn_g* = false |
| AlmEmptyOn_g    | boolean   | false   | If set to true, the *AlmEmpty* (almost empty) status flag is generated (otherwise it is omitted) |
| AlmEmptyLevel_g | natural   | 0       | Level to generate *AlmEmpty* flag at. <br>Has no effect if *AlmEmptyOn_g* = false |
| RamStyle_g      | string    | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes *ram_style* and *ramstyle* which vendors offer to control RAM implementation.<br>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| RamBehavior_g   | string    | "RBW"   | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| ReadyRstState_g | std_logic | '1'     | Controls the status of the *In_Ready* signal in during reset.<br> Choose '1' for minimal logic on the (often timing-critical) *In_Ready* path. <br |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### Input Data

| Name     | In/Out | Length    | Default | Description                                  |
| :------- | :----- | :-------- | ------- | :------------------------------------------- |
| In_Data  | in     | *Width_g* | -       | Input data                                   |
| In_Valid | in     | 1         | '1'     | AXI4-Stream handshaking signal for *In_Data* |
| In_Ready | out    | 1         | N/A     | AXI4-Stream handshaking signal for *In_Data* |

### Output Data

| Name      | In/Out | Length    | Default | Description                                   |
| :-------- | :----- | :-------- | ------- | :-------------------------------------------- |
| Out_Data  | out    | *Width_g* | N/A     | Output data                                   |
| Out_Valid | out    | 1         | N/A     | AXI4-Stream handshaking signal for *Out_Data* |
| Out_Ready | in     | 1         | '1'     | AXI4-Stream handshaking signal for *Out_Data* |

### Status

| Name      | In/Out | Length                  | Default | Description                                                  |
| :-------- | :----- | :---------------------- | ------- | :----------------------------------------------------------- |
| In_Level  | out    | ceil(log2(*Depth_g*+1)) | N/A     | FIFO fill level calculated on the write side. <br>Write operations are reflected in the level immediately, read operations are reflected with a delay of one clock cycle. |
| Out_Level | out    | ceil(log2(*Depth_g*+1)) | N/A     | FIFO fill level calculated on the read side. <br>Read operations are reflected in the level immediately, write operations are reflected with a delay of one clock cycle. |
| Full      | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is full.                   |
| Empty     | out    | 1                       | N/A     | Status flag. Asserted if the FIFO is empty.                  |
| AlmFull   | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is >= *AlmFullLevel_g*.<br>Output is undefined if *AlmFullOn_g*=false. |
| AlmEmpty  | out    | 1                       | N/A     | Status flag. Asserted if the FIFO fill level is <= *AlmEmptyevel_g*.<br>Output is undefined if *AlmEmptyOn_g*=false. |

## Architecture

No detailed architecture documentation is required for a FIFO. The behavior of the FIFO is sufficiently defined without details about the internals being required.

For more information, look into the source code (see link at the top of the page)



