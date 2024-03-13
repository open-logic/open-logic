
from vunit import VUnit
from glob import glob
import os
import sys

#Argument handling
argv = sys.argv[1:]
print(argv)
print(sys.argv)
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
print(files)
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
olo_tb.test_bench('olo_base_pkg_math_tb').add_config(name='default')

if USE_COVERAGE:
    olo.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])
    olo.set_compile_option('modelsim.vlog_flags', ['+cover=bs'])
    olo_tb.set_sim_option("enable_coverage", True)
    #Add coverage for package TBs (otherwise coverage does not work)
    olo_tb.get_source_file("*_pkg_*_tb.vhd").set_compile_option('modelsim.vcom_flags', ['+cover=bs'])

    def post_run(results):
        results.merge_coverage(file_name='coverage_data')
else:
    def post_run(results):
        pass

# Run
vu.main(post_run=post_run)

#Coverage analysis
#cover report -byfile -nocomment coverage_data
