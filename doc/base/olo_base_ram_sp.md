<img src="../Logo.png" alt="Logo" width="400">

# olo_base_ram_sp

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_ram_sp.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_ram_sp.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_ram_sp.json?cacheSeconds=0)

VHDL Source: [olo_base_ram_sp](../../src/base/vhdl/olo_base_ram_sp.vhd)

## Description

This component implements a **single-port** RAM.

The RAM is implemented in pure VHDL but in a way that allows tools to implement it in block-RAMs.

## Generics

| Name            | Type     | Default | Description                                                  |
| :-------------- | :------- | ------- | :----------------------------------------------------------- |
| Depth_g         | positive | -       | Number of addresses the RAM has                              |
| Width_g         | positive | -       | Number of bits stored per address (word-width)               |
| UseByteEnable_g | boolean  | false   | By default, all bits of a memory cell are written. Enabling byte-enables allows to control which bytes are written individually. <br>The setting is only allows for if _Width_g_ is a multiple of eight (otherwise the word _byte-enable_ does not make sense). |
| RdLatency_g     | positive | 1       | Read latency. <br>1 is the behavior of a normal synchronous RAM<br>Higher values can be desirable for timing-optimization in high-speed logic. |
| RamStyle_g      | string   | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes _ram_style_ and _ramstyle_ which vendors offer to control RAM implementation. Commonly used values are given below.<br>AMD: "auto", block", "distributed", "ultra" - see [ug901](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/RAM_STYLE?tocId=EWhb59DDWEWsMr4arnAICw) for details<br>Altera: "M4K", "M9K", "M20K", "M144K", "MLAB" - see [quartus-help](https://www.intel.com/content/www/us/en/programmable/quartushelp/17.0/hdl/vhdl/vhdl_file_dir_ram.htm) for details<br />Efinix: "block_ram", "registers" - see [efinity-synthesis](https://www.efinixinc.com/docs/efinity-synthesis-v3.9.pdf) for details<br />Synplify(Lattice/Microchip): "block_ram", "registers", "distributed" - see [microchip-attributes-guide](https://ww1.microchip.com/downloads/aemdocuments/documents/fpga/ProductDocuments/ReleaseNotes/microsemi_p201903asp1_attribute_reference.pdf) for details<br />Gowin: "block_ram", "distributed_ram", "registers", "rw_check", "no_rw_check" - see [GowinSynthesis User Guide](https://cdn.gowinsemi.com.cn/SUG550E.pdf) for details. |
| RamBehavior     | string   | "RBW"   | Controls the RAM behavior. Must match the behavior of RAM resources of the target technology for efficient implementation.<br>"RBW": Read-before-write - more common common, hence the default <br>"WBR": Write-before-read<br>If you are unsure what behavior your target device offers, try both settings and check which one is correctly mapped to RAM resources using the synthesis report. |

## Interfaces

| Name   | In/Out | Length                | Default | Description                                                  |
| :----- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Clk    | in     | 1                     | -       | Clock                                                        |
| Addr   | in     | _ceil(log2(Depth_g))_ | -       | Address                                                      |
| Be     | in     | _Width_g/8_           | All '1' | Byte-enables<br>Ignored if _UseByteEnable_g_ = false         |
| WrEna  | in     | 1                     | '1'     | Write enable. The memory cell at _Addr_ is written only if _WrEna_='1'. |
| WrData | in     | _Width_g_             | -       | Write data                                                   |
| RdData | out    | _Width_g_             | N/A     | Read data                                                    |

## Architecture

Below figure explains the _RdLatency_g_ generic in detail:

![RdLatency](./ram/RdLatency_SP.png)
