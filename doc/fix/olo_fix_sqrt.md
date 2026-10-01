<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_sqrt

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_sqrt.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_sqrt.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_sqrt.json?cacheSeconds=0)

VHDL Source: [olo_fix_sqrt](../../src/fix/vhdl/olo_fix_sqrt.vhd)<br />
Bit-true Model: [olo_fix_sqrt](../../src/fix/python/olo_fix/olo_fix_sqrt.py)

## Description

This entity calculates the square root. It does so based on piecewise linear approximation
([olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md)). It can process one sample per clock cycle but has a
fixed latency. It is optimal for pipelined processing chains with high throughput.

The input is normalized (blue) into the range `[0.25, 1)`, the square root is taken through a table based piecewise
linear approximation (red) and the normalization is reverted on the result (green):

![Formula](./approx/olo_fix_sqrt_formula.png)

Because the square root halves the exponent, the normalization shift _N_ must be **even** - which is why the
approximation covers the two octaves `[0.25, 1)` and not just one.

Because the normalization maps the full input range to a relatively small range for approximation, a relatively small
table delivers accurate results over the full range of any input format. The precision of the approximation is selected
through _PrecisionBits_g_, see [Precision](#precision).

The entity is fully pipelined, hence it accepts one input sample per clock cycle. As a result, back-pressure is
not supported.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Corner Cases

An input of **zero** delivers **exactly zero**.

**Powers of four** are _not_ inverted exactly. The relative error stays within the bounds given
under [Precision](#precision) for all inputs.

### Latency

Latency is not guaranteed to be constant across different versions. It's therefore best to design user logic to be
independent of the latency of this block (e.g. through [olo_base_latency_comp](../base/olo_base_latency_comp.md)).

In the current version the latency is 19 clock cycles, independently of the input format.

## Generics

| Name            | Type     | Default       | Description                                                  |
| :-------------- | :------- | :------------ | :----------------------------------------------------------- |
| OutFmt_g        | string   | -             | Output format                                                |
| InFmt_g         | string   | -             | Input format. Must be unsigned and at least 5 and at most 256 bits wide. |
| PrecisionBits_g | positive | 18            | Number of fractional bits of the square root approximation.<br>Allowed values: 10, 14, 18, 20 |
| MemStyle_g      | string   | "auto"        | Resource control for the table (_auto_, _block_ or _distributed_) |
| Round_g         | string   | "NonSymPos_s" | Rounding mode of the output stage                            |
| Saturate_g      | string   | "Sat_s"       | Saturation mode of the output stage                          |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Data

| Name     | In/Out | Length           | Default | Description                                  |
| :------- | :----- | :--------------- | ------- | :------------------------------------------- |
| In_Valid | in     | 1                | '1'     | AXI4-Stream handshaking signal for _In_Data_ |
| In_Data  | in     | _width(InFmt_g)_ | -       | Input data<br />Format: _InFmt_g_            |

### Output Data

| Name       | In/Out | Length            | Default | Description                                       |
| :--------- | :----- | :---------------- | ------- | :------------------------------------------------ |
| Out_Valid  | out    | 1                 | N/A     | AXI4-Stream handshaking signal for _Out_Result_   |
| Out_Result | out    | _width(OutFmt_g)_ | N/A     | Square root of _In_Data_<br />Format: _OutFmt_g_  |

## Details

### Architecture

The figure below shows the architecture of the entity. The colors of the signal labels match the formula given in
the [Description](#description).

![Block Diagram](./approx/olo_fix_sqrt.drawio.png)

The normalization shift _N_ is derived from the number of leading zeros of the input. Because the compensation shift
is half of the normalization shift, normalization shift must be even, which is automatically enforced by the logic
itself. The input value is always normalized into the range `[0.25, 1)` after the shift.

Normalization and its reversal are both implemented by [olo_base_dyn_sft](../base/olo_base_dyn_sft.md), which
spreads the barrel shifter over two pipeline stages to achieve good timing. The output shift is _N/2_, because
the square root halves the exponent. It is delayed to the point where it is needed by
[olo_base_latency_comp](../base/olo_base_latency_comp.md).

The approximation is implemented by the internal entity _olo_fix_private_lin_approx_sqrt_. It contains the square
root tables (one per supported _PrecisionBits_g_ value) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) for the piecewise linear interpolation. Below `0.25` the
tables contain zeros, which makes the square root of a zero input exactly zero without any extra logic.

Reverting the normalization shifts the result right by _N/2_. The remaining constant factor (which depends only on
the number of integer bits of the input format) is applied by reinterpreting the number format of the shifted
result, hence it is pure wiring and does not cost any logic. Finally the result is rounded/saturated to _OutFmt_g_
by [olo_fix_resize](./olo_fix_resize.md).

### Precision

_PrecisionBits_g_ selects the number of fractional bits the square root approximation delivers. One table exists
per supported value, hence only the values listed below are allowed - any other value leads to an error:

| _PrecisionBits_g_ | Table size    |
| ----------------- | ------------- |
| 10                | 32 x 16 bit   |
| 14                | 128 x 23 bit  |
| 18                | 512 x 29 bit  |
| 20                | 1024 x 33 bit |

Because the normalization makes the accuracy independent of the magnitude of the input, the error is defined
**relative** to the result:

![Error](./approx/olo_fix_sqrt_error.png)

For very small outputs that are represented by less than _PrecisionBits_g_, the relative error can be larger,
but the absolute error remains below 1 LSB.
