<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_array

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_pkg_array.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_pkg_array.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_array.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_array](../../src/base/vhdl/olo_base_pkg_array.vhd)

## Description

This package contains different array types which are used in _Open Logic_ internally but also on its interfaces to the
user (e.g. for generics). The package is written mainly for these purposes and does not aim for completeness -
nevertheless as a user you are free to use it for your code of course.

## Definitions

### StdlvArray\<N\>_t

Arrays of _std_logic_vector_ of width N for regularly used widths.

Options for \<N\>: 2...32, 36, 48, 64, 512

Example:

```vhdl
variable x : StdlvArray4_t(0 to 9);  -- An array containint 10 std_logic_vector(3 downto 0);
```

### \<T\>Array_t

Arrays of different types .

Options for \<T\>: bool, integer, real

Examples:

```vhdl
variable x : IntegerArray_t(0 to 2); -- An array of 3 integers
variable y : BoolArray_t(0 to 3);    -- An array of 4 bools
variable z : RealArray_t(0 to 1);    -- An array of 2 reals
```

## Functions

### Converter Functions

Convert one array type into another.

```vhdl
function arrayInteger2Real(a : in t_ainteger) return t_areal;
function arrayStdl2Bool(a : in std_logic_vector) return t_abool;
function arrayBool2Stdl(a : in t_abool) return std_logic_vector;
```

For _bool_ and _std_logic_vector_ '1' is converted to _true_ and '0' to _false_.
