<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ecc_decode

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_ft_ecc_decode.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_ft_ecc_decode.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_ft_ecc_decode.json?cacheSeconds=0)

VHDL Source: [olo_ft_ecc_decode](../../src/ft/vhdl/olo_ft_ecc_decode.vhd)

## Description

This entity provides a reusable, optionally pipelined SECDED decoder. It wraps the package functions
[eccSyndromeAndParity](./olo_ft_pkg_ecc.md#eccsyndromeandparity),
[eccCorrectData](./olo_ft_pkg_ecc.md#ecccorrectdata),
[eccSecError](./olo_ft_pkg_ecc.md#eccsecerror) and [eccDedError](./olo_ft_pkg_ecc.md#eccdederror) into a single
standalone entity exposing an AXI4-Stream handshake (_In\_Valid_ / _In\_Ready_, _Out\_Valid_ / _Out\_Ready_).
Single-bit errors (SEC) are corrected before _Out\_Data_ is driven. Double-bit errors (DED) are detected via
_Out\_EccDed_ but cannot be corrected. _Out\_Data_, _Out\_EccSec_ and _Out\_EccDed_ are time-aligned.

A codeword-wide error-injection side channel is also provided. The injection pattern is latched on
_ErrInj\_Valid_ and XORed into the codeword on the next accepted beat (simulating an in-transit
corruption — useful for FEC scenarios). See
[Open Logic Fault-Tolerance Principles - Error Injection](./olo_ft_principles.md#error-injection) for the
latched-injection semantics shared across the _ft_ area.

### Pipeline structure

The `Pipeline_g` generic inserts register stages on the decode datapath. The range is **0..2** and
the pipeline is explicitly distributed across the SECDED stages rather than relying on
register-retiming:

| `Pipeline_g` | Structure |
| :---: | --- |
| 0 | Combinational decode (no register).                                                                              |
| 1 | Combinational syndrome + correction + SEC/DED → register near the output. Breaks the path from the decoder to downstream logic. |
| 2 | Combinational syndrome → register `{InjectedCw, SynPar}` → combinational correction + SEC/DED → register `{Out_Data, Out_EccSec, Out_EccDed}`. Breaks both the syndrome path and the correction path - use this when both halves of the SECDED logic need their own clock cycle to close timing. |

For background on the SECDED scheme and codeword layout, see
[Open Logic Fault-Tolerance Principles](./olo_ft_principles.md).

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| Width_g    | positive | -       | Number of uncoded data bits                                  |
| Pipeline_g | natural  | 0       | Number of register stages (range _0..2_). See _Pipeline structure_ above. |
| UseReady_g | boolean  | true    | If _true_, _In\_Ready_ honours back-pressure from _Out\_Ready_ (shadow-register pipeline). If _false_, _In\_Ready_ is hard-wired to '1' and the pipeline is a plain register chain. |

## Interfaces

### Clock and Reset

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset (high-active, synchronous to _Clk_). Clears the injection latch and the pipeline valid register(s). |

### Input

| Name        | In/Out | Length                                                              | Default | Description |
| :---------- | :----- | :------------------------------------------------------------------ | ------- | :--- |
| In_Valid    | in     | 1                                                                   | '1'     | AXI4-Stream handshaking signal for _In\_Codeword_ |
| In_Ready    | out    | 1                                                                   | N/A     | AXI4-Stream handshaking signal for _In\_Codeword_ |
| In_Codeword | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | -       | SECDED codeword to decode |

### Output

| Name        | In/Out | Length    | Default | Description                                                  |
| :---------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Out_Valid   | out    | 1         | N/A     | AXI4-Stream handshaking signal for _Out\_Data_ / _Out\_EccSec_ / _Out\_EccDed_ |
| Out_Ready   | in     | 1         | '1'     | AXI4-Stream handshaking signal for _Out\_Data_ / _Out\_EccSec_ / _Out\_EccDed_ |
| Out_Data    | out    | _Width_g_ | N/A     | Decoded data word (corrected if a single-bit error was detected) |
| Out_EccSec  | out    | 1         | N/A     | Single error corrected flag                                  |
| Out_EccDed  | out    | 1         | N/A     | Double error detected flag (data unreliable in this case)    |

### Error Injection

| Name            | In/Out | Length                                                              | Default | Description |
| :-------------- | :----- | :------------------------------------------------------------------ | ------- | :--- |
| ErrInj_BitFlip  | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | all 0   | Codeword-wide bit-flip pattern. XORed into _In\_Codeword_ before the syndrome calculation. |
| ErrInj_Valid    | in     | 1                                                                   | '0'     | Strobe that latches _ErrInj\_BitFlip_. The latched pattern is applied to the next accepted data beat, then cleared. |
