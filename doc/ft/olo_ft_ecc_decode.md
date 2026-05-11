<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ecc_decode

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_ecc_decode](../../src/ft/vhdl/olo_ft_ecc_decode.vhd)

## Description

This entity provides a reusable, optionally pipelined SECDED decoder. It wraps the package functions
[eccSyndromeAndParity](./olo_ft_pkg_ecc.md#eccsyndromeandparity),
[eccCorrectData](./olo_ft_pkg_ecc.md#ecccorrectdata),
[eccSecError](./olo_ft_pkg_ecc.md#eccsecerror) and [eccDedError](./olo_ft_pkg_ecc.md#eccdederror) into a single
standalone entity. Single-bit errors (SEC) are corrected before _Out_Data_ is driven. Double-bit errors (DED) are detected via
_Out_EccDed_ but cannot be corrected. _Out_Data_, _Out_EccSec_ and _Out_EccDed_ are time-aligned.

For background on the SECDED scheme and codeword layout, see
[Open Logic Fault-Tolerance Principles](./olo_ft_principles.md).

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| Width_g    | positive | -       | Number of data bits per codeword                             |
| Pipeline_g | natural  | 0       | Number of register stages after the decode combinational logic. 0 = combinational output. |

## Interfaces

| Name        | In/Out | Length                          | Default | Description                                                  |
| :---------- | :----- | :------------------------------ | ------- | :----------------------------------------------------------- |
| Clk         | in     | 1                               | '0'     | Clock. Only used when _Pipeline_g_ > 0.                      |
| In_Codeword | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | - | SECDED codeword to decode                                    |
| Out_Data    | out    | _Width_g_                       | N/A     | Decoded data word (corrected if a single-bit error was detected) |
| Out_EccSec  | out    | 1                               | N/A     | Single error corrected flag                                  |
| Out_EccDed  | out    | 1                               | N/A     | Double error detected flag (data unreliable in this case)    |
