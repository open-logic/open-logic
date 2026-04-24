<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ram_sp

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_ram_sp](../../src/ft/vhdl/olo_ft_ram_sp.vhd)

## Description

This component implements an **ECC-protected single-port RAM** using SECDED (Single Error Correction, Double Error
Detection) Hamming code. It wraps [olo_base_ram_sp](../base/olo_base_ram_sp.md) internally with a wider word to store
parity bits alongside data.

The ECC is transparent to the user: data is automatically encoded on write and decoded/corrected on read. Error status
flags indicate whether a single-bit error was corrected or a double-bit error was detected.

This is useful in **radiation-hardened** designs where single-event upsets (SEUs) can flip bits in memory cells.

## Generics

| Name          | Type     | Default | Description                                                  |
| :------------ | :------- | ------- | :----------------------------------------------------------- |
| Depth_g       | positive | -       | Number of addresses the RAM has                              |
| Width_g       | positive | -       | Number of data bits stored per address (word-width). The internal RAM is wider to accommodate ECC parity bits. |
| RdLatency_g   | positive | 1       | Read latency inside the RAM. Higher values can help close timing. |
| RamStyle_g    | string   | "auto"  | Controls the RAM implementation resource. Passed through to [olo_base_ram_sp](../base/olo_base_ram_sp.md). |
| RamBehavior_g | string   | "RBW"   | Controls the RAM behavior. <br>"RBW": Read-before-write<br>"WBR": Write-before-read |
| EccPipeline_g | natural  | 0       | Number of pipeline stages after ECC decode. <br>0 = combinational output (default). <br>1+ = adds register stages to break the critical path. Total read latency becomes _RdLatency_g_ + _EccPipeline_g_. |

## Interfaces

| Name         | In/Out | Length                | Default | Description                                                  |
| :----------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Clk          | in     | 1                     | -       | Clock                                                        |
| Addr         | in     | _ceil(log2(Depth_g))_ | -       | Address                                                      |
| WrEna        | in     | 1                     | '1'     | Write enable                                                 |
| WrData       | in     | _Width_g_             | -       | Write data                                                   |
| WrEccBitFlip | in     | 2                     | "00"    | ECC error injection for testing/BIST. Each bit flips the corresponding bit in the stored codeword.<br>"01" = single-bit error, "11" = double-bit error.<br>See [Error Injection](#error-injection). |
| RdData       | out    | _Width_g_             | N/A     | Read data (corrected if a single-bit error was detected)     |
| RdSecErr     | out    | 1                     | N/A     | Single error corrected flag. '1' when a single-bit error was detected and corrected. |
| RdDedErr     | out    | 1                     | N/A     | Double error detected flag. '1' when an uncorrectable double-bit error was detected. Read data is unreliable in this case. |

## Detailed Description

### Architecture

```
Write path:  WrData -> eccEncode -> XOR bit-flip injection -> wider internal RAM
Read path:   wider internal RAM -> eccSyndromeAndParity -> eccCorrectData + SecErr/DedErr -> [optional ECC pipeline]
```

The ECC encoding is combinational on the write path. The internal RAM (an instance of _olo_base_ram_sp_ with wider
word) provides the configurable read pipeline (_RdLatency_g_). The ECC decoding is combinational after the read
pipeline, so the error flags are time-aligned with the read data.

When _EccPipeline_g_ > 0, additional register stages are inserted after the ECC decode logic. This breaks the
combinational path between the RAM output and the corrected data output, which can help close timing at high clock
frequencies. The total read latency becomes _RdLatency_g_ + _EccPipeline_g_ clock cycles.

### ECC Overhead

The SECDED Hamming code adds parity bits to each stored word:

| Data Width | Parity Bits | Total Stored Bits |
| :--------- | :---------- | :---------------- |
| 8          | 5           | 13                |
| 16         | 6           | 22                |
| 32         | 7           | 39                |
| 64         | 8           | 72                |
| 128        | 9           | 137               |

### Error Injection

The _WrEccBitFlip_ port allows deliberate injection of bit errors into stored codewords. This is useful for testing the
ECC mechanism in simulation and for built-in self-test (BIST) in hardware.

- Setting bit 0 to '1' flips bit 0 of the stored codeword (overall parity bit)
- Setting bit 1 to '1' flips bit 1 of the stored codeword (first Hamming parity bit)
- Setting both bits to '1' injects a double-bit error

### Constraints

- Byte enables are not supported (ECC covers the full word; partial writes would invalidate parity)
- RAM initialization is not supported (the internal RAM stores ECC codewords, not raw data)
