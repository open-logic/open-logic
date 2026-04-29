########################################################################################################################
# Imports
########################################################################################################################

from vunit import VUnit, VUnitCLI
from glob import glob
import os

# Import open-logic test configurations
# .. they are in separate files to keep the size of run.py in range
from test_configs import olo_axi, olo_intf, olo_fix, olo_base
from codegen import generate as codegen_generate

########################################################################################################################
# Code Generators
########################################################################################################################
# Code-generator tests must generate code before VUnit detects files because the files must be present for VUnit
# to detect them.
codegen_generate()

########################################################################################################################
# Setup
########################################################################################################################

# Execute from sim directory
os.chdir(os.path.dirname(os.path.realpath(__file__)))

cli = VUnitCLI()
group = cli.parser.add_mutually_exclusive_group()
group.add_argument(
    "--modelsim",
    action="store_true",
    default=False,
    help="Use Modelsim/Questa as simulator",
)
group.add_argument(
    "--nvc",
    action="store_true",
    default=False,
    help="Use NVC as simulator",
)
group.add_argument(
    "--ghdl",
    action="store_true",
    default=True,
    help="Use GHDL as simulator (default)",
)
group.add_argument(
    "--rivierapro",
    action="store_true",
    default=False,
    help="Use Riviera-PRO as simulator",
)
cli.parser.add_argument(
    "--coverage",
    action="store_true",
    default=False,
    help="Enables simulation coverage",
)
cli.parser.add_argument(
    "--vhdl_ls",
    action="store_true",
    default=False,
    help="Generate VHDL LS TOML configuration file",
)
cli.parser.add_argument(
    "--compile_list",
    action="store_true",
    default=False,
    help="Generate compile order list and exit",
)

args = cli.parse_args()

# Set simulator environment variable if not already set
if 'VUNIT_SIMULATOR' not in os.environ:
    # Simulator selection logic
    if args.modelsim:
        simulator = 'modelsim'
    elif args.nvc:
        simulator = 'nvc'
    elif args.rivierapro:
        simulator = 'rivierapro'
        print("Warning: Riviera Pro is not actively maintained by Open Logic, see HowTo document.")
    else:  # args.ghdl is default True
        simulator = 'ghdl'
    os.environ['VUNIT_SIMULATOR'] = simulator

# Rivierapro workaround: VUnit's format_generic only quotes values containing spaces,
# but Rivierapro parses unquoted values like "(1,8,4)" as VHDL aggregates instead of
# strings, rejecting them and falling back to the default generic value.
# Quoting values that contain '(', ')', or ',' fixes this.
if os.environ.get('VUNIT_SIMULATOR') == 'rivierapro':
    import vunit.sim_if.rivierapro as _rp
    def _rivierapro_format_generic(value):
        value_str = str(value)
        if any(c in value_str for c in '(), '):
            return f'"{value_str}"'
        return value_str
    _rp.format_generic = _rivierapro_format_generic

# Only allow coverage for modelsim or nvc
if args.coverage and simulator not in ['modelsim', 'nvc']:
    raise Exception("Coverage is only allowed with --modelsim or --nvc.")

# Parse VUnit Arguments
vu = VUnit.from_args(args=args)
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
if args.compile_list:
    # Generate list of files in the compile order
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

# Disable IEEE numeric_std warnings to avoid slow simulation speed due to X-propagation
olo_tb.set_sim_option('ghdl.sim_flags', ['--ieee-asserts=disable'])
olo_tb.set_sim_option('nvc.global_flags', ['--ieee-warnings=off'])
vu.set_sim_option("disable_ieee_warnings", True)
# Disable optimization - it's faster for Open Logic to run without
vu.set_sim_option("modelsim.vopt_flags", ["+acc"])
olo_tb.set_sim_option("modelsim.three_step_flow", True)

if args.coverage:
    olo.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])
    olo.set_compile_option('modelsim.vlog_flags', ['+cover=bs'])
    olo_tb.set_sim_option("enable_coverage", True)
    # Add coverage for package TBs (otherwise coverage does not work)
    for f in olo_tb.get_source_files("*_pkg_*_tb.vhd"):
        f.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])
    for f in olo_tb.get_source_files("*_pkg_tb.vhd"):
        f.set_compile_option('modelsim.vcom_flags', ['+cover=bs'])

    def post_run(results):
        if simulator == 'modelsim':
            results.merge_coverage(file_name='coverage_data')
        if simulator == 'nvc':
            os.system('nvc --cover-merge --output coverage_data ./*.ncdb')
            os.system('nvc --cover-report --per-file --output nvc_coverage coverage_data > nvc_coverage.txt 2>&1')
else:
    def post_run(results):
        pass

# Generate VHDL LS Config if needed
if args.vhdl_ls:
    from create_vhdl_ls_config import create_configuration
    from pathlib import Path
    create_configuration(output_path=Path('..'), vunit_proj=vu)
    exit(0)

# Run
vu.main(post_run=post_run)