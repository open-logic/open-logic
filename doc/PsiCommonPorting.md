<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Open Logic - *psi_common* Porting Guide

The aim of this document is to describe which *Open Logic* entities replace a given *psi_common* entity. 

*Open Logic* aims for minimizing code duplication. Hence in some cases multiple *psi_common* entity match to the same *Open Logic* entity, just with different Generics. 

Note that naming conventions in *Open Logic* are different. Although some entities are functionally identical, the code must be adapted to the new port-names of *Open Logic*.

| psi_common Entity                      | Open Logic Entity                                            | Comments / Generic Values                                    |
| -------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| psi_common_arb_priority                | [olo_base_arb_prio](./base/olo_base_arb_prio.md)             | -                                                            |
| psi_common_arb_round_robin             | [olo_base_arb_rr](./base/olo_base_arb_rr.md)                 | -                                                            |
| psi_common_async_fifo                  | [olo_base_fifo_async](./base/olo_base_fifo_async.md)         | -                                                            |
| psi_common_axi_master_full             | [olo_axi_master_full](./axi/olo_ax_master_full.md)           | -                                                            |
| psi_common_axi_master_simple           | [olo_axi_master_simple](./axi/olo_ax_master_simple.md)       | -                                                            |
| psi_common_axi_multi_pl_stage          | [olo_axi_pl_stage](./axi/olo_axi_pl_stage.md)                | -                                                            |
| psi_common_axi_pkg                     | Won't be ported                                              | Package only is valid for a specific AXI implementation (IFC1210) with specific address and data widths. Hence the package is not generic. |
| psi_common_axi_slave_ipif              | Not ported yet                                               | Use the AXI4-Lite version ([olo_axi_lite_slave](./axi/olo_ax_lite_slave.md)) until a full AXI4 slave is implemented. |
| psi_common_axilite_slave_ipif          | [olo_axi_lite_slave](./axi/olo_ax_lite_slave.md)             | User code interface is significantly changed.                |
| psi_common_axi_slave_ipif64            | Not ported yet                                               | Use the AXI4-Lite version ([olo_axi_lite_slave](./axi/olo_ax_lite_slave.md)) until a full AXI4 slave is implemented. |
| psi_common_bit_cc                      | [olo_base_cc_bits](./base/olo_base_cc_bits.md)<br />[olo_intf_sync](./intf/olo_intf_sync.md) | Use [olo_base_cc_bits](./base/olo_base_cc_bits.md) internally (all signals inside the FPGA) and [olo_intf_sync](./base/olo_intf_sync.md) to synchronize external signals. |
| psi_common_debouncer                   | [olo_intf_debounce](./base/olo_intf_debounce.md)             | -                                                            |
| psi_common_clk_meas                    | [olo_intf_clk_meas](./intf/olo_intf_clk_meas.md)             | -                                                            |
| psi_common_debouncer                   | [olo_intf_debounce](./base/olo_intf_debounce.md)             | -                                                            |
| pis_common_delay                       | [olo_base_delay](./base/olo_base_delay.md)                   | -                                                            |
| psi_common_delay_cfg                   | [olo_base_delay_cfg](./base/olo_base_delay_cfg.md)           | *Hold_g* behavior is not ported (considered as not generic enough for a library component). |
| psi_common_dyn_sft                     | [olo_base_dyn_sft](./base/olo_base_dyn_sft.md)               | -                                                            |
| psi_common_find_min_max                | Won't be ported                                              | The functionality is rather trivial. Because it often is used in entities that contain handwritten processing, the functionality for minimum/maximum detection can easily be implemented in handwritten code as well. |
| psi_common_i2c_master                  | [olo_intf_i2c_master](./intf/olo_intf_i2c_master.md)         | -                                                            |
| psi_common_logic_pkg                   | [olo_base_pkg_logic](./base/olo_base_pkg_logic.md)           | -                                                            |
| psi_common_math_pkg                    | [olo_base_pkg_math](./base/olo_base_pkg_math.md)             | -                                                            |
| psi_common_min_max_sum                 | Won't be ported                                              | The functionality is rather trivial. Because it often is used in entities that contain handwritten processing, the functionality for minimum/maximum/sum detection can easily be implemented in handwritten code as well. |
| psi_common_multi_pl_stage              | [olo_base_pl_stage](./base/olo_base_pl_stage.md)             | -                                                            |
| psi_common_par_ser                     | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md)         | Use the following mappings:<br />- *InWidth_g* = Width<br />- *OutWidth_g* = 1<br />- Use *Out_Ready* to control the bit-rate (e.g. through *olo_base_strobe_generator*)<br />- Some features are not 1:1 ported (e.g. overrun control and signalling start of frame) |
| psi_common_par_tdm                     | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md)         | Use the following mappings:<br />- *InWidth_g* = NumberOfChannels x ChannelWidth<br />- *OutWidth_g* = ChannelWidth |
| psi_common_par_tdm_cfg                 | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md)         | Use the following mappings:<br />- *InWidth_g* = NumberOfChannels x ChannelWidth<br />- *OutWidth_g* = ChannelWidth<br />- *In Last* = '1'<br />- *In_WordEna* = Lowest *EnabledChannels*  bits '1', others '0' |
| psi_common_ping_pong                   | Won't be ported                                              | Various vendor IP is available for making AXI4-Stream data available through AXI4 (e.g. AMD AXI4-Stream FIFO). I<br />Data handover to CPUs more-often is done through DMAs. Hence the functionality of this entity is  seldom required. |
| psi_common_pl_stage                    | [olo_base_pl_stage](./base/olo_base_pl_stage.md)             | Use *Stages_g*=1                                             |
| psi_common_prbs                        | [olo_base_prbs](./base/olo_base_prbs.md)                     | -                                                            |
| psi_common_pulse_cc                    | [olo_base_cc_pulse](./base/olo_base_cc_pulse.md)             | -                                                            |
| psi_common_pulse_generator_ctrl_static | Won't be ported                                              | Not generic enough for a library component                   |
| psi_common_pulse_shaper                | Not ported yet                                               | -                                                            |
| psi_common_pulse_shaper_cfg            | Not ported yet                                               | -                                                            |
| psi_common_ramp_gene                   | Won't be ported                                              | Not generic enough for a library component                   |
| psi_common_sdp_ram                     | [olo_base_ram_sdp](./base/olo_base_ram_sdp.md)               | Use *UseByteEnable_g*=False                                  |
| psi_common_ser_par                     | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md)         | Use the following mappings:<br />- *InWidth_g* = 1<br />- *OutWidth_g* = Width<br /> |
| psi_common_simple_cc                   | [olo_base_cc_simple](./base/olo_base_cc_simple.md)           | -                                                            |
| psi_common_sp_ram_be                   | [olo_base_ram_sp](./base/olo_base_ram_sp.md)                 | Use *UseByteEnable_g*=True                                   |
| psi_common_spi_master                  | [olo_intf_spi_master](./intf/olo_intf_spi_master.md)         | Leave *Cmd_TransWidth* unconnected.                          |
| psi_common_spi_master_cfg              | [olo_intf_spi_master](./intf/olo_intf_spi_master.md)         | -                                                            |
| psi_common_status_cc                   | [olo_base_cc_status](./base/olo_base_cc_status.md)           | -                                                            |
| psi_common_strobe_divider              | [olo_base_strobe_div](./base/olo_base_strobe_div.md)         | -                                                            |
| psi_common_strobe_generator            | [olo_base_strobe_gen](./base/olo_base_strobe_gen.md)         | -                                                            |
| psi_common_sync_cc_n2xn                | [olo_base_cc_n2xn](./base/olo_base_cc_n2xn.md)               | -                                                            |
| psi_common_sync_cc_xn2n                | [olo_base_cc_xn2n](./base/olo_base_cc_xn2n.md)               | -                                                            |
| psi_common_sync_fifo                   | [olo_base_fifo_sync](./base/olo_base_fifo_sync.md)           | -                                                            |
| psi_common_tdm_mux                     | [olo_base_tdm_mux](./base/olo_base_tdm_mux.md)               | -                                                            |
| psi_common_tdm_par                     | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md)         | Use the following mappings:<br />- *OutWidth_g* = NumberOfChannels x ChannelWidth<br />- *InWidth_g* = ChannelWidth<br />- *Out_WordEna* = *keep* on Parallel side |
| psi_common_tdm_par_cfg                 | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md)         | The functionality is not ported 1:1. Instead of selecting the number of channels through a separate signal, it is suggested to use *In_Last* to signal the last channel of the TDM input. This way *olo_base_wconv_n2xn* works naturally.<br>See [Conventions](./Conventions.md) for details. |
| psi_common_tdp_ram                     | [olo_base_ram_tdp](./base/olo_base_ram_tdp.md)               | Use *UseByteEnable_g*=False                                  |
| psi_common_tdp_ram_be                  | [olo_base_ram_tdp](./base/olo_base_ram_tdp.md)               | Use *UseByteEnable_g*=True                                   |
| psi_common_tickgenerator               | Won't be ported                                              | Use three instances of [olo_base_strobe_gen](./base/olo_base_strobe_gen.md) instead. |
| psi_common_trigger_analog              | Won't be ported                                              | Not generic enough for a library component                   |
| psi_common_trigger_digital             | Won't be ported                                              | Not generic enough for a library component                   |
| psi_common_wconv_n2xn                  | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md)         | -                                                            |
| psi_common_wconv_xn2n                  | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md)         | -                                                            |

