#Create Project
create_project tutorial_prj ./tutorial_prj -part xc7z010clg400-1
set_property target_language VHDL [current_project]

#Add OLO
source ../../../../tools/vivado/import_sources.tcl

#Add Files
add_files ./vivado_tutorial.vhd
add_files -fileset constrs_1 -norecurse ./pinout.xdc

#Build
set_property top vivado_tutorial [current_fileset]
launch_runs impl_1 -to_step write_bitstream -jobs 3
wait_on_run -timeout 30 impl_1
