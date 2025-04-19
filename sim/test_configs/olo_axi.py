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

def add_axi_configs(olo_tb):
    """
    Add all axi testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """


    axi_lite_slave_tb = 'olo_axi_lite_slave_tb'
    tb = olo_tb.test_bench(axi_lite_slave_tb)
    for AxiAddrWidth in [8, 12, 16, 32]:
        for AxiDataWidth in [8, 16, 32, 128]:
            named_config(tb, {'AxiAddrWidth_g': AxiAddrWidth, 'AxiDataWidth_g': AxiDataWidth})

    axi_master_simple_tb = 'olo_axi_master_simple_tb'
    tb = olo_tb.test_bench(axi_master_simple_tb)
    for ImplRead in [True, False]:
        for ImplWrite in [True, False]:
            #Skip illegal case where no functionality is implemented
            if (not ImplRead) and (not ImplWrite): continue
            for AddrWidth in [16, 20, 32]:
                named_config(tb, {'ImplRead_g': ImplRead, 'ImplWrite_g': ImplWrite, 'AxiAddrWidth_g': AddrWidth})
            for DataWidth in [16, 32, 64]:
                named_config(tb, {'ImplRead_g': ImplRead, 'ImplWrite_g': ImplWrite, 'AxiDataWidth_g': DataWidth})
    #Case reported by customer
    named_config(tb, {'ImplRead_g': True, 'ImplWrite_g': True, 'AxiAddrWidth_g': 12, 'AxiDataWidth_g': 8, 'AxiMaxOpenTransactions_g': 1})

    axi_master_full_tb = 'olo_axi_master_full_tb'
    tb = olo_tb.test_bench(axi_master_full_tb)
    #Check Widths
    for AddrWidth in [16, 20, 32]:
        named_config(tb, {'ImplRead_g': True, 'ImplWrite_g': True, 'AxiAddrWidth_g': AddrWidth})
    for DataWidth in [16, 32, 64]:
        for UserWidth in [16, 32, 64]:
            if UserWidth > DataWidth: continue #Skip illegal configurations
            named_config(tb, {'ImplRead_g': True, 'ImplWrite_g': True,
                                'AxiDataWidth_g': DataWidth, 'UserDataWidth_g': UserWidth})
    #Check Partial Implementations
    for ImplRead in [True, False]:
        for ImplWrite in [True, False]:
            named_config(tb, {'ImplRead_g': ImplRead, 'ImplWrite_g': ImplWrite})

            #Skip illegal case where no functionality is implemented
            if (not ImplRead) and (not ImplWrite): continue


    axi_pl_stage_tb = 'olo_axi_pl_stage_tb'
    tb = olo_tb.test_bench(axi_pl_stage_tb)
    for AddrWidth in [32, 64]:
        named_config(tb, {'AddrWidth_g': AddrWidth})
    for DataWidth in [16, 64]:
        named_config(tb, {'DataWidth_g': DataWidth})
    for IdWidth in [0, 4]:
        named_config(tb, {'IdWidth_g': IdWidth})
    for UserWidth in [0, 4, 16]:
        named_config(tb, {'UserWidth_g': UserWidth})
    for Stages in [1, 4, 12]:
        named_config(tb, {'Stages_g': Stages})