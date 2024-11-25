<img src="../Logo.png" alt="Logo" width="400">

# olo_base_strobe_div

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_strobe_div.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_strobe_div.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_strobe_div.json?cacheSeconds=0)

VHDL Source: [olo_base_strobe_div](../../src/base/vhdl/olo_base_strobe_div.vhd)

## Description

This component takes single-cycle pulses as inputs and divides the pulse frequency.

The ratio can be configured at runtime or at compile-time. To use the compile-time variant, just leave the _In_Ratio_
port unconnected and assign the ratio to _MaxRatio_g_.

The latency can be selected to be 0 (combinatorial output) or 1 (registered output) clock cycle through the generic
_Latency_g_. Registered output (_Latency_g_=1) is preferred for timing optimization reasons.

Below figure shows an example for a ratio of 3.

![normal-operation](./misc/olo_base_strobe_divider.png)

The entity can also be used to convert single cycle pulses into pulses that stay active until acknowledged by
_Out_Ready_='1'. For this usage, simply use _MaxRatio_g=1_ and leave _In_Ratio_ unconnected.

![ready-conversion](./misc/olo_base_strobe_divider_readyconv.png)

Note that for runtime configurable ratio, _In_Ratio_ must be set to the **desired ratio minus one**. E.g. to forward
every third pulse to the output, _In_Ratio_ must be set to 2.

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| MaxRatio_g | positive | -       | Maximum ratio supported.<br />If _In_Ratio_ is left unconnected, exactly the ratio assigned to _MaxRatio_g_ is implemented. |
| Latency_g  | natural  | 1       | 0 = Combinatorial output, 1 = Registered output              |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Timing

| Name      | In/Out | Length                   | Default        | Description                                                  |
| :-------- | :----- | :----------------------- | -------------- | :----------------------------------------------------------- |
| In_Valid  | in     | 1                        | -              | Input pulse/strobe signal                                    |
| In_Ratio  | in     | _ceil(log2(MaxRatio_g))_ | _MaxRatio_g-1_ | Ratio selection.<br />Apply the desired ratio **minus one**. E.g. to forward every third pulse to the output, use _In_Ratio=2_. |
| Out_Valid | out    | 1                        | -              | Output pulse/strobe signal                                   |
| Out_Ready | in     | 1                        | '1'            | Optional handshaking signal                                  |

## Architecture

The architecture of the entity is simple, not detailed description is required.
