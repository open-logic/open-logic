#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_base_reset_gen
# Load in vivado using "read_xdc -ref olo_base_reset_gen <path>/olo_base_reset_gen.tcl"

# Delay of the async reset input does not play any role
set_false_path -to [get_cell RstSyncChain*]

#  Constrain input to synchronizer in case of synchronous assertion
set period [get_property PERIOD [get_clocks -of_objects [get_cells *DsSync*]]]
set_max_delay -from [get_cell RstSyncChain*] -to [get_cell *DsSync*] -datapath_only $period 
