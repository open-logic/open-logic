<img src="../Logo.png" alt="Logo" width="400">

# olo_base_ram_tdp

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_ram_tdp.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_ram_tdp.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_ram_tdp.json?cacheSeconds=0)

VHDL Source: [olo_base_ram_sdp](../../src/base/vhdl/olo_base_ram_sdp.vhd)

## Description

This component implements a **true dual-port** RAM. It offers two ports, which both allow reading and writing. The two ports run on separate clocks - although connecting the same clock to both ports is allowed.

The RAM is implemented in pure VHDL but in a way that allows tools to implement it in block-RAMs.

## Generics

| Name            | Type     | Default | Description                                                  |
| :-------------- | :------- | ------- | :----------------------------------------------------------- |
| Depth_g         | positive | -       | Number of addresses the RAM has                              |
| Width_g         | positive | -       | Number of bits stored per address (word-width)               |
| UseByteEnable_g | boolean  | false   | By default, all bits of a memory cell are written. Enabling byte-enables allows to control which bytes are written individually. <br>The setting is only allows for if *Width_g* is a multiple of eight (otherwise the word *byte-enable* does not make sense). |
| RdLatency_g     | positive | 1       | Read latency. <br>1 is the behavior of a normal synchronous RAM<br>Higher values can be desirable for timing-optimization in high-speed logic. |
| RamStyle_g      | string   | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes *ram_style* and *ramstyle* which vendors offer to control RAM implementation. Commonly used values are given below.<br>AMD: "auto", block", "distributed", "ultra" - see [ug901](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/RAM_STYLE?tocId=EWhb59DDWEWsMr4arnAICw) for details<br>Intel: "M4K", "M9K", "M20K", "M144K", "MLAB" - see [quartus-help](https://www.intel.com/content/www/us/en/programmable/quartushelp/17.0/hdl/vhdl/vhdl_file_dir_ram.htm) for details |
| RamBehavior     | string   | "RBW"   | Controls the RAM behavior. Must match the behavior of RAM resources of the target technology for efficient implementation.<br>"RBW": Read-before-write - more common common, hence the default <br>"WBR": Write-before-read<br>If you are unsure what behavior your target device offers, try both settings and check which one is correctly mapped to RAM resources using the synthesis report. |

## Interfaces

### Port A

| Name     | In/Out | Length                | Default | Description                                                  |
| :------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| A_Clk    | in     | 1                     | -       | Port A clock                                                 |
| A_Addr   | in     | ceil(log2(*Depth_g*)) | -       | Port A address                                               |
| A_Be     | in     | *Width_g*/8           | All '1' | Port A byte-enables<br>Ignored if *UseByteEnable_g* = false  |
| A_WrEna  | in     | 1                     | '0'     | Port A write enable. The memory cell at *A_Addr* is written only if *A_WrEna*='1'. |
| A_WrData | in     | *Width_g*             | 0       | Port A write data                                            |
| A_RdData | out    | *Width_g*             | N/A     | Port A read data                                             |

### Port B

| Name     | In/Out | Length                | Default | Description                                                  |
| :------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| B_Clk    | in     | 1                     | -       | Port B clock                                                 |
| B_Addr   | in     | ceil(log2(*Depth_g*)) | -       | Port B address                                               |
| B_Be     | in     | *Width_g*/8           | All '1' | Port B byte-enables<br>Ignored if *UseByteEnable_g* = false  |
| B_WrEna  | in     | 1                     | '0'     | Port B write enable. The memory cell at *A_Addr* is written only if *A_WrEna*='1'. |
| B_WrData | in     | *Width_g*             | 0       | Port B write data                                            |
| B_RdData | out    | *Width_g*             | N/A     | Port B read data                                             |

## Architecture

Below figure explains the *RdLatency_g* generic in detail:

![RdLatency](./ram/RdLatency_TDP.png)



