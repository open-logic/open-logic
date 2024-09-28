<img src="../Logo.png" alt="Logo" width="400">

# olo_base_fifo_packet

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_fifo_packet.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_fifo_packet.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_fifo_packet.json?cacheSeconds=0)

VHDL Source: [olo_base_fifo_packet](../../src/base/vhdl/olo_base_fifo_packet.vhd)

## Description

This component implements a synchronous packet FIFO. The FIFO works in store and forward mode. This means a packet is only presented to the output after it is written into the FIFO completely.

This component offers the following additional features compared to [olo_base_fifo_sync](./olo_base_fifo_sync.md):

* Due to the store and forward implementation, packets are compressed. Even if the data is written into the FIFO at low rate, it is guaranteed that the packet can be read in a single short burst once it is presented at the output.
* Writing of a packet into a FIFO can be aborted at any time during writing the packet (see [Dropping Packets on Write Side](#Dropping-Packets-on-Write-Side)). The write pointer is automatically rewinded in this case. 
  * Example use-case: A CRC error can only be detected at the end of the packet. User logic can still write the packet into the FIFO directly and just asserts *In_Drop* if a CRC error is detected at the end of the packet. The full packet (including already written data) is ignored.
* On the read side, it is possible to skip the remaining data of a packet at any time during reading a packet (see [Skipping Packets on Read Side](#Skipping-Packets-on-Read-Side)).
  * Example use-case: The user logic is interested only in some packet types. If a different packet type is found in the header, *Out_Next* can be asserted to skip the rest of the packet and directly continue reading the next packet.
* On the read side, it is possible to repeat a packet (see [Repeating Packets on Read Side](#Repeating-packets-on-Read-Side)).
  * Example use-case: A packet is read from the FIFO and transmitted wirelessly. During sending the packet a collision occurs and the transmission is aborted. In this situation the user logic can assert *Out_Repeat* to read the same packet again and retry the transmission.

Below samples assumes *Depth_g*=32.

![BasicWaveform](./fifo/olo_base_fifo_packet_basic.png)

The memory is described in a way that it utilizes RAM resources (Block-RAM or distributed RAM) available in FPGAs with commonly used tools. For this purpose [olo_base_ram_sdp](./olo_base_ram_sdp.md) is used.

The FIFO  has AXI-S interfaces on read and write side.

The RAM behavior (read-before-write or write-before-read) can be selected. This allows efficiently implementing FIFOs for different technologies (some technologies implement one, some the other behavior).

The FIFO contains a large RAM for packet data and a small [olo_base_fifo_sync](./olo_base_fifo_sync.md) for storing the sizes of individual packets.

**Note:** Due to implementation reasons the FIFO introduces one stall cycle per packet on the read-side. Hence the FIFO throughput is suboptimal for very small packets.

Packets exceeding *Depth_g* cannot be processed in store and forward mode and are therefore dropped automatically.

## Generics

| Name            | Type      | Default | Description                                                  |
| :-------------- | :-------- | ------- | :----------------------------------------------------------- |
| Width_g        | positive  | -       | Number of bits per FIFO entry (word-width)                   |
| Depth_g         | positive  | .       | Number of FIFO entries                                       |
| RamStyle_g      | string    | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes *ram_style* and *ramstyle* which vendors offer to control RAM implementation.<br>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| RamBehavior_g   | string    | "RBW"   | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| SmallRamStyle_g | string    | "auto"  | Same as *RamStyle_g* but applies to the small FIFO for packet sizes instead of the main RAM. <br>Offers the additional option "same" to use the same value as for *RamStyle_g*. |
| SmallRamBehavior_g | string | "same"  | Same as *RamBehavior_g* but applies to the small FIFO for packet sizes instead of the main RAM. <br>Offers the additional option "same" to use the same value as for *RamBehavior_g*. |
| MaxPackets_g    | positive  | 17     | Controls how many packets can be stored at maximum in the FIFO (i.e. controls the size of the packet-size FIFO).<br>Range: 2 ... 2^31-1 |

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### Input Data

| Name     | In/Out | Length    | Default | Description                                  |
| :------- | :----- | :-------- | ------- | :------------------------------------------- |
| In_Data  | in     | *Width_g* | -       | Input data                                   |
| In_Valid | in     | 1         | '1'     | AXI4-Stream handshaking signal for *In_Data* |
| In_Ready | out    | 1         | N/A     | AXI4-Stream handshaking signal for *In_Data* |
| In_Last  | in     | 1         | '1'     | AXI4-Stream end of packet signaling for *In_Data* |
| In_Drop  | in     | 1         | '0'     | Assert this signal for dropping the current packet (not storing it in the FIFO). |
| In_IsDropped | out | 1        | N/A     | Indicates that the current packet is dropped. Either because *In_Drop* was asserted during the packet or because the packet exceeds the *Depth_g* of the FIFO. |

### Output Data

| Name      | In/Out | Length    | Default | Description                                   |
| :-------- | :----- | :-------- | ------- | :-------------------------------------------- |
| Out_Data  | out    | *Width_g* | N/A     | Output data                                   |
| Out_Valid | out    | 1         | N/A     | AXI4-Stream handshaking signal for *Out_Data* |
| Out_Ready | in     | 1         | '1'     | AXI4-Stream handshaking signal for *Out_Data* |
| Out_Last  | out    | 1         | N/A     | AXI4-Stream end of packet signaling for *Out_Data* |
| Out_Size | out     | ceil(log2(*Depth_g*+1)) | N/A | Indicates the size of the current packet in words/data-beats. |
| Out_Next | in      | 1         | '0' | Assert this signal for aborting readout of the current packet and jump to the next one. |
| Out_Repeat | in    | 1         | '0' | Assert this signal for repeating this packet one more time after it was read completely (or it was aborted due to *Out_Next*). |

For aborting the current packet and repeating it one more time, *Out_Next* and *Out_Repeat* can be asserted both at the same time.

Note that it also is possible to repeat a packet several times by asserting *Out_Repeat* again during the repeated readout of the packet.

### Status

| Name      | In/Out | Length                  | Default | Description                                                  |
| :-------- | :----- | :---------------------- | ------- | :----------------------------------------------------------- |
| PacketLevel  | out    | ceil(log2(*MaxPackets_g*+1)) | N/A     | Number of packets stored in the FIFO. The counter is incremented *after* a packet was written completely and decremented *after* the packet was read completely or skipped (due to *Out_Next*). |
| FreeWords | out    | ceil(log2(*Depth_g*+1)) | N/A     | Available space in the FIFO. The counter is decremented *during* writing of the packet as the individual words are written and increased *after* the packet was read completely or skipped (due to *Out_Next*). The counter is also increased if a packet is dropped (due to *In_Drop* or its size exceeding *Depth_g*)  |

## Details

### Architecture

The FIFO works like a normal FIFO, just that it contains a small FIFO storing the end address for each packet. This allows to calculate the packet size on the read size for indication through *Out_Size* and asserting *Out_Last* on the correct data-beat.

![Block Diagram](./fifo/olo_base_fifo_packet.svg)

The end-address of the currently read packet is removed from the FIFO when readout starts. Therefore the depth of the FIFO for the end-address is *MaxPackets_g-1*. This is also the reason for the default value of 17: 16 is a reasonable default size of the FIFO (maps well to distributed RAM in all common FPGA architectures) and one more packet is currently being read-out.

### Dropping Packets on Write Side

For dropping a packet during writing it into the FIFO, the *In_Drop* signal is asserted anywhere between (including) the transaction of the first data word and (including) the transaction of the last data word.

The signal *In_IsDropped* is kept asserted from the clock cycle where *In_Drop* is asserted until the end of the packet. The signal is implemented to avoid that user logic has to remember whether *In_Drop* was at any earlier point during writing a packet. 

Note that the user may still provide more data after *In_Drop* being asserted. All this data until *In_Last* is ignored.

Below is an example for asserting *In_Drop* during a packet:

![DropDuringPacket](./fifo/olo_base_fifo_packet_drop_during.png)

It is also allowed to assert *In_Drop* together with the last data word of a packet:

![DropLastWord](./fifo/olo_base_fifo_packet_drop_last.png)

*In_Drop* can also be detected when *In_Valid* or *In_Ready* are low (i.e. in between transactions). However, it is strongly suggested that the signal is kept asserted until a transaction (*In_Valid* and *In_Ready* both are high) for easy understanding of the waveforms and to be in-line with the AXI4-Stream handshaking protocol.

### Skipping Packets on Read Side

For skipping the rest of a packet on the read side, the *Out_Next* signal is aserted anywhere between (including) the transaction of the first data word and the transaction of the last data word. Asserting the signal on the last data word does not have any effect because there is no more data to skip at this point.

Skipped packets are ended by asserting *Out_Last* earlier and omitting the remaining data words - hence the AXI4-Stream protocol is fully respected (*Out_Last* is **NOT** omitted).

If *Out_Next* is asserted during a transaction of a data word (*Out_Valid* and *Out_Ready* both are high), *Out_Last* is asserted immediately on this word.

Example for skipping a packet containing the data 0x1, 0x2, 0x3, 0x4:

![SkipPacket](./fifo/olo_base_fifo_packet_next.png)

*Out_Next* can also be detected when *Out_Valid* or *Out_Ready* are low (i.e. in between transactions). However, it is strongly suggested that the signal is kept asserted until a transaction (*Out_Valid* and *Out_Ready* both are high) for easy understanding of the waveforms and to be in-line with the AXI4-Stream handshaking protocol. If *Out_Next* is asserted between transactions, one more word is read after the assertion - this is required because *Out_Last* must be asserted during a transaction according to the AXI4-Stream protocol.

### Repeating Packets on Read Side

For repeating a packet on the read side, the *Out_Repeat* signal is asserted anywhere between (including) the transaction of the first data word and (including) the transaction of the last data word. The remaining data of the packet still is read but after the last word of the packet, the same packet is repeated.

Example for repeating a packet containing the data 0x1, 0x2, 0x3, 0x4:

![RepeatPacket](./fifo/olo_base_fifo_packet_repeat.png)

For repeating a packet immediately in the middle of a packet and without reading the remaining words, *Out_Repeat* and *Out_Next* can be asserted both at the same time.

Example for repeating a packet containing the data 0x1, 0x2, 0x3, 0x4 immediately:

![RepeatPacket](./fifo/olo_base_fifo_packet_repeat_immediate.png)

*Out_Repeat* can also be detected when *Out_Valid* or *Out_Ready* are low (i.e. in between transactions). However, it is strongly suggested that the signal is kept asserted until a transaction (*Out_Valid* and *Out_Ready* both are high) for easy understanding of the waveforms and to be in-line with the AXI4-Stream handshaking protocol. 

