#Load constraints with correct processing order
namespace eval fusesoc_wrapper {

	variable fileLoc [file normalize [file dirname [info script]]]

	add_files -fileset constrs_1 -norecurse $fileLoc/constraints_amd.tcl
	set_property used_in_synthesis false [get_files $fileLoc/constraints_amd.tcl]
	set_property used_in_simulation false [get_files $fileLoc/constraints_amd.tcl]
	set_property PROCESSING_ORDER LATE [get_files $fileLoc/constraints_amd.tcl]
}

