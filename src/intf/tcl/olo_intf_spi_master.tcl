#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_intf_spi_master
# Load in vivado using "read_xdc -ref olo_intf_spi_master <path>/olo_intf_spi_master.tcl"

# The MISO signal is synchronized through SCLK anyways. Constraints are given to
# make sure it arrives within one clock and to not hassle with timing errors
# which do not exist in reality
 
#Get MISO port
set in_ports [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects [get_nets *SpiMiso_i*]]
#Get clock (busy is not involved, any FF will do)
set latch_clk [get_clocks -of_objects [get_cells *Busy*]]

#Set max delay 0 to ensure delay Port->FF is less than one clock period
set_input_delay -clock $latch_clk -add_delay -max 0.0 $in_ports

#Min delay does not play any role. Set to one clock period to avoid needless hold-warnings.
set_input_delay -clock $latch_clk -add_delay -min [get_property PERIOD $latch_clk] $in_ports


