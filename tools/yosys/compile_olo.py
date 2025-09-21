###############################################################################
# Copyright (c) 2025 by Oliver Bruendler, Switzerland
# Authors: Oliver Bruendler
###############################################################################

from os import path
import os
import glob
import argparse
import shutil

SCRIPT_DIR = path.dirname(path.abspath(__file__))
OLO_DIR = path.abspath(path.join(SCRIPT_DIR, "..", ".."))

#Read compile-order file
with open(path.join(OLO_DIR, "compile_order.txt"), "r") as f:
    comppile_order = f.readlines()

# Create file paths relative to project directory
files_abs = [path.join(OLO_DIR, f) for f in comppile_order]

# Create yosys script to compile all files
for vhdl_file in files_abs:
    os.system(f"ghdl -a --std=08 --work=olo -frelaxed-rules -Wno-hide -Wno-shared -Wno-unhandled-attribute {vhdl_file}")