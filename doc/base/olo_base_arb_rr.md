<img src="../Logo.png" alt="Logo" width="400">

# olo_base_arb_rr

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_arb_rr.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_arb_rr.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_arb_rr.json?cacheSeconds=0)

VHDL Source: [olo_base_arb_rr](../../src/base/vhdl/olo_base_arb_rr.vhd)

## Description

This entity implements a round-robin arbiter. If multiple bits are asserted in the *In_Req* vector, the left-most bit is forwarded to the grant vector first. Next, the second left-most bit that is set is forwarded etc. Whenever at least one bit in the *Out_Grant* vector is asserted, the *Out_Valid* handshaking signal is asserted to signal that a request was granted. The consumer of the *Out_Grant* vector signalizes that the granted access was executed by pulling *Out\_Ready* high.

Note that the round-robin arbiter is implemented without an output register. Therefore combinatorial paths between input and output exist and it is recommended to add a register-stage to the output as early as possible.

![Waveform](./arb/olo_base_arb_rr_example.png)

Especially interesting is the part in orange. At this point the arbiter does not grant access to bit 3 because it already granted this request in the clock cycle before. However, it continues to grant access to the highest-priority (i.e. left-most) bit of the request vector that is still left of the bit set in the last *Out_Grant* output. If the *In_Req* vector asserts a higher priority this change is directly forwarded to the output. This is shown in the orange section of the waveform.

## Generics

| Name    | Type     | Default | Description                                                  |
| :------ | :------- | ------- | :----------------------------------------------------------- |
| Width_g | positive | -       | Number of requesters (number of bits in *In_Req* and *Out_Grant* vectors) |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### Input Data

| Name   | In/Out | Length    | Default | Description                                                  |
| :----- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Req | in     | *Width_g* | -       | Request vector. The highest (left-most) bit has highest priority. |

### Output Data

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Out_Grant | out    | *Width_g* | N/A     | Grant output signal                                          |
| Out_Ready | out    | 1         | N/A     | AXI-S handshaking signal, Asserted whenever Grant != 0       |
| Out_Valid | out    | 1         | N/A     | AXI-S handshaking signal The state of the  arbiter is updated  upon *Out\_Ready =   '1'* |

Note that the output is not fully AXI4-Stream compliant because the *Out_Grant* vector can change its value while *Out_Valid* is asserted (as shown in the example waveform further up). Still the naming of the signals was kept because it seems relatively natural to the arbiter behavior.

## Architecture

Not described in detail. Refer to the code for details.
