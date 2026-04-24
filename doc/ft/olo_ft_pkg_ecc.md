<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_pkg_ecc

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_pkg_ecc](../../src/ft/vhdl/olo_ft_pkg_ecc.vhd)

## Description

This package contains SECDED (Single Error Correction, Double Error Detection) Hamming code functions used internally
by the ECC-protected entities in the _ft_ area (e.g. [olo_ft_ram_sp](./olo_ft_ram_sp.md)).

The encoding uses a standard Hamming code with an additional overall parity bit for double error detection. Resulting overhead:

| Data Width | Parity Bits | Total Stored Bits |
| :--------- | :---------- | :---------------- |
| 8          | 5           | 13                |
| 16         | 6           | 22                |
| 32         | 7           | 39                |
| 64         | 8           | 72                |
| 128        | 9           | 137               |
