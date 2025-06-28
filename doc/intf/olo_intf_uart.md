<img src="../Logo.png" alt="Logo" width="400">

# olo_intf_uart

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_intf_uart.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_intf_uart.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_intf_uart.json?cacheSeconds=0)

VHDL Source: [olo_intf_uart](../../src/intf/vhdl/olo_intf_uart.vhd)

## Description

### Overview

This entity implements an UART. It is designed to run high baud-rates (up to 10% of the clock frequency).

Parity checking for RX and parity calculation for TX is done internally in _olo_intf_uart_.

The _Uart_Rx_ line is synchronized internally inside _olo_intf_uart_.

The UART protocol is commonly known and hence not described here. A good and concise description of the protocol can be
found [here](https://ece353.engr.wisc.edu/serial-interfaces/uart-basics/).

## Generics

| Name       | Type     | Default | Description                                                  |
| :--------- | :------- | ------- | :----------------------------------------------------------- |
| ClkFreq_g  | real     | -       | Clock Frequency in Hz                                        |
| BaudRate_g | real     | 115.2e3 | Baud rate                                                    |
| DataBits_g | positive | 8       | Number of data bits<br />Range: 7 ... 9                      |
| StopBits_g | string   | "1"     | Number of stop bits. Allowed values: "1", "1.5", "2"         |
| Parity_g   | string   | "none"  | Parity setting:<br />"none" : No parity bit<br />"even" : parity bit = 0 when there is an even number of ones in data<br />"odd" : parity but = 0 when there is an odd number of ones in data |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock - Frequency must be at least **10x higher than _BaudRate_g_** |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_)              |

### RX Data Interface

Interface for data received over UART. There is no _Ready_ signal - hence the consumer must be able to accept data
immediately.

| Name           | In/Out | Length       | Default | Description                                                  |
| :------------- | :----- | :----------- | ------- | :----------------------------------------------------------- |
| Rx_Valid       | out    | 1            | N/A     | AXI-S handshaking signal for _Rx_Data_                       |
| Rx_Data        | out    | _DataBits_g_ | N/A     | Data received over UART                                      |
| Rx_ParityError | out    | 1            | N/A     | Asserted if the parity bit does not match the expected value according to the data received (hence there was a bit error). |

### TX Data Interface

Interface for data to be sent over UART.

| Name     | In/Out | Length       | Default | Description                            |
| :------- | :----- | :----------- | ------- | :------------------------------------- |
| Tx_Valid | in     | 1            | '0'     | AXI-S handshaking signal for _Tx_Data_ |
| Tx_Ready | out    | 1            | N/A     | AXI-S handshaking signal for _Tx_Data_ |
| Tx_Data  | in     | _DataBits_g_ | 0       | Data to be sent over UART              |

### UART Interface

| Name    | In/Out | Length | Default | Description          |
| :------ | :----- | :----- | ------- | :------------------- |
| Uart_Tx | out    | 1      | N/A     | UART transmit signal |
| Uart_Rx | in     | 1      | '0'     | UART receive signal  |

## Detailed Description

No detailed description is given. The UART is very simple.
