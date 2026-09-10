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

This entity approximates the sine of **one quadrant**. The input is a phase in **rotations** covering one quadrant,
i.e. the range [0, 0.25), which corresponds to 0 to 90 degrees. It uses
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) piecewiese linear approximation to do so. As a result
it requires a little RAM plus one multiplier per generated output and can produce one or two samples per clock cycle.

For cases where multiple clock cycles per sample are available or usage of more LUT logic instead of RAM and
multiplier resources is wanted, [olo_fix_cordic_rot](./olo_fix_cordic_rot.md) can be used instead.

The table is read through **two independent ports** _A_ and _B_. Both ports approximate the same function, they only
differ in the phase applied to them. Port _B_ is optional. Setting _UsePortB_g_ to false removes the second read port
and the second calculation, which roughly halves the resource usage.

The entity allows producing different output precisions (10 to 20 fractional bits). For every output format option
an optimized approximation table is used in order to not needlessly waste memory.

For sine and cosine over all four quadrants, use [olo_fix_sin](./olo_fix_sin.md), which does the range reduction and
instantiates this entity. Use _olo_fix_lin_approx_qsin_ directly only if the quadrant handling is done elsewhere.

**Latency** of this entity is 8 clock cycles. The entity is fully pipelined, hence it accepts one input sample per
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

### Input Resolution

_InFmt_g_ must be `(0, -2, M)`, i.e. an unsigned phase covering exactly one quadrant.

Note that the full input resolution goes into the multiplier for linear approximation. Hence it is suggested to
not needlessly extend the input format. In most cases the number of fractional bits in _InFmt_g_ should be in the same
range as for _OutFmt_g_ or slightly higher (1-2 bits more).

### Accuracy

The table configurations are chosen so that the overall error stays below **one LSB** of the output over the full
quadrant. The dominating contributions are the linear interpolation error (kept below 0.5 LSB by the number of
points) and the output rounding (0.5 LSB).

## Generics

| Name          | Type      | Default          | Description                                                                                                                                     |
| :------------ | :-------- | :--------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| OutFmt_g      | string    | -                | Output format. Must be `(1, 0, 10..20)` or `(1, 1, 10..20)`.                                                                                    |
| InFmt_g       | string    | -                | Quarter phase input format. Must be `(0, -2, M)` - the input covers one quadrant only.                                                          |
| UsePortB_g    | boolean   | false            | If true, port _B_ is implemented (second table read port and second calculation). If false, _In_B_ is ignored and _Out_B_ is driven with zeros. |
| MemStyle_g    | string    | "auto"           | Resource control for the table (_auto_, _block_ or _distributed_)                                                                               |
| Round_g       | string    | "NonSymPos_s"    | Rounding mode of the output stage                                                                                                               |
| Saturate_g    | string    | "Sat_s"          | Saturation mode of the output stage                                                                                                             |

## Interfaces

| Name       | In/Out | Length            | Default | Description                                    |
| :--------- | :----- | :---------------- | ------- | :--------------------------------------------- |
| Clk        | in     | 1                 | -       | Clock                                          |
| Rst        | in     | 1                 | -       | Reset input (high-active, synchronous to _Clk_) |
| In_Valid   | in     | 1                 | '1'     | AXI4-Stream handshaking signal for _In_A_ and _In_B_ |
| In_A       | in     | _width(InFmt_g)_  | -       | Phase applied to port _A_, in rotations, in the range [0, 0.25), corresponding to 0 to 90 degrees |
| In_B       | in     | _width(InFmt_g)_  | 0       | Phase applied to port _B_ (same unit and range). Ignored if _UsePortB_g_ = false. |
| Out_Valid  | out    | 1                 | N/A     | AXI4-Stream handshaking signal for _Out_A_ and _Out_B_ |
| Out_A      | out    | _width(OutFmt_g)_ | N/A     | Sine of _In_A_                                 |
| Out_B      | out    | _width(OutFmt_g)_ | N/A     | Sine of _In_B_ (zeros if _UsePortB_g_ = false)    |

## Architecture

The entity contains the table (ROM) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md) once for port _A_ and - if _UsePortB_g_ is set - a second time
for port _B_. Both instances read from the same table through separate read ports.

## Bit-True Model

```python
from olo_fix import olo_fix_lin_approx_qsin
from en_cl_fix_pkg import *

dut = olo_fix_lin_approx_qsin(out_fmt=FixFormat(1, 0, 16), in_fmt=FixFormat(0, -2, 20))
out_a = dut.process(phase_a)
```

The model covers **one** port. If both ports are used in the HDL, call the model twice - once per port:

```python
out_b = dut.process(phase_b)
```

The model is stateless, hence _next()_ and _process()_ are identical.

### Tables & Developer Information

The table content is generated in Python and checked into the repository as
[olo_fix_private_lin_approx_qsin_pkg.vhd](../../src/fix/vhdl/olo_fix_private_lin_approx_qsin_pkg.vhd). It is
**not** calculated in VHDL, because the accuracy of _ieee.math_real_ is implementation defined and the table content
would therefore differ between tools - which would break the bit-trueness against the Python model.

The package itself is written by the generic table package generator of
[olo_fix_lin_approx](./olo_fix_lin_approx.md), hence it provides the standard _getTable()_ / _getOffsetFmt()_ /
_getGradientFmt()_ interface. The entity picks its table by the name `qsin_i<I>f<F>`, assembled from _OutFmt_g_.

The table configurations (number of points, offset format, gradient format) live in the `QSIN_TABLES` dictionary in
[olo_fix_lin_approx_qsin.py](../../src/fix/python/olo_fix/olo_fix_lin_approx_qsin.py). To review or modify them,
analyze the approximation of one output format:

```bash
cd src/fix/python
python3 -m olo_fix.olo_fix_lin_approx_qsin --analyze "(1,0,16)"
```

The analysis plots the approximation against the ideal function and prints the error plus the value ranges required
by the offset/gradient formats.

After changing `QSIN_TABLES`, regenerate the package:

```bash
cd src/fix/python
python3 -m olo_fix.olo_fix_lin_approx_qsin --generate
```

The co-simulation checks the HDL (which uses the checked-in package) against the Python model (which uses
`QSIN_TABLES`), hence the two cannot drift apart unnoticed.

Table sizes range from 32 entries (20 bit each) for `(1, x, 10)` to 1024 entries (35 bit each) for `(1, x, 20)`.
Only the table selected by _OutFmt_g_ is referenced by logic - the others are removed by the synthesis tool.
