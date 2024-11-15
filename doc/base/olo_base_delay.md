<img src="../Logo.png" alt="Logo" width="400">

# olo_base_delay

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_delay.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_delay.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_delay.json?cacheSeconds=0)

VHDL Source: [olo_base_delay](../../src/base/vhdl/olo_base_delay.vhd)

## Description

This component is an efficient implementation for delay chains. It uses FPGA memory resources (Block-RAM and distributed
RAM resp. SRLs) for implementing the delays (instead of many FFs). The last delay stage is always implemented in FFs to
ensure good timing (RAM outputs are usually slow).

The delay is specified as a number of data-beats (samples). For a delay in clock-cycles, simply connect _In_Valid_='1' -
or lave _In_Valid_ unconnected to rely on its default value.

One Problem with using RAM resources to implement delays is that they don't have a reset, so the content of the RAM
persists after resetting the logic. The _olo_base_delay_ entity works around this issue by some logic that ensures that
any persisting data is replaced by zeros after a reset. The replacement is done at the output of the _olo_base_delay_,
so no time to overwrite memory cells after a reset is required and the entity is ready to operate on the first clock
cycle after the reset.

If the delay is implemented using a RAM, the behavior of the RAM (read-before-write or write-before-read) can be
selected to allow efficient implementation independently of the target technology.

Note that output data is valid together with Input data (when _In_Valid_ is high). Below figure shows the behavior for
_Delay_g_=3 with both possible settings for _RstState_g_:

![DataValidity](./misc/olo_base_delay.png)

In cases a delayed version of an AXI4-Stream with back-pressure (_Ready_ signal) is required, the ANDed _Ready_ and
_Valid_ signals shall be connected to the _In_Valid_ input of _olo_base_delay_.

![BackpressureCase](./misc/olo_base_delay_arch.svg)

![WaveBackpressuree](./misc/olo_base_delay_backpressure.png)

## Generics

| Name            | Type     | Default | Description                                                  |
| :-------------- | :------- | ------- | :----------------------------------------------------------- |
| Width_g         | positive | -       | Data width                                                   |
| Delay_g         | natural  | -       | Number of samples / data-beats of delay                      |
| Resource_g      | string   | "AUTO"  | The following values are possible:<br />- "BRAM": Always use BlockRAM  (only allowed for _Delay_g_ >= 3)<br />- "SRL": Always use shift registers<br />- "AUTO": Automatically select based on _Delay_g_ and _BramThreshold_g_ |
| BramThreshold_g | positive | 128     | In case of _Resource_g_="AUTO", BlockRAM is used when _Delay_g_ > _BramThreshold_g_ and shift registers are used otherwise.<br />Must be greater or equal to 3. |
| RstState_g      | boolean  | true    | true: 0 is outputted for the first _Delay_g_ data beats after reset<br />false: No special handling for reset, the content of the delay-line is output after reset. |
| RamBehavior_g   | string   | "RBW"   | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |

Note that BlockRAM as resource are only a valid choice for _Delay_g_ >= 3. For lower _Delay_g_ values, "SRL" or "AUTO"
must be chosen as resource.

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Data

| Name     | In/Out | Length    | Default | Description                                  |
| :------- | :----- | :-------- | ------- | :------------------------------------------- |
| In_Data  | in     | _Width_g_ | -       | Input data                                   |
| In_Valid | in     | 1         | '1'     | AXI4-Stream handshaking signal for _In_Data_ |

### Output Data

| Name     | In/Out | Length    | Default | Description                                    |
| :------- | :----- | :-------- | ------- | :--------------------------------------------- |
| Out_Data | out    | _Width_g_ | N/A     | Output data (valid as indicated by _In_Valid_) |

## Architecture

The architecture of the entity is simple, not detailed description is required.
