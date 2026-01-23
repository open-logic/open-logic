<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_cordic_rot

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_cordic_rot.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_cordic_rot.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_cordic_rot.json?cacheSeconds=0)

VHDL Source: [olo_fix_cordic_rot](../../src/fix/vhdl/olo_fix_cordic_rot.vhd)<br />
Bit-true Model: [olo_fix_cordic_rot](../../src/fix/python/olo_fix/olo_fix_cordic_rot.py)

## Description

### Overview

This entity implements the rotating CORDIC algorithm. This algorithm is usually used to convert from the polar
to the cartesian coordinate system, i.e. to calculate I and Q components (complex numbers) from an
angle and a magnitude.

The algorithm can be implemented in two different modes:

- **SERIAL**
  - Iterations are executed one after the other
  - A new sample can be accepted every _Iterations_g_ clock cycles.
  - Lowest possible resource usage
- **PIPELINED**
  - Iterations are implemented in individual pipeline stages
  - Every clock cycle a new sample can be accepted
  - Highest possible throughput

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Gain Compensation

The CORDIC algorithm has an inherent gain that depends on the number of iterations. This gain can optionally be
compensated directly within the _olo_fix_cordic_rot_ entity. The internal gain compensation works most efficiently
if the internal format _IntXyFmt_g_  fits into one multiplier of the target device.

Alternatively, the user may choose to do the gain compensation outside of the entity, e.g. by using an
_olo_fix_mult_ entity before the CORDIC to scale down the input magnitude. For this the gain factor must be known,
hence the formula is given below:

![Cordic Gain Formula](./cordic/cordic_gain.png)

Note that depending on the application the gain compensation may be omitted completely. Therefore it is optional and can
be controlled through the generic _GainCorrCoefFmt_g_.

### Latency

The latency of the entity depends on several factors and can best be determined in the simulation.

Note: Latency is not guaranteed to be constant across different versions. It's therefore best to design user logic
to be independent of the latency of this block (e.g. through [olo_base_latency_comp](../base/olo_base_latency_comp.md)).

In the current version the latency can be calculated as follows:

- _Mode_g_ = "PIPELINED" with gain correction: _Latency_ = 4 + _Iterations_g_ + _resize_latency_
- _Mode_g_ = "PIPELINED" without gain correction (_GainCorrCoefFmt_g_ = "NONE"): _Latency_ = 3 + _Iterations_g_ +
  _resize_latency_
- _Mode_g_ = "SERIAL" with gain correction: _Latency_ = 4 + _Iterations_g_ + _resize_latency_
- _Mode_g_ = "SERIAL" without gain correction (_GainCorrCoefFmt_g_ = "NONE"): _Latency_ = 3 + _Iterations_g_ +
  _resize_latency_

Where _resize_latency_ is calculated as follows:

- +1 cycle if _Round_g_ is NOT "Trunc_s"
- +1 cycle if _Saturate_g_ is NOT "None_s"

## Generics

| Name              | Type     | Default     | Description                                                                                                                                                                                                                                                          |
| :---------------- | :------- | ----------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| InMagFmt_g        | string   | -           | Input magnitude format <br>Must be (0,x,y) <br />String representation of an _en_cl_fix Format_t_ (e.g. "(0,1,15)")                                                                                                                                                  |
| InAngFmt_g        | string   | -           | Input angle format <br>Must be (0,0,x) <br />String representation of an _en_cl_fix Format_t_ (e.g. "(0,0,15)")                                                                                                                                                      |
| OutFmt_g          | string   | -           | Output data format <br>Usually (1,x,y) <br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)")                                                                                                                                                      |
| IntXyFmt_g        | string   | "AUTO"      | Internal format for X/Y values. <br>With "AUTO" the format is chosen automatically. <br>For manual control, specify a string representation of a signed _en_cl_fix Format_t_ (e.g. "(1,1,15)"). Refer to [Format Considerations](#format-considerations) for details |
| IntAngFmt_g       | string   | "AUTO"      | Internal format for angles <br>With "AUTO" the format is chosen automatically. <br>For manual control, specify a string representation of a (1,-2,x) _en_cl_fix Format_t_ (e.g. "(1,-2,15)"). Refer to [Format Considerations](#format-considerations) for details   |
| Iterations_g      | positive | 16          | Number of CORDIC iterations. <br>Range: 3 .. 32 <br>Refer to [Format Considerations](#format-considerations) for details                                                                                                                                             |
| Mode_g            | string   | "PIPELINED" | CORDIC operation mode<br />"SERIAL": one iteration per clock cycle<br />"PIPELINED": Pipelined mode (one sample per clock cycle)                                                                                                                                     |
| GainCorrCoefFmt_g | string   | "(0,0,17)"  | Format of the gain correction coefficient, specify a string representation of a signed _en_cl_fix Format_t_ (e.g. "(0,0,15)"). Refer to [Format Considerations](#format-considerations). <br> To disable the internal gain compensation, choose "NONE"               |
| Round_g           | string   | "Trunc_s"   | Rounding mode <br />String representation of an _en_cl_fix FixRound_t_.                                                                                                                                                                                              |
| Saturate_g        | string   | "Warn_s"    | Saturation mode <br />String representation of an _en_cl_fix FixSaturate_t_.                                                                                                                                                                                         |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_)              |

### Input Data

| Name     | In/Out | Length              | Default | Description                                                                                                                |
| :------- | :----- | :------------------ | ------- | :------------------------------------------------------------------------------------------------------------------------- |
| In_Mag   | in     | _width(InMagFmt_g)_ | N/A     | Input magnitude<br />Format _InMagFmt_g_                                                                                   |
| In_Ang   | in     | _width(InAngFmt_g)_ | N/A     | Input angle, Normalized units (1.0 = 360° = 2*PI)<br />Format _InAngFmt_g_                                                 |
| In_Valid | in     | 1                   | '1'     | AXI4-Stream handshaking signal for _In_Mag_ and _In_Ang_                                                                   |
| In_Ready | out    | 1                   | N/A     | AXI4-Stream ready signal for _In_Mag_ and _In_Ang_<br>Used in "SERIAL" mode to signal when a new input sample is taken     |

### Output Data

| Name       | In/Out | Length               | Default | Description                                                      |
| :--------- | :----- | :------------------- | ------- | :--------------------------------------------------------------- |
| Out_I      | out    | _width(OutFmt_g)_    | -       | In-phase/real part of output data<br />Format: _OutFmt_g_        |
| Out_Q      | out    | _width(OutFmt_g)_    | -       | Quadrature/imaginary part of output data<br />Format: _OutFmt_g_ |
| Out_Valid  | out    | 1                    | N/A     | AXI4-Stream handshaking signal for _Out_Q_ and _Out_I_           |

**Note** The output interface does not implement backpressure (_Ready_). If backpressure is required, the user ideally
implements it over the whole processing chain using [olo_base_flowctrl_handler](../base/olo_base_flowctrl_handler.md).

## Detail

### Format Considerations

#### IntXyFmt_g

The format for internal calculation of X and Y components must be **signed**.

The more fractional bits are used, the more precise the calculation gets. Usually a few more fractional bits than in
_OutFmt_g_ are required.

The number of integer bits must be chosen to ensure that no overflows happen during calculation. Except for special
cases one more bit than for _InMagFmt_g_ is required.

Optimization is best performed based on the bit-true python model.

For "AUTO" mode, the internal format is chosen as follows:

- Sign bit: yes
- Integer bits: _InMagFmt_g.I_ + 1
- Fractional bits: _OutFmt_g.F_ + 3

#### GainCorrCoefFmt_g

For optimal absolute precision, the gain correction coefficient shall have at least the same number of fractional
bits as _OutFmt_g_.

In many cases the absolute precision is secondary and only the relative precision matters. In such cases the number
of bits can be reduced to save resources. Because all samples receive the same gain correction, any errors in the
correction factor will not impact the relative precision between samples.

#### IntAngFmt_g

Internal calculation format for angles (must be signed) and have -2 integer bits (because only one quadrant is used,
angles 0...0.25).)

The more fractional bits, the more precise the calculation gets. Usually a few more bits than in _InAngFmt_g_ are
required.

Optimization is best performed based on the bit-true python model.

For "AUTO" mode, the internal format is chosen as follows:

- Sign bit: yes
- Integer bits: -2
- Fractional bits: _InAngFmt_g.F_ + 3

#### Iterations_g

More iterations lead to more precise results. A good starting point is one iteration per bit in the output format.

Optimization is best performed based on the bit-true python model.
