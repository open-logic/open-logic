<img src="../Logo.png" alt="Logo" width="400">

# Clock Crossing Principles

[Back to **Entity List**](../EntityList.md)

## Constraining

### Manual Constraining

All clock-crossings require the following constraints:

```
set_max_delay -from [get_clocks <src-clock>] to [get_clocks <dst-clock>] -datapath_only <period-of-faster-clock>
set_max_delay -from [get_clocks <dst-clock>] to [get_clocks <src-clock>] -datapath_only <period-of-faster-clock>
```


**Note:** For Intel Quartus, manual constraints are required because automatic constraining (scoped constraints) is not supported by Quartus.

**Note:** For using *Open Logic* from Verilog, manual constraints are required. Automatic constraining currently only works for VHDL.

### Automatic Constraining

For *AMD* tools (*Vivado*) scoped constraints files exist, which automatically identify all *Open Logic* clock-crossings and constrain them correctly. When using the `import_sources.tcl` script to add *Open Logic* to your project (see [How To ...](../HowTo.md) section), the constraints are applied automatically.

To alternatively configure usage of the scoped constraints manually , follow the steps below.

1. Create an empty TCL file and add it to the Vivado project as constraint.
2. Enable the TCL file **for implementation only** (see screenshot below)
3. In the TCL file, add a single line `source <path-to-open-logic>/src/base/tcl/constraints_amd.tcl`

![auto constraining](./clock_crossings/auto_constraining.png)



## Reset Handling

Most clock crossings need logic in both clock domains to be reset if a reset in one of the two domains is detected. The logic to transfer a reset from one clock domain to the other and ensure that both clock domains stay in reset at the same time for at least one clock cycle before resets are released is implemented in [olo_base_cc_reset](./olo_base_cc_reset.md), which is used within most clock crossings.

Because logic around clock crossings usually must be reset along with them, most clock crossings provide not only reset inputs (*Xxx_RstIn*) but also reset outputs (*Xxx_RstOut*) on both clock domains. The reset input is the port through which a reset is requested. The reset output does indicate that a reset is active on the related clock domain (because of a reset input being requested on one or the other clock domain). 

Any logic that must be reset when the clock crossing is reset shall be connected to the reset output signals (*Xxx_RstOut*).

![Reset CC](./clock_crossings/reset_cc.png)

