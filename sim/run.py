#!/usr/bin/env python3

########################################################################################################################
# Imports
########################################################################################################################

from vunit import VUnit
from glob import glob
import os
import sys
from enum import Enum
from functools import partial

# Import open-logic test configurations
# .. they are in separate files to keep the size of run.py in range
from test_configs import olo_axi, olo_intf, olo_fix, olo_base

########################################################################################################################
# Setup
########################################################################################################################

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
GENERATE_VHDL_LS_TOML = False
GENERATE_COMPILE_LIST = False

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
if "--vhdl_ls" in sys.argv:
    GENERATE_VHDL_LS_TOML = True
    argv.remove("--vhdl_ls")
if "--compile_list" in sys.argv:
    GENERATE_COMPILE_LIST = True
    argv.remove("--compile_list")


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
files += glob('../3rdParty/en_cl_fix/hdl/*.vhd', recursive=True)
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
# Test bench configurations
########################################################################################################################

# Load all TB configs. For the exact configurations, see the test_configs folder.
for area in [olo_base, olo_axi, olo_intf, olo_fix]:
    area.add_configs(olo_tb)

########################################################################################################################
# Execution
########################################################################################################################

# Generate compile list if needed
if GENERATE_COMPILE_LIST:
    #Generate list of files in the compile order
    compile_order = []
    vunit_compile_order = [item for item in vu.get_compile_order() if item.library.name == "olo"]
    for item in vunit_compile_order:
        path = os.path.relpath(item.name, os.path.join(os.path.dirname(__file__), ".."))
        compile_order.append(path)
    # Write file
    with open("../compile_order.txt", "w") as f:
        for item in compile_order:
            f.write(item + "\n")
    exit(0)

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

# Generate VHDL LS Config if needed
if GENERATE_VHDL_LS_TOML:
    from create_vhdl_ls_config import create_configuration
    from pathlib import Path
    create_configuration(output_path=Path('..'), vunit_proj=vu)
    exit(0)

# Run
vu.main(post_run=post_run)

#Coverage analysis
#cover report -byfile -nocomment coverage_data
