#-----------------------------------------------------------------------------
#-  Copyright (c) 2024 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_intf_i2c_master
# Load in vivado using "read_xdc -ref olo_intf_sync <path>/olo_intf_i2c_master.tcl"
 
#Get Ports
set scl_port [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects [get_nets *Scl*]]
set sda_port [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects [get_nets *Sda*]]

#Input delays are set by the olo_intf_sync constraints for the input synchronizer

#Output delays
#Min delay does not play any role. 20 ns is sufficient to avoid failures.
set tolerance 20.000
set_output_delay -add_delay -min $tolerance $scl_port
set_output_delay -add_delay -min $tolerance $sda_port
set_output_delay -add_delay -max -$tolerance $scl_port
set_output_delay -add_delay -max -$tolerance $sda_port

