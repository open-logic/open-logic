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

    # Width sweep: two powers of two and one non-power-of-two to exercise the SECDED math
    # at an "odd" width.
    Widths = [8, 13, 32]

    ### olo_ft_ecc_encode ###
    tb = olo_tb.test_bench('olo_ft_ecc_encode_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for Pipeline in [0, 1]:
        named_config(tb, {'Pipeline_g': Pipeline})
    # Backpressure coverage: exercise the codec's UseReady_g=true shadow-register path with
    # randomized stalls on both ends. Sweeps Pipeline_g so both the pass-through (Pipeline_g=0)
    # and the registered (Pipeline_g=1) configurations are stressed.
    for Pipeline in [0, 1]:
        named_config(tb, {'Stalling_g': True, 'Pipeline_g': Pipeline})

    ### olo_ft_ecc_decode ###
    tb = olo_tb.test_bench('olo_ft_ecc_decode_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for Pipeline in [0, 1, 2]:
        named_config(tb, {'Pipeline_g': Pipeline})
    # Backpressure coverage: exercise the codec's UseReady_g=true shadow-register path with
    # randomized stalls on both ends. Pipeline_g=2 in particular places back-to-back beats
    # in the syndrome stage and the correction stage simultaneously, which is the most
    # demanding configuration for the distributed pipeline.
    for Pipeline in [0, 1, 2]:
        named_config(tb, {'Stalling_g': True, 'Pipeline_g': Pipeline})

    ### olo_ft_ram_sp ###
    tb = olo_tb.test_bench('olo_ft_ram_sp_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})
