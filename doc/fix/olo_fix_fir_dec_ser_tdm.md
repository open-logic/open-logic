<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_fir_dec_ser_tdm

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_fir_dec_ser_tdm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_fir_dec_ser_tdm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_fir_dec_ser_tdm.json?cacheSeconds=0)

VHDL Source: [olo_fix_fir_dec_ser_tdm.vhd](../../src/fix/vhdl/olo_fix_fir_dec_ser_tdm.vhd)<br />
Bit-true Model: [olo_fix_fir_dec.py](../../src/fix/python/olo_fix/olo_fix_fir_dec.py)

## Description

This entity implements a decimating FIR filter for multiple TDM (time-division-multiplexed) channels.
All channels share the same coefficient set and are processed one after the other. A single shared
multiplier computes filter taps serially -- one tap per clock cycle.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

### Coefficient Storage

The coefficient storage is controlled by _CoefStorageType_g_:

- _CoefStorageType_g = "ROM"_: Coefficients are fixed at synthesis time via _CoefInit_g_.
  The _Coef\_Cfg\_*_ ports are ignored and can be left unconnected.
- _CoefStorageType_g = "RAM"_: Coefficients can be updated at runtime via the _Coef\_Cfg\_*_ ports.
  Initial values are set via _CoefInit_g_. RAM readback is enabled by setting _CoefRamReadback_g = true_.

The _Coef\_Cfg\_*_ ports share the main _Clk_. Coefficient updates must only occur when the filter
is in reset (_Rst = '1'_).

### Accumulator Guard Bit

The accumulator has one integer guard bit above _OutFmt_g_ (_AccuFmt.I = OutFmt.I + 1_). This
supports outputs of up to twice the _OutFmt_g_ maximum without overflow. The user is responsible for
choosing coefficients and formats such that the filter output fits within this range; otherwise the
output format must be widened.

### Runtime Configuration

_Cfg_Ratio_ and _Cfg_Taps_ must only be changed while _Rst = '1'_. Changing these ports during
operation produces undefined behavior.

### Input Bandwidth Limitation

**This entity does not generate backpressure.** The serial MAC requires _MaxTaps_g_ clock cycles
to compute one output sample set (for all channels). The input rate must therefore satisfy:

```
f_in <= f_clk / MaxTaps_g
```

where _f_in_ is the rate of complete TDM frames (one frame = _Channels_g_ samples). If the input
arrives faster than this limit, the computation will fall behind and results will be incorrect.

Use [olo_base_rate_limit](../base/olo_base_rate_limit.md) externally to enforce the rate limit.

### Latency

This block changes the sample rate. Because not every input sample produces an output sample, the
latency is not fixed and is therefore not documented in detail.

## Generics

| Name              | Type     | Default         | Description                                                   |
| :---------------- | :------- | :-------------- | :------------------------------------------------------------ |
| InFmt_g           | string   | -               | Input format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| OutFmt_g          | string   | -               | Output format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| CoefFmt_g         | string   | -               | Coefficient format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| Channels_g        | positive | 2               | Number of TDM channels (must be >= 2)                         |
| MaxRatio_g        | positive | -               | Maximum decimation ratio (must be >= 2)                       |
| MaxTaps_g         | positive | -               | Maximum number of filter taps (must be >= 2)                  |
| Round_g           | string   | "NonSymPos\_s"  | Rounding mode<br>String representation of an _en\_cl\_fix FixRound\_t_ |
| Saturate_g        | string   | "Warn\_s"       | Saturation mode<br>String representation of an _en\_cl\_fix FixSaturate\_t_ |
| MultRegs_g        | positive | 1               | Number of pipeline registers in the multiplier                |
| CoefInit_g        | string   | "0.0"           | Comma-separated initial coefficient values (real numbers, quantized to _CoefFmt_g_) |
| CoefStorageType_g | string   | "ROM"           | Coefficient storage type: "ROM" (fixed) or "RAM" (runtime-updateable) |
| CoefRamReadback_g | boolean  | false           | Enable coefficient readback via _Coef\_Cfg\_Rd\*_ ports (RAM mode only) |
| CoefRamBehavior_g | string   | "RBW"           | Coefficient RAM behavior: "RBW" = read-before-write, "WBR" = write-before-read |
| CoefMemStyle_g    | string   | "auto"          | Synthesis attribute for coefficient memory style (e.g. "block", "distributed") |
| DataRamBehavior_g | string   | "RBW"           | Data RAM behavior: "RBW" = read-before-write, "WBR" = write-before-read |
| DataMemStyle_g    | string   | "auto"          | Synthesis attribute for data RAM style (e.g. "block", "distributed") |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                      |
| :--- | :----- | :----- | :------ | :------------------------------- |
| Clk  | in     | 1      | -       | Clock                            |
| Rst  | in     | 1      | -       | Reset (synchronous, active high) |

### Runtime Configuration

| Name      | In/Out | Length                   | Default         | Description                                          |
| :-------- | :----- | :----------------------- | :-------------- | :--------------------------------------------------- |
| Cfg_Ratio | in     | _log2ceil(MaxRatio_g)_   | _MaxRatio_g-1_  | Decimation ratio minus 1 (0 = ratio 1, 7 = ratio 8) |
| Cfg_Taps  | in     | _log2ceil(MaxTaps_g)_    | _MaxTaps_g-1_   | Active tap count minus 1 (0 = 1 tap)                |

Both ports have safe defaults (maximum ratio and tap count). They can be left unconnected to use fixed
maximum values. Change only when _Rst = '1'_.

### Coefficient Configuration

| Name             | In/Out | Length                    | Default      | Description                                                |
| :--------------- | :----- | :------------------------ | :----------- | :--------------------------------------------------------- |
| Coef\_Cfg\_Addr  | in     | _log2ceil(MaxTaps_g)_     | 0            | Coefficient address for read/write                        |
| Coef\_Cfg\_WrEna | in     | 1                         | '0'          | Coefficient write enable (RAM mode only)                  |
| Coef\_Cfg\_WrData| in     | _width(CoefFmt_g)_        | 0            | Coefficient write data (RAM mode only)                    |
| Coef\_Cfg\_RdEna | in     | 1                         | '0'          | Coefficient read enable (RAM readback mode only)          |
| Coef\_Cfg\_RdData| out    | _width(CoefFmt_g)_        | N/A          | Coefficient read data (0 in ROM mode)                     |
| Coef\_Cfg\_RdValid| out   | 1                         | N/A          | Coefficient read valid (0 in ROM mode)                    |

All _Coef\_Cfg\_*_ ports have safe defaults and can be left unconnected in ROM mode or when
coefficient updates are not needed.

### Input Data

| Name     | In/Out | Length           | Default | Description                                                                        |
| :------- | :----- | :--------------- | :------ | :--------------------------------------------------------------------------------- |
| In_Valid | in     | 1                | -       | Input valid                                                                        |
| In_Data  | in     | _width(InFmt_g)_ | -       | Input data (TDM: channels interleaved, ch0 first)                                 |
| In_Last  | in     | 1                | '0'     | TDM frame boundary (optional)<br>see [TDM Conventions](../Conventions.md#tdm-time-division-multiplexing) |

The _In_Last_ signal is optional. When asserted, it is checked in simulation that it occurs at the
correct TDM position (last channel). Errors are reported if _In_Last_ is asserted at the wrong time.

### Output Data

| Name      | In/Out | Length            | Default | Description                                                                        |
| :-------- | :----- | :---------------- | :------ | :--------------------------------------------------------------------------------- |
| Out_Valid | out    | 1                 | N/A     | Output valid                                                                       |
| Out_Data  | out    | _width(OutFmt_g)_ | N/A     | Output data (TDM: channels interleaved, ch0 first)                                |
| Out_Last  | out    | 1                 | N/A     | TDM frame boundary<br>see [TDM Conventions](../Conventions.md#tdm-time-division-multiplexing) |

## Details

### Architecture

All channel data is stored in a single true dual-port RAM. The higher address bits select the
channel region; the lower bits address the tap (delay line) within that channel. Port A writes
new input samples; Port B reads historical samples during computation.

Coefficients are stored in a dedicated `olo_fix_coef_storage` instance (ROM or RAM depending on
_CoefStorageType_g_).

The serial MAC pipeline:
- Stages 0-4: input registration, data/coefficient RAM address generation, RAM reads
- Stages 5 to 4+MultRegs_g: multiplier (`olo_fix_mult` with _MultRegs_g_ pipeline registers)
- Stage 4+MultRegs_g: accumulator (`cl_fix_add` inline, resets to zero on first tap of each channel)
- Output: `olo_fix_resize` rounds and saturates the final accumulation result to _OutFmt_g_

### Startup Behavior

At startup the data RAM is uninitialized. The filter replaces RAM reads of locations not yet
written with zeros. This matches the Python model (`olo_fix_fir_dec`), which initializes its delay
line to zero, ensuring bit-true agreement from the first output sample.

### Coefficient Format

The accumulator operates at full multiply precision:
- _MultFmt = (max(In.S, Coef.S), In.I + Coef.I, In.F + Coef.F)_
- _AccuFmt = (1, Out.I + 1, In.F + Coef.F)_ (one guard bit above output)

Choosing _OutFmt.I_ too small risks accumulator overflow. Ensure
_max\_sum\_of\_products <= 2^(OutFmt.I+1) - 1 LSB_.
