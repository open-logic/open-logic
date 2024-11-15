<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cc_simple

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cc_simple.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cc_simple.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cc_simple.json?cacheSeconds=0)

VHDL Source: [olo_base_cc_simple](../../src/base/vhdl/olo_base_cc_simple.vhd)

## Description

This component implements a clock crossing for transferring single values from one clock domain to another (completely
asynchronous clocks). In both clock domains the valid samples are marked with a Valid signal according to the AXI-S
specification but back-pressure (Ready) is not handled.

**For the entity to work correctly, the data-rate must be significantly lower ( (_3+SyncStages_g_ x lower) than the
slower clock frequency.**

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
| In_RstOut  | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _In_Clk_)) |
| In_Data    | in     | _Width_g_ | -       | Input data (synchronous to _In_Clk_)                         |
| In_Valid   | in     | 1         | -       | AXI4-Stream handshaking signal for _In_Data_                 |
| Out_Clk    | in     | 1         | -       | Destination clock                                            |
| Out_RstIn  | in     | 1         | '0'     | Reset input (high-active, synchronous to _Out_Clk_)          |
| Out_RstOut | out    | 1         | N/A     | Reset output (see [clock-crossing principles](clock_crossing_principles.md), synchronous to _Out_Clk_)) |
| Out_Data   | out    | _Width_g_ | N/A     | Output data (synchronous to _Out_Clk_)                       |
| Out_Valid  | out    | 1         | N/A     | AXI4-Stream handshaking signal for _Out_Data_                |

## Architecture

_In_Data_ is latched when _In_Valid_ is asserted. The valid signal is then clock-crossed using _olo_base_cc_pulse_. In
the output clock domain, the latched data signal is latched when the valid pulse is detected.

A specific clock crossing for the data signal is not required since it is guaranteed to be stable (latched) when the
valid pulse is detected in the output clock domain.

![architecture](./clock_crossings/olo_base_cc_simple.svg)

Regarding timing constraints, refer to [clock-crossing principles](clock_crossing_principles.md).
