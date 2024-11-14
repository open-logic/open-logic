<img src="../Logo.png" alt="Logo" width="400">

# olo_intf_debounce

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_intf_debounce.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_intf_debounce.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_intf_debounce.json?cacheSeconds=0)

VHDL Source: [olo_intf_debounce](../../src/intf/vhdl/olo_intf_debounce.vhd)

## Description

This component synchronizes external signals and debounces them. The debouncing is implemented efficiently with a
prescaler divider shared between all signals in order to keep resource usage as low as possible.

The entity has two modes of operation.

- In _LOW_LATENCY_ mode, an incoming edge is forwarded immediately (less than 5 clock cycles of delay). After the edge
  is forwarded to the output, the next edge can be detected only after the signal was stable for _DebounceTime_g_.
  - This mode of operation implies that single cycle input pulses are stretched to a pulse-width of _DebounceTime_g_.
- In _GLITCH_FILTER_ mode, any signal change is only forwarded to the output after the signal was stable for
  _DebounceTime_g_ on the new level.
  - This mode of operation implies that single cycle input pulses are suppressed.

Below figure provides an example waveform for both modes of operation.

![wave](./misc/olo_intf_debounce.png)

## Generics

| Name           | Type      | Default       | Description                                                  |
| :------------- | :-------- | ------------- | :----------------------------------------------------------- |
| ClkFrequency_g | real      | -             | Frequency of the _Clk_ clock in Hz.                          |
| DebounceTime_g | real      | 20.0e-3       | Time during which the signals may bounce in seconds.<br />Must be at least 10 _Clk_ periods. |
| Width_g        | positive  | 1             | Number of signals to debounce                                |
| IdleLevel_g    | std_logic | '0'           | Logic level the signal is in idle-state (e.g. button not pressed). <br />This affects the behavior of _DataOut_ immediately after reset (all outputs are set to _IdleLevel_g_ upon reset) |
| Mode_g         | string    | "LOW_LATENCY" | Mode of operation. See [Description](#description) for details. <br />Valid values are _LOW_LATENCY_ and _GLITCH_FILTER_. |

## Interfaces

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Clk       | in     | 1         | -       | Clock                                                        |
| Rst       | in     | 1         | '0'     | Reset input (high-active, synchronous to _Clk_)<br />For synchronizers the reset is normally not required. |
| DataAsync | in     | _Width_g_ | -       | Vector of independent input bits (asynchronous external input). |
| DataSync  | out    | _Width_g_ | N/A     | Vector of synchronized and debounced output bits (synchronous to _Clk_) |

## Architecture

Below figure shows the architecture of the entity for a _Width_g=2_ setup.

![Architecture](./misc/olo_intf_debounce_arch.svg)

The _olo_base_strobe_gen_ serves as prescaler. It produces a _Tick_ signal with a target period of 1/31 of
_DebounceTime_g_. Due to rounding the actual period may vary (especially for very short _DebounceTime_g_ values of only
a few clock cycles). The prescaler is shared for all signals to reduce the resource consumption for the normal case
where _DebounceTime_g_ is very long compared to _ClkFrequency_g_.

The inputs are synchronized using _olo_intf_sync_ and one _Debounce Timer_ per signal counts how many ticks the signal
was stable and does the debouncing based on this counter. The number of _Ticks_ the signal must stay stable (equal to
_DebounceTime_g_) depends on the exact rounding of the _Tick_ frequency - the compensation for the rounding is handled
internally by _olo_intf_debounce_.
