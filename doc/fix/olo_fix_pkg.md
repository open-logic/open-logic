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

### Reading Fixed-Point Stimuli Files

Stimuli files written by the _olo_fix_ cosimulation infrastructure (e.g. `olo_fix_cosim` in Python) follow a simple
text format: the first line contains the fixed-point format string (e.g. `(1,0,15)`) and every following line contains
one sample as hex value. The functions below allow reading such files from a testbench or behavioral model.

The first two functions operate on an already opened file (`file f : text`) and read the header / one sample at a time:

```vhdl
-- Check the header (first line) against the expected format. Must be called once directly after
-- opening the file because it consumes the header line. Asserts on a format mismatch.
procedure fixFileCheckHeader (file f : text; fmt : FixFormat_t);

-- Read a single sample (one data line) and return it as std_logic_vector with exactly
-- cl_fix_width(fmt) bits.
impure function fixFileReadSample (file f : text; fmt : FixFormat_t) return std_logic_vector;
```

`fixFileReadSample` returns the sample with exactly `cl_fix_width(fmt)` bits, so it can be assigned directly to a port
or signal of the corresponding format.

Usage example:

```vhdl
use std.textio.all;
...
constant Fmt_c : FixFormat_t := cl_fix_format_from_string("(1,0,15)");
...
file DataFile      : text;
variable DataSlv_v : std_logic_vector(cl_fix_width(Fmt_c)-1 downto 0);
...
-- Open the file and check its header against the expected format
file_open(DataFile, "stimuli.fix", read_mode);
fixFileCheckHeader(DataFile, Fmt_c);

-- Read all samples
while not endfile(DataFile) loop
    DataSlv_v := fixFileReadSample(DataFile, Fmt_c);
    -- ... use DataSlv_v ...
end loop;

file_close(DataFile);
```

The next two functions read a complete file (given by its path) in one call. They open the file, check its header
against the passed format and return all samples - either as `RealArray_t` or as a comma-separated string of real
values (e.g. `"0.1, 1.0e2"`, which can be used to pass to coefficient initialization generics of _olo_fix_).

```vhdl
-- Read a complete file and return all samples as real values.
impure function fixFileReadReal (filePath : string; fmt : FixFormat_t) return RealArray_t;

-- Read a complete file and return all samples as a comma-separated string of real values.
impure function fixFileReadString (filePath : string; fmt : FixFormat_t) return string;
```

Usage example:

```vhdl
constant Fmt_c    : FixFormat_t := cl_fix_format_from_string("(1,0,15)");
constant Values_c : RealArray_t := fixFileReadReal("stimuli.fix", Fmt_c);
constant String_c : string      := fixFileReadString("stimuli.fix", Fmt_c);
```

### Internal Functions

The following functions are used in _Open Logic_ internally but they are not intended for use by the user and hence
they are undocumented

```vhdl
function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;
```
