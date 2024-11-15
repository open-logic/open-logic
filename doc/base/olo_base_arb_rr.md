<img src="../Logo.png" alt="Logo" width="400">

# olo_base_arb_rr

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_arb_rr.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_arb_rr.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_arb_rr.json?cacheSeconds=0)

VHDL Source: [olo_base_arb_rr](../../src/base/vhdl/olo_base_arb_rr.vhd)

## Description

This entity implements a round-robin arbiter. If multiple bits are asserted in the _In_Req_ vector, the left-most bit is
forwarded to the grant vector first. Next, the second left-most bit that is set is forwarded etc. Whenever at least one
bit in the _Out_Grant_ vector is asserted, the _Out_Valid_ handshaking signal is asserted to signal that a request was
granted. The consumer of the _Out_Grant_ vector signalizes that the granted access was executed by pulling _Out\_Ready_
high.

Note that the round-robin arbiter is implemented without an output register. Therefore combinatorial paths between input
and output exist and it is recommended to add a register-stage to the output as early as possible.

![Waveform](./arb/olo_base_arb_rr_example.png)

Especially interesting is the part in orange. At this point the arbiter does not grant access to bit 3 because it
already granted this request in the clock cycle before. However, it continues to grant access to the highest-priority
(i.e. left-most) bit of the request vector that is still left of the bit set in the last _Out_Grant_ output. If the
_In_Req_ vector asserts a higher priority this change is directly forwarded to the output. This is shown in the orange
section of the waveform.

## Generics

| Name    | Type     | Default | Description                                                  |
| :------ | :------- | ------- | :----------------------------------------------------------- |
| Width_g | positive | -       | Number of requesters (number of bits in _In_Req_ and _Out_Grant_ vectors) |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Data

| Name   | In/Out | Length    | Default | Description                                                  |
| :----- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| In_Req | in     | _Width_g_ | -       | Request vector. The highest (left-most) bit has highest priority. |

### Output Data

| Name      | In/Out | Length    | Default | Description                                                  |
| :-------- | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Out_Grant | out    | _Width_g_ | N/A     | Grant output signal                                          |
| Out_Ready | out    | 1         | N/A     | AXI-S handshaking signal, Asserted whenever Grant != 0       |
| Out_Valid | out    | 1         | N/A     | AXI-S handshaking signal The state of the  arbiter is updated  upon _Out\_Ready = '1'_ |

Note that the output is not fully AXI4-Stream compliant because the _Out_Grant_ vector can change its value while
_Out_Valid_ is asserted (as shown in the example waveform further up). Still the naming of the signals was kept because
it seems relatively natural to the arbiter behavior.

## Architecture

Not described in detail. Refer to the code for details.
