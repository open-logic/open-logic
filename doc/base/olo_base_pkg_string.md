<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_string

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_pkg_string.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_pkg_string.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_string.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_string](../../src/base/vhdl/olo_base_pkg_string.vhd)

## Description

This package contains useful string-related functions.

## Definitions

None

## Functions

### Case Conversion

Convert a string to upper or lower case.

```vhdl
function toUpper (a : in string) return string;
function toLower (a : in string) return string;
```

### Trim Whitespaces

Trip white-spaces at the beginning and the end of a string.

```vhdl
function trim (a : in string) return string;
```

### Parse Hex-String to std_logic_vector

Parse a hex-string to std_logic_vector.

```vhdl
function hex2StdLogicVector (
    a         : in string;
    bits      : in natural;
    hasPrefix : in boolean := false) return std_logic_vector;
```

_a_ is the string to parse, _bits_ the width of the resulting vector.

_hasPrefix_ defines whether the string has a _0x_ prefix (e.g. "0xABCD") or not (e.g. "ABCD").

### Count Character Occurrences

Count how often a character occurs in a string.

```vhdl
function countOccurence (
    a : in string;
    c : in character) return natural;
```
