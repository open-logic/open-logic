###############################################################################
# Copyright (c) 2024 by Oliver Bründler, Switzerland
# All rights reserved.
# Authors: Oliver Bruendler
###############################################################################

from os import path
import glob

SRC_DIR = "../../src"

#Find all *.vhd files in SRC_DIR/.../vhdl
files_rel = glob.glob(path.join(SRC_DIR, "**/vhdl/*.vhd"), recursive=True)

#Get project directory
print()
prj_file = input("Enter the path to the project file (<name>.xml): ")
if prj_file == "":
    raise "Project file-name must be specified"
prj_dir = path.dirname(prj_file)

#Get VHDL library to compile into")
print()
print("For using from VHDL, files are usually compiled into the library 'olo'.")
print("For using from Verilog, files are usually compiled into the library 'default'.")
print("For details and reasoning, see markdown documentation.")
lib = input("Enter the VHDL library to compile into: ")
if lib == "":
    raise "Library name can't be empty"

# Create file paths relative to project directory
files_rel_prj = [path.relpath(path.abspath(f), path.abspath(prj_dir)) for f in files_rel]

#Efinity does not cleanly stick to XML rules, therefore no XML library is used but the file is
#... edited exactly the way required.

#Read project file into string
with open(prj_file, "r") as f:
    prj_lines = f.readlines()

#Find index of the first project file
for i, l in enumerate(prj_lines):
    if l.strip().startswith("<efx:design_file"):
        target_idx = i
        break
else:
    raise "No line starting with '<efx:design_file' found in project file"

#Find whitespaces
whitespaces = prj_lines[target_idx].split("<")[0]

#Add lines
for f in files_rel_prj:
    prj_lines.insert(target_idx, whitespaces + f'<efx:design_file name="{f}" version="default" library="{lib}"/>\n')

#Write file
with open(prj_file, "w+") as f:
    f.writelines(prj_lines)

