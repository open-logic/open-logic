# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Julian Schneider
# All rights reserved.
# Authors: Julian Schneider
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from .utils import named_config

# ---------------------------------------------------------------------------------------------------
# Functionality
# ---------------------------------------------------------------------------------------------------

def add_configs(olo_tb):
    """
    Add all fault-tolerant testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """

    ### olo_ft_ecc_encode / olo_ft_ecc_decode ###
    for tb_name in ['olo_ft_ecc_encode_tb', 'olo_ft_ecc_decode_tb']:
        tb = olo_tb.test_bench(tb_name)
        for Width in [8, 16, 32, 64]:
            named_config(tb, {'Width_g': Width})
        for Pipeline in [0, 1, 2]:
            named_config(tb, {'Pipeline_g': Pipeline})

    ### olo_ft_ram_sp ###
    tb = olo_tb.test_bench('olo_ft_ram_sp_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in [8, 16, 32, 64]:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1]:
        named_config(tb, {'EccPipeline_g': EccPipeline})
