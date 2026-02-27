<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_cosim

[Back to **Entity List**](../EntityList.md)

## Status Information

This is a pure Python utility and therefore does not come with VHDL simulation status.

Python Source: [olo_fix_cosim](../../src/fix/python/olo_fix_cosim.py)

## Usage

A detailed example for the usage of _olo_fix_cosim_ can be found in the
[OloFixTutorial](../tutorials/OloFixTutorial.md). Below is a brief example for the usage of _olo_fix_cosim_.

The package is used as shown below:

```python
someFormat = FixFormat(1, 8, 23)
...
writer = olo_fix_cosim("./cosim_directory")
writer.write_cosim_files([1,2,3], someFormat, "signalA.fix")
writer.write_cosim_files([4,5,6], someFormat, "signalB.fix")
```

This will generate two files in the `./cosim_directory`. Both files are meant to be read by
[olo_fix_sim_stimuli](./olo_fix_sim_stimuli.md) and [olo_fix_sim_checker](./olo_fix_sim_checker.md) in HDL simulations.

The files contain the fixed-point format (to check if the format written in python matches the format expected in HDL)
and the samples stored in hex.
