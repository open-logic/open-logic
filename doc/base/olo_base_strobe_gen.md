<img src="../Logo.png" alt="Logo" width="400">

# olo_base_strobe_gen

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_strobe_gen.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_strobe_gen.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_strobe_gen.json?cacheSeconds=0)

VHDL Source: [olo_base_strobe_gen](../../src/base/vhdl/olo_base_strobe_gen.vhd)

## Description

This component generates pulse at a fixed frequency. It optionally allows synchronization of those events to an input.

In the most simple use-case, single cycle pulses are generated free-running at a fixed frequency. To achieve this,
_Out_Ready_ and _In_Sync_ can be left unconnected. Bellow figure depicts this situation for _FreqClkHz_g=5e6_ and
_FreqStrobeHz_g=1e6_.

![simple-operation](./misc/olo_base_strobe_generator_simple.png)

Additionally the strobe phase can be synchronized to _In_Sync_. In this case, the event is synchronized to the rising
edge of the _In_Sync_ input.

![simple-operation](./misc/olo_base_strobe_generator_sync.png)

If the _Out_Ready_ signal is connected, _Out_Valid_ stays asserted until _Out_Ready_ and _Out_Valid_ are asserted at the
same time (AXI4-Stream hanshaking). Note that in this case, the rising edges of _Out_Valid_ occur at _FreqStrobeHz_g_
independently of how long the signal stays asserted.

![simple-operation](./misc/olo_base_strobe_generator_ready.png)

However, _Out_Ready_ and _In_Sync_ are optional signals and can be left unconnected in the standard-case where just a
pulse with a known frequency is required.

The strobe generator by default works in _aequidistant mode_: It produces _Out_Valid_ pulses that are always the same
number of clock-cycles apart from each other. This has the down-side of the output strobe period being off by up to half
a clock period - which finally leads to a slightly shifted frequency.

Alternatively the strobe generator can be used in _fractional mode_ (by setting _FractionalMode_g=true_). In this mode,
the strobe generator does vary the time between _Out_Valid_ pulses by one clock cycle to meet the _FreqStrobeHz_g_ with
less than 1% of error _on average_ (over a long time).

Use _fractional mode_ if _FreqStrobeHz_g_ is relatively close to _FreqClkHz_g_ and the exact strobe frequency is
important.

Use _aequidistant mode_ if a constant number of clock cycles between _Out_Valid_ pulses is required.

## Generics

| Name             | Type    | Default | Description                                        |
| :--------------- | :------ | ------- | :------------------------------------------------- |
| FreqClkHz_g      | real    | -       | Clock frequency in Hz                              |
| FreqStrobeHz_g   | real    | -       | Pulse frequency to generate in Hz                  |
| FractionalMode_g | boolean | false   | true: Fractional mode <br>false: Aequidistant mode |

**Note:** Fractional Mode is only supported for a factor of less than 1'000'000 between _FreqClkHz_g_ and
_FreqStrobeHz_g_.

**Note:** The maximum allowed ratio between _FreqClkHz_g_ and _FreqStrobeHz_g_ is 2'147'483'000.

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Timing

| Name      | In/Out | Length | Default | Description                 |
| :-------- | :----- | :----- | ------- | :-------------------------- |
| In_Sync   | in     | 1      | '0'     | Synchronization signal      |
| Out_Valid | out    | 1      | -       | Output pulse/strobe signal  |
| Out_Ready | in     | 1      | '1'     | Optional handshaking signal |

## Architecture

The architecture of the entity is simple, not detailed description is required.
