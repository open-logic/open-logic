#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_base_cc_bits
# Load in vivado using "read_xdc -ref olo_base_reset_gen <path>/olo_base_reset_gen.tcl"

#Delay of the async reset input does not play any role
set_false_path -to [get_cell RstSyncChain*]
