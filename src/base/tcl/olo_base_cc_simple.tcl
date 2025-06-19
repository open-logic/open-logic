#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_base_cc_simple
# Load in vivado using "read_xdc -ref olo_base_cc_simple <path>/olo_base_cc_simple.tcl"

#Get clocks based on cells, not ports because get_ports does not work reliable in scoped constraints
set launch_clk [get_clocks -of_objects [get_cell DataLatchIn*]]
set latch_clk [get_clocks -of_objects [get_cell Out_Data_Sig*]]

set period [expr min([get_property PERIOD $launch_clk], [get_property PERIOD $latch_clk])]


set_max_delay -from $launch_clk -to [get_cell Out_Data_Sig*] -datapath_only $period
set_bus_skew -from [get_cell DataLatchIn*] -to [get_cell Out_Data_Sig*] $period

