<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_coef_storage

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_coef_storage.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_coef_storage.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_coef_storage.json?cacheSeconds=0)

VHDL Source: [olo_fix_coef_storage](../../src/fix/vhdl/olo_fix_coef_storage.vhd)

## Description

This entity implements a fixed-point coefficient storage. The storage can be configured as a
read-only ROM or as a read-write RAM, allowing coefficients to be updated at runtime.

The intended use case for this entity is to hold coefficients for DSP datapaths. In this context, the entity
has the following advantages over using RAMs from _olo_base_ directly:

- Initialization with real values in _Init_g_, which are quantized to the specified fixed-point format.
  - This allows copy-pasting coefficients from tools like Python or MATLAB without needing to pre-quantize them.
- BROM/RAM options for coefficient storage do not need to be implemented separately in the datapath.
  - This prevents significant code duplication (many DSP elements require RAM or ROM coefficient storage)

Two independent read ports are provided:

- **Coef port** - read-only, intended for DSP datapaths that consume coefficients every cycle.
- **Cfg port** - write port (RAM only) plus optional read-back, intended for software-controlled
  coefficient updates.

Both ports support a configurable read latency (_RdLatency_g_).

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

## Generics

| Name           | Type    | Default | Description                                                                                          |
| :------------- | :------ | :------ | :--------------------------------------------------------------------------------------------------- |
| Depth_g        | positive | -      | Number of coefficient entries                                                                        |
| Fmt_g          | string  | -       | Coefficient format<br />String representation of an _en_cl_fix Format_t_ (e.g. "(1,1,15)")          |
| Init_g         | string  | "0.0"   | Comma-separated initial real values (e.g. "1.0, 0.5")<br />Missing entries default to 0.0 |
| StorageType_g  | string  | "ROM"   | "ROM": read-only storage initialized from _Init_g_<br />"RAM": read-write storage, updateable via the Cfg port |
| RamReadback_g  | boolean | false   | True: Readback through _Cfg_RdData_ / _Cfg_RdValid_ is possible (RAM only)<br />False: Readback is not possible|
| RamBehavior_g  | string  | "WBR"   | "RBW" = read-before-write, "WBR" = write-before-read<br/>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). |
| RdLatency_g    | positive | 1      | Read latency in clock cycles for both read ports (minimum 1)                                        |
| RamStyle_g     | string  | "auto"  | Through this generic, the exact resource to use for implementation can be controlled. This generic is applied to the attributes _ram_style_ and _ramstyle_ which vendors offer to control RAM implementation.<br>For details refer to the description in [olo_base_ram_sdp](./olo_base_ram_sdp.md). <br> Does apply to _StorageType_g=ROM_ as well and can be used to control ROM implementation. |

**Note:** _RamReadback_g=True_ implements a true-dual-port RAM. Consider technology restrictions and set _RamBehavior_g_
as needed for true dual port RAMs in your target technology.

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | :------ | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Cfg Port

| Name        | In/Out | Length          | Default     | Description                                                                          |
| :---------- | :----- | :-------------- | :---------- | :----------------------------------------------------------------------------------- |
| Cfg_Addr    | in     | _ceil(log2(Depth_g))_ | 0   | Address for Cfg read or write                                                        |
| Cfg_WrEna   | in     | 1               | 0           | Write enable - Ignored for _StorageType_g=ROM_                                             |
| Cfg_WrData  | in     | _width(Fmt_g)_  | 0           | Data to write - Ignored for _StorageType_g=ROM_ <br />Format: _Fmt_g_                                                   |
| Cfg_RdEna   | in     | 1               | 0           | Read enable for Cfg readback - Unused for _StorageType_g=ROM_ or _RamReadback_g_=false  |
| Cfg_RdData  | out    | _width(Fmt_g)_  | N/A         | Readback data - Unused for _StorageType_g=ROM_ or _RamReadback_g_=false<br />Format: _Fmt_g_ |
| Cfg_RdValid | out    | 1               | N/A         | Read valid for _Cfg_RdData_ - Unused for _StorageType_g=ROM_ or _RamReadback_g_=false                  |

### Coef Port

| Name         | In/Out | Length                | Default | Description                                      |
| :----------- | :----- | :-------------------- | :------ | :----------------------------------------------- |
| Coef_Addr    | in     | _ceil(log2(Depth_g))_ | 0       | Read address                                     |
| Coef_RdEna   | in     | 1                     | 0       | Read enable                                      |
| Coef_RdData  | out    | _width(Fmt_g)_        | N/A     | Coefficient read data<br />Format: _Fmt_g_       |
| Coef_RdValid | out    | 1                     | N/A     | Read valid for _Coef_RdData_                     |

## Detail

### Initialization

All entries are initialized from _Init_g_ at elaboration time. _Init_g_ is a comma-separated
string of real values (e.g. "1.0, 0.5e-1"). Each value is quantized to _Fmt_g_. Entries with no
corresponding _Init_g_ value default to 0.0.

For ROM storage, these initial values are permanent. For RAM storage, they represent the
power-on state before any Cfg writes.

**Note:** Not all FPGA devices do allow initialization of RAMs. Check the documentation of your target device and
synthesis tool for details and consider using _StorageType_g=ROM_ if your device does not. SRAM FPGAs typically support
RAM initialization.

### Read Latency

Both the Coef and Cfg read ports have a latency of _RdLatency_g_ clock cycles from the rising
edge that samples the address and read-enable to the rising edge where the output is valid.
_Cfg_RdValid_ and _Coef_RdValid_ track the latency pipeline and are asserted exactly
_RdLatency_g_ cycles after the corresponding _RdEna_ was sampled.

### ROM vs RAM

When _StorageType_g_ = "ROM", _Cfg_WrEna_ is ignored and the stored values cannot change
after elaboration. _Cfg_RdData_ and _Cfg_RdValid_ are always driven to zero.

When _StorageType_g_ = "RAM", coefficients can be updated at runtime via the Cfg write port.
Setting _RamReadback_g_ = true additionally enables the Cfg read port so written values can be
verified.

### Read-Before-Write vs Write-Before-Read

When _StorageType_g_ = "RAM" and a Cfg write and a Coef read target the same address in the
same clock cycle, _RamBehavior_g_ determines which value the Coef port returns:

- "RBW": the Coef port returns the value that existed **before** the write.
- "WBR": the Coef port returns the value **after** the write has been applied.
