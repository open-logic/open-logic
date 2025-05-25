<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_resize

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_resize.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_resize.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_resize.json?cacheSeconds=0)

VHDL Source: [olo_fix_resize](../../src/fix/vhdl/olo_fix_resize.vhd)
Bit-true Model: [olo_fix_resize](../../src/fix/python/olo_fix/olo_fix_resize.py)

## Description

This entity changes the format of a fixed-point number. It optionally can execute saturation (if the number of integer
bits on the output is reduced) and rounding (if the number of fractional bits is reduced).

**Latency** of this entity is given by the optional rounding and saturation registers. The default generics lead
to a latency of 2 clock cycles.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

## Generics

| Name        | Type    | Default   | Description                                                  |
| :---------- | :------ | --------- | :----------------------------------------------------------- |
| AFmt_g      | string  | -         | Input A format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| ResultFmt_g | string  | -         | Format of the result<br />String representation of an _en_cl_fix Format_t_ (e.g. "(0,1,15)") |
| Round_g     | string  | "Trunc_s" | Rounding mode<br />String representation of an _en_cl_fix FixRound_t_. |
| Saturate_g  | string  | "Sat_s"   | Saturation mode<br />String representation of an _en_cl_fix FixSaturate_t_. |
| RoundReg_g  | string  | "YES"     | Presence of rounding pipeline stage<br />"YES": Always implement register<br />"NO": Never implement register<br />"AUTO": Implement register if rounding is needed according to the formats chosen |
| SatReg_g    | string  | "YES"     | Presence of saturation pipeline stage<br />"YES": Always implement register<br />"NO": Never implement register<br />"AUTO": Implement register if saturation is needed according to the formats chosen |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | '0'     | Clock<br />Not required if all registers are disabled (_RoundReg_g="NO", SatReg_g="NO"_) |
| Rst  | in     | 1      | '0'     | Reset input (high-active, synchronous to _Clk_)<br />Not required if all registers are disabled (_RoundReg_g="NO", SatReg_g="NO"_) |

### Input Data

| Name     | In/Out | Length          | Default | Description                               |
| :------- | :----- | :-------------- | ------- | :---------------------------------------- |
| In_A     | in     | _width(AFmt_g)_ | -       | Input data<br />Format: _AFmt_g_          |
| In_Valid | in     | 1               | '1'     | AXI4-Stream handshaking signal for _In_A_ |

### Output Data

| Name       | In/Out | Length               | Default | Description                               |
| :--------- | :----- | :------------------- | ------- | :---------------------------------------- |
| Out_Result | out    | _width(ResultFmt_g)_ | N/A     | Result data<br />Format _ResultFmt_g_     |
| Out_Valid  | out    | 1                    | N/A     | AXI-S handshaking signal for _Out_Result_ |

## Detail

Below figure shows the implementation of _olo_fix_resize_

![impl](./entities/olo_fix_resize.drawio.png)
