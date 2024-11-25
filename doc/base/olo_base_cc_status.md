<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cc_status

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cc_status.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cc_status.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cc_status.json?cacheSeconds=0)

VHDL Source: [olo_base_cc_status](../../src/base/vhdl/olo_base_cc_status.vhd)

## Description

This component implements a clock crossing for slowly changing status information that does not have exact sample rates.
It can for example be used to  transfer a buffer fill level from one clock domain to another with minimal effort and
without knowing anything about the frequencies of the two clocks (e.g. without knowing which one runs faster).

The entity ensures that data from the source clock domain is correctly transferred to the destination clock domain.
The value at the destination clock domain is always correct in terms of "the exact same value was present on the input
clock domain in one clock-cycle". The exact timing of the sampling points at which the data is transferred is generated
by the entity itself, so it is unknown to the user. As a result, the entity does not guarantee to show transient states
of the data signal in the source clock domain to the destination clock domain in cases of fast changing signals.

For the entity to work correctly, the data-rate must be significantly lower (_6 + 2 * SyncStages_g_ x lower) than the
slower clock frequency. Of course the signal can change more quickly but the clock crossing will skip some values in
this case.

This block follows the general [clock-crossing principles](clock_crossing_principles.md). Read through them for more
information.

## Generics

| Name         | Type     | Default | Description                                            |
| :----------- | :------- | ------- | :----------------------------------------------------- |
| Width_g      | positive | 1       | Width of the data-signal to clock-cross                |
| SyncStages_g | positive | 2       | Number of synchronization stages. <br />Range: 2 ... 4 |

## Interfaces

| Name       | In/Out | Length    | Default | Description                                                  |
| :--------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Clk     | in     | 1         | -       | Source clock                                                 |
| In_RstIn   | in     | 1         | '0'     | Reset input (high-active, synchronous to _In_Clk_)           |
| In_RstOut  | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _In_Clk_) |
| In_Data    | in     | _Width_g_ | -       | Input data (synchronous to _In_Clk_)                         |
| Out_Clk    | in     | 1         | -       | Destination clock                                            |
| Out_RstIn  | in     | 1         | '0'     | Reset input (high-active, synchronous to _Out_Clk_)          |
| Out_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _Out_Clk_) |
| Out_Data   | out    | _Width_g_ | N/A     | Output data (synchronous to _Out_Clk_)                       |

## Architecture

The architecture of of _olo_base_cc_status_ is based on the idea of passing around a valid pulse between the two
clock-domains continuously. Data is transferred from _In_Clk_ to _Out_Clk_ together with the pulse.

This architecture is built based on _olo_base_cc_simple_ and _olo_base_cc_pulse_.

![architecture](./clock_crossings/olo_base_cc_status.svg)

Regarding timing constraints, refer to [clock-crossing principles](clock_crossing_principles.md).
