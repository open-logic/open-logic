#Automatically load all constraints
namespace eval olo_all_constraints_amd {

	variable fileLoc [file normalize [file dirname [info script]]]

	puts "OLO LOAD ALL CONSTRAINTS"

	#axi does not have constraints
	foreach area {base intf} {
		source $fileLoc/../../src/$area/tcl/olo_${area}_constraints_amd.tcl
	}
}

