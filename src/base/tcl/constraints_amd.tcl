#Constraints must be enabled for Implementation only (disabled for synthesis)


#olo_base_cc_reset
#.. no constraints required

#olo_base_cc_bits
foreach my_cell [get_cell -hierarchical -quiet *i_olo_base_cc_bits_constraints_region] {
    set launch_clk [get_clocks -of_objects [get_pins $my_cell/In_Clk]]
    set latch_clk [get_clocks -of_objects [get_pins $my_cell/Out_Clk]]
    set period [expr min([get_property PERIOD $launch_clk], [get_property PERIOD $latch_clk])]
    puts "OLO AUTO-CONSTRAINT - olo_base_cc_bits: set_max_delay -from \[get_clocks $launch_clk\] -to \[get_cell -filter {TYPE == \"Flop & Latch\"}  $my_cell/Reg0*\] -datapath_only $period"
    set_max_delay -from [get_clocks $launch_clk] -to [get_cell -filter {TYPE == "Flop & Latch"}  $my_cell/Reg0*] -datapath_only $period
}

#olo_base_cc_pulse
#.. covered by olo_base_cc_bits

#olo_base_cc_simple
foreach my_cell [get_cell -hierarchical -quiet *i_olo_base_cc_simple_constraints_region] {
    set launch_clk [get_clocks -of_objects [get_pins $my_cell/In_Clk]]
    set latch_clk [get_clocks -of_objects [get_pins $my_cell/Out_Clk]]
    set period [expr min([get_property PERIOD $launch_clk], [get_property PERIOD $latch_clk])]
    puts "OLO AUTO-CONSTRAINT - olo_base_cc_simple: set_max_delay -from \[get_clocks $launch_clk\] -to \[get_cell -filter {TYPE == \"Flop & Latch\"}  $my_cell/Out_Data_Sig*\] -datapath_only $period"
    set_max_delay -from [get_clocks $launch_clk] -to [get_cell -filter {TYPE == "Flop & Latch"}  $my_cell/Out_Data_Sig*] -datapath_only $period
}
