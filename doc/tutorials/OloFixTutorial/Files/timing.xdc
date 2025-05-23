# Constraints for Vivado implementation

##Clock signal
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS18} [get_ports Clk]
create_clock -period 8.000 -name Clk -waveform {0.000 4.000} -add [get_ports Clk]

##Reset
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS18} [get_ports Rst]; 

#KI
set_property -dict {PACKAGE_PIN P15   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[0]}];
set_property -dict {PACKAGE_PIN W13   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[1]}];
set_property -dict {PACKAGE_PIN T16   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[2]}];
set_property -dict {PACKAGE_PIN K18   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[3]}];
set_property -dict {PACKAGE_PIN P16   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[4]}];
set_property -dict {PACKAGE_PIN K19   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[5]}];
set_property -dict {PACKAGE_PIN Y16   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[6]}];
set_property -dict {PACKAGE_PIN M14   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ki[7]}];

#KP
set_property -dict {PACKAGE_PIN M15   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[0]}];
set_property -dict {PACKAGE_PIN G14   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[1]}];
set_property -dict {PACKAGE_PIN D18   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[2]}];
set_property -dict {PACKAGE_PIN V18   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[3]}];
set_property -dict {PACKAGE_PIN V17   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[4]}];
set_property -dict {PACKAGE_PIN V15   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[5]}];
set_property -dict {PACKAGE_PIN V16   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[6]}];
set_property -dict {PACKAGE_PIN F17   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[7]}];
set_property -dict {PACKAGE_PIN M17   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[8]}];
set_property -dict {PACKAGE_PIN R19   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[9]}];
set_property -dict {PACKAGE_PIN R17   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[10]}];
set_property -dict {PACKAGE_PIN P18   IOSTANDARD LVCMOS18} [get_ports {Cfg_Kp[11]}];

#ILIM
set_property -dict {PACKAGE_PIN E17   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[0]}];
set_property -dict {PACKAGE_PIN E19   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[1]}];
set_property -dict {PACKAGE_PIN F16   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[2]}];
set_property -dict {PACKAGE_PIN F19   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[3]}];
set_property -dict {PACKAGE_PIN F20   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[4]}];
set_property -dict {PACKAGE_PIN G19   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[5]}];
set_property -dict {PACKAGE_PIN G20   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[6]}];
set_property -dict {PACKAGE_PIN H15   IOSTANDARD LVCMOS18} [get_ports {Cfg_Ilim[7]}];

#In_Valid
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS18} [get_ports In_Valid]; 

#In_Actual
set_property -dict {PACKAGE_PIN U12   IOSTANDARD LVCMOS18} [get_ports {In_Actual[0]}];
set_property -dict {PACKAGE_PIN W19   IOSTANDARD LVCMOS18} [get_ports {In_Actual[1]}];
set_property -dict {PACKAGE_PIN W18   IOSTANDARD LVCMOS18} [get_ports {In_Actual[2]}];
set_property -dict {PACKAGE_PIN Y19   IOSTANDARD LVCMOS18} [get_ports {In_Actual[3]}];
set_property -dict {PACKAGE_PIN U19   IOSTANDARD LVCMOS18} [get_ports {In_Actual[4]}];
set_property -dict {PACKAGE_PIN U18   IOSTANDARD LVCMOS18} [get_ports {In_Actual[5]}];
set_property -dict {PACKAGE_PIN W20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[6]}];
set_property -dict {PACKAGE_PIN V20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[7]}];
set_property -dict {PACKAGE_PIN U20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[8]}];
set_property -dict {PACKAGE_PIN T20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[9]}];
set_property -dict {PACKAGE_PIN P20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[10]}];
set_property -dict {PACKAGE_PIN N20   IOSTANDARD LVCMOS18} [get_ports {In_Actual[11]}];

#In_Target
set_property -dict {PACKAGE_PIN E18   IOSTANDARD LVCMOS18} [get_ports {In_Target[0]}];
set_property -dict {PACKAGE_PIN G17   IOSTANDARD LVCMOS18} [get_ports {In_Target[1]}];
set_property -dict {PACKAGE_PIN G18   IOSTANDARD LVCMOS18} [get_ports {In_Target[2]}];
set_property -dict {PACKAGE_PIN H17   IOSTANDARD LVCMOS18} [get_ports {In_Target[3]}];
set_property -dict {PACKAGE_PIN H16   IOSTANDARD LVCMOS18} [get_ports {In_Target[4]}];
set_property -dict {PACKAGE_PIN D20   IOSTANDARD LVCMOS18} [get_ports {In_Target[5]}];
set_property -dict {PACKAGE_PIN D19   IOSTANDARD LVCMOS18} [get_ports {In_Target[6]}];
set_property -dict {PACKAGE_PIN B20   IOSTANDARD LVCMOS18} [get_ports {In_Target[7]}];
set_property -dict {PACKAGE_PIN C20   IOSTANDARD LVCMOS18} [get_ports {In_Target[8]}];
set_property -dict {PACKAGE_PIN A20   IOSTANDARD LVCMOS18} [get_ports {In_Target[9]}];
set_property -dict {PACKAGE_PIN B19   IOSTANDARD LVCMOS18} [get_ports {In_Target[10]}];
set_property -dict {PACKAGE_PIN U17   IOSTANDARD LVCMOS18} [get_ports {In_Target[11]}];

#Out_Valid
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS18} [get_ports Out_Valid]; 

#Out_Result
set_property -dict {PACKAGE_PIN L14   IOSTANDARD LVCMOS18} [get_ports {Out_Result[0]}];
set_property -dict {PACKAGE_PIN K16   IOSTANDARD LVCMOS18} [get_ports {Out_Result[1]}];
set_property -dict {PACKAGE_PIN K14   IOSTANDARD LVCMOS18} [get_ports {Out_Result[2]}];
set_property -dict {PACKAGE_PIN N16   IOSTANDARD LVCMOS18} [get_ports {Out_Result[3]}];
set_property -dict {PACKAGE_PIN L15   IOSTANDARD LVCMOS18} [get_ports {Out_Result[4]}];
set_property -dict {PACKAGE_PIN J16   IOSTANDARD LVCMOS18} [get_ports {Out_Result[5]}];
set_property -dict {PACKAGE_PIN J14   IOSTANDARD LVCMOS18} [get_ports {Out_Result[6]}];
set_property -dict {PACKAGE_PIN T15   IOSTANDARD LVCMOS18} [get_ports {Out_Result[7]}];
set_property -dict {PACKAGE_PIN T14   IOSTANDARD LVCMOS18} [get_ports {Out_Result[8]}];
set_property -dict {PACKAGE_PIN T12   IOSTANDARD LVCMOS18} [get_ports {Out_Result[9]}];
set_property -dict {PACKAGE_PIN T11   IOSTANDARD LVCMOS18} [get_ports {Out_Result[10]}];
set_property -dict {PACKAGE_PIN T10   IOSTANDARD LVCMOS18} [get_ports {Out_Result[11]}];




