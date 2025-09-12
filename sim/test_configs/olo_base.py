# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bruendler
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
    Add all base testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """

    ### olo_base_cc_... ###
    cc_tbs = ['olo_base_cc_simple_tb', 'olo_base_cc_status_tb', 'olo_base_cc_bits_tb', 'olo_base_cc_pulse_tb', 'olo_base_cc_reset_tb', 'olo_base_cc_handshake_tb']
    for tb_name in cc_tbs:
        tb = olo_tb.test_bench(tb_name)
        # Iterate through various clock combinations
        ratios = [(1, 1), (1, 3), (3, 1), (1, 20), (20, 1), (19, 20), (20, 19)]
        for N, D in ratios:
            # Simulate same clock only once
            if N == D and N != 1:
                continue
            named_config(tb, {'ClockRatio_N_g': N, 'ClockRatio_D_g': D})
        for Stages in [2, 4]:
            named_config(tb, {'SyncStages_g': Stages})

    ### olo_base_cc_handshake ###
    cc_handshake_tb = 'olo_base_cc_handshake_tb'
    tb = olo_tb.test_bench(cc_handshake_tb)
    for ReadyRst in [0, 1]:
        named_config(tb, {'ReadyRstState_g': ReadyRst})
    for RandomStall in [True, False]:
        named_config(tb, {'RandomStall_g': RandomStall})


    ### olo_base_cc_... sync ###
    scc_tbs = ['olo_base_cc_xn2n_tb', 'olo_base_cc_n2xn_tb']
    for tb_name in scc_tbs:
        tb = olo_tb.test_bench(tb_name)
        for R in [2, 3, 19]:
            named_config(tb, {'ClockRatio_g': R})

    ### olo_base_ram_... dualport ###
    ram_tbs = ['olo_base_ram_sp_tb', 'olo_base_ram_tdp_tb']
    for tb_name in ram_tbs:
        tb = olo_tb.test_bench(tb_name)
        for RamBehav in ['RBW', 'WBR']:
            named_config(tb, {'RamBehavior_g': RamBehav})
        for ReadLatency in [1, 2]:
            named_config(tb, {"RdLatency_g": ReadLatency})
        for Width in [5, 32]:
            named_config(tb, {'Width_g': Width})
        for Be in [True, False]:
            named_config(tb, {'Width_g': 32, 'UseByteEnable_g' : Be})
        # Check no-init
        named_config(tb, {'InitFormat_g': 'NONE'})
        # Check non byte-width
        named_config(tb, {'InitFormat_g': 'HEX', 'Width_g': 7})
        # Check init, byte-enables play a role internally
        for Be in [True, False]:
            for Width in [8, 16]: 
                named_config(tb, {'InitFormat_g': 'HEX', 'Width_g': Width, 'UseByteEnable_g' : Be})


    ### olo_base_ram_... singleport ###
    ram_tbs = ['olo_base_ram_sdp_tb']
    for tb_name in ram_tbs:
        tb = olo_tb.test_bench(tb_name)
        for RamBehav in ['RBW', 'WBR']:
            for Async in [True, False]:
                named_config(tb, {'RamBehavior_g': RamBehav, "IsAsync_g": Async})

        for ReadLatency in [1,2]:
            named_config(tb, {"RdLatency_g": ReadLatency})

        for Width in [5, 32]:
            named_config(tb, {'Width_g': Width})
        for Be in [True, False]:
            named_config(tb, {'Width_g': 32, 'UseByteEnable_g' : Be})
        # Check no-init
        named_config(tb, {'InitFormat_g': 'NONE'})
        # Check non byte-width
        named_config(tb, {'InitFormat_g': 'HEX', 'Width_g': 7})
        # Check init, byte-enables play a role internally
        for Be in [True, False]:
            for Width in [8, 16]: 
                named_config(tb, {'InitFormat_g': 'HEX', 'Width_g': Width, 'UseByteEnable_g' : Be})

    ### olo_base_fifo_... non-packet ###
    fifo_tbs = ['olo_base_fifo_sync_tb', 'olo_base_fifo_async_tb']
    for tb_name in fifo_tbs:
        tb = olo_tb.test_bench(tb_name)
        for RamBehav in ['RBW', 'WBR']:
            named_config(tb, {'RamBehavior_g': RamBehav})
        for RstState in [0, 1]:
            named_config(tb, {'ReadyRstState_g': RstState})
        for Depth in [32, 128]:
            named_config(tb, {'Depth_g': Depth})
        if tb_name == "olo_base_fifo_sync_tb":
            Depth = 53 #For Sync FIFO, completely odd depths are allowed
            named_config(tb, {'Depth_g': Depth})
        for AlmFull in [True, False]:
            for AlmEmpty in [True, False]:
                named_config(tb, {"AlmFullOn_g": AlmFull, "AlmEmptyOn_g": AlmEmpty})
        # For async FIFO, test different sync stagecounts
        if tb_name == "olo_base_fifo_async_tb":
            for Stages in [2, 4]:
                named_config(tb, {"SyncStages_g": Stages})
            for Opt in ["SPEED", "LATENCY"]:
                named_config(tb, {"Optimization_g": Opt})

    ### olo_base_wconv_xn2n ###
    wconv_xn2n_tb = 'olo_base_wconv_xn2n_tb'
    tb = olo_tb.test_bench(wconv_xn2n_tb)
    for Ratio in [2, 3]:
        named_config(tb, {'WidthRatio_g': Ratio})

    ### olo_base_wconv_n2xn ###
    wconv_n2xn_tb = 'olo_base_wconv_n2xn_tb'
    tb = olo_tb.test_bench(wconv_n2xn_tb)
    for Ratio in [1, 2, 3]:
        named_config(tb, {'WidthRatio_g': Ratio})

    ### olo_base_wconv_n2m ###
    wconv_n2m_tb = 'olo_base_wconv_n2m_tb'
    tb = olo_tb.test_bench(wconv_n2m_tb)
    for Ratio in [(8, 8), (16, 24), (24, 16), (18, 27), (27, 18)]:
        named_config(tb, {'InWidth_g': Ratio[0], 'OutWidth_g': Ratio[1]})
    wconv_n2m_78_tb = 'olo_base_wconv_n2m_78_tb'
    tb = olo_tb.test_bench(wconv_n2m_78_tb)
    for Direction in ["up", "down"]:
        named_config(tb, {'Direction_g': Direction})
    wconv_n2m_be_tb = 'olo_base_wconv_n2m_be_tb'
    tb = olo_tb.test_bench(wconv_n2m_be_tb)
    for Ratio in [(16, 24), (24, 16), (32, 8), (8, 32)]:
        named_config(tb, {'InWidth_g': Ratio[0], 'OutWidth_g': Ratio[1]})

    ### olo_base_pl_stage ###
    pl_tb = 'olo_base_pl_stage_tb'
    tb = olo_tb.test_bench(pl_tb)
    for Stages in [0, 1, 5]:
        for UseReady in [True, False]:
            RandomStall = True
            named_config(tb, {'Stages_g': Stages, 'UseReady_g': UseReady, 'RandomStall_g': RandomStall})

    ### olo_base_delay ###
    delay_tb = 'olo_base_delay_tb'
    tb = olo_tb.test_bench(delay_tb)
    BramThreshold = 16
    # Test AUTO
    Resource = "AUTO"
    RandomStall = True
    for Delay in [0, 1, 2, 3, 8, 30, 32]:
        named_config(tb, {'Delay_g': Delay, 'Resource_g': Resource, 'RandomStall_g': RandomStall})
    # Test BRAM
    Resource = "BRAM"
    for Delay in [3, 30, 32]:
        for RamBehav in ["RBW", "WBR"]:
            named_config(tb, {'Delay_g': Delay, 'Resource_g': Resource, 'RandomStall_g': RandomStall,
                                'RamBehavior_g': RamBehav})
    # Test SRL
    Resource = "SRL"
    for Delay in [1, 2, 3, 30, 32]:
        named_config(tb, {'Delay_g': Delay, 'Resource_g': Resource, 'RandomStall_g': RandomStall})
    # Test State Reset
    RstState = True
    for Resource in ["BRAM", "SRL"]:
        for RstState in [True, False]:
            for Delay in [3, 32]:
                named_config(tb, {'Delay_g': Delay, 'Resource_g': Resource, 'RandomStall_g': RandomStall,
                                    'RstState_g': RstState})

    ### olo_base_delay_cfg ###
    delay_cfg_tb = 'olo_base_delay_cfg_tb'
    tb = olo_tb.test_bench(delay_cfg_tb)
    for SupportZero in [True, False]:
        for RamBehav in ["RBW", "WBR"]:
            # Random-Stall is sufficient (non-random is only used for debugging purposes)
            RandomStall = True
            named_config(tb, {'SupportZero_g': SupportZero, 'RandomStall_g': RandomStall, 'RamBehavior_g': RamBehav})
    for MaxDelay in [20, 256]:
        # Random-Stall is sufficient (non-random is only used for debugging purposes)
        RandomStall = True
        named_config(tb, {'MaxDelay_g': MaxDelay, 'RandomStall_g': RandomStall})       


    ### olo_base_dyn_sft ###
    dyn_sft_tb = 'olo_base_dyn_sft_tb'
    tb = olo_tb.test_bench(dyn_sft_tb)
    for Direction in ["LEFT", "RIGHT"]:
        for BitsPerStage in [1,4,7]:
            for MaxShift in [1, 10, 16]:
                for SignExt in [True, False]:
                    #Sign extension only for right shift
                    if Direction == "LEFT" and SignExt:
                        continue
                    #Add case
                    named_config(tb, {'Direction_g': Direction, 'SelBitsPerStage_g': BitsPerStage,
                                        'MaxShift_g': MaxShift, 'SignExtend_g': SignExt})

    ### olo_base_arb_prio ###
    arb_prio_tb = 'olo_base_arb_prio_tb'
    tb = olo_tb.test_bench(arb_prio_tb)
    for Latency in [0, 1, 3]:
        named_config(tb, {'Latency_g': Latency})

    ### olo_base_arb_rr ###
    arb_rr_tb = 'olo_base_arb_rr_tb'
    #Only one config required, hence no "add_config" looping

    ### olo_base_arb_wrr###
    arb_wrr_tb = 'olo_base_arb_wrr_tb'
    tb = olo_tb.test_bench(arb_wrr_tb)
    for RandomStall in [False, True]:
        for Latency in [0, 1]:
            named_config(tb, {'Latency_g' : Latency, 'RandomStall_g' : RandomStall})

    ### olo_base_strobe_gen ###
    strobe_gen_tb = 'olo_base_strobe_gen_tb'
    tb = olo_tb.test_bench(strobe_gen_tb)
    for Freq in ["10.0e6", "13.2e6"]:
        for FMode in [False, True]:
            named_config(tb, {'FreqStrobeHz_g': Freq, 'FractionalMode_g' : FMode})

    ### olo_base_strobe_div ###
    strobe_div_tbs = ['olo_base_strobe_div_tb', 'olo_base_strobe_div_backpressonly_tb']
    for tb_name in strobe_div_tbs:
        tb = olo_tb.test_bench(tb_name)
        for Latency in [0, 1]:
            named_config(tb, {'Latency_g': Latency})
    strobe_div_fixratio_tb ='olo_base_strobe_div_fixratio_tb'
    tb = olo_tb.test_bench(strobe_div_fixratio_tb)
    for Latency in [0, 1]:
        for Ratio in [3, 4, 5, 6]:
            named_config(tb, {'Latency_g': Latency, 'Ratio_g' : Ratio})

    ### olo_base_prbs ###
    prbs_tbs = ['olo_base_prbs4_tb']
    for tb_name in prbs_tbs:
        tb = olo_tb.test_bench(tb_name)
        for BitsPerSymbol in [1, 2, 3, 4, 6]:
            named_config(tb, {'BitsPerSymbol_g': BitsPerSymbol})

    ### olo_base_reset_gen ###
    reset_gen_tb = 'olo_base_reset_gen_tb'
    tb = olo_tb.test_bench(reset_gen_tb)
    for Cycles in [3, 5, 50, 64]:
        named_config(tb, {'RstPulseCycles_g': Cycles})
    for Cycles in [3, 5]:
        for Polarity in [0, 1]:
            for AsyncOutput in [True, False]:
                named_config(tb, {'RstPulseCycles_g': Cycles, 'RstInPolarity_g': Polarity, 'AsyncResetOutput_g': AsyncOutput})

    ### olo_base_fifo_packet ###
    fifo_packet_tb = 'olo_base_fifo_packet_tb'
    fifo_packet_tb_hs = 'olo_base_fifo_packet_hs_tb'
    tb = olo_tb.test_bench(fifo_packet_tb)
    tb_hs = olo_tb.test_bench(fifo_packet_tb_hs)
    #Choose settings for short runtime
    for FeatureSet in ["FULL", "DROP_ONLY"]:
        named_config(tb, {'RandomPackets_g': 10, 'RandomStall_g': True, 'FeatureSet_g' : FeatureSet})
        named_config(tb, {'RandomPackets_g': 10, 'RandomStall_g': False, 'FeatureSet_g' : FeatureSet}) #Some checks require non-random stall
        named_config(tb_hs, {'FeatureSet_g' : FeatureSet})

    ### olo_base_cam ###
    cam_tb = 'olo_base_cam_tb'
    tb = olo_tb.test_bench(cam_tb)
    #Content smaller or bitter than RAM AddrBits
    named_config(tb, {'ContentWidth_g': 10, 'RamBlockDepth_g': 512})
    named_config(tb, {'ContentWidth_g': 10, 'RamBlockDepth_g': 4096})
    #Test different RAM configs
    named_config(tb, {'RamBlockDepth_g': 512})
    named_config(tb, {'RamBlockDepth_g': 64})
    #Read/Write Interleaving
    for ReadPriority in [False, True]:
        for StrictOrdering in [False, True]:
            for RamBehav in ["RBW", "WBR"]:
                named_config(tb, {'ReadPriority_g': ReadPriority, 'StrictOrdering_g': StrictOrdering, 'RamBehavior_g' : RamBehav})
    #Latency / Throughput / Balacned configs
    named_config(tb, {'RegisterInput_g': True, 'RegisterMatch_g': True, 'FirstBitDecLatency_g': 2, 'Addresses_g': 128})
    named_config(tb, {'RegisterInput_g': False, 'RegisterMatch_g': False, 'FirstBitDecLatency_g': 0})
    named_config(tb, {'RegisterInput_g': True, 'RegisterMatch_g': False, 'FirstBitDecLatency_g': 1})
    #Omit AddrOut
    named_config(tb, {'UseAddrOut_g': True})
    named_config(tb, {'UseAddrOut_g': False})
    #Clear after reset with different input latency configs
    for ClearAfterReset in [False, True]:
        for InReg in [False, True]:
            named_config(tb, {'ClearAfterReset_g': ClearAfterReset, 'RegisterInput_g': InReg})

    ### olo_base_decode_firstbit ###
    decode_firstbit_tb = 'olo_base_decode_firstbit_tb'
    tb = olo_tb.test_bench(decode_firstbit_tb)
    for InReg in [True, False]:
        for OutReg in [True, False]:
            for PlRegs in [0, 2]:
                named_config(tb, {'InWidth_g': 64, 'InReg_g': InReg, 'OutReg_g': OutReg, 'PlRegs_g': PlRegs})
    for InWidth in [512, 783]:
        for PlRegs in [0, 2]:
            named_config(tb, {'InWidth_g': InWidth, 'PlRegs_g': PlRegs})

    ### olo_base_crc ###
    crc_tb = 'olo_base_crc_tb'
    tb = olo_tb.test_bench(crc_tb)
    for CrcWidth in [5, 8, 16]:
        for DataWidth in [5, 8, 16]:
            named_config(tb, {'CrcWidth_g': CrcWidth, 'DataWidth_g': DataWidth})
    for BitOrder in ["MSB_FIRST", "LSB_FIRST"]:
        named_config(tb, {'CrcWidth_g': 8, 'DataWidth_g': 5, 'BitOrder_g': BitOrder})
    for DataWidth in [8, 16]:
        for BitOrder in ["MSB_FIRST", "LSB_FIRST"]:
            for ByteOrder in ["MSB_FIRST", "LSB_FIRST", "NONE"]:
                named_config(tb, {'CrcWidth_g': 8, 'DataWidth_g': DataWidth, 'BitOrder_g': BitOrder, 'ByteOrder_g': ByteOrder})
    for BitFlip in [True, False]:
        for InvertOutput in [True, False]:
            named_config(tb, {'BitflipOutput_g': BitFlip, 'InvertOutput_g' : InvertOutput})

    ### olo_base_crc_append ###
    crc_append_tb = 'olo_base_crc_append_tb'
    tb = olo_tb.test_bench(crc_append_tb)  
    for DataWidth, CrcWidth in [(8, 8), (16, 8), (16, 16)]:
        named_config(tb, {'CrcWidth_g': CrcWidth, 'DataWidth_g': DataWidth})

    ### olo_base_crc_check ###
    crc_check_tb = 'olo_base_crc_check_tb'
    tb = olo_tb.test_bench(crc_check_tb)  
    for DataWidth, CrcWidth in [(8, 8), (16, 8), (16, 16)]:
        named_config(tb, {'CrcWidth_g': CrcWidth, 'DataWidth_g': DataWidth})
    for Mode in ["DROP", "FLAG"]:
        named_config(tb, {'Mode_g': Mode})

    ### olo_base_crc_append + olo_base_crc_check ###
    crc_append_check_tb = 'olo_base_crc_append_check_tb'
    tb = olo_tb.test_bench(crc_append_check_tb)  
    for Mode in ["DROP", "FLAG"]:
        named_config(tb, {'CheckMode_g': Mode})
