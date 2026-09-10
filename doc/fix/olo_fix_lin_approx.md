<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_lin_approx

[Back to **Entity List**](../EntityList.md)

## Status Information

This is a pure Python utility and therefore does not come with VHDL simulation status.

Python Source: [olo_fix_lin_approx](../../src/fix/python/olo_fix/olo_fix_lin_approx.py)<br />
Related Entity: [olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md)

## Description

_olo_fix_lin_approx_ is a bit-true model **and** a code generator for function approximations. Any function can be
approximated by a table containing the function value (_offset_) and its derivative (_gradient_) for regularly spaced
points, plus linear interpolation between those points.

This is not just one component but a whole family of components. All approximations share the same HDL implementation
of the calculation ([olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md)) and only differ in number formats and
table content. The HDL is therefore not written by hand but generated from Python.

The typical workflow is:

1. Describe the approximation in a configuration object (_olo_fix_lin_approx_cfg_).
2. Iterate on the settings using _analyze()_ until the accuracy and the resource usage fit the needs.
3. Generate the VHDL entity (_generate_entity()_) and - optionally - a bit-true testbench (_generate_tb()_).
4. Use the generated entity in the HDL design and the Python object as bit-true model in the Python design.

For details about the approximation itself, refer to [olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md).

## Usage

### Describing an Approximation

```python
from olo_fix import olo_fix_lin_approx, olo_fix_lin_approx_cfg
from en_cl_fix_pkg import *
import numpy as np

cfg = olo_fix_lin_approx_cfg(
    function=lambda x: np.sin(x*2*np.pi)*(1 - 2**-16),  # Prevent +1.0 from occurring
    in_fmt=FixFormat(0, 0, 16),
    out_fmt=FixFormat(1, 0, 16),
    offs_fmt=FixFormat(1, 0, 18),
    grad_fmt=FixFormat(1, 3, 12),
    points=256,
    name="sin16b")
my_approx = olo_fix_lin_approx(cfg)
```

The function is approximated over the **full range** of _in_fmt_. Lambdas can be used to scale the X and Y axes, as
shown above where the input range [0, 1) is mapped to one full period of the sine.

### Designing an Approximation

_analyze()_ plots the approximation against the ideal function, prints the approximation error and prints the value
ranges required for the offset and gradient tables. It is meant to be used interactively while choosing settings and is
not part of the bit-true model.

```python
my_approx.analyze()
```

Typical iteration steps are:

- Increase _points_ if the approximation error is too large (the error scales roughly with _1/points^2_).
- Adapt _offs_fmt_ and _grad_fmt_ to the ranges printed by _analyze()_ - the higher their resolution the smaller the
  output error - but also the higher the memory consumption for the table.
- Restrict _valid_range_ if the function is only used on a part of the input range (e.g. _1/x_ or _sqrt(x)_ have very
  steep gradients close to zero). Table entries outside the valid range are still generated but they are not used for
  the analysis and for the generated testbench.

### Generating Code

```python
my_approx.generate_entity("./hdl")     # Generates ./hdl/olo_fix_lin_approx_sin16b.vhd
my_approx.generate_tb("./testbench")   # Generates the testbench plus the co-simulation data files
```

_generate_entity()_ writes a self-contained VHDL entity that contains the table (as ROM) and instantiates
[olo_fix_lin_approx_calc](./olo_fix_lin_approx_calc.md). The entity has the following interface:

```vhdl
entity olo_fix_lin_approx_sin16b is
    generic (
        MemStyle_g : string := "auto"    -- Resource control for the table
    );
    port (
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        In_Valid   : in    std_logic := '1';
        In_Data    : in    std_logic_vector(16 - 1 downto 0);
        Out_Valid  : out   std_logic;
        Out_Result : out   std_logic_vector(17 - 1 downto 0)
    );
end entity;
```

_generate_tb()_ writes a [VUnit](https://vunit.github.io/) testbench that checks the generated HDL against the Python
model. It uses the same verification components as all other _olo_fix_ testbenches
(_olo_test_fix_stimuli_vc_ / _olo_test_fix_checker_vc_) and it also writes the co-simulation files containing the
stimuli and the expected responses.

If _Open Logic_ is compiled into a library other than _olo_, the library name can be passed to both functions through
the _olo_library_ argument.

### Using the Bit-True Model

```python
out_data = my_approx.process(in_data)
```

The model is stateless, hence _next()_ and _process()_ are identical. The result is bit-true to the generated HDL.

## Class Descriptions

Generally the methods are documented in python docstring format.

### olo_fix_lin_approx_cfg

Data container describing one approximation.

| Argument    | Type                | Default        | Description                                                  |
| :---------- | :------------------ | :------------- | :----------------------------------------------------------- |
| function    | Callable            | -              | Function to approximate over the full range of _in_fmt_. Must accept numpy arrays. |
| in_fmt      | FixFormat           | -              | Format of the input to the approximation                     |
| out_fmt     | FixFormat           | -              | Format of the output of the approximation                    |
| offs_fmt    | FixFormat           | -              | Format of the offset table (function values at the segment centers) |
| grad_fmt    | FixFormat           | -              | Format of the gradient table (derivatives at the segment centers) |
| points      | int                 | -              | Number of segments in the table. Must be a power of two and smaller than _2^width(in_fmt)_ |
| name        | str                 | -              | Name suffix of the approximator generated. The entity generated is named _olo_fix_lin_approx_\<name\>_ |
| valid_range | tuple               | full _in_fmt_  | Range in which the approximation is valid. Clipped to the range representable by _in_fmt_. |
| round       | FixRound            | NonSymPos_s    | Rounding mode of the output stage                            |
| saturate    | FixSaturate         | Sat_s          | Saturation mode of the output stage                          |

Most things are self-explanatory. One thing being worth an explanation is _valid_range_. This setting does allow
defining approximations that are only valid in a certain range. For example it is possible using _in_fmt=(0,0,10)_
(which has a range of 0...~1.0) but define _valid_range=(0.25, 1.0)_ to design an approximation that is not valid
in the lowest quarter of the values (e.g in case the value is very large in this area).

### olo_fix_lin_approx

The methods are grouped the same way as in the source code: the bit-true model first, then the code generation and
finally the helpers used while designing an approximation.

| Method               | Description                                                                     |
| :------------------- | :------------------------------------------------------------------------------ |
| reset()              | Does nothing - the approximation is stateless. Exists for consistency with the other olo_fix models |
| next(in_data)        | Bit-true calculation of the approximation for the samples passed                |
| process(in_data)     | Identical to _next()_ - the approximation is stateless                          |
| generate_entity(...) | Generate the VHDL entity (including the table) and return the entity name       |
| generate_tb(...)     | Generate the bit-true testbench plus co-simulation files and return the TB name  |
| entity_name          | Property containing the name of the entity generated                            |
| analyze(...)         | Design helper - plot accuracy and print the ranges required for the tables      |

## Verification

The bit-trueness between the Python model and the generated HDL is verified in the _Open Logic_ regression. This
co-simulation also covers the code generation (including the templates), hence the code generation is excluded from the
python unit-test coverage. The samples used are defined in
[test/fix/olo_fix_lin_approx/lin_approx_codegen.py](../../test/fix/olo_fix_lin_approx/lin_approx_codegen.py) and cover
all combinations of signed/unsigned input and signed/unsigned output. The entities, testbenches and co-simulation files
are generated by _sim/codegen.py_ before VUnit detects the files.
