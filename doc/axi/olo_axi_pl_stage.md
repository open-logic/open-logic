<img src="../Logo.png" alt="Logo" width="400">

# olo_axi_pl_stage

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_axi_pl_stage.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_axi_pl_stage.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_axi_pl_stage.json?cacheSeconds=0)

VHDL Source: [olo_axi_pl_stage](../../src/axi/vhdl/olo_axi_pl_stage.vhd)

## Description

This component implements a pipeline stage for AXI4 interfaces. The component registers all signals of the interface.

Note that the component can be used for AXI4-Lite by simply leaving all unused signals unconnected.

## Generics

| Name        | Type     | Default | Description                                                  |
| :---------- | :------- | ------- | :----------------------------------------------------------- |
| Stages_g    | positive | 1       | Number of register stages to insert                          |
| AddrWidth_g | positive | 32      | With of the *AwAddr* and *ArAddr* signals in bits.           |
| DataWidth_g | positive | 32      | Width of the *WData* and *RData* signals in bits             |
| IdWidth_g   | natural  | 0       | Width of the signals *AwId*, *ArId*, *BId* and *RId* signals in bits. |
| UserWidth_g | natural  | 0       | Width of the siginals *AwUser*, *ArUser*, *WUser*, *BUser* and *RUser* in bits. |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### AXI Interfaces

| Name  | In/Out | Length | Default | Description                                                  |
| :---- | :----- | :----- | ------- | :----------------------------------------------------------- |
| S_... | *      | *      | *       | AXI4 slave interface. For the exact meaning of the signals, refer to the AXI protocol specification. |
| M_... | *      | *      | *       | AXI4 master interface. For the exact meaning of the signals, refer to the AXI protocol specification. |

Transaction requests are forwarded from the slave interface to the master interfaces. Responses are forwarded from the master interface to the slave interface.

## Architecture

The entity is based on the [olo_base_pl_stage](../base/olo_base_pl_stage.md) entity. One such entity is used for every one of the 5 channels AXI4 has.
