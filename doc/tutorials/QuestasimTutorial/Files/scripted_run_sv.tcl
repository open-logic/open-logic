source ../../../../tools/questa/vcom_sources.tcl
vlog ./questa_tutorial.sv

vsim work.questa_tutorial
add wave *
do ./stimuli.do

