###########################################################################
# Copyright (c) 2024 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
###########################################################################

# Imports
from jinja2 import Environment, FileSystemLoader
import os
import argparse

# Init
curdir = os.path.abspath(os.curdir)

# Parse command line arguments
parser = argparse.ArgumentParser()
parser.add_argument("--version", help="Specify the version", required=True)
args = parser.parse_args()


#Constants
VERSION = args.version
DESCRIPTIONS = {
    "base" : "Basic Circuitry (e.g. FIFOs, CDCs, ...)",
    "axi" : "AXI related modules",
    "intf" : "Interfaces (e.g. I2C, synchronizer, SPI, ...)"
}
DEPENDENCIES = {
    "base" : [],
    "axi" : ["base"],
    "intf" : ["base"]
}

#Jinja setup
print(curdir)
env = Environment(loader=FileSystemLoader(curdir))

# Navigate to src
os.chdir("../../src")

# Get all subdirectories
areas = os.listdir()

# Iterate over all areas
for area in areas:
    # Navigate to area
    os.chdir(area)
    # Get all VHDL files
    os.chdir("vhdl")
    vhdlFiles = os.listdir()
    # Navigate to area
    os.chdir("..")

    # Generaete core-file
    template = env.get_template("core.template")
    data = {
        "area" : area,
        "vhdlFiles" : vhdlFiles,
        "version" : VERSION,
        "description" : DESCRIPTIONS[area],
        "dependencies" : DEPENDENCIES[area]
    }
    rendered_template = template.render(data)
    with open(f"olo_{area}.core", "w+") as f:
        f.write(rendered_template)


    # Navigate to src
    os.chdir("..")

#Tutorials
os.chdir("../doc/tutorials")
data = {
    "version": VERSION
}
# Vivado Tutorial
os.chdir("VivadoTutorial/Files")
template = env.get_template("olo_vivado_tutorial.template")
rendered_template = template.render(data)
with open(f"olo_vivado_tutorial.core", "w+") as f:
    f.write(rendered_template)
os.chdir("../..")
#Quartus Tutorial
os.chdir("QuartusTutorial/Files")
template = env.get_template("olo_quartus_tutorial.template")
rendered_template = template.render(data)
with open(f"olo_quartus_tutorial.core", "w+") as f:
    f.write(rendered_template)
# Navigate back to tools
os.chdir(curdir)











