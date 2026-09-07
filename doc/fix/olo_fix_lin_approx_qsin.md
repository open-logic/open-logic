<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_lin_approx_qsin

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_lin_approx_qsin.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_lin_approx_qsin.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_lin_approx_qsin.json?cacheSeconds=0)

VHDL Source: [olo_fix_lin_approx_qsin](../../src/fix/vhdl/olo_fix_lin_approx_qsin.vhd)<br />
Bit-true Model: [olo_fix_lin_approx_qsin](../../src/fix/python/olo_fix/olo_fix_lin_approx_qsin.py)

## Description

!!! Add information about precision (+/- 1 LSB Max) !!!

This entity approximates sine and cosine of **one quadrant**. The input is a phase in **rotations** covering one
quadrant, i.e. the range [0, 0.25), which corresponds to 0 to 90 degrees:

```text
Out_Sin = sin(2*pi * t) * peak
Out_Cos = cos(2*pi * t) * peak
```

The phase is given in the same unit as for [olo_fix_sin](./olo_fix_sin.md), hence the input format must be
`(0, -2, N)` - the two negative integer bits express that only a quarter of a rotation is covered.

For sine and cosine over all four quadrants, use [olo_fix_sin](./olo_fix_sin.md), which does the range reduction and
instantiates this entity. Use _olo_fix_lin_approx_qsin_ directly only if the quadrant handling is done elsewhere.

Only the sine is stored in a table. The cosine is read from the **same table through a second read port** using the
mirrored address _0.25-t_, because `cos(2*pi*t) = sin(2*pi*(0.25-t))`. Setting _CosOutput_g_ to false removes the second
read port and the second calculation, which roughly halves the resource usage.

The tables are optimized for every supported output format - the number of points and the offset/gradient formats
are chosen individually so that each table is exactly as large as it needs to be. They are contained in the
generated package _olo_fix_private_lin_approx_qsin_pkg_ (see [Tables](#tables)).

The approximation itself is done by [olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md).

**Latency** of this entity is 9 clock cycles. The entity is fully pipelined, hence it accepts one input sample per
clock cycle. As a result, back-pressure is not supported.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Output Format and Scaling

_OutFmt_g_ must be `(1, 0, N)` or `(1, 1, N)` with _N_ between 10 and 20 (22 supported formats in total). The number
of integer bits selects the scaling:

| _OutFmt_g_ | Peak value  | Description                                                                      |
| ---------- | ----------- | -------------------------------------------------------------------------------- |
| `(1, 0, N)` | `1.0 - 1 LSB` | The wave is **scaled** so that its peak is the largest representable value        |
| `(1, 1, N)` | `1.0`         | The wave is **unscaled**. One integer bit is required to represent the peak value |

### Critical Input Value

The mirrored address used for the cosine is calculated as the two's complement of the quarter phase, which is exactly
_1-a_ for every _t_ other than zero. For _t = 0_ the two's complement wraps back to zero, hence this one input value
is handled separately. Both results are exact for it:

```text
t = 0  ->  Out_Sin = 0,  Out_Cos = peak
```

### Input Resolution

_InFmt_g_ must be `(0, -2, M)`, i.e. an unsigned phase covering exactly one quadrant. Its width (_M-2_ bits) must be
larger than the number of table index bits (`log2(points)`), otherwise the table cannot be addressed. To keep the
phase quantization below half an LSB of the output, the width should be at least _N+2_ (i.e. _M_ at least _N+4_).
The entity reports a warning during elaboration if this is not the case.

Note that a higher resolution does not change the table - it only refines the linear interpolation between the table
points.

### Accuracy

The table configurations are chosen so that the overall error stays below **one LSB** of the output over the full
quadrant, for both the sine and the cosine output. The dominating contributions are the linear interpolation error
(kept below 0.5 LSB by the number of points) and the output rounding (0.5 LSB).

## Generics

| Name          | Type      | Default          | Description                                                  |
| :------------ | :-------- | :--------------- | :----------------------------------------------------------- |
| OutFmt_g      | string    | "(1, 0, 16)"     | Output format. Must be `(1, 0, 10..20)` or `(1, 1, 10..20)`. |
| InFmt_g       | string    | "(0, -2, 20)"    | Quarter phase input format. Must be `(0, -2, M)` - the input covers one quadrant only. |
| CosOutput_g   | boolean   | false            | If true, _Out_Cos_ is calculated (second table read port and second calculation). If false, _Out_Cos_ is driven with zeros. |
| MemStyle_g    | string    | "auto"           | Resource control for the table (_auto_, _block_ or _distributed_) |
| Round_g       | string    | "NonSymPos_s"    | Rounding mode of the output stage                            |
| Saturate_g    | string    | "Sat_s"          | Saturation mode of the output stage                          |

## Interfaces

| Name       | In/Out | Length          | Default | Description                                    |
| :--------- | :----- | :-------------- | ------- | :--------------------------------------------- |
| Clk        | in     | 1               | -       | Clock                                          |
| Rst        | in     | 1               | -       | Reset input (high-active, synchronous to _Clk_) |
| In_Valid   | in     | 1               | '1'     | AXI4-Stream handshaking signal for _In_Data_   |
| In_Data    | in     | _width(InFmt_g)_ | -      | Phase in rotations, in the range [0, 0.25), corresponding to 0 to 90 degrees |
| Out_Valid  | out    | 1               | N/A     | AXI4-Stream handshaking signal for _Out_Sin_ and _Out_Cos_ |
| Out_Sin    | out    | _width(OutFmt_g)_ | N/A   | Sine of the quarter phase                      |
| Out_Cos    | out    | _width(OutFmt_g)_ | N/A   | Cosine of the quarter phase (zeros if _CosOutput_g_ = false) |

## Architecture

The entity contains the table (ROM) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) once for the sine and - if _CosOutput_g_ is set - a second
time for the cosine. Both instances read from the same table through separate read ports.

```text
                 +----------------------+
In_Data -------->| olo_fix_lin_approx   |----> Out_Sin
            |    | _calc (sine)         |
            |    +----------------------+
            |            ^ |
            |    +-------+-+------------+
            |    |   Table (ROM)        |
            |    +-------+-+------------+
            |            | v
            |    +----------------------+
            +-0-x|  olo_fix_lin_approx  |----> Out_Cos
                 |  _calc (cosine)      |
                 +----------------------+
```

### Tables

The table content is generated in Python and checked into the repository as
[olo_fix_private_lin_approx_qsin_pkg.vhd](../../src/fix/vhdl/olo_fix_private_lin_approx_qsin_pkg.vhd). It is
**not** calculated in VHDL, because the accuracy of _ieee.math_real_ is implementation defined and the table content
would therefore differ between tools - which would break the bit-trueness against the Python model.

The package itself is written by the generic table package generator of
[olo_fix_lin_approx](./olo_fix_lin_approx.md), hence it provides the standard _getTable()_ / _getOffsetFmt()_ /
_getGradientFmt()_ interface. The entity picks its table by the name `qsin_i<I>f<F>`, assembled from _OutFmt_g_.

The table configurations (number of points, offset format, gradient format) live in the `QSIN_TABLES` dictionary in
[olo_fix_lin_approx_qsin.py](../../src/fix/python/olo_fix/olo_fix_lin_approx_qsin.py). To review or modify them,
print the design report:

```bash
cd src/fix/python
python3 -c "from olo_fix import olo_fix_lin_approx_qsin; olo_fix_lin_approx_qsin.report()"
```

The report prints, for every supported output format, the maximum sine/cosine error in LSB, the table geometry, the
table memory usage and the value ranges the offset/gradient formats must cover.

After changing `QSIN_TABLES`, regenerate the package:

```bash
cd src/fix/python
python3 -c "from olo_fix import olo_fix_lin_approx_qsin; olo_fix_lin_approx_qsin.generate_package('../vhdl')"
```

The co-simulation checks the HDL (which uses the checked-in package) against the Python model (which uses
`QSIN_TABLES`), hence the two cannot drift apart unnoticed.

Table sizes range from 32 entries (20 bit each) for `(1, x, 10)` to 1024 entries (35 bit each) for `(1, x, 20)`.
Only the table selected by _OutFmt_g_ is referenced by logic - the others are removed by the synthesis tool.

## Bit-True Model

```python
from olo_fix import olo_fix_lin_approx_qsin
from en_cl_fix_pkg import *

dut = olo_fix_lin_approx_qsin(out_fmt=FixFormat(1, 0, 16), in_fmt=FixFormat(0, -2, 20))
sin_data, cos_data = dut.process(quarter_phase)
```

The model is stateless, hence _next()_ and _process()_ are identical. It always returns both outputs, independently
of _CosOutput_g_ in the HDL.
