<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Open Logic - *psi_common* Porting Guide

The aim of this document is to describe which *Open Logic* entities replace a given *psi_common* entity. 

*Open Logic* aims for minimizing code duplication. Hence in some cases multiple *psi_common* entity match to the same *Open Logic* entity, just with different Generics. 

Note that naming conventions in *Open Logic* are different. Although some entities are functionally identical, the code must be adapted to the new port-names of *Open Logic*.

| psi_common Entity                      | Open Logic Entity                                    | Comments / Generic Values                                    |
| -------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------ |
| psi_common_arb_priority                | [olo_base_arb_prio](./base/olo_base_arb_prio.md)     | -                                                            |
| psi_common_arb_round_robin             | [olo_base_arb_rr](./base/olo_base_arb_rr.md)         | -                                                            |
| psi_common_async_fifo                  | [olo_base_fifo_async](./base/olo_base_fifo_async.md) | -                                                            |
| psi_common_axi_master_full             | Not ported yet                                       | -                                                            |
| psi_common_axi_master_simple           | Not ported yet                                       | -                                                            |
| psi_common_axi_multi_pl_stage          | Not ported yet                                       | -                                                            |
| psi_common_axi_pkg                     | Not ported yet                                       | -                                                            |
| psi_common_axi_slave_ipif              | Not ported yet                                       | -                                                            |
| psi_common_axi_slave_ipif64            | Not ported yet                                       | -                                                            |
| psi_common_bit_cc                      | [olo_base_cc_bits](./base/olo_base_cc_bits.md)       | -                                                            |
| psi_common_clk_meas                    | Not ported yet                                       | -                                                            |
| psi_common_debouncer                   | Not ported yet                                       | -                                                            |
| pis_common_delay                       | [olo_base_delay](./base/olo_base_delay.md)           | -                                                            |
| psi_common_delay_cfg                   | [olo_base_delay_cfg](./base/olo_base_delay_cfg.md)   | *Hold_g* behavior is not ported (considered as not generic enough for a library component). |
| psi_common_dyn_sft                     | [olo_base_dyn_sft](./base/olo_base_dyn_sft.md)       | -                                                            |
| psi_common_find_min_max                | Not ported yet                                       | -                                                            |
| psi_common_i2c_master                  | Not ported yet                                       | -                                                            |
| psi_common_logic_pkg                   | [olo_base_pkg_logic](./base/olo_base_pkg_logic.md)   | -                                                            |
| psi_common_math_pkg                    | [olo_base_pkg_math](./base/olo_base_pkg_math.md)     | -                                                            |
| psi_common_min_max_sum                 | Not ported yet                                       | -                                                            |
| psi_common_multi_pl_stage              | [olo_base_pl_stage](./base/olo_base_pl_stage.md)     | -                                                            |
| psi_common_par_ser                     | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Use the following mappings:<br />- *InWidth_g* = Width<br />- *OutWidth_g* = 1<br />- Use *Out_Ready* to control the bit-rate (e.g. through *olo_base_strobe_generator*)<br />- Some features are not 1:1 ported (e.g. overrun control and signalling start of frame) |
| psi_common_par_tdm                     | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Use the following mappings:<br />- *InWidth_g* = NumberOfChannels x ChannelWidth<br />- *OutWidth_g* = ChannelWidth |
| psi_common_par_tdm_cfg                 | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | Use the following mappings:<br />- *InWidth_g* = NumberOfChannels x ChannelWidth<br />- *OutWidth_g* = ChannelWidth<br />- *In Last* = '1'<br />- *In_WordEna* = Lowest *EnabledChannels*  bits '1', others '0' |
| psi_common_ping_pong                   | Not ported yet                                       | -                                                            |
| psi_common_pl_stage                    | [olo_base_pl_stage](./base/olo_base_pl_stage.md)     | Use *Stages_g*=1                                             |
| psi_common_prbs                        | Not ported yet                                       | -                                                            |
| psi_common_pulse_cc                    | [olo_base_cc_pulse](./base/olo_base_cc_pulse.md)     | -                                                            |
| psi_common_pulse_generator_ctrl_static | Won't be ported                                      | Not generic enough for a library component                   |
| psi_common_pulse_shaper                | Not ported yet                                       | -                                                            |
| psi_common_pulse_shaper_cfg            | Not ported yet                                       | -                                                            |
| psi_common_ramp_gene                   | Won't be ported                                      | Not generic enough for a library component                   |
| psi_common_sdp_ram                     | [olo_base_ram_sdp](./base/olo_base_ram_sdp.md)       | Use *UseByteEnable_g*=False                                  |
| psi_common_ser_par                     | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Use the following mappings:<br />- *InWidth_g* = 1<br />- *OutWidth_g* = Width<br /> |
| psi_common_simple_cc                   | [olo_base_cc_simple](./base/olo_base_cc_simple.md)   | -                                                            |
| psi_common_sp_ram_be                   | [olo_base_ram_sp](./base/olo_base_ram_sp.md)         | Use *UseByteEnable_g*=True                                   |
| psi_common_spi_master                  | Not ported yet                                       | -                                                            |
| psi_common_spi_master_cfg              | Not ported yet                                       | -                                                            |
| psi_common_status_cc                   | [olo_base_cc_status](./base/olo_base_cc_status.md)   | -                                                            |
| psi_common_strobe_divider              | Not ported yet                                       | -                                                            |
| psi_common_strobe_generator            | Not ported yet                                       | -                                                            |
| psi_common_sync_cc_n2xn                | [olo_base_cc_n2xn](./base/olo_base_cc_n2xn.md)       | -                                                            |
| psi_common_sync_cc_xn2n                | [olo_base_cc_xn2n](./base/olo_base_cc_xn2n.md)       | -                                                            |
| psi_common_sync_fifo                   | [olo_base_fifo_sync](./base/olo_base_fifo_sync.md)   | -                                                            |
| psi_common_tdm_mux                     | [olo_base_tdm_mux](./base/olo_base_tdm_mux.md)       | -                                                            |
| psi_common_tdm_par                     | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | Use the following mappings:<br />- *OutWidth_g* = NumberOfChannels x ChannelWidth<br />- *InWidth_g* = ChannelWidth<br />- *Out_WordEna* = *keep* on Parallel side |
| psi_common_tdm_par_cfg                 | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | The functionality is not ported 1:1. Instead of selecting the number of channels through a separate signal, it is suggested to use *In_Last* to signal the last channel of the TDM input. This way *olo_base_wconv_n2xn* works naturally.<br>See [Conventions](./Conventions.md) for details. |
| psi_common_tdp_ram                     | [olo_base_ram_tdp](./base/olo_base_ram_tdp.md)       | Use *UseByteEnable_g*=False                                  |
| psi_common_tdp_ram_be                  | [olo_base_ram_tdp](./base/olo_base_ram_tdp.md)       | Use *UseByteEnable_g*=True                                   |
| psi_common_tickgenerator               | Not ported yet                                       | -                                                            |
| psi_common_trigger_analog              | Won't be ported                                      | Not generic enough for a library component                   |
| psi_common_trigger_digital             | Won't be ported                                      | Not generic enough for a library component                   |
| psi_common_wconv_n2xn                  | [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) | -                                                            |
| psi_common_wconv_xn2n                  | [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) | -                                                            |

