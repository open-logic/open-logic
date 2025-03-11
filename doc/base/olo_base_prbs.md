<img src="../Logo.png" alt="Logo" width="400">

# olo_base_prbs

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_prbs.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_prbs.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_prbs.json?cacheSeconds=0)

VHDL Source: [olo_base_prbs](../../src/base/vhdl/olo_base_prbs.vhd)

## Description

This component generates a pseudorandom binary sequence based (PRBS) on a logic feed-back shift register (LFSR) method.
A set of common polynomials (aiming the maximum cycle possible) is available in
[olo_base_pkg_logic](./olo_base_pkg_logic.md) and can be passed to _olo_base_prbs_ through the generic _Polynomial_g_.

The number of bits per symbol which is presented at the output is configurable.

Polynomials are passed as _std_logic_vector_ where a one denotes every position where x^n is used: "100010000" means
"x⁹ +x⁵ + 1".

The initial state of the LFSR can be configured throuh _Seed_g_ at compile time or through _State_New_ at the moment
where _State_Set='1'_ is asserted at runtime. Note that the state of an LFSR never should be zero - otherwise the LFSR
will stay zero forever.

## Generics

| Name            | Type             | Default | Description                                                  |
| :-------------- | :--------------- | ------- | :----------------------------------------------------------- |
| Polynomial_g    | std_logic_vector | -       | Polynomial to use. <br />"100010000" means "x⁴+x⁸". |
| Seed_g          | std_logic_vector | -       | Initial state of the LFSR. Needs to be the same width as _Polynomial_g_. Must be non-zero vector. |
| BitsPerSymbol_g | positive         | 1       | Number of bits of the PRBS sequence to present at the output for every symbol (width of _Out_Data_). <br />Must be at least 1. |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Output Data

| Name      | In/Out | Length            | Default | Description                                                  |
| :-------- | :----- | :---------------- | ------- | :----------------------------------------------------------- |
| Out_Data  | out    | _BitsPerSymbol_g_ | -       | Output data                                                  |
| Out_Valid | out    | 1                 | -       | AXI4-Stream handshaking signal for _Out_Data_<br />Always one. The output is always valid. |
| Out_Ready | in     | 1                 | '1'     | AXI4-Stream handshaking signal for _Out_Data_<br />          |

### State

| Name          | In/Out | Length        | Default | Description                                                  |
| :------------ | :----- | :------------ | ------- | :----------------------------------------------------------- |
| State_Current | out    | _LfsrWidth_g_ | -       | Current state of the LFSR register                           |
| State_Set     | in     | 1             | '0'     | The LFSR content is set to _State_New_ when _State_Set='1'_ is asserted. |
| State_New     | in     | _LfsrWidth_g_ | 0       | LFSR state to set upon _State_Set='1'_.                      |

Note: If the state functionality is not needed, the corresponding signals can be left unconnected.

## Architecture

The PRBS generation is implemented using an LFSR register.

Below figures shows the implementation for a 4-bit LFSR with the polynomial _x⁴ + x³ + 1_ ("1100").

![PRBS](./misc/prbs.png)
