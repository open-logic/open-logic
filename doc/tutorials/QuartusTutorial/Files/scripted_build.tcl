# Load Quartus Prime Tcl Project package
package require ::quartus::project
package require ::quartus::flow

#Create project
file mkdir tutorial_prj
cd ./tutorial_prj
project_new -revision tutorial_prj tutorial_prj

# Project Settings
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CEBA4F23C7
set_global_assignment -name TOP_LEVEL_ENTITY quartus_tutorial

#Add top level
set_global_assignment -name VHDL_FILE "../quartus_tutorial.vhd" -library prj

#Add OLO
source ../../../../../tools/quartus/import_sources.tcl

#Load Pinout
source ../pinout.tcl

#Load Timing
set_global_assignment -name SDC_FILE ../timing.sdc

# Commit assignments
export_assignments

# Build project
execute_flow -compile

# Revert path
cd ..

