#Automatically load all constraints
namespace eval olo_intf_constraints_amd {
	variable fileLoc [file normalize [file dirname [info script]]]

	puts "OLO LOAD read_xdc for intf"

	read_xdc -quiet -ref olo_intf_sync $fileLoc/olo_intf_sync.tcl
	read_xdc -quiet -ref olo_intf_spi_master $fileLoc/olo_intf_spi_master.tcl

	set_property used_in_synthesis false [get_files $fileLoc/olo_intf_sync.tcl]
	set_property used_in_synthesis false [get_files $fileLoc/olo_intf_spi_master.tcl]

	set_property PROCESSING_ORDER LATE [get_files $fileLoc/olo_intf_sync.tcl]
	set_property PROCESSING_ORDER LATE [get_files $fileLoc/olo_intf_spi_master.tcl]

	set_msg_config -id {Designutils 20-1281} -new_severity WARNING
}

