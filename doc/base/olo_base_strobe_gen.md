<img src="../Logo.png" alt="Logo" width="400">

# olo_base_strobe_gen

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_strobe_gen.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_strobe_gen.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_strobe_gen.json?cacheSeconds=0)

VHDL Source: [olo_base_strobe_gen](../../src/base/vhdl/olo_base_strobe_gen.vhd)

## Description

This component generates pulse at a fixed frequency. It optionally allows synchronization of those events to an input.

In the most simple use-case, single cycle pulses are generated free-running at a fixed frequency. To achieve this, *Out_Ready* and *In_Sync* can be left unconnected. Bellow figure depicts this situation for *FreqClkHz_g=5e6* and *FreqStrobeHz_g=1e6*.

![simple-operation](./misc/olo_base_strobe_generator_simple.png)

Additionally the strobe phase can be synchronized to *In_Sync*. In this case, the event is synchronized to the rising edge of the *In_Sync* input.

![simple-operation](./misc/olo_base_strobe_generator_sync.png)

If the *Out_Ready* signal is connected, *Out_Valid* stays asserted until *Out_Ready* and *Out_Valid* are asserted at the same time (AXI4-Stream hanshaking). Note that in this case, the rising edges of *Out_Valid* occur at *FreqStrobeHz_g* independently of how long the signal stays asserted.

![simple-operation](./misc/olo_base_strobe_generator_ready.png)

However, *Out_Ready* and *In_Sync* are optional signals and can be left unconnected in the standard-case where just a pulse with a known frequency is required.

The strobe generator by default works in *aequidistant mode*: It produces *Out_Valid* pulses that are always the same number of clock-cycles apart from each other. This has the down-side of the output strobe period being off by up to half a clock period - which finally leads to a slightly shifted frequency.

Alternatively the strobe generator can be used in *fractional mode* (by setting *FractionalMode_g=true*). In this mode, the strobe generator does vary the time between *Out_Valid* pulses by one clock cycle to meet the *FreqStrobeHz_g* with less than 1% of error *on average* (over a long time).

Use *fractional mode* if *FreqStrobeHz_g* is relatively close to *FreqClkHz_g* and the exact strobe frequency is important.

Use *aequidistant mode* if a constant number of clock cycles between *Out_Valid* pulses is required. 

## Generics

| Name             | Type    | Default | Description                                        |
| :--------------- | :------ | ------- | :------------------------------------------------- |
| FreqClkHz_g      | real    | -       | Clock frequency in Hz                              |
| FreqStrobeHz_g   | real    | -       | Pulse frequency to generate in Hz                  |
| FractionalMode_g | boolean | false   | true: Fractional mode <br>false: Aequidistant mode |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### Timing

| Name      | In/Out | Length | Default | Description                 |
| :-------- | :----- | :----- | ------- | :-------------------------- |
| In_Sync   | in     | 1      | '0'     | Synchronization signal      |
| Out_Valid | out    | 1      | -       | Output pulse/strobe signal  |
| Out_Ready | in     | 1      | '1'     | Optional handshaking signal |

## Architecture

The architecture of the entity is simple, not detailed description is required.

