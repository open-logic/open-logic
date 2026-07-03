<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_mix_c2r

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_mix_c2r.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_mix_c2r.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_mix_c2r.json?cacheSeconds=0)

VHDL Source: [olo_fix_mix_c2r](../../src/fix/vhdl/olo_fix_mix_c2r.vhd)<br />
Bit-true Model: [olo_fix_mix_c2r](../../src/fix/python/olo_fix/olo_fix_mix_c2r.py)

## Description

This entity implements a complex-to-real mixer. It multiplies a complex input signal
(_In_SigI_, _In_SigQ_) with a complex local oscillator (_In_MixI_, _In_MixQ_) to produce
a real output signal (_Out_SigReal_).

The downconversion convention is used, which corresponds to multiplying by the conjugate of the
local oscillator:

> Out_SigReal = +In_SigI x In_MixI + In_SigQ x In_MixQ

Two I/Q handling modes are supported, selected by the _IqHandling_g_ generic:

- **Parallel** -- I and Q channels of both signal and mixer are presented simultaneously on
  separate ports. Two multiply-accumulate operations run in parallel.
- **TDM** -- I sample is followed immediately by Q sample on shared ports (_In_SigIQ_,
  _In_MixIQ_). One multiplier is time-shared between the I and Q products; one real output
  sample is produced per I/Q pair.

The _In_Last_ port is used in TDM mode to re-synchronise the I/Q phase: after _In_Last_ is
asserted the first sample received is treated as I. In Parallel mode _In_Last_ is ignored.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

## Generics

| Name          | Type    | Default    | Description                                                  |
| :------------ | :------ | ---------- | :----------------------------------------------------------- |
| InFmt_g      | string  | -          | Input signal format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| MixFmt_g     | string  | -          | Local oscillator format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,0,15)") |
| OutFmt_g     | string  | -          | Output format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)") |
| Round_g      | string  | "Trunc_s" | Rounding mode<br />String representation of an _en_cl_fix FixRound_t_. |
| Saturate_g   | string  | "Warn_s"  | Saturation mode<br />String representation of an _en_cl_fix FixSaturate_t_. |
| MultRegs_g   | natural | 1          | Number of pipeline stages for the multiplication             |
| IqHandling_g | string  | "Parallel" | I/Q handling mode: _"Parallel"_ or _"TDM"_                  |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_)              |

### Input Data

| Name      | In/Out | Length            | Default     | Description                                                  |
| :-------- | :----- | :---------------- | ----------- | :----------------------------------------------------------- |
| In_Valid | in     | 1                 | '1'         | AXI4-Stream handshaking signal for all inputs                |
| In_SigI  | in     | _width(InFmt_g)_ | (all zeros) | Signal in-phase component for _IqHandling_g="Parallel"_<br />Format: _InFmt_g_ |
| In_SigQ  | in     | _width(InFmt_g)_ | (all zeros) | Signal quadrature component for _IqHandling_g="Parallel"_<br />Format: _InFmt_g_ |
| In_MixI  | in     | _width(MixFmt_g)_| (all zeros) | Oscillator in-phase component for _IqHandling_g="Parallel"_<br />Format: _MixFmt_g_ |
| In_MixQ  | in     | _width(MixFmt_g)_| (all zeros) | Oscillator quadrature component for _IqHandling_g="Parallel"_<br />Format: _MixFmt_g_ |
| In_SigIQ | in     | _width(InFmt_g)_ | (all zeros) | Signal I then Q for _IqHandling_g="TDM"_<br />Format: _InFmt_g_ |
| In_MixIQ | in     | _width(MixFmt_g)_| (all zeros) | Oscillator I then Q for _IqHandling_g="TDM"_<br />Format: _MixFmt_g_ |
| In_Last  | in     | 1                 | '0'         | TDM re-sync: marks the last Q sample; the next sample is treated as I |

_In_Valid_ is the single handshaking signal for all inputs. Ready is not supported; the entity
accepts data every cycle _In_Valid_ is asserted.

### Output Data

| Name          | In/Out | Length             | Default | Description                                             |
| :------------ | :----- | :----------------- | ------- | :------------------------------------------------------ |
| Out_Valid    | out    | 1                  | -       | AXI4-Stream handshaking signal for _Out_SigReal_       |
| Out_SigReal  | out    | _width(OutFmt_g)_ | -       | Real output<br />Format: _OutFmt_g_                    |

In TDM mode, one output sample is produced per I/Q input pair, so the output rate is half the
input sample rate.

## Detail

### Parallel Architecture

The parallel architecture uses two multiply-accumulate operations whose structure matches the
I-path of [olo_fix_cplx_mult](./olo_fix_cplx_mult.md) in MULT4/Parallel/MIX mode.

![parallel architecture](./entities/olo_fix_mix_c2r_parallel.drawio.png)

**Latency** This architecture has a latency of _MultRegs_g_+ 3 + _resize_latency_ clock cycles.

Where _resize_latency_ is calculated as follows:

- +1 cycle if _Round_g_ is NOT "Trunc_s"
- +1 cycle if _Saturate_g_ is NOT "None_s"/"Warn_s"

### TDM Architecture

The TDM architecture time-shares a single multiplier between the I and Q products, following
the same pipeline as [olo_fix_cplx_mult](./olo_fix_cplx_mult.md) in TDM/MIX mode but
producing only the real output.

![TDM architecture](./entities/olo_fix_mix_c2r_tdm.drawio.png)

The _In_Last_ signal (sampled on the Q slot) resets the I/Q phase tracker so that the
immediately following sample is treated as I. This mirrors the resync behaviour of
_olo_fix_cplx_mult_.

**Latency** (TDM): _MultRegs_g_ + 3 clock cycles from the I input sample, plus one cycle each
for rounding and saturation when those registers are enabled.

The latency is defined as Q-sample input to real output.
