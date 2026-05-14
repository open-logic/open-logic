<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ecc_encode

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_ft_ecc_encode.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_ft_ecc_encode.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_ft_ecc_encode.json?cacheSeconds=0)

VHDL Source: [olo_ft_ecc_encode](../../src/ft/vhdl/olo_ft_ecc_encode.vhd)

## Description

This entity provides a reusable, optionally pipelined SECDED encoder. It wraps the
[eccEncode](./olo_ft_pkg_ecc.md#eccencode) function from [olo_ft_pkg_ecc](./olo_ft_pkg_ecc.md) into a standalone
entity exposing an AXI4-Stream forward handshake (_In\_Valid_ / _In\_Ready_, _Out\_Valid_ / _Out\_Ready_).

A codeword-wide error-injection side channel is also provided. The injection pattern is latched on
_ErrInj\_Valid_ and applied to the next accepted data beat. If _ErrInj\_Valid_ is asserted in the
same cycle as a completed handshake, the pattern is applied directly without going through the latch.
See
[Open Logic Fault-Tolerance Principles - Error Injection](./olo_ft_principles.md#error-injection) for the
latched-injection semantics shared across the _ft_ area.

Use cases:

- Inside ECC-protected RAM/FIFO entities in the _ft_ area (instantiated by [olo_ft_ram_sp](./olo_ft_ram_sp.md)
  and friends to avoid duplicating the encoder body).
- Forward error correction (FEC) over a transmission link.
- AXI4-Stream traffic that is buffered in unprotected external memory (encode at the producer, decode at the
  consumer with [olo_ft_ecc_decode](./olo_ft_ecc_decode.md)).

### Pipeline structure

The `Pipeline_g` generic inserts register stages on the encode datapath. The range is **0..1**.

| `Pipeline_g` | Structure |
| :---: | --- |
| 0 | Combinational `eccEncode` + injection XOR (no register). _Out\_Codeword_ tracks _In\_Data_ within the same cycle as a completed handshake. |
| 1 | Combinational `eccEncode` + injection XOR feeds a single register at the output. Breaks the combinational path from upstream logic to whatever consumes _Out\_Codeword_. |

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| Width_g    | positive | -       | Number of uncoded data bits                                  |
| Pipeline_g | natural  | 0       | Number of register stages (range _0..1_). 0 = combinational output, 1 = register near output. |
| UseReady_g | boolean  | true    | If _true_, _In\_Ready_ honours back-pressure from _Out\_Ready_ (shadow-register pipeline). If _false_, _In\_Ready_ is hard-wired to '1' and the pipeline is a plain register chain. |

## Interfaces

### Clock and Reset

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset (high-active, synchronous to _Clk_). Clears the injection latch and the pipeline valid register(s). |

### Input

| Name     | In/Out | Length    | Default | Description |
| :------- | :----- | :-------- | ------- | :--- |
| In_Valid | in     | 1         | '1'     | AXI4-Stream handshaking signal for _In\_Data_ |
| In_Ready | out    | 1         | N/A     | AXI4-Stream handshaking signal for _In\_Data_ |
| In_Data  | in     | _Width_g_ | -       | Data word to encode |

### Output

| Name         | In/Out | Length                                                              | Default | Description |
| :----------- | :----- | :------------------------------------------------------------------ | ------- | :--- |
| Out_Valid    | out    | 1                                                                   | N/A     | AXI4-Stream handshaking signal for _Out\_Codeword_ |
| Out_Ready    | in     | 1                                                                   | '1'     | AXI4-Stream handshaking signal for _Out\_Codeword_ |
| Out_Codeword | out    | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | N/A     | SECDED-encoded codeword (with any injection applied) |

### Error Injection

| Name            | In/Out | Length                                                              | Default | Description |
| :-------------- | :----- | :------------------------------------------------------------------ | ------- | :--- |
| ErrInj_BitFlip  | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | all 0   | Codeword-wide bit-flip pattern. XORed into the encoded codeword before it leaves the entity. |
| ErrInj_Valid    | in     | 1                                                                   | '0'     | Strobe that latches _ErrInj\_BitFlip_. The latched pattern is applied to the next accepted data beat, then cleared. |
