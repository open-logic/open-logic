<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cc_bits

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cc_bits.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cc_bits.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cc_bits.json?cacheSeconds=0)

VHDL Source: [olo_base_cc_bits](../../src/base/vhdl/olo_base_cc_bits.vhd)

## Description

This component implements a clock crossing for multiple independent single-bit signals. It contains double-stage
synchronizers and sets all the attributes required for proper synthesis.

Note that this clock crossing does not guarantee that all bits arrive in the same clock cycle at the destination clock
domain, therefore it can only be used for independent single-bit signals. Do not use it to transfer multi-bit signals
(e.g. numbers) where it is important that all the bits are updated in the same clock cycle.

This block follows the general [clock-crossing principles](clock_crossing_principles.md). Read through them for more
information.

## Generics

| Name         | Type     | Default | Description                                             |
| :----------- | :------- | ------- | :------------------------------------------------------ |
| Width_g      | positive | 1       | Number of data bits to implement the clock crossing for |
| SyncStages_g | positive | 2       | Number of synchronization stages. <br />Range: 2 ... 4  |

## Interfaces

| Name     | In/Out | Length    | Default | Description                                                  |
| :------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Clk   | in     | 1         | -       | Source clock                                                 |
| In_Rst   | in     | 1         | '0'     | Reset input (high-active, synchronous to _In_Clk_)           |
| In_Data  | in     | _Width_g_ | -       | Vector of independent input bits (synchronous to _In_Clk_)   |
| Out_Clk  | in     | 1         | -       | Destination clock                                            |
| Out_Rst  | in     | 1         | '0'     | Reset input (high-active, synchronous to _Out_Clk_)          |
| Out_Data | out    | _Width_g_ | N/A     | Vector of independent output bits (synchronous to _Out_Clk_) |

## Architecture

_In_Data_ is first synchronized to _In_Clk_. The synchronization register is included to cover cases where users connect
a combinatorial signal (from the _In_Clk_ domain) to _In_Data_. Although this is in-line with synchronous design
practices, without the input FF this would lead to a clock crossing containing combinatorial logic which is
problematic.

On the _Out_Clk_ domain, the signal is then synchronized using an ordinary ordinary N-stage synchronizer. In most cases,
the default value of two synchronization stages is fine. However, in special cases more stages might be required to
increase MTBF.

Below figures shows the implementation for _SyncStages_g=2_.

![architecture](./clock_crossings/olo_base_cc_bits.svg)

The VHDL code contains all synthesis attributes required to ensure correct behavior of tools (e.g. avoid mapping of the
synchronizer FFs into shift registers) for all supported tools.

Regarding timing constraints, refer to [clock-crossing principles](clock_crossing_principles.md).
