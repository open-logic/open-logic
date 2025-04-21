<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_round

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_round.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_round.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_round.json?cacheSeconds=0)

VHDL Source: [olo_fix_round](../../src/fix/vhdl/olo_fix_round.vhd)
Bit-true Model: [olo_fix_round](../../src/fix/python/olo_fix/olo_fix_round.py)

## Description

This entity allows reducing the number of fractional bits in a fixed-point number and executes rounding.

**Note:** The output format _MUST_ be one that _ONLY_ requires rounding. It is not allowed to select any other number
of integer bits than exactly the one required.

Format examples:

- _AFmt_g="(1,2,4)"_, _ResultFmt_g="(1,**3**,3)"_, _Round_g="NonSymPos_s"_
  - Requires 3 integer bits because rounding up the highes possible input value requires one more integer bit
- _AFmt_g="(1,2,4)"_, _ResultFmt_g="(1,**2**,3)"_, _Round_g="Trunc_s"_
  - Does not required an additional integer bit because truncation does never lead to higher output than input

For details about the fixed-point number format used in _Open Logic_, refer to the [fixed point principles](./olo_fix_principles.md).

## Generics

| Name        | Type    | Default   | Description                                                  |
| :---------- | :------ | --------- | :----------------------------------------------------------- |
| AFmt_g      | string  | -         | Input A format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| ResultFmt_g | string  | -         | Format of the result<br />String representation of an _en_cl_fix Format_t_ (e.g. "(0,1,15)") |
| Round_g     | string  | "Trunc_s" | Rounding mode<br />String representation of an _en_cl_fix FixRound_t_. |
| FmtCheck_g  | boolean | true      | If true, an error is thrown in case _ResultFmt_g_ is not as required |
| RoundReg_g  | string  | "YES"     | Presence of rounding pipeline stage<br />"YES": Always implement register<br />"NO": Never implement register<br />"AUTO": Implement register if rounding is needed according to the formats chosen |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | '0'     | Clock<br />Not required if all registers are disabled (_RoundReg_g="NO"_) |
| Rst  | in     | 1      | '0'     | Reset input (high-active, synchronous to _Clk_)<br />Not required if all registers are disabled (_RoundReg_g="NO"_) |

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

No detailed description required. All details that could be mentioned here are already covered by [fixed point principles](./olo_fix_principles.md).
