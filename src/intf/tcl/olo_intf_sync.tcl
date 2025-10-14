#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bruendler
#-  Oliver Bruendler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_intf_sync
# Load in vivado using "read_xdc -ref olo_intf_sync <path>/olo_intf_sync.tcl"
 
#Get D-Pins of Input FFs
set in_ffs [get_pins -of_objects [get_cells *Reg0*] -filter {REF_PIN_NAME == D}]
#Get Ports connected to those nets
set in_ports [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects [get_nets -of_objects $in_ffs]]
#Get clock
set latch_clk [get_clocks -of_objects [get_cells *Reg0*]]

#Set max delay to ensure delay Port->FF is less than one clock period
set_max_delay -datapath_only [get_property PERIOD $latch_clk] -from $in_ports

#Make sure the first FF is not placed in the IOB. This ensures both FFs are placed in the same slice.
set_property IOB FALSE [get_cells *Reg0*]
