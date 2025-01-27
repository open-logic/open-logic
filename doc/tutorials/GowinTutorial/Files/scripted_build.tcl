# Build VHDL tutorial from TCL shell in GowinEDA GUI

# Create Project
set oloRoot [file normalize "[file dirname [info script]]/../../../.."]
create_project -name tutorial_prj -dir . -pn GW1N-LV4LQ144C6/I5 -device_version D
# The console in the GUI does not open the project upon "create_project", but the shell version does.
if {![info exists RunFromShell]} {
    after 5000
    open_project ./tutorial_prj/tutorial_prj.gprj
}
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name gowin_tutorial
set_option -vhdl_std vhd2008
set_option -print_all_synthesis_warning 1

#Add OLO
source $oloRoot/tools/gowin/import_sources.tcl

#Add Files
add_file -type vhdl "$oloRoot/doc/tutorials/GowinTutorial/Files/gowin_tutorial.vhd"
add_file -type cst "$oloRoot/doc/tutorials/GowinTutorial/Files/pinout.cst"
add_file -type sdc "$oloRoot/doc/tutorials/GowinTutorial/Files/timing.sdc"

#Build
set_option -top_module gowin_tutorial
run all

puts "Done"

