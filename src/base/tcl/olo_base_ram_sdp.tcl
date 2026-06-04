#-----------------------------------------------------------------------------
#-  Copyright (c) 2025 by Oliver Bründler
#-  All rights reserved.
#-  Oliver Bründler
#-----------------------------------------------------------------------------

# Scoped constraints for olo_base_ram_sdp
# Load in Vivado using "read_xdc -ref olo_base_ram_sdp <path>/olo_base_ram_sdp.tcl"

# These constraints are only necessary when the RAM is implemented as LUTRAM.
# In this case there is a timing path from the write clock to the first read data register.
# See https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/LUTRAM-Read/Write-Potential-Collision.
# This path can be safely ignored in order for timing to pass because the logic of the async FIFO
# can never generate the same read and write addresses during active read and write operations.
# This is not needed for BRAM since the first read data register is located in the BRAM primitive.
set mem_cells [get_cells -hierarchical g_async.Mem_v* -quiet]

if {[llength $mem_cells] > 0} {
  set ram_type [expr {[regexp {LUTRAM} [get_property PRIMITIVE_SUBGROUP $mem_cells]] ? "LUTRAM" : ""}]

  if {$ram_type eq "LUTRAM"} {
      set launch_clk [get_clocks -of_objects [get_cell -hierarchical g_async.Mem_v*]]
      set latch_clk [get_clocks -of_objects [get_cell -hierarchical g_async.RdPipe_reg[1][*]]]

      set period [get_property -min PERIOD [concat $launch_clk $latch_clk]]

      set_max_delay -from $launch_clk -to [get_cell -hierarchical g_async.RdPipe_reg[1][*]] -datapath_only $period

      # Waive "LUTRAM read/write potential collision" CDC warning from "report_cdc" command.
      create_waiver -type CDC -id "CDC-26" \
        -from [get_pins *.i_ram/g_async.Mem_v*/*/CLK] \
        -to [get_pins *.i_ram/g_async.RdPipe_reg[1][*]/D] \
        -description "Read/Write logic (like for Async FIFO) should ensure no collision"
  }
}
