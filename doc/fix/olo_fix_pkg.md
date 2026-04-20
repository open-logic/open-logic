<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_pkg

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_pkg.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_pkg.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_pkg.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_array](../../src/fix/vhdl/olo_fix_pkg.vhd)

## Description

This package contains various definitions that are used accross many _olo_fix_ components. For example does it contain
definitions and conversions that simpilify passing _en_cl_fix_ as strings to _olo_fix_components_, which is required
for verilog compatibility.

## Definitions

### String Representations of FixRound_t

String representations for all rounding modes:

- _FixRound_Trunc_c_ Truncation
- _FixRound_NonSymPos_c_: Nearest (round up if the value isexactly half-way)
- _FixRound_NonSymNeg_c_: Nearest (round down if the value isexactly half-way)
- _FixRound_SymInf_c_: Nearest (round away from zero if the valueis exactly half-way)
- _FixRound_SymZero_c_: Nearest (round towards zero if the valueis exactly half-way)
- _FixRound_ConvEven_c_: Convergent rounding
- _FixRound_ConvOdd_c_: Convergent rounding

Example:

```vhdl
...
    Round_g => FixRound_Trunc_c, -- use olo_fix_pkg constant
...
    Round_g => to_string(Trunc_s), --- use en_cl_fix FixRound_t and convert to string
```

### String Representations of FixSaturate_t

String representations for all saturation modes:

- _FixSaturate_None_c_: No saturation (wrap)
- _FixSaturate_Warn_c_: No saturation logic but warn in simulations in case of wraparounds
- _FixSaturate_Sat_c_: Add saturation logic but do not warn in simulations if saturation happens (for cases
  where saturation is expected)
- _FixSaturate_SatWarn_c_: Add saturation and warn in simulations if saturation happens (for cases where
  saturation is expected)

Example:

```vhdl
...
    Saturate_g => FixSaturate_None_c, -- use olo_fix_pkg constant
...
    Saturate_g => to_string(None_s), --- use en_cl_fix FixSaturate_t and convert to string
```

## Functions

### Calculate Width of Format in String Representation

The fixed-point formats are passed as strings (for verilog compatibility) but their width is required for input and
output ports. Therefore a function to directly calcualte the width of a fixed-point format available as string is
needed.

```vhdl
function fixFmtWidthFromString (fmt : string) return natural;
```

### Dynamic Shift Function

The way `cl_fix_shift` from the _en_cl_fix_ package is written, many synthesis tools cannot synthesize it for varaible
shifts. Therefore a dynamic shift function is implemented in _olo_fix_pkg_ that can be used in the _olo_fix_ components
instead of `cl_fix_shift` when variable shifts are required.

```vhdl
function fixDynShift(   a : std_logic_vector;
                        aFmt : FixFormat_t;
                        shift : integer; 
                        minShift : integer := 0;
                        maxShift : integer;
                        rFmt : FixFormat_t;
                        rnd : FixRound_t := Trunc_s;
                        sat : FixSaturate_t := None_s) return std_logic_vector;
```

The function works exactly the same as `cl_fix_shift` but taking additional parameters for minimum and maximum shift.

Note that the shift direction is left (like in `cl_fix_shift`) if the shift value is positive and right if the shift
value is negative.

### Internal Functions

The following functions are used in _Open Logic_ internally but they are not intended for use by the user and hence
they are undocumented

```vhdl
function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;
```
