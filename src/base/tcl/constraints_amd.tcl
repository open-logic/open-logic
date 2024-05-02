#Automatically load all constraints

variable fileLoc [file normalize [file dirname [info script]]]

puts "OLO LOAD read_xdc -quiet -ref olo_base_cc_reset $fileLoc/olo_base_cc_reset.tcl"

read_xdc -quiet -ref olo_base_cc_reset $fileLoc/olo_base_cc_reset.tcl
read_xdc -quiet -ref olo_base_cc_bits $fileLoc/olo_base_cc_bits.tcl
read_xdc -quiet -ref olo_base_cc_simple $fileLoc/olo_base_cc_simple.tcl

