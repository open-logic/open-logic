###############################################################################
# Copyright (c) 2025 by Oliver Bruendler, Switzerland
# Authors: Oliver Bruendler
###############################################################################

from os import path
import os
import glob
import argparse
import shutil

# argument parsing
parser = argparse.ArgumentParser(description="Compile Open Logic VHDL files using GHDL.")
parser.add_argument("--library", type=str, default="olo", help="Library to compile Open Logic into (default: olo). For Verilog use 'work'.")
args = parser.parse_args()
library = args.library

SCRIPT_DIR = path.dirname(path.abspath(__file__))
OLO_DIR = path.abspath(path.join(SCRIPT_DIR, "..", ".."))

#Read compile-order file
with open(path.join(OLO_DIR, "compile_order.txt"), "r") as f:
    comppile_order = f.readlines()

# Create file paths relative to project directory
files_abs = [path.join(OLO_DIR, f) for f in comppile_order]

# Create yosys script to compile all files
for vhdl_file in files_abs:
    os.system(f"ghdl -a --std=08 --work={args.library} -frelaxed-rules -Wno-hide -Wno-shared -Wno-unhandled-attribute {vhdl_file}")