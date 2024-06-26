#Automatically load all constraints

variable fileLoc [file normalize [file dirname [info script]]]

puts "OLO LOAD read_xdc for intf"

read_xdc -ref olo_intf_sync $fileLoc/olo_intf_sync.tcl
read_xdc -ref olo_intf_i2c_master $fileLoc/olo_intf_i2c_master.tcl


