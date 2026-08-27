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

    ### olo_ft_private_scrubber ###
    # Unit test benches for the private scrubber engine (behavioral RAM model, direct port
    # control), split into a free-running and a paced test bench: the pacer is selected by a
    # generic, and one configuration carries one generic set for all cases of a test bench, so the
    # two activity patterns cannot share a single test bench. Pacer timing uses integer generics
    # (GHDL cannot override real generics on the command line; the TB converts them to the real
    # ScrubClkHz_g / ScrubPeriod_g at the generic map).
    tb = olo_tb.test_bench('olo_ft_private_scrubber_tb')
    for Latency in [1, 2, 3]:
        for SinglePort in [False, True]:
            named_config(tb, {'TotalReadLatency_g': Latency, 'SinglePortRam_g': SinglePort})

    ### olo_ft_private_scrubber_paced ###
    tb = olo_tb.test_bench('olo_ft_private_scrubber_paced_tb')
    for Latency, SinglePort in [(1, False), (3, False), (1, True)]:
        named_config(tb, {'TotalReadLatency_g': Latency, 'SinglePortRam_g': SinglePort,
                          'ScrubClkHz_g': 10000, 'ScrubPeriodMs_g': 15})

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

    ### olo_ft_ram_sp_scrub ###
    tb = olo_tb.test_bench('olo_ft_ram_sp_scrub_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for RamRdLatency in [1, 2]:
        for EccPipeline in [0, 1, 2]:
            named_config(tb, {'RamRdLatency_g': RamRdLatency,
                              'EccPipeline_g': EccPipeline})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})

    ### olo_ft_ram_sdp ###
    tb = olo_tb.test_bench('olo_ft_ram_sdp_tb')
    for RamBehav in ['RBW', 'WBR']:
        for Async in [True, False]:
            named_config(tb, {'RamBehavior_g': RamBehav, 'IsAsync_g': Async})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_ram_sdp_scrub ###
    tb = olo_tb.test_bench('olo_ft_ram_sdp_scrub_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for RamRdLatency in [1, 2]:
        for EccPipeline in [0, 1, 2]:
            named_config(tb, {'RamRdLatency_g': RamRdLatency,
                              'EccPipeline_g': EccPipeline})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})

    ### olo_ft_ram_tdp ###
    tb = olo_tb.test_bench('olo_ft_ram_tdp_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_fifo_sync ###
    tb = olo_tb.test_bench('olo_ft_fifo_sync_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    # Coverage knobs of the base FIFO test bench
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for RstState in [0, 1]:
        named_config(tb, {'ReadyRstState_g': RstState})
    for Depth in [31, 53, 128]:
        named_config(tb, {'Depth_g': Depth})
    for AlmFull in [True, False]:
        for AlmEmpty in [True, False]:
            named_config(tb, {'AlmFullOn_g': AlmFull, 'AlmEmptyOn_g': AlmEmpty})

    ### olo_ft_fifo_packet ###
    tb = olo_tb.test_bench('olo_ft_fifo_packet_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    # DROP_ONLY is rejected by the entity (In_Last would be stored in RAM outside the ECC codeword)
    for FeatureSet in ['FULL', 'DROP_SKIP_ONLY']:
        named_config(tb, {'FeatureSet_g': FeatureSet})
