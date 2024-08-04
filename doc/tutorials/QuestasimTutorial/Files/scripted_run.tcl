source ../../../../tools/questa/vcom_sources.tcl
vcom ./questa_tutorial.vhd

vsim work.questa_tutorial
add wave *
do ./stimuli.do

