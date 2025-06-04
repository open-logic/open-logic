# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
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
    Add all intf testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """

    ### olo_intf_debounce ###
    debounce_tb = 'olo_intf_debounce_tb'
    tb = olo_tb.test_bench(debounce_tb)
    for IdleLevel in [0, 1]:
        for Mode in ["LOW_LATENCY", "GLITCH_FILTER"]:
            named_config(tb, {'IdleLevel_g': IdleLevel, 'Mode_g' : Mode})
    for Mode in ["LOW_LATENCY", "GLITCH_FILTER"]:
        #Cover ranges around 31/32 and 63/64 in detail (clock divider edge cases)
        for Cycles in [10, 30, 31, 32, 50, 60, 61, 62, 63, 64, 65, 100, 200, 735]:
            named_config(tb, {'DebounceCycles_g': Cycles, 'Mode_g': Mode})

    ### olo_intf_i2c_master ###
    i2c_master_tb = 'olo_intf_i2c_master_tb'
    tb = olo_tb.test_bench(i2c_master_tb)
    for BusFreq in [int(100e3), int(400e3), int(1e6)]:
        named_config(tb, {'BusFrequency_g': BusFreq})
    for IntTri in [True, False]:
        named_config(tb, {'InternalTriState_g': IntTri})

    ### olo_intf_sync ###
    sync_tb = 'olo_intf_sync_tb'
    tb = olo_tb.test_bench(sync_tb)
    for SyncStages in [2, 4]:
        for ResetLvel in [0, 1]:
            named_config(tb, {'SyncStages_g': SyncStages, 'RstLevel_g': ResetLvel})

    ### olo_intf_clk_meas ###
    clk_meas_tb = 'olo_intf_clk_meas_tb'
    tb = olo_tb.test_bench(clk_meas_tb)
    freqs = [(100, 100), (123, 7837), (7837, 123)]
    for FreqClk, FreqTest in freqs:
        named_config(tb, {'ClkFrequency_g': FreqClk, 'MaxClkTestFrequency_g': FreqTest})

    ### olo_intf_spi_slave ###
    spi_slave_tb = 'olo_intf_spi_slave_tb'
    tb = olo_tb.test_bench(spi_slave_tb)
    #Test different configs for transactions (all combinations)
    for CPHA in [0, 1]:
        for CPOL in [0, 1]:
            for Consecutive in [False, True]:
                #Try TxOnSampleEdge
                named_config(tb, {'SpiCpha_g': CPHA, 'SpiCpol_g': CPOL, 'ConsecutiveTransactions_g' : Consecutive})
    #Test Lsb/Msb first
    for LsbFirst in [True, False]:
        named_config(tb, {'LsbFirst_g': LsbFirst})
    #Test different transaction widths
    for TransWidth in [8, 16]:
        named_config(tb, {'TransWidth_g': TransWidth})
    #Test external tristate
    for InternalTriState in [True, False]:
        named_config(tb, {'InternalTriState_g': InternalTriState})
    #Test maximum clock frequency
    clkFreq = int(100e6)
    for CPHA in [0, 1]:
        named_config(tb, {'SpiCpha_g': CPHA, 'ClkFrequency_g': clkFreq, 'BusFrequency_g': int(clkFreq/8),
                        'ConsecutiveTransactions_g': True})

    ### olo_intf_uart ###
    uart_tb = 'olo_intf_uart_tb'
    tb = olo_tb.test_bench(uart_tb)
    for BaudRate in [115200, 10000000]:
        named_config(tb, {'BaudRate_g' : BaudRate})
    for DataBits in [8, 9]:
        for Parity in ["none", "even", "odd"]:
            named_config(tb, {'DataBits_g': DataBits, 'Parity_g' : Parity})
    for StopBits in ["1", "1.5", "2"]:
        named_config(tb, {'StopBits_g' : StopBits})

    ### olo_intf_spi_master ###
    spi_master_tb = 'olo_intf_spi_master_tb'
    tb = olo_tb.test_bench(spi_master_tb)
    for FreqBus in [int(1e6), int(10e6)]:
        named_config(tb, {'BusFrequency_g': FreqBus})
    for LsbFirst in [False, True]:
        named_config(tb, {'LsbFirst_g': LsbFirst})
    for CPHA in [0, 1]:
        for CPOL in [0, 1]:
            named_config(tb, {'SpiCpha_g': CPHA, 'SpiCpol_g': CPOL})
    #fixed size TB
    spi_master_fixsize_tb = 'olo_intf_spi_master_fixsize_tb'
    tb = olo_tb.test_bench(spi_master_fixsize_tb)
    for LsbFirst in [False, True]:
        named_config(tb, {'LsbFirst_g': LsbFirst})

    ### olo_intf_inc_encoder ###
    inc_encoder_tb = 'olo_intf_inc_encoder_tb'
    tb = olo_tb.test_bench(inc_encoder_tb)
    named_config(tb, {'DefaultAngleResolution_g' : 1024, "PositionWidth_g" : 32})
