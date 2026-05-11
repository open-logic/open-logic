<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ecc_encode

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_ecc_encode](../../src/ft/vhdl/olo_ft_ecc_encode.vhd)

## Description

This entity provides a reusable, optionally pipelined SECDED encoder. It wraps the
[eccEncode](./olo_ft_pkg_ecc.md#eccencode) function from [olo_ft_pkg_ecc](./olo_ft_pkg_ecc.md) into a standalone
entity.

The entity also exposes a codeword-wide bit-flip injection input, useful for built-in self-test (BIST) and
simulation-time error injection. See
[Open Logic Fault-Tolerance Principles - Error Injection](./olo_ft_principles.md#error-injection) for the
codeword-flip semantics.

Use cases:

- Inside ECC-protected RAM/FIFO entities in the _ft_ area (instantiated by [olo_ft_ram_sp](./olo_ft_ram_sp.md)
  and friends to avoid duplicating the encoder body).
- Forward error correction (FEC) over a transmission link.
- AXI4-Stream traffic that is buffered in unprotected external memory (encode at the producer, decode at the
  consumer with [olo_ft_ecc_decode](./olo_ft_ecc_decode.md)).

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| Width_g    | positive | -       | Number of data bits per codeword                             |
| Pipeline_g | natural  | 0       | Number of register stages after the encode/inject combinational logic. 0 = combinational output. |

## Interfaces

| Name         | In/Out | Length                          | Default | Description                                                  |
| :----------- | :----- | :------------------------------ | ------- | :----------------------------------------------------------- |
| Clk          | in     | 1                               | '0'     | Clock. Only used when _Pipeline_g_ > 0.                      |
| In_Data      | in     | _Width_g_                       | -       | Data word to encode                                          |
| In_BitFlip   | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | all 0 | Codeword-flip injection. Each '1' bit XORs (flips) the corresponding bit of the encoded codeword before it is output. |
| Out_Codeword | out    | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | N/A | SECDED-encoded codeword (with any injection applied)         |
