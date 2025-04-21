<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_compare

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_compare.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_compare.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_compare.json?cacheSeconds=0)

VHDL Source: [olo_fix_compare](../../src/fix/vhdl/olo_fix_compare.vhd)
Bit-true Model: [olo_fix_compare](../../src/fix/python/olo_fix/olo_fix_compare.py)

## Description

This entity performs a comparison of two fixed-point numbers. The comparison to execute can be selected through
generics. 

Input A is on the left hand side of the operator, Input B on the right hand side. E.g. for _Comparison_g=">"_, the 
comparison implemented is _A > B_.

For details about the fixed-point number format used in _Open Logic_, refer to the [fixed point principles](./olo_fix_principles.md).

## Generics

| Name          | Type    | Default   | Description                                                  |
| :------------ | :------ | --------- | :----------------------------------------------------------- |
| AFmt_g        | string  | -         | Input A format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| BFmt_g        | string  | -         | Input B format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| Comparison_g  | string  | -         | Comparison to execute. <br> Selection: >, <, =, !=, >=, <= |
| OpRegs_g      | natural | 1         | Number of pipeline stages for the operation                  |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | '0'     | Clock<br />Not required if all registers are disabled (_OpRegs_g=0_) |
| Rst  | in     | 1      | '0'     | Reset input (high-active, synchronous to _Clk_)<br />Not required if all registers are disabled (_OpRegs_g=0_) |

### Input Data

| Name     | In/Out | Length          | Default | Description                               |
| :------- | :----- | :-------------- | ------- | :---------------------------------------- |
| In_A     | in     | _width(AFmt_g)_ | -       | Input data<br />Format: _AFmt_g_          |
| In_B     | in     | _width(BFmt_g)_ | -       | Input data<br />Format: _BFmt_g_          |
| In_Valid | in     | 1               | '1'     | AXI4-Stream handshaking signal for _In_A_ and _In_B_ |

### Output Data

| Name       | In/Out | Length               | Default | Description                               |
| :--------- | :----- | :------------------- | ------- | :---------------------------------------- |
| Out_Result | out    | 1                    | N/A     | '1' = true, '0' = false'   |
| Out_Valid  | out    | 1                    | N/A     | AXI-S handshaking signal for _Out_Result_ |

## Detail

No detailed description required. All details that could be mentioned here are already covered by [fixed point principles](./olo_fix_principles.md).
