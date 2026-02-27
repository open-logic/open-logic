<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_pkg_writer

[Back to **Entity List**](../EntityList.md)

## Status Information

This is a pure Python utility and therefore does not come with VHDL simulation status.

Python Source: [olo_fix_pkg_writer](../../src/fix/python/olo_fix_pkg_writer.py)

## Usage

A detailed example for the usage of _olo_fix_pkg_writer_ can be found in the
[OloFixTutorial](../tutorials/OloFixTutorial.md). Below is a brief example for the usage of _olo_fix_pkg_writer_.

The package is used as shown below:

```python
someFormat = FixFormat(1, 8, 23)
...
writer = olo_fix_pkg_writer()
writer.add_constant("SomeInt", int, 5)
writer.add_constant("SomeFormat", FixFormat, someFormat) # Constant of FixFormat are not allowed for Verilog
writer.add_constant("SomeFormatStr", FixFormat, someFormat, as_string=True)
writer.add_vector("SomeIntVector", int, [1, 2, 3])
# Write VHDL package
writer.write_vhdl_pkg("my_pkg", out_dir)
# Write Verilog header
writer.write_verilog_header("my_hdr", out_dir)
```

This will generate a VHDL package with the following content:

```vhdl
package my_pkg is
    constant SomeInt : integer := 5;
    constant SomeFormat : FixFormat_t := (1, 8, 23);
    constant SomeFormatStr : string := "(1, 8, 23)";
    constant SomeIntVector : IntegerArray_t := (1, 2, 3);
end package;
```

And a Verilog header file with the following content:

```verilog
package my_hdr;
    localparam int SomeInt = 5;
    localparam string SomeFormatStr = "(1, 8, 23)";
    localparam int SomeIntVector [0:2] = '{1, 2, 3};
endpackage : my_hdr
```

## Method Descriptions

Generally the methods are documenged in python docstring format.

### add_constant

```python
def add_constant(self, name: str, type: type, value, as_string=False):
```

Add a constant to the package.

- _name_: Name of the constant
- _type_: Type of the constant
  - Valid options are: int, FixFormat, str, float
- value: Value of the constant
- _as_string_: Whether to write the constant as string
  - _olo_fix_ entities take number formats as string for verilog compatibility
  - For formats that are passed to _olo_fix_ entities, it is recommended to use _as_string=True_ to avoid needless
    conversion to string in the HDL Code

Note that in Verilog, no _FixedFormat_ type exists. So `typle=FixFormat` is only allowed in combination
with `as_string=True` for Verilog. In VHDL, both options are allowed and can be used as needed.

### add_vector

```python
def add_vector(self, name: str, type: type, values: list, as_string=False):
```

Same as _add_constant_ but for vectors (1D arrays).

### write_vhdl_pkg

```python
def write_vhdl_pkg(self, pkg_name: str, out_dir: str, olo_library: str = "olo"):
```

Write VHDL package.

- _pkg_name_: Name of the package
  - The file-name is `<pkg_name>.vhd`
- _out_dir_: Directory to write the package to
- _olo_library_: Library Open Logic is compiled into
  - By default Open Logic is compoled to the VHDL library `olo`
  - Only change this setting if you manually changed the library Open Logic is compiled into

### write_verilog_header

```python
def write_verilog_header(self, pkg_name: str, out_dir: str):
```

Write Verilog header file.

- _pkg_name_: Name of the header file
  - The file-name is `<pkg_name>.vh`
- _out_dir_: Directory to write the header file to
