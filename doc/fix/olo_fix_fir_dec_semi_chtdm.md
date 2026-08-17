<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_fir_dec_semi_chtdm

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_fir_dec_semi_chtdm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_fir_dec_semi_chtdm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_fir_dec_semi_chtdm.json?cacheSeconds=0)

VHDL Source: [olo_fix_fir_dec_semi_chtdm.vhd](../../src/fix/vhdl/olo_fix_fir_dec_semi_chtdm.vhd)<br />
Bit-true Model: [olo_fix_fir_dec.py](../../src/fix/python/olo_fix/olo_fix_fir_dec.py)

## Description

This entity implements a decimating FIR filter for multiple TDM (time-division-multiplexed) channels.
All channels share the same coefficient set and are processed one after the other. The filter taps are
computed _semi-parallel_: _Multipliers_g_ multiply-add operations are chained together in the classic
MACC (multiply-accumulate) chain and _ceil(Taps_g / Multipliers_g)_ clock cycles are used to compute one
output sample for one channel.

The number of multipliers therefore trades resources against throughput:

- _Multipliers_g = 1_ behaves like a fully serial FIR (one tap per clock cycle).
- _Multipliers_g = Taps_g_ behaves like a fully parallel FIR (all taps in one clock cycle).
- Any value in between provides a semi-parallel implementation.

Example: A 4 channel, 16 taps FIR filter with _Multipliers_g = 4_ requires _4 x 4 = 16_ clock cycles to
produce one output sample set (one sample for each channel).

Note that the filter can also be used without decimation (_Ratio_g = 1_).

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

Coefficients can be fixed (ROM) or runtime configurable (RAM) with optional readback.

### Input Bandwidth Limitation

**This entity does not generate backpressure.** The semi-parallel MACC chain requires
_ceil(Taps_g / Multipliers_g) x Channels_g_ clock cycles to compute one output sample set (for all
channels). This calculation is repeated every _Ratio_g_ input sample sets.

```text
f_in <= (f_clk x Ratio_g x Multipliers_g) / (Taps_g x Channels_g)
```

where _f_in_ is the rate of complete TDM frames (one frame = _Channels_g_ samples). If the input
arrives faster than this limit, the filter stops working correctly. In simulation an error is reported
if the processing power is insufficient.

Use [olo_base_rate_limit](../base/olo_base_rate_limit.md) externally to enforce the rate limit.

Unless _FullInpRateSupport_g = true_, at least one idle cycle (_In_Valid = '0'_) is required between two
consecutive input samples. See [Full Input Rate Support](#full-input-rate-support).

### Latency

This block changes the sample rate. Because not every input sample produces an output sample, the
latency is not fixed and is therefore not documented in detail.

## Generics

### General Generics

| Name                 | Type     | Default    | Description                                                   |
| :------------------- | :------- | :--------- | :------------------------------------------------------------ |
| InFmt_g              | string   | -          | Input format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| OutFmt_g             | string   | -          | Output format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| CoefFmt_g            | string   | -          | Coefficient format<br>String representation of an _en\_cl\_fix FixFormat\_t_ |
| Channels_g           | positive | -          | Number of TDM channels (must be >= 2)                         |
| Ratio_g              | positive | -          | Decimation ratio (one output per _Ratio_g_ input sample sets) |
| Taps_g               | positive | -          | Number of filter taps (must be >= 2)                          |
| Multipliers_g        | positive | 1          | Number of multipliers (MACC-chain lanes) computed in parallel |
| FullInpRateSupport_g | boolean  | false      | _true_ - input samples may be applied on every clock cycle (uses an additional delay line).<br>_false_ - at least one idle cycle is required between input samples. |
| GuardBits_g          | natural  | 1          | Number of integer guard bits in the accumulator above _OutFmt_g_ |
| Round_g              | string   | "Trunc\_s" | Rounding mode<br>String representation of an _en\_cl\_fix FixRound\_t_ |
| Saturate_g           | string   | "Warn\_s"  | Saturation mode<br>String representation of an _en\_cl\_fix FixSaturate\_t_ |
| MultRegs_g           | positive | 1          | Number of pipeline registers in each multiplier               |

### Coefficient and Data Storage

| Name              | Type     | Default | Description                                                   |
| :---------------- | :------- | :------ | :------------------------------------------------------------ |
| CoefInit_g        | string   | "0.0"   | Comma-separated initial coefficient values (real numbers, quantized to _CoefFmt_g_)<br> Example: "0.3, 0.55, 0.2"<br> see [olo_fix_coef_storage](./olo_fix_coef_storage.md) |
| CoefStorageType_g | string   | "ROM"   | Coefficient storage type: "ROM" (fixed) or "RAM" (runtime-updateable)<br> see [olo_fix_coef_storage](./olo_fix_coef_storage.md) |
| CoefRamReadback_g | boolean  | false   | Enable coefficient readback via _Coef\_Rd\_..._ ports (RAM mode only)<br> see [olo_fix_coef_storage](./olo_fix_coef_storage.md) |
| CoefRamBehavior_g | string   | "RBW"   | Coefficient RAM behavior: "RBW" = read-before-write, "WBR" = write-before-read<br> see [olo_fix_coef_storage](./olo_fix_coef_storage.md) |
| CoefMemStyle_g    | string   | "auto"  | Synthesis attribute for coefficient memory style (e.g. "block", "distributed")<br> see [olo_fix_coef_storage](./olo_fix_coef_storage.md) |
| DataRamBehavior_g | string   | "RBW"   | Data RAM behavior: "RBW" = read-before-write, "WBR" = write-before-read<br> see [olo_base_ram_tdp](../base/olo_base_ram_tdp.md) |
| DataMemStyle_g    | string   | "auto"  | Synthesis attribute for data RAM style (e.g. "block", "distributed")<br> see [olo_base_ram_tdp](../base/olo_base_ram_tdp.md) |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                      |
| :--- | :----- | :----- | :------ | :------------------------------- |
| Clk  | in     | 1      | -       | Clock                            |
| Rst  | in     | 1      | -       | Reset (synchronous, active high) |

### Coefficient Configuration

| Name          | In/Out | Length              | Default | Description                                      |
| :------------ | :----- | :------------------ | :------ | :----------------------------------------------- |
| Coef\_Addr    | in     | _log2ceil(Taps_g)_  | 0       | Coefficient address for read/write               |
| Coef\_WrEna   | in     | 1                   | '0'     | Coefficient write enable (RAM mode only)         |
| Coef\_WrData  | in     | _width(CoefFmt_g)_  | 0       | Coefficient write data (RAM mode only)           |
| Coef\_RdEna   | in     | 1                   | '0'     | Coefficient read enable (RAM readback mode only) |
| Coef\_RdData  | out    | _width(CoefFmt_g)_  | N/A     | Coefficient read data (0 in ROM mode)            |
| Coef\_RdValid | out    | 1                   | N/A     | Coefficient read valid (0 in ROM mode)           |

All _Coef\_*_ ports have safe defaults and can be left unconnected in ROM mode or when
coefficient updates are not needed.

### Delay-Line Flushing

| Name       | In/Out | Length | Default | Description                                                                 |
| :--------- | :----- | :----- | :------ | :-------------------------------------------------------------------------- |
| Flush_Ena  | in     | 1      | '0'     | A pulse on this port starts a flush that zeros all data delay lines.         |
| Flush_Done | out    | 1      | N/A     | A pulse on this port indicates that a flush started by _Flush_Ena_ finished. |

See [Startup and Flushing](#startup-and-flushing).

### Input Data

| Name     | In/Out | Length           | Default | Description                                                                        |
| :------- | :----- | :--------------- | :------ | :--------------------------------------------------------------------------------- |
| In_Valid | in     | 1                | -       | Input valid                                                                        |
| In_Data  | in     | _width(InFmt_g)_ | -       | Input data (TDM: channels interleaved, ch0 first)                                 |
| In_Last  | in     | 1                | '0'     | TDM frame boundary (optional)<br>see [TDM Conventions](../Conventions.md#tdm-time-division-multiplexing) |

The _In_Last_ signal is optional and has no functional effect. In simulation it is only used to check
that it is asserted at the correct TDM position (last channel); an error is reported if _In_Last_ is
asserted on a sample of any other channel. See [Last Handling](#last-handling).

### Output Data

| Name      | In/Out | Length            | Default | Description                                                                        |
| :-------- | :----- | :---------------- | :------ | :--------------------------------------------------------------------------------- |
| Out_Valid | out    | 1                 | N/A     | Output valid                                                                       |
| Out_Data  | out    | _width(OutFmt_g)_ | N/A     | Output data (TDM: channels interleaved, ch0 first)                                |
| Out_Last  | out    | 1                 | N/A     | TDM frame boundary, asserted on the last channel<br>see [TDM Conventions](../Conventions.md#tdm-time-division-multiplexing) |

## Details

### Example Instantiation

The example below shows a simple instantiation: fixed coefficients stored in ROM, four taps computed with
two multipliers and a decimation ratio of two. All coefficient configuration ports, the flushing
interface and _In_Last_ are omitted.

```vhdl
i_fir : entity olo.olo_fix_fir_dec_semi_chtdm
    generic map (
        -- Formats
        InFmt_g       => "(1,0,15)",
        OutFmt_g      => "(1,0,15)",
        CoefFmt_g     => "(1,0,17)",
        -- Filter parameters
        Channels_g    => 4,
        Ratio_g       => 2,
        Taps_g        => 4,
        Multipliers_g => 2,
        -- Fixed coefficients stored in ROM
        CoefInit_g    => "0.1, 0.4, 0.4, 0.1"
    )
    port map (
        Clk       => Clk,
        Rst       => Rst,
        In_Valid  => In_Valid,
        In_Data   => In_Data,
        Out_Valid => Out_Valid,
        Out_Data  => Out_Data
    );
```

### Architecture

The datapath consists of _Multipliers_g_ parallel MACC lanes built from [olo_fix_madd](./olo_fix_madd.md).
The lanes are chained (each lane adds its product to the running sum coming from the previous lane) so the
synthesizer can map them onto a DSP cascade. In every calculation cycle the chain produces the sum of
_Multipliers_g_ tap products; these partial sums are accumulated over _ceil(Taps_g / Multipliers_g)_ cycles
to form one output sample.

Each lane owns:

- A data delay-line RAM ([olo_base_ram_tdp](../base/olo_base_ram_tdp.md)). The RAMs are chained so that each
  stage sees the input delayed by a further block of taps.
- A coefficient storage ([olo_fix_coef_storage](./olo_fix_coef_storage.md)), holding a full copy of the
  coefficient set (ROM or RAM depending on _CoefStorageType_g_). Coefficient writes are broadcast to all
  copies; readback is taken from the first copy.

The result of the accumulation is rounded and saturated to _OutFmt_g_ using
[olo_fix_resize](./olo_fix_resize.md).

The memory styles of the coefficient storage and the data RAM can be selected independently through
_CoefMemStyle_g_ and _DataMemStyle_g_.

### Full Input Rate Support

When _FullInpRateSupport_g = false_ (default), the chained data memory needs one idle cycle between two
input samples, hence _In_Valid_ must not be asserted on two consecutive clock cycles.

When _FullInpRateSupport_g = true_, an additional delay line ([olo_base_delay](../base/olo_base_delay.md))
per lane provides the chained delay, so _In_Valid_ may be asserted on every clock cycle. Note that this
only relaxes the back-to-back input restriction; the overall processing power limit (see
[Input Bandwidth Limitation](#input-bandwidth-limitation)) still applies.

### Startup and Flushing

The delay lines are stored in RAM and are **not** cleared by reset. After power-up the RAMs are zero
initialized, hence the first outputs are bit-true without any special action. If the filter is reset
during operation, the RAMs still contain old data. In this case a flush must be triggered (pulse
_Flush_Ena_ and wait for _Flush_Done_) to zero the delay lines before feeding new data. This guarantees
bit-true agreement with the Python model, which initializes its delay line to zero.

### Coefficient Format

The accumulator operates at full multiply precision:

- _MultFmt = (max(In.S, Coef.S), In.I + Coef.I, In.F + Coef.F)_
- _AccuFmt = (1, Out.I + GuardBits_g, In.F + Coef.F)_ (_GuardBits_g_ guard bits above output)

Choosing _OutFmt.I_ or _GuardBits_g_ too small risks accumulator overflow. Ensure
_max\_sum\_of\_products <= 2^(OutFmt.I + GuardBits_g) - 1 LSB_.

### Accumulator Guard Bits

The accumulator carries _GuardBits_g_ integer guard bits above _OutFmt_g_
(_AccuFmt.I = OutFmt.I + GuardBits_g_). These bits allow the sum of products to grow beyond the output
range during the accumulation without overflowing. With the default of one guard bit, intermediate
results of up to twice the _OutFmt_g_ maximum are supported. The user is responsible for choosing
_GuardBits_g_, the coefficients and the formats such that the accumulator does not overflow; otherwise
the number of guard bits or the output format must be increased.

### Last Handling

On the input, _In_Last_ is not required for operation. It is only used in simulation to detect
incorrect TDM framing: an error is reported if _In_Last_ is asserted on a sample that does not belong
to the last channel (_Channels_g-1_). It has no functional effect on the computation.

On the output, _Out_Last_ is generated by the entity itself and is always asserted together with
_Out_Valid_ on the last channel (_Channels_g-1_) of every output sample set.
