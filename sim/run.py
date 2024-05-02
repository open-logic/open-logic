
from vunit import VUnit
from glob import glob
import os
import sys

#Argument handling
argv = sys.argv[1:]
USE_GHDL = True
USE_COVERAGE = False
if "--modelsim" in sys.argv:
    USE_GHDL = False
    argv.remove("--modelsim")
if "--coverage" in sys.argv:
    USE_COVERAGE = True
    argv.remove("--coverage")
    if USE_GHDL:
        "Coverage is only allowed with --modelsim"

# Obviously the simulator must be chosen before sources are added
if USE_GHDL:
    os.environ['VUNIT_SIMULATOR'] = 'ghdl'
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
if USE_GHDL:
    vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])

# Clock Crossings
cc_tbs = ['olo_base_cc_simple_tb', 'olo_base_cc_status_tb', 'olo_base_cc_bits_tb', 'olo_base_cc_pulse_tb', 'olo_base_cc_reset_tb']
for tb_name in cc_tbs:
    tb = olo_tb.test_bench(tb_name)
    # Iterate through various clock combinations
    for N in [1, 3, 19, 20]:
        for D in [1, 3, 19, 20]:
            # Simulate same clock only once
            if N == D and N != 1:
                continue
            tb.add_config(name=f'D={D}-N={N}', generics={'ClockRatio_N_g': N, 'ClockRatio_D_g': D})

# Sync Clock Crossings
scc_tbs = ['olo_base_cc_xn2n_tb', 'olo_base_cc_n2xn_tb']
for tb_name in scc_tbs:
    tb = olo_tb.test_bench(tb_name)
    for R in [2, 3, 19]:
        tb.add_config(name=f'R={R}', generics={'ClockRatio_g': R})

# RAM TBs
ram_tbs = ['olo_base_ram_sp_tb', 'olo_base_ram_tdp_tb']
for tb_name in ram_tbs:
    tb = olo_tb.test_bench(tb_name)
    for RamBehav in ['RBW', 'WBR']:
        for ReadLatency in [1, 2]:
            for Width in [5, 32]:
                for Be in [True, False]:
                    if Width == 5 and Be == True:
                        continue #No byte enables for non multiple of 8
                    tb.add_config(name=f'B={RamBehav}-W={Width}-Be={Be}-Lat={ReadLatency}', generics={'Width_g': Width, 'RamBehavior_g': RamBehav, 'UseByteEnable_g' : Be, "RdLatency_g" : ReadLatency})
ram_tbs = ['olo_base_ram_sdp_tb']
for tb_name in ram_tbs:
    tb = olo_tb.test_bench(tb_name)
    for RamBehav in ['RBW', 'WBR']:
        for Async in [True, False]:
            for ReadLatency in [1,2]:
                for Width in [5, 32]:
                    for Be in [True, False]:
                        if Width == 5 and Be == True:
                            continue #No byte enables for non multiple of 8
                        tb.add_config(name=f'B={RamBehav}-W={Width}-Be={Be}-Async={Async}-Lat={ReadLatency}',
                                      generics={'Width_g': Width, 'RamBehavior_g': RamBehav, 'UseByteEnable_g' : Be, "RdLatency_g" : ReadLatency, "IsAsync_g" : Async})

#FIFO TBs
fifo_tbs = ['olo_base_fifo_sync_tb', 'olo_base_fifo_async_tb']
for tb_name in fifo_tbs:
    tb = olo_tb.test_bench(tb_name)
    for RamBehav in ['RBW', 'WBR']:
        for RstState in [0, 1]:
            for Depth in [32, 128]:
                for AlmFull in [True, False]:
                    for AlmEmpty in [True, False]:
                        tb.add_config(name=f'B={RamBehav}-D={Depth}-RdyRst={RstState}-AlmF={AlmFull}-AlmE={AlmEmpty}',
                                      generics={'RamBehavior_g': RamBehav, 'Depth_g': Depth, 'ReadyRstState_g': RstState,
                                                "AlmFullOn_g": AlmFull, "AlmEmptyOn_g": AlmEmpty})

#Width Converter TBs
wconv_tbs = ['olo_base_wconv_xn2n_tb', 'olo_base_wconv_n2xn_tb']
for tb_name in wconv_tbs:
    tb = olo_tb.test_bench(tb_name)
    for Ratio in [2, 3]:
        tb.add_config(name=f'R={Ratio}', generics={'WidthRatio_g': Ratio})

#Pipeline TB
pl_tb = 'olo_base_pl_stage_tb'
tb = olo_tb.test_bench(pl_tb)
for Stages in [0, 1, 5]:
    for UseReady in [True, False]:
        for RandomStall in [True, False]:
            tb.add_config(name=f'Stg={Stages}-Rdy={UseReady}-Rnd={RandomStall}',
                          generics={'Stages_g': Stages, 'UseReady_g': UseReady, 'RandomStall_g': RandomStall})

#Delay TB
delay_tb = 'olo_base_delay_tb'
tb = olo_tb.test_bench(delay_tb)
#No BRAM cases
BramThreshold = 16
for Delay in [0, 1, 2, 3, 8, 30, 32]:
    for Resource in ["BRAM", "SRL", "AUTO"]:
        for RstState in [True, False]:
            #Random-Stall is sufficient (non-random is only used for debugging purposes)
            RandomStall = True
            #Skip illegal configurations
            if (Resource == "BRAM" and Delay < 3):
                continue
            #Create test configurations
            RamBehav = "RBW"
            tb.add_config(name=f'D={Delay}-R={Resource}-RS={RstState}-Rnd={RandomStall}-B={RamBehav}',
                      generics={'Delay_g': Delay, 'Resource_g': Resource, 'RstState_g': RstState,
                                'RandomStall_g': RandomStall, 'RamBehavior_g': RamBehav})
            #Skip Ram behavior for non-ram cases
            if (Resource != "BRAM") and (Resource != "AUTO" or Delay < BramThreshold):
                continue
            RamBehav = "WBR"
            tb.add_config(name=f'D={Delay}-R={Resource}-RS={RstState}-Rnd={RandomStall}-B={RamBehav}',
                      generics={'Delay_g': Delay, 'Resource_g': Resource, 'RstState_g': RstState,
                                'RandomStall_g': RandomStall, 'RamBehavior_g': RamBehav})

#DelayCfg TB
delay_cfg_tb = 'olo_base_delay_cfg_tb'
tb = olo_tb.test_bench(delay_cfg_tb)
for SupportZero in [True, False]:
    for RamBehav in ["RBW", "WBR"]:
        # Random-Stall is sufficient (non-random is only used for debugging purposes)
        RandomStall = True
        tb.add_config(name=f'SZ={SupportZero}-Rnd={RandomStall}-B={RamBehav}',
              generics={'SupportZero_g': SupportZero, 'RandomStall_g': RandomStall, 'RamBehavior_g': RamBehav})


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
                tb.add_config(name=f'D={Direction}-BPS={BitsPerStage}-MS={MaxShift}-SE{SignExt}',
                              generics={'Direction_g': Direction, 'SelBitsPerStage_g': BitsPerStage,
                                        'MaxShift_g': MaxShift, 'SignExtend_g': SignExt})

#Arbiters
arb_prio_tb = 'olo_base_arb_prio_tb'
tb = olo_tb.test_bench(arb_prio_tb)
for Latency in [0, 1, 3]:
    tb.add_config(name=f'L={Latency}', generics={'Latency_g': Latency})
arb_rr_tb = 'olo_base_arb_rr_tb'
#Only one config required, hence no "add_config" looping

#strobe gorenerat
strobe_generator_tb = 'olo_base_strobe_generator_tb'
tb = olo_tb.test_bench(strobe_generator_tb)
for Freq in ["10.0e6", "13.2e6"]:
    tb.add_config(name=f'F={Freq}', generics={'FreqStrobeHz_g': Freq})

if USE_GHDL:
    olo_tb.set_sim_option('ghdl.elab_flags', ['-frelaxed'])

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
