###############################################################################
# Copyright (c) 2024 by Oliver Bründler, Switzerland
# All rights reserved.
# Authors: Oliver Bruendler
###############################################################################

from os import path
import glob
import argparse
import shutil


#Parse Arguments
# Parse command line arguments
HELP_LIBRARY = \
"""
VHDL library to compile into".
For using from VHDL, files are usually compiled into the library 'olo'.
For using from Verilog, files are usually compiled into the library 'default'.
For details and reasoning, see markdown documentation.
"""
parser = argparse.ArgumentParser(description="Import Open Logic sources into Efinity project file")
parser.add_argument("--project", type=str, help="Path to the project file (<name>.xml)", required=True)
parser.add_argument("--library", type=str, help=HELP_LIBRARY, required=True)
args = parser.parse_args()

# Find all *.vhd files in SRC_DIR/.../vhdl
SRC_DIR = path.join(path.dirname(path.abspath(__file__)), "../../src")
files_rel = glob.glob(path.join(SRC_DIR, "**/vhdl/*.vhd"), recursive=True)

# Get project directory
prj_file = path.abspath(args.project)
prj_dir = path.dirname(prj_file)

#Store backup of project file
shutil.copy(prj_file, prj_file + ".backup")

# Get VHDL library to compile into
lib = args.library

#Find all *.vhd files in SRC_DIR/.../vhdl
files_rel = glob.glob(path.join(SRC_DIR, "**/vhdl/*.vhd"), recursive=True)
files_rel += glob.glob(path.join(SRC_DIR, "../3rdParty/en_cl_fix/hdl/*.vhd"), recursive=True)


# Create file paths relative to project directory
files_rel_prj = [path.relpath(path.abspath(f), path.abspath(prj_dir)) for f in files_rel]

#Efinity does not cleanly stick to XML rules, therefore no XML library is used but the file is
#... edited exactly the way required.

#Read project file into string
with open(prj_file, "r") as f:
    prj_lines = f.readlines()

#Find index of the first project file
for i, l in enumerate(prj_lines):
    if l.strip().startswith("<efx:top_module"):
        target_idx = i + 1
        break
else:
    raise "No line starting with '<efx:design_file' found in project file"

#Find whitespaces
whitespaces = prj_lines[target_idx].split("<")[0]

#Add lines
for f in files_rel_prj:
    prj_lines.insert(target_idx, whitespaces + f'<efx:design_file name="{f}" version="vhdl_2008" library="{lib}"/>\n')

#Write file
with open(prj_file, "w+") as f:
    f.writelines(prj_lines)

