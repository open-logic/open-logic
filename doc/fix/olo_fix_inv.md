<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_inv

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_inv.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_inv.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_inv.json?cacheSeconds=0)

VHDL Source: [olo_fix_inv](../../src/fix/vhdl/olo_fix_inv.vhd)<br />
Bit-true Model: [olo_fix_inv](../../src/fix/python/olo_fix/olo_fix_inv.py)

## Description

This entity calculates the inverse of the input:

```text
Out_Result = 1/In_Data
```

The absolute value of the input is normalized into the range `[1, 2)`, inverted through a table based piecewise
linear approximation and the normalization is reverted on the result. Compared to
[olo_fix_bin_div](./olo_fix_bin_div.md) it trades memory for latency and logic: it needs a ROM and two multipliers
but it is fully pipelined and has a constant latency instead of one iteration per output bit.

Because the normalization covers the full input range, the approximation only has to cover one octave. Hence a
relatively small table delivers accurate results over the full range of any input format. The precision of the
approximation is selected through _PrecisionBits_g_ - the normalization covers the rest of the range.

**Latency** of this entity depends on the input format, see [Latency](#latency). The entity is fully pipelined,
hence it accepts one input sample per clock cycle. As a result, back-pressure is not supported.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Number Formats

**Any** input format is allowed, as long as it is at least two bits wide (a leading one plus at least one mantissa
bit are required). Signed and unsigned inputs are both supported - for a signed input format, _OutFmt_g_ must be
signed as well, because the result of a negative input is negative.

**Any** output format is allowed. Results not representable in _OutFmt_g_ are rounded and saturated according to
_Round_g_ and _Saturate_g_. Note that the output format normally needs many more integer bits than the input
format: the smallest non-zero input of a format with _F_ fractional bits is `2**-F`, whose inverse is `2**F`.

### Precision

_PrecisionBits_g_ selects the number of fractional bits the inversion approximation delivers. One table exists per
supported value, hence only the values listed below are allowed - any other value leads to an error:

| _PrecisionBits_g_ | Table size          | Relative error |
| ----------------- | ------------------- | -------------- |
| 10                | 32 x 22 bit         | < 2^-9         |
| 14                | 128 x 29 bit        | < 2^-13        |
| 18                | 512 x 36 bit        | < 2^-17        |
| 20                | 1024 x 35 bit       | < 2^-19        |

The error is given **relative** to the absolute value of the result, because the normalization makes the accuracy
independent of the magnitude of the input. The two largest tables are sized to fit into a single block RAM of
common FPGA families (512 x 36 and 1024 x 36 respectively), hence _PrecisionBits_g_ = 18 or 20 costs one block RAM
if _MemStyle_g_ = "block" is used. To exploit the precision fully, _OutFmt_g_ must provide at least
_PrecisionBits_g_ significant bits for the results of interest. Choosing a precision higher than the output format
resolution does not improve the result - it only costs memory and multiplier width.

### Corner Cases

Inputs that are **powers of two** are inverted **exactly** (as far as the result is representable in _OutFmt_g_).
Their normalized value is exactly 1.0, for which the approximation returns exactly 1.0.

An input of **zero** delivers the same result as the smallest non-zero input, which is the largest result the
entity can produce. No error is flagged. With the default _Saturate_g_ = "Sat_s" and an output format that cannot
represent `2**InFmt_g.F`, this result saturates to the maximum value of _OutFmt_g_.

### Latency

Latency is not guaranteed to be constant across different versions. It's therefore best to design user logic to be
independent of the latency of this block (e.g. through [olo_base_latency_comp](../base/olo_base_latency_comp.md)).

In the current version the latency can be calculated as follows, with _W_ being the width of _InFmt_g_:

```text
Latency = 13 + 2*(ceil(ceil(log2(W))/4) + 1)
```

This is 17 clock cycles for input formats up to 16 bits and 19 clock cycles for input formats up to 256 bits.

## Generics

| Name            | Type     | Default       | Description                                                  |
| :-------------- | :------- | :------------ | :----------------------------------------------------------- |
| OutFmt_g        | string   | -             | Output format. Must be signed if _InFmt_g_ is signed.        |
| InFmt_g         | string   | -             | Input format. Any format that is at least two bits wide.     |
| PrecisionBits_g | positive | 18            | Number of fractional bits of the inversion approximation. Must be 10, 14, 18 or 20. |
| MemStyle_g      | string   | "auto"        | Resource control for the table (_auto_, _block_ or _distributed_) |
| Round_g         | string   | "NonSymPos_s" | Rounding mode of the output stage                            |
| Saturate_g      | string   | "Sat_s"       | Saturation mode of the output stage                          |

## Interfaces

| Name       | In/Out | Length            | Default | Description                                     |
| :--------- | :----- | :---------------- | ------- | :---------------------------------------------- |
| Clk        | in     | 1                 | -       | Clock                                           |
| Rst        | in     | 1                 | -       | Reset input (high-active, synchronous to _Clk_) |
| In_Valid   | in     | 1                 | '1'     | AXI4-Stream handshaking signal for _In_Data_    |
| In_Data    | in     | _width(InFmt_g)_  | -       | Input data                                      |
| Out_Valid  | out    | 1                 | N/A     | AXI4-Stream handshaking signal for _Out_Result_ |
| Out_Result | out    | _width(OutFmt_g)_ | N/A     | Inverse of _In_Data_                            |

## Architecture

The absolute value of the input is normalized by shifting it left until its MSB is one, which brings it into the
range `[1, 2)`. The number of positions shifted is the number of leading zeros of the absolute value.

Because the leading one of the normalized value is known, it is not passed on. The input of the approximation is
the **mantissa fraction** _m_ in the range `[0, 1)`, and the function approximated is `1/(1+m)`, which covers the
range `(0.5, 1.0]`. As a result the whole table is used - a table covering `[1, 2)` directly would waste half of
its entries.

The approximation itself is implemented by the internal entity _olo_fix_private_lin_approx_inv_. It contains the
inversion table (one table per supported precision, so that no memory is wasted) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) for the piecewise linear interpolation.

Reverting the normalization means multiplying the result by `2**shift`, hence the result is shifted left by the
same number of positions the input was shifted by. Both shifts are implemented by
[olo_base_dyn_sft](../base/olo_base_dyn_sft.md), which spreads the barrel shifter over several pipeline stages to
achieve good timing. The remaining constant factor (which depends on the number of integer bits of the input
format only) is applied by reinterpreting the number format of the shifted result, hence it is pure wiring and does
not cost any logic.

Finally the result is negated for negative inputs and rounded/saturated to _OutFmt_g_.

## Bit-True Model

```python
from olo_fix import olo_fix_inv
from en_cl_fix_pkg import *

dut = olo_fix_inv(out_fmt=FixFormat(0, 8, 12), in_fmt=FixFormat(0, 0, 16), precision_bits=18)
result = dut.process(data)
```

The model is stateless, hence _next()_ and _process()_ are identical.
