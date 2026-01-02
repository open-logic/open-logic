<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_bin_div

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_bin_div.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_bin_div.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_bin_div.json?cacheSeconds=0)

VHDL Source: [olo_fix_bin_div](../../src/fix/vhdl/olo_fix_bin_div.vhd)<br />
Bit-true Model: [olo_fix_bin_div](../../src/fix/python/olo_fix/olo_fix_bin_div.py)

## Description

### Overview

This entity implements a binary division of two fixed-point numbers.

The division is executed over multiple clock cycles using a iterative algorithm. Pipelined implementation is not
available because in most applications for maximum throughput an approximation based implementation is more efficient.

### Latency

The latency of the entity depends on several factors and can best be determined in the simulation.

Note: Latency is not guaranteed to be constant accross different version. It's therefore best to design user logic
to be independent of the latency of this block.

In the current version the implementation can be calculated as follows:

_Latency_ = width(_OutFmt_g_) + 6

The latency is equal to the insertion interval (a new sample is accepted every _Latency_ clock cycles).

## Generics

| Name              | Type     | Default     | Description                                                                                                                                                                                                                                                          |
| :---------------- | :------- | ----------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NumFmt_g          | string   | -           | Numerator format <br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)")                                                                                                                                                                            |
| DenomFmt_g        | string   | -           | Denominator format <br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)")                                                                                                                                                                          |
| OutFmt_g          | string   | -           | Output data format <br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)")                                                                                                                                                                          |
| Round_g           | string   | "Trunc_s"   | Rounding mode <br />String representation of an _en_cl_fix FixRound_t_.                                                                                                                                                                                              |
| Saturate_g        | string   | "Sat_s"     | Saturation mode <br />String representation of an _en_cl_fix FixSaturate_t_.                                                                                                                                                                                         |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_)              |

### Input Data

| Name     | In/Out | Length              | Default | Description                                                                                                                |
| :------- | :----- | :------------------ | ------- | :------------------------------------------------------------------------------------------------------------------------- |
| In_Num   | in     | _width(NumFmt_g)_   | N/A     | Input numerator<br />Format _NumFmt_g_                                                                                     |
| In_Denom | in     | _width(DenomFmt_g)_ | N/A     | Input denominator<br />Format _DenomFmt_g_                                                                                 |
| In_Valid | in     | 1                   | '1'     | AXI4-Stream handshaking signal for _In_xxx_                                                                                |
| In_Ready | out    | 1                   | N/A     | AXI4-Stream handshaking signal for _In_xxx_                                                                                |

### Output Data

| Name       | In/Out | Length               | Default | Description                                                      |
| :--------- | :----- | :------------------- | ------- | :--------------------------------------------------------------- |
| Out_Quot   | out    | _width(OutFmt_g)_    | -       | Quotient output data<br />Format: _OutFmt_g_                     |
| Out_Valid  | out    | 1                    | N/A     | AXI4-Stream handshaking signal for _Out_Quot_                    |

**Note** The output interface does not implement backpressure (_Ready_). If backpressure is required, the user ideally
implements it over the whole processing chain using [olo_base_flowctrl_handler](../base/olo_base_flowctrl_handler.md).

## Detail

The entity converts numerator and denominator to unsigned numbers, so the division can be implemented
using a simple non-restoriding division algorithm. At the output the sign is then restored correctly.

![olo_fix_bin_div_block_diagram](./entities/olo_fix_bin_div.drawio.png)
