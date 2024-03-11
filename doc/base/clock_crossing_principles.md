<img src="../Logo.png" alt="Logo" width="400">

# Clock Crossing Principles

[Back to **Entity List**](../EntityList.md)

## Constraining

### Manual Constraining

All clock-crossings require the following constraint:

`set_max_delay -from [get_clocks <src-clock>] to [get_clocks <dst-clock>] -datapath_only <period-of-faster-clock>`

### Automatic Constraining

For *AMD* tools (*Vivado*) an automatic constraint file exist, which automatically identifies all *Open Logic* clock-crossings and constrains them correctly. 

You can just add the file */src/base/tcl/constraints_amd.tcl* to your Vivado Project and enable it for implementation only (they cause errors when used for Synthesis):

![auto constraining](./auto_constraining.png)

The script only constrains data-paths within clock-crossings. If there are any other paths between the clocks, those are not constrained and hence still correctly reported as problems.

The constraints generated are reported with the prefix `OLO AUTO-CONSTRAINT -` so you can always check if auto constraining works correctly.



## Reset Handling

Most clock crossings need logic in both clock domains to be reset if a reset in one of the two domains is detected. The logic to transfer a reset from one clock domain to the other and ensure that both clock domains stay in reset at the same time for at least one clock cycle before resets are released is implemented in [olo_base_cc_reset](./olo_base_cc_reset.md), which is used within most clock crossings.

Because logic around clock crossings usually must be reset along with them, most clock crossings provide not only reset inputs (*Xxx_RstIn*) but also reset outputs (*Xxx_RstOut*) on both clock domains. The reset input is the port through which a reset is signaled. The reset output does indicate that a reset is active on the related clock domain (because of a reset input being asserted on one or the other clock domain). 

Any logic that must be reset when the clock crossing is reset shall be connected to the reset output signals (*Xxx_RstOut*).

![Reset CC](./clock_crossings/reset_cc.png)

