
from vunit import VUnit
from glob import glob
import os
import sys
from enum import Enum


class Simulator(Enum):
    GHDL = 1
    MODELSIM = 2
    NVC = 3

#Execute from sim directory
os.chdir(os.path.dirname(os.path.realpath(__file__)))

#Argument handling
argv = sys.argv[1:]
SIMULATOR = Simulator.GHDL
USE_COVERAGE = False

#Simulator Selection
#.. The environment variable VUNIT_SIMULATOR has precedence over the commandline options.
if "--modelsim" in sys.argv:
    SIMULATOR = Simulator.MODELSIM
    argv.remove("--modelsim")
if "--nvc" in sys.argv:
    SIMULATOR = Simulator.NVC
    argv.remove("--nvc")
if "--ghdl" in sys.argv:
    SIMULATOR = Simulator.GHDL
    argv.remove("--ghdl")
if "--coverage" in sys.argv:
    USE_COVERAGE = True
    argv.remove("--coverage")
    if SIMULATOR != Simulator.MODELSIM:
        raise "Coverage is only allowed with --modelsim"

# Obviously the simulator must be chosen before sources are added
if 'VUNIT_SIMULATOR' not in os.environ:
    if SIMULATOR == Simulator.GHDL:
        os.environ['VUNIT_SIMULATOR'] = 'ghdl'
    elif SIMULATOR == Simulator.NVC:
        os.environ['VUNIT_SIMULATOR'] = 'nvc'
    else:
        os.environ['VUNIT_SIMULATOR'] = 'modelsim'

# Parse VUnit Arguments
vu = VUnit.from_argv(compile_builtins=False, argv=argv)
vu.add_vhdl_builtins()
vu.add_com()
vu.add_verification_components()

# Create a library
olo = vu.add_library('olo')
olo_tb = vu.add_library('olo_tb')

# Add all source VHDL files
files = glob('../src/**/*.vhd', recursive=True)
olo.add_source_files(files)

# Add test helpers
files = glob('../test/tb/legacy/*.vhd', recursive=True)
olo_tb.add_source_files(files)

# Add all tb VHDL files
files = glob('../test/**/*.vhd', recursive=True)
olo_tb.add_source_files(files)

# Obviously flags must be set after files are imported
vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])
vu.add_compile_option('nvc.a_flags', ['--relaxed'])

########################################################################################################################
# Shared Functions
########################################################################################################################
def named_config(tb, map : dict):
    cfg_name = "-".join([f"{k}={v}" for k, v in map.items()])
    tb.add_config(name=cfg_name, generics = map)

########################################################################################################################
# olo_base TBs
########################################################################################################################

# Clock Crossings
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

# Specific cases to cc_handshake
cc_handshake_tb = 'olo_base_cc_handshake_tb'
tb = olo_tb.test_bench(cc_handshake_tb)
for ReadyRst in [0, 1]:
    named_config(tb, {'ReadyRstState_g': ReadyRst})
for RandomStall in [True, False]:
    named_config(tb, {'RandomStall_g': RandomStall})


# Sync Clock Crossings
scc_tbs = ['olo_base_cc_xn2n_tb', 'olo_base_cc_n2xn_tb']
for tb_name in scc_tbs:
    tb = olo_tb.test_bench(tb_name)
    for R in [2, 3, 19]:
        named_config(tb, {'ClockRatio_g': R})

# RAM TBs
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

#FIFO TBs
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

#Width Converter TBs
wconv_xn2n_tb = 'olo_base_wconv_xn2n_tb'
tb = olo_tb.test_bench(wconv_xn2n_tb)
for Ratio in [2, 3]:
    named_config(tb, {'WidthRatio_g': Ratio})

wconv_n2xn_tb = 'olo_base_wconv_n2xn_tb'
tb = olo_tb.test_bench(wconv_n2xn_tb)
for Ratio in [1, 2, 3]:
    named_config(tb, {'WidthRatio_g': Ratio})

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

#Pipeline TB
pl_tb = 'olo_base_pl_stage_tb'
tb = olo_tb.test_bench(pl_tb)
for Stages in [0, 1, 5]:
    for UseReady in [True, False]:
        RandomStall = True
        named_config(tb, {'Stages_g': Stages, 'UseReady_g': UseReady, 'RandomStall_g': RandomStall})

#Delay TB
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

#DelayCfg TB
delay_cfg_tb = 'olo_base_delay_cfg_tb'
tb = olo_tb.test_bench(delay_cfg_tb)
for SupportZero in [True, False]:
    for RamBehav in ["RBW", "WBR"]:
        # Random-Stall is sufficient (non-random is only used for debugging purposes)
        RandomStall = True
        named_config(tb, {'SupportZero_g': SupportZero, 'RandomStall_g': RandomStall, 'RamBehavior_g': RamBehav})


#Dynamic Shift TB
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

#Arbiters
arb_prio_tb = 'olo_base_arb_prio_tb'
tb = olo_tb.test_bench(arb_prio_tb)
for Latency in [0, 1, 3]:
    named_config(tb, {'Latency_g': Latency})
arb_rr_tb = 'olo_base_arb_rr_tb'
#Only one config required, hence no "add_config" looping

#strobe generator
strobe_gen_tb = 'olo_base_strobe_gen_tb'
tb = olo_tb.test_bench(strobe_gen_tb)
for Freq in ["10.0e6", "13.2e6"]:
    for FMode in [False, True]:
        named_config(tb, {'FreqStrobeHz_g': Freq, 'FractionalMode_g' : FMode})

#strobe divider
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


#prbs
prbs_tbs = ['olo_base_prbs4_tb']
for tb_name in prbs_tbs:
    tb = olo_tb.test_bench(tb_name)
    for BitsPerSymbol in [1, 2, 3, 4]:
        named_config(tb, {'BitsPerSymbol_g': BitsPerSymbol})

#reset_gen
reset_gen_tb = 'olo_base_reset_gen_tb'
tb = olo_tb.test_bench(reset_gen_tb)
for Cycles in [3, 5, 50, 64]:
    tb.add_config(name=f'C={Cycles}', generics={'RstPulseCycles_g': Cycles})
for Cycles in [3, 5]:
    for Polarity in [0, 1]:
        for AsyncOutput in [True, False]:
            named_config(tb, {'RstPulseCycles_g': Cycles, 'RstInPolarity_g': Polarity, 'AsyncResetOutput_g': AsyncOutput})

#fifo_packet
fifo_packet_tb = 'olo_base_fifo_packet_tb'
tb = olo_tb.test_bench(fifo_packet_tb)
#Choose settings for short runtim
named_config(tb, {'RandomPackets_g': 10, 'RandomStall_g': True})
named_config(tb, {'RandomPackets_g': 10, 'RandomStall_g': False}) #Some checks require non-random stall
#fifo_packet_hs_tb does not have generics

#cam
cam_tb = 'olo_base_cam_tb'
tb = olo_tb.test_bench(cam_tb)
#Content smaller or bitter than RAM AddrBits
named_config(tb, {'ContentWidth_g': 10, 'RamBlockDepth_g': 512})
named_config(tb, {'ContentWidth_g': 10, 'RamBlockDepth_g': 4096})
#Test different RAM configs
named_config(tb, {'RamBlockWidth_g': 32, 'RamBlockDepth_g': 512})
named_config(tb, {'RamBlockWidth_g': 4, 'RamBlockDepth_g': 64})
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

#first bit decoder
decode_firstbit_tb = 'olo_base_decode_firstbit_tb'
tb = olo_tb.test_bench(decode_firstbit_tb)
for InReg in [True, False]:
    for OutReg in [True, False]:
        for PlRegs in [0, 2]:
            named_config(tb, {'InWidth_g': 64, 'InReg_g': InReg, 'OutReg_g': OutReg, 'PlRegs_g': PlRegs})
for InWidth in [512, 783]:
    for PlRegs in [0, 2]:
        named_config(tb, {'InWidth_g': InWidth, 'PlRegs_g': PlRegs})

#crc
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

########################################################################################################################
# olo_axi TBs
########################################################################################################################

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

########################################################################################################################
# olo_intf TBs
########################################################################################################################
debounce_tb = 'olo_intf_debounce_tb'
tb = olo_tb.test_bench(debounce_tb)
for IdleLevel in [0, 1]:
    for Mode in ["LOW_LATENCY", "GLITCH_FILTER"]:
        named_config(tb, {'IdleLevel_g': IdleLevel, 'Mode_g' : Mode})
for Mode in ["LOW_LATENCY", "GLITCH_FILTER"]:
    #Cover ranges around 31/32 and 63/64 in detail (clock divider edge cases)
    for Cycles in [10, 30, 31, 32, 50, 60, 61, 62, 63, 64, 65, 100, 200, 735]:
        named_config(tb, {'DebounceCycles_g': Cycles, 'Mode_g': Mode})

i2c_master_tb = 'olo_intf_i2c_master_tb'
tb = olo_tb.test_bench(i2c_master_tb)
for BusFreq in [int(100e3), int(400e3), int(1e6)]:
    named_config(tb, {'BusFrequency_g': BusFreq})
for IntTri in [True, False]:
    named_config(tb, {'InternalTriState_g': IntTri})

sync_tb = 'olo_intf_sync_tb'
tb = olo_tb.test_bench(sync_tb)
for SyncStages in [2, 4]:
    for ResetLvel in [0, 1]:
        named_config(tb, {'SyncStages_g': SyncStages, 'RstLevel_g': ResetLvel})

clk_meas_tb = 'olo_intf_clk_meas_tb'
tb = olo_tb.test_bench(clk_meas_tb)
freqs = [(100, 100), (123, 7837), (7837, 123)]
for FreqClk, FreqTest in freqs:
    named_config(tb, {'ClkFrequency_g': FreqClk, 'MaxClkTestFrequency_g': FreqTest})

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

uart_tb = 'olo_intf_uart_tb'
tb = olo_tb.test_bench(uart_tb)
for BaudRate in [115200, 10000000]:
    named_config(tb, {'BaudRate_g' : BaudRate})
for DataBits in [8, 9]:
    for Parity in ["none", "even", "odd"]:
        named_config(tb, {'DataBits_g': DataBits, 'Parity_g' : Parity})
for StopBits in ["1", "1.5", "2"]:
    named_config(tb, {'StopBits_g' : StopBits})

spi_master_tb = 'olo_intf_spi_master_tb'
tb = olo_tb.test_bench(spi_master_tb)
for FreqBus in [int(1e6), int(10e6)]:
    tb.add_config(name=f'F={FreqBus}',
                  generics={'BusFrequency_g': FreqBus})
for LsbFirst in [False, True]:
    tb.add_config(name=f'LF={LsbFirst}',
                  generics={'LsbFirst_g': LsbFirst})
for CPHA in [0, 1]:
    for CPOL in [0, 1]:
        tb.add_config(name=f'CPHA={CPHA}-CPOL={CPOL}',
                      generics={'SpiCpha_g': CPHA, 'SpiCpol_g': CPOL})

spi_master_fixsize_tb = 'olo_intf_spi_master_fixsize_tb'
tb = olo_tb.test_bench(spi_master_fixsize_tb)
for LsbFirst in [False, True]:
    tb.add_config(name=f'LF={LsbFirst}',
                  generics={'LsbFirst_g': LsbFirst})


########################################################################################################################
# Execution
########################################################################################################################

olo_tb.set_sim_option('ghdl.elab_flags', ['-frelaxed'])
olo_tb.set_sim_option('nvc.heap_size', '5000M')

if USE_COVERAGE:
    olo.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])
    olo.set_compile_option('modelsim.vlog_flags', ['+cover=bs'])
    olo_tb.set_sim_option("enable_coverage", True)
    #Add coverage for package TBs (otherwise coverage does not work)
    for f in olo_tb.get_source_files("*_pkg_*_tb.vhd"):
        f.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])

    def post_run(results):
        results.merge_coverage(file_name='coverage_data')
else:
    def post_run(results):
        pass

# Run
vu.main(post_run=post_run)

#Coverage analysis
#cover report -byfile -nocomment coverage_data
