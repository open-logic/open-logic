#Configure Clock
create_clock -period 8.000 -name Clk -waveform {0.000 4.000} -add [get_ports Clk]

