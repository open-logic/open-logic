<img src="../Logo.png" alt="Logo" width="400">

# olo_base_cam

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_cam.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_cam.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_cam.json?cacheSeconds=0)

VHDL Source: [olo_base_cam](../../src/base/vhdl/olo_base_cam.vhd)

## Description

This component implements a content addressable memory. Content addressable memories are usually used for fast-lookups in caches, routing tables and other similar scenarios.

The concept of mapping a CAM into block and/or distributed RAM described in the [AMD application not XAPP 1151](https://docs.amd.com/v/u/en-US/xapp1151_Param_CAM) is applied. However, *olo_base_cam* has a very different and much easier to understand user interface than the component described in the application note. 

The *olo_base_cam* does allow to write address/content pairs and to find out in which address a queried content is stored. 

Reads take one clock cycle, writes take two clock cycles and the two things cannot happen at the same time.

Below example assumes a *olo_base_cam* with 4 addresses and 16 bit content.

![Basic](./cam/olo_base_cam_basic.png)

The CAM has logically separated read and write interfaces. They share some resources internally but from a users perspective they are independent. Every read-request issues through *Rd_...* is followed by one output on both read-response streams:

* *OneHot_...* provides a match response 
  * A vector with one entry per address, indicating if the requested *Rd_Content* was stored in this address or not
* *Addr_...* provides the binary encoded address where *Rd_Content* is stored
  * The first (lowest) matching address is returned
  * If *Rd_Content* is not found, *Addr_Found='0'* is returned.

**Note:** By default the content of the CAM is cleared after reset. During the *RamBlockDepth_g* clock cycles this takes, it is not ready to accept any requests and holds *Rd/Wr_Ready* low. This behavior can be changed through generics if needed.

**Warning:** The user must ensure that an address is NOT occupied when new content is written to this address. Failure to adhere to this rule may lead to undefined behavior.

## Generics

Settings that normally must be adjusted by users are given in bold letters. All other settings are regarded as optimization settings and normally are only touched to tweak the *olo_base_cam* to match specific needs of an application.

| Name                 | Type     | Default | Description                                                  |
| :------------------- | :------- | ------- | :----------------------------------------------------------- |
| **Addresses_g**      | positive | -       | Number of addresses in the CAM                               |
| **ContentWidth_g**   | positive | .       | Width of the content to be stored in the CAM                 |
| **RamStyle_g**       | string   | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes *ram_style* and *ramstyle* which vendors offer to control RAM implementation.<br>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| **RamBehavior_g**    | string   | "RBW"   | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| **RamBlockWidth_g**  | positive | 32      | For mapping the CAM efficiently into RAM elements of a given technology, the width and depth of the underlying RAM element must be known.<br />**Use the RAM configuration with maximum width**. The CAM gets more resource efficient the wider BRAM ports are.<br /> |
| **RamBlockDepth_g**  | positive | 512     | For mapping the CAM efficiently into RAM elements of a given technology, the width and depth of the underlying RAM element must be known.<br />Use the RAM configuration with maximum width. The CAM gets more resource efficient the wider BRAM ports are. |
| ClearAfterReset_g    | boolean  | true    | **True**: After reset the CAM content is cleared. This process takes *RamBlockDepth_g* clock cycles during which *Wr_Ready* and *Rd_Ready* stay low.<br />**False**: The CAM is not cleared after reset. Contents from before the reset stay in the CAM but the CAM is operable immedieatly.<br />*Note:* It is strongly suggested to keep this setting enabled if the CAM is receiving resets after it was once operated. Clearing a CAM manually requires looping through all possible content values which can be time-consuming. |
| ReadPriority_g       | true     | true    | **True**: *Rd_Valid* and *Wr_Valid* are high at the same time, the read is executed first. This means that writes are delayed (*Wr_Ready* held low) until reads are done. <br />**False**: *Rd_Valid* and *Wr_Valid* are high at the same time, the write is executed first. This means that reads are delayed (*Rd_Ready* held low)until reads are done. <br />Default value is *true* to ensure constant read-latency because read-latency is one of the main drivers for using CAMs. |
| StrictOrdering_g     | boolean  | false   | **True:** After a write to the CAM, the next read is delayed by one clock-cycle by holding *Rd_Ready* low to ensure the read already sees the updated CAM content.<br />**False:** A read following a write immediately (in the next clock cycle) may read the old CAM content. In return compared to the *StrictOrdering_g=true* setting reads can follow writes immediately and are not delayed in this case.<br />Default value is *false* to ensure constant read-latency because read-latency is one of the main drivers for using CAMs. |
| UseAddrOut_g         | boolean  | true    | **True**: The binary-encoded address output (*Addr_...*) is implemented. This often is more logical to the user but requires additional logic for first-bit decoding. <br />**False**: Only the match output (*Match_...*) is implemented. The binary-encoded output is omitted to save logic. Normally the same can be achieved by just not connecting the output and relying on the tools optimizing away the related logic. |
| RegisterInput_g      | boolean  | true    | **True:** All inputs are registered. This is optimal for throughput/clock-speed but adds one cycle of latency.<br />**False:** The address lines of the RAM blocks are driven by user inputs combinatorially. This reduces the latency but may negatively affect the possible clock-speed. |
| RegisterMatch_g      | boolean  | true    | **True:** The match output (*Match_...*) is registered. This is optimal for throughput/clock-speed but adds one cycle of latency. <br />**False:** The match output is driven by RAM blocks combinatorially. This reduces the latency but may negatively affect the possible clock-speed. |
| FirstBitDecLatency_g | natural  | 1       | Number of FF stages for calculating the binary address output *Addr_...* after the one-hot output *Match_...* is known.<br />Range: 0 ... ceil(log2(*InWidth_g*))/2-1 |



## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to *Clk*) |

### Read Request

| Name       | In/Out | Length           | Default | Description                                     |
| :--------- | :----- | :--------------- | ------- | :---------------------------------------------- |
| Rd_Content | in     | *ContentWidth_g* | -       | Content to find address for                     |
| Rd_Valid   | in     | 1-               |         | AXI4-Stream handshaking signal for *Rd_Content* |
| Rd_Ready   | out    | 1                | N/A     | AXI4-Stream handshaking signal for *Rd_Content* |

### Write Request

| Name        | In/Out | Length                    | Default | Description                                                  |
| :---------- | :----- | :------------------------ | ------- | :----------------------------------------------------------- |
| Wr_Content  | in     | *ContentWidth_g*          | -       | Content to find to modify entry for                          |
| Wr_Addr     | in     | *ceil(log2(Addresses_g))* | -       | Address to modify entry for                                  |
| Wr_Write    | in     | 1                         | -       | Write *Wr_Content* to *Wr_Addr* in CAM. <br />Note that the **user must ensure that this address is NOT occupied at the time of writing** to it. |
| Wr_Clear    | in     | 1                         | '0'     | Clear *Wr_Content* from *Wr_Addr*. Only this exact content is removed from this exact address. |
| Wr_ClearAll | in     | 1                         | '0'     | Clear *Wr_Content* from all addresses it is stored in (*Wr_Addr* is ignored). |
| Wr_Valid    | in     | 1                         | -       | AXI4-Stream handshaking signal for *Wr_...*                  |
| Wr_Ready    | out    | 1                         | N/A     | AXI4-Stream handshaking signal for *Wr_...*                  |

### One Hot Encoded Output

| Name        | In/Out | Length        | Default | Description                                                  |
| :---------- | :----- | :------------ | ------- | :----------------------------------------------------------- |
| Match_Match | out    | *Addresses_g* | N/A     | Match vector, containing a '1' for every address in which the requested *Rd_Content* is stored. |
| Match_Valid | out    | 1             | N/A     | AXI4-Stream handshaking signal for *Match_Match*.<br />One *Match_Valid* pulse is produced for every read transaction as signaled through *Rd_Valid*/*Rd_Ready* |

### Binary Encoded Output

Note that this interface is only operated if *UseAddrOut_g=true*.

| Name       | In/Out | Length                    | Default | Description                                                  |
| :--------- | :----- | :------------------------ | ------- | :----------------------------------------------------------- |
| Addr_Found | out    | 1                         | N/A     | '1' if the requested *Rd_Content* was found in the CAM, '0' otherwise. |
| Addr_Addr  | out    | *ceil(log2(Addresses_g))* | N/A     | First (lowest) address *Rd_Content* was found in.            |
| Addr_Valid | out    | 1                         | N/A     | AXI4-Stream handshaking signal for *Addr_...*.<br />One *Addr_Valid* pulse is produced for every read transaction as signaled through *Rd_Valid*/*Rd_Ready* |

## Details

### Architecture

Below figure shows the architecture for the following properties:

* *Addresses_g*=64
* *ContentWidth_g*=18
* AMD 7-Series BRAM18 
  * *RamBlockWidth_g*=32
  * *RamBlockDepth_g*=512

The match-entries are stored with one bit per address. Hence overall the RAM must be 64 bits wide, which leads to the need of having two block RAM in parallel (each one 32 bits wide). 

The content is used to address the RAMs. Naturally an 18-bit address would lead to 256k entries to address. However, the content can be split and 9 bits can be fed to two different RAMs. Like this only 1k entries are required. In order to receive the correct match entries, the outputs of the two sub-RAMs must be ANDed. This concept works because each address is occupied only once.

Note that the figure only shows the read path. The write path is best understood from the code directly.

![Architecture](./cam/olo_base_cam_arch.svg)

Let's assume the CAM contains the following entries:

* Address 2 = Content 0x10010
* Address 3 = Content 0x100FF
* Address 4 = Content 0xFF010

If the *Rd_Content* 0x100010 is applied, this is split into two sub-addresses. The upper bits (0x080) go to *RAM 1-0* and *RAM 1-1* and the lower bits (0x010) go to *RAM 0-0* and *RAM 0-1*.

The upper RAMs return 0x0000'0000'0000'000C. Two bits are set, because the same partial address (0x080) applies to both entries in the CAM.

The lower RAMs return 0x0000'0000'0000'0014 (again two entries match the pattern). ANDing the two RAM responses results in a *Match_Match* of 0x0000'0000'0000'0004 (bit 2 is set) and a *Addr_Addr* o 2 as expected.

For more details about this architecture, refer to [AMD application not XAPP 1151](https://docs.amd.com/v/u/en-US/xapp1151_Param_CAM).

### Read/Write Access Ordering

The ordering and prioritization between read and write accesses is important for CAMs. First, because they often are used in cases where traffic is very asymmetric with many fast lookups (read operations) and much less write operations. Second, in some applications deterministic read-latency is a key driver for using CAMs - and this property often should not be destroyed by write operations having priority over read operations. On the other hand, there are applications that can read from CAMs continuously and in this case write operations must have priority (because they never happen otherwise). 

Bottomline: There are a few things to consider and the behavior of *olo_base_cam* is configurable therefore.

Below four samples show different configurations. All examples assume the following things:

* Initial CAM content:
  * Content 0x1234 at address 2
  * Content 0xABCD at address 3
* RAM behavior is read before write

#### ReadPriority_g = True / StrictOrdering_g = False

![ReadStrict](./cam/olo_base_cam_read_nonstrict.png)

In above figure the following things are noticeable:

* Between the yellow and the orange transaction, the read transaction is executed first due to *ReadPriority_g=true*.
* For the blue transaction, although the entry was cleared in the clock cycle just before, the read still returns a match. This is caused by *StrictOrdering_g=false* which leads to reads in the clock cycle directly after the write still reading the old content.
  * Note that this only happens for *RamBehavior_g="RBW"*. Write before read RAMs always return the new value.
* In the last part it is visible that read transactions are prioritized and write transactions are delayed until the point where no read is happening.

#### ReadPriority_g = True / StrictOrdering_g = True

![ReadStrict](./cam/olo_base_cam_read_strict.png)

In above figure the following difference to the last section is noticeable:

* For the blue transaction, the read is delayed by one clock cycle to ensure the updated CAM content is seen after the write transaction. This is caused by *StrictOrdering_g=true*.
  * As a result, the new content is read. *AddrFound='0'* is returned because the clearing took effect before the read.
* In the last part, it is visible that the low-pulse on *Rd_Ready* after a write happens always (independently of the details about the read and the write).

#### ReadPriority_g = False / StrictOrdering_g = False

![ReadStrict](./cam/olo_base_cam_write_nonstrict.png)

The following points are notable about the figure above:

* Writes are prioritized over reads (see yellow/orange transaction or the part at the end of the figure). This is due to *ReadPriority_g=False*.
* Due to *StrictOrdering_g=False* a read can happen immediately after the write but reads the old content (see blue transaction). In the colorful part to the end of the figure, it becomes visible that this configuration allows to use the stall cycles of the writes (where *Wr_Ready* is pulsed low) for reads. Hence this configuration allows for maximum overall throughput.

#### ReadPriority_g = False / StrictOrdering_g = True

![WriteStrict](./cam/olo_base_cam_write_strict.png)

The following points are notable about the figure above:

* Due to the strict ordering, the read for the blue transaction is delayed by one clock cycle and the new value is read.
* Because the strict ordering does not allow to use the *Wr_Ready* low pulses for reading, the reads are delayed until all writes are done towards the end of the figure.

### Latency/Throughput Considerations 

#### Low Latency

If you aim for lowest possible read latency (in terms of clock cycles), disable all optional registers. Note that this may lead to reduced clock frequencies for larger CAM implementations:

* *RegisterInput_g=false*
* *RegisterMatch_g=false*
* *FirstBitDecLatency_g=0*

Additionally prioritize reads over writes to ensure the read-latency is not negatively impacted when the CAM is written. Also disable strict ordering to ensure reads are not delayed *after* writes.

* *ReadPriority_g=true*
* *StrictOrdering_g=false*

![LowLAtency](./cam/olo_base_cam_latency.png)

To avoid long combinatorial paths, the *Match_* outputs shall be preferred over *Addr_...*-

#### Maximum Clock Speed

For achieving maximum throughput and high clock speed, use enable all registering. The number of *FirstBitDecLatency_g* registers for the first bit decoding depends on the size of the CAM. However, for maximum clock frequency the number shall be chosen better a bit higher. 

* *RegisterInput_g=true*
* *RegisterMatch_g=true*
* *FirstBitDecLatency_g=3*

If read-throughput is in focus, of course reads shall never be stalled due to writes:

* *ReadPriority_g=true*
* *StrictOrdering_g=false*

![HighSpeed](./cam/olo_base_cam_speed.png)

### Reset Behavior

The fact that RAM contents are not reset when reset signals are asserted is well known. For RAMs this is not too severe because one can easily iterate through all addresses to clear the RAMs. 

For CAMs the situation is more difficult because often the width of the contents are relatively high (this is a good reason to use a CAM instead of a RAM) and hence iterating through e.g. all possible 64-bit values of a CAM content to clear the memory is not practicable. However, in the internal structure it is possible to iterate through each RAM block separately.

*olo_base_cam* implements clearing of the RAM contents after reset if *ClearAfterReset_g=true*. It is strongly recommended to leave this setting enabled unless the initial delay of *RamBlockDepth_g* clock cycles (required for the clearing) before *Rd_Ready* and *Wr_Ready* going high is really not tolerable.









