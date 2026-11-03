<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_log2

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_log2.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_log2.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_log2.json?cacheSeconds=0)

VHDL Source: [olo_fix_log2](../../src/fix/vhdl/olo_fix_log2.vhd)<br />
Bit-true Model: [olo_fix_log2](../../src/fix/python/olo_fix/olo_fix_log2.py)

## Description

This entity calculates the binary logarithm of the input:

```text
Out_Result = log2(In_Data)
```

The input is normalized into the range `[1, 2)` by a left shift, so that `In_Data = 2^k * (1+m)` with the mantissa
fraction `m` in `[0, 1)`. The logarithm is then split into two parts:

```text
log2(In_Data) = k + log2(1+m)
```

- The **integer part** _k_ is given by the position of the leading one of the input (leading zero detection).
- The **fractional part** `log2(1+m)` is calculated through a table based piecewise linear approximation. It covers
  `[0, 1)`.

Because the integer part is a two's complement number and the fractional part is a positive fraction, the two parts are
simply concatenated, which is pure wiring.

Because the normalization covers the full input range, the approximation only has to cover one octave. Hence a
relatively small table delivers accurate results over the full range of any input format. The precision of the
approximation is selected through _PrecisionBits_g_, see [Precision](#precision).

**Latency** of this entity is constant, see [Latency](#latency). The entity is fully pipelined,
hence it accepts one input sample per clock cycle. As a result, back-pressure is not supported.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Corner Cases

The logarithm is only defined for positive numbers, hence the input format must be **unsigned**.

Inputs that are **powers of two** are handled **exactly** (as far as the result is representable in _OutFmt_g_). Their
mantissa fraction is exactly zero, for which the approximation returns exactly zero.

An input of **zero** delivers the same result as the smallest non-zero input (`-InFmt_g.F`), which is the smallest
result the entity can produce. No error is flagged.

Results are **negative** for inputs below 1.0. If _OutFmt_g_ is unsigned, they are handled by _Saturate_g_ (with the
default "Sat_s" they saturate to zero). It is the responsibility of the user to choose a signed output format if
negative results are required.

### Latency

Latency is not guaranteed to be constant across different versions. It's therefore best to design user logic to be
independent of the latency of this block (e.g. through [olo_base_latency_comp](../base/olo_base_latency_comp.md)).

In the current version the latency is 17 clock cycles, independently of the input format.

## Generics

| Name            | Type     | Default       | Description                                                  |
| :-------------- | :------- | :------------ | :----------------------------------------------------------- |
| OutFmt_g        | string   | -             | Output format. Must be signed to represent results of inputs below 1.0. |
| InFmt_g         | string   | -             | Input format. Must be unsigned and at least two and at most 256 bits wide. |
| PrecisionBits_g | positive | 18            | Number of fractional bits of the logarithm approximation. Must be 10, 14, 18 or 20. |
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

| Name       | In/Out | Length            | Default | Description                                         |
| :--------- | :----- | :---------------- | ------- | :-------------------------------------------------- |
| Out_Valid  | out    | 1                 | N/A     | AXI4-Stream handshaking signal for _Out_Result_     |
| Out_Result | out    | _width(OutFmt_g)_ | N/A     | Binary logarithm of _In_Data_<br />Format: _OutFmt_g_ |

## Details

### Architecture

The figure below shows the architecture of the entity.

![Block Diagram](./approx/olo_fix_log2.drawio.png)

The number of leading zeros _N_ of the input is determined, and the input is normalized by shifting it left by _N_
using [olo_base_dyn_sft](../base/olo_base_dyn_sft.md), which spreads the barrel shifter over two pipeline stages to
achieve good timing. The integer part of the result is calculated from _N_ (`I-1-N` for an input format with _I_
integer bits) and delayed to the output of the approximation by
[olo_base_latency_comp](../base/olo_base_latency_comp.md).

The leading one of the normalized value `1+m` is known, hence it is dropped and only the **mantissa fraction** _m_
in the range `[0, 1)` is passed on. The function approximated is `log2(1+m)`, which covers the range `[0, 1)`.
As a result the whole range of the approximation is used.

The approximation is implemented by the internal entity _olo_fix_private_lin_approx_log2_. It contains the logarithm
tables (one per supported _PrecisionBits_g_ value) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) for the piecewise linear interpolation.

The integer part (signed, just wide enough to cover `-InFmt_g.F ... InFmt_g.I-1`) and the fractional part are
concatenated into a number with _PrecisionBits_g_ fractional bits. Finally the result is rounded/saturated to
_OutFmt_g_ by [olo_fix_resize](./olo_fix_resize.md).

### Precision

_PrecisionBits_g_ selects the number of fractional bits the logarithm approximation delivers. One table exists per
supported value, hence only the values listed below are allowed - any other value leads to an error:

| _PrecisionBits_g_ | Table size    |
| ----------------- | ------------- |
| 10                | 32 x 17 bit   |
| 14                | 128 x 23 bit  |
| 18                | 512 x 30 bit  |
| 20                | 1024 x 33 bit |

Because the normalization makes the accuracy independent of the magnitude of the input, the error is defined as an
**absolute** error. The approximation stays within +/-1 LSB of an output with _PrecisionBits_g_ fractional bits.
