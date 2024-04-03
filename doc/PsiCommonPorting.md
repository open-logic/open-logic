<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Open Logic - *psi_common* Porting Guide

The aim of this document is to describe which *Open Logic* entities replace a given *psi_common* entity. 

*Open Logic* aims for minimizing code duplication. Hence in some cases multiple *psi_common* entity match to the same *Open Logic* entity, just with different Generics. 

Note that naming conventions in *Open Logic* are different. Although some entities are functionally identical, the code must be adapted to the new port-names of *Open Logic*.

| psi_common Entity                      | Open Logic Entity   | Comments / Generic Values                                    |
| -------------------------------------- | ------------------- | ------------------------------------------------------------ |
| psi_common_arb_priority                | Not ported yet      | -                                                            |
| psi_common_arb_round_robin             | Not ported yet      | -                                                            |
| psi_common_async_fifo                  | olo_base_fifo_async | -                                                            |
| psi_common_axi_master_full             | Not ported yet      | -                                                            |
| psi_common_axi_master_simple           | Not ported yet      | -                                                            |
| psi_common_axi_multi_pl_stage          | Not ported yet      | -                                                            |
| psi_common_axi_pkg                     | Not ported yet      | -                                                            |
| psi_common_axi_slave_ipif              | Not ported yet      | -                                                            |
| psi_common_axi_slave_ipif64            | Not ported yet      | -                                                            |
| psi_common_bit_cc                      | olo_base_cc_bits    | -                                                            |
| psi_common_clk_meas                    | Not ported yet      | -                                                            |
| psi_common_debouncer                   | Not ported yet      | -                                                            |
| pis_common_delay                       | olo_base_delay      | -                                                            |
| psi_common_delay_cfg                   | olo_base_delay_cfg  | *Hold_g* behavior is not ported (considered as not generic enough for a library component). |
| psi_common_dyn_sft                     | Not ported yet      | -                                                            |
| psi_common_find_min_max                | Not ported yet      | -                                                            |
| psi_common_i2c_master                  | Not ported yet      | -                                                            |
| psi_common_logic_pkg                   | olo_base_pkg_logic  | -                                                            |
| psi_common_math_pkg                    | olo_base_pkg_math   | -                                                            |
| psi_common_min_max_sum                 | Not ported yet      | -                                                            |
| psi_common_multi_pl_stage              | olo_base_pl_stage   | -                                                            |
| psi_common_par_ser                     | Not ported yet      | -                                                            |
| psi_common_par_tdm                     | Not ported yet      | -                                                            |
| psi_common_par_tdm_cfg                 | Not ported yet      | -                                                            |
| psi_common_ping_pong                   | Not ported yet      | -                                                            |
| psi_common_pl_stage                    | olo_base_pl_stage   | Use *Stages_g*=1                                             |
| psi_common_prbs                        | Not ported yet      | -                                                            |
| psi_common_pulse_cc                    | olo_base_cc_pulse   | -                                                            |
| psi_common_pulse_generator_ctrl_static | Won't be ported     | Not generic enough for a library component                   |
| psi_common_pulse_shaper                | Not ported yet      | -                                                            |
| psi_common_pulse_shaper_cfg            | Not ported yet      | -                                                            |
| psi_common_ramp_gene                   | Won't be ported     | Not generic enough for a library component                   |
| psi_common_sdp_ram                     | olo_base_ram_sdp    | Use *UseByteEnable_g*=False                                  |
| psi_common_ser_par                     | Not ported yet      | -                                                            |
| psi_common_simple_cc                   | olo_base_cc_simple  | -                                                            |
| psi_common_sp_ram_be                   | olo_base_ram_sp     | Use *UseByteEnable_g*=True                                   |
| psi_common_spi_master                  | Not ported yet      | -                                                            |
| psi_common_spi_master_cfg              | Not ported yet      | -                                                            |
| psi_common_status_cc                   | olo_base_cc_status  | -                                                            |
| psi_common_strobe_divider              | Not ported yet      | -                                                            |
| psi_common_strobe_generator            | Not ported yet      | -                                                            |
| psi_common_sync_cc_n2xn                | olo_base_cc_n2xn    | -                                                            |
| psi_common_sync_cc_xn2n                | olo_base_cc_xn2n    | -                                                            |
| psi_common_sync_fifo                   | olo_base_fifo_sync  | -                                                            |
| psi_common_tdm_mux                     | Not ported yet      | -                                                            |
| psi_common_tdm_par                     | Not ported yet      | -                                                            |
| psi_common_tdm_par_cfg                 | Not ported yet      | -                                                            |
| psi_common_tdp_ram                     | olo_base_ram_tdp    | Use *UseByteEnable_g*=False                                  |
| psi_common_tdp_ram_be                  | olo_base_ram_tdp    | Use *UseByteEnable_g*=True                                   |
| psi_common_tickgenerator               | Not ported yet      | -                                                            |
| psi_common_trigger_analog              | Won't be ported     | Not generic enough for a library component                   |
| psi_common_trigger_digital             | Won't be ported     | Not generic enough for a library component                   |
| psi_common_wconv_n2xn                  | olo_base_wconv_n2xn | -                                                            |
| psi_common_wconv_xn2n                  | olo_base_wconv_xn2n | -                                                            |

