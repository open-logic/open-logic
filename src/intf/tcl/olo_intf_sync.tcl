#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_intf_sync
# Load in vivado using "read_xdc -ref olo_intf_sync <path>/olo_intf_sync.tcl"
 
#Get D-Pins of Input FFs
set in_ffs [get_pins -of_objects [get_cells *Reg0*] -filter {REF_PIN_NAME == D}]
#Get Ports connected to those nets
set in_ports [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects [get_nets -of_objects $in_ffs]]
#Get clock
set latch_clk [get_clocks -of_objects [get_cells *Reg0*]]

#Set max delay 0 to ensure delay Port->FF is less than one clock period
set_input_delay -clock $latch_clk -add_delay -max 0.0 $in_ports

#Min delay does not play any role. Set to one clock period to avoid needless hold-warnings.
set_input_delay -clock $latch_clk -add_delay -min [get_property PERIOD $latch_clk] $in_ports


