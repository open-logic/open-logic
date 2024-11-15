<img src="../Logo.png" alt="Logo" width="400">

# olo_base_decode_firstbit

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_decode_firstbit.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_decode_firstbit.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_decode_firstbit.json?cacheSeconds=0)

VHDL Source: [olo_base_arb_prio](../../src/base/vhdl/olo_base_arb_prio.vhd)

## Description

This entity implements a first-bit decoder. It does return the index of the lowest bit set in a vector.

First bit decoding can be done in only a few lines of code if all the decoding is done in one clock cycles. However,
for doing first-bit decoding on very wide vectors this leads to poor timing performance. In this case using
_olo_base_decode_firstbit_ makes sense - because it allows pipelining the operation.

The figure below assumes _InReg_g=false_, _OutReg_g=false_ and _PlRegs_g=2_.

![Wave](./misc/olo_base_decode_firstbit.png)

## Generics

| Name      | Type     | Default | Description                                                  |
| :-------- | :------- | ------- | :----------------------------------------------------------- |
| InWidth_g | positive | -       | Width of the input vector                                    |
| InReg_g   | boolean  | true    | If set to _true_ all inputs are registered before any operations are done on it. <br />Can be set to _false_ if the user knows that _*_In_Data_ is driven by FFs directly without combinatorial logic after the FF. |
| OutReg_g  | boolean  | true    | If set to _true_ all outputs are registered.<br />Can be set to _false_ if the user knows that _Out_FirstBit_ and _Out_Found_ are fed into FFs without any combinatorial logic. |
| PlRegs_g  | natural  | 1       | Number of pipeline registers in the first-bit decoding logic. 0 Means that the decoding is done in one clock-cycle, 1 means that one register stage is added and the logic is split into two clock cycles.<br />Range: 0 ... ceil(log2(_InWidth_g_))/2-1 |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Data

| Name     | In/Out | Length      | Default | Description                                  |
| :------- | :----- | :---------- | ------- | :------------------------------------------- |
| In_Data  | in     | _InWidth_g_ | -       | Input data vector                            |
| In_Valid | in     | 1           | '1'     | AXI4-Stream handshaking signal for _In_Data_ |

### Output Data

| Name         | In/Out | Length                  | Default | Description                                                  |
| :----------- | :----- | :---------------------- | ------- | :----------------------------------------------------------- |
| Out_FirstBit | out    | ceil(log2(_InWidth_g_)) | N/A     | Index of the lowest bit set in _In_Data_                     |
| Out_Found    | out    | 1                       | N/A     | Set to '1' if any bit in _In_Data_ was set. If no bit is set in _In_Data_ this output is '0'. |
| Out_Valid    | out    | 1                       | N/A     | AXI4-Stream handshaking signal for _Out_..._                 |

## Architecture

Below figure shows the overall architecture of the block. The figure assumes _InReg_g=true_, _OutReg_g=true_ and
_PlRegs_g=2_.

Note that these settings are chosen for illustrative reasons only. Two pipeline registers for only a 64 bit first-bit
detector would not actually be required.

![Architecture](./misc/olo_base_decode_firstbit_arch.svg)

The first stage detects the index of the first bit on a small number of input bits. All subsequent stages detect the
upstream stage with the lowest index that found a bit, forward this result to the output and extend a few more bits of
the index information.
