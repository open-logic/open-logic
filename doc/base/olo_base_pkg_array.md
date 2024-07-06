<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_array

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_pkg_array.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_pkg_array.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_array.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_array](../../src/base/vhdl/olo_base_pkg_array.vhd)

## Description

This package contains different array types which are used in *Open Logic* internally but also on its interfaces to the user (e.g. for generics). The package is written mainly for these purposes and does not aim for completeness - nevertheless as a user you are free to use it for your code of course.

## Definitions

### t_aslv\<N\>

Arrays of *std_logic_vector* of width N for regularly used widths.

Options for \<N\>: 2...32, 36, 48, 64, 512

Example:

```
variable x : t_aslv4(0 to 9);  -- An array containint 10 std_logic_vector(3 downto 0);
```

### t_a\<T\>

Arrays of different types .

Options for \<T\>: bool, integer, real

Examples:

```
variable x : t_ainteger(0 to 2); -- An array of 3 integers
variable y : t_abool(0 to 3); -- An array of 4 bools
variable z : t_areal(0 to 1); -- An array of 2 reals
```



## Functions

### Converter Functions

Convert one array type into another.

```
function aInteger2aReal(a : in t_ainteger) return t_areal;
function stdlv2aBool(a : in std_logic_vector) return t_abool;
function aBool2stdlv(a : in t_abool) return std_logic_vector;
```

For *bool* and *std_logic_vector* '1' is converted to *true* and '0' to *false*.



