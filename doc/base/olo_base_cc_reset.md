<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cc_reset

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cc_reset.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cc_reset.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cc_reset.json?cacheSeconds=0)

VHDL Source: [olo_base_cc_reset](../../src/base/vhdl/olo_base_cc_reset.vhd)

## Description

This component synchronizes reset inputs from two clock domains in both directions. Whenever a reset is received on
one clock domain, it produces reset outputs on both clock domains and ensures that both reset outputs are asserted at
the same time for at least one clock cycle before they are released again.

This type of reset synchronization is required in many clock crossings. Usually both sides of the clock crossing must
be reset at the same time to avoid unwanted behavior in corner conditions around resets.

When using the block, you should connect any reset request signals to _A/B_RstIn_ and reset your logic with the outputs
_A/B_RstOut_.

This block follows the general [clock-crossing principles](clock_crossing_principles.md). Read through them for more
information.

## Generics

| Name         | Type     | Default | Description                                            |
| :----------- | :------- | ------- | :----------------------------------------------------- |
| SyncStages_g | positive | 2       | Number of synchronization stages. <br />Range: 2 ... 4 |

## Interfaces

| Name     | In/Out | Length | Default | Description                                        |
| :------- | :----- | :----- | :------ | :------------------------------------------------- |
| A_Clk    | in     | 1      | -       | Clock domain A clock                               |
| A_RstIn  | in     | 1      | '0'     | Reset input (high-active, synchronous to _A_Clk_)  |
| A_RstOut | out    | 1      | N/A     | Reset output (high-active, synchronous to _A_Clk_) |
| B_Clk    | in     | 1      | -       | Clock domain B clock                               |
| B_RstIn  | in     | 1      | '0'     | Reset input (high-active, synchronous to _B_Clk_)  |
| B_RstOut | out    | 1      | N/A     | Reset output (high-active, synchronous to _B_Clk_) |

## Architecture

The exact same functionality is built in both directions.

Below figures assume _SyncStages_g=2_.

![architecture](./clock_crossings/olo_base_cc_reset.svg)

The concept is explained based on a reset arriving on _A_RstIn_ (see waveform below)

- When the reset is asserted, _RstALatch_ is set.
- Setting _RstALatch_ leads to _A_RstOut_ being asserted (i.e. the logic on _A_Clk_ is held in reset)
- _RstALatch_ causes _RstRqstA2B_ to be asserted (asynchronous set). The FF-chain acts as reset synchronizer
  (asynchronous assert, synchronous de-assert).
- Setting _RstRqstA2B_ leads to _B_RstOut_ being asserted (i.e. the logic on _B_Clk_ is held in reset).
- The detection of the reset on clock-domain A is confirmed by synchronizing _RstRqstA2B_ back to the _A_Clk_ domain
  (_RstAckB2A_).
- One _RstAckB2A_ is set, _RstALatch_ is de-asserted.
- The de-assertion of _RstALatch_ causes _A_RstOut_ to be de-asserted and a few clock cycles later _B_RstOut_ being
  de-asserted.

As a result it is guaranteed that during at least one clock cycle both resets are asserted at the same time.

![wave](./clock_crossings/reset_cc_detail.png)

The VHDL code contains all synthesis attributes required to ensure correct behavior of tools (e.g. avoid mapping of the
synchronizer FFs into shift registers) for all supported tools/vendors.

Regarding timing constraints, refer to [clock-crossing principles](clock_crossing_principles.md).
