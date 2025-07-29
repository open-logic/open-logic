source ../../../../tools/questa/vcom_sources.tcl
vcom ./fix_formats_pkg.vhd

set StdArithNoWarnings 1
set NumericStdNoWarnings 1

proc olo_fix_tutorial {tb_name} {
    if {$tb_name == "controller_verilog"} {
        vlog ./$tb_name.sv
    } else {
        vcom ./$tb_name.vhd
    }
    vcom ./controller_tb.vhd

    vsim work.controller_tb
    add wave *

    run -all
}



