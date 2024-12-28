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
repoRoot = os.path.abspath(f"{curdir}/../../")

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
env = Environment(loader=FileSystemLoader(curdir))

# Navigate to src
os.chdir(f"{repoRoot}/src")

# Get all subdirectories
areas = os.listdir()

#Create stable directory
os.makedirs(f"{repoRoot}/tools/fusesoc/stable/{VERSION}", exist_ok=True)

# Generate dev/stable cores
for state in ["dev", "stable"]:

    # Select library name and codebase
    if state == "dev":
        codebase = "local files (release plus WIP)"
        postfix = "-dev"
        filepostfix = "_dev"
    elif state == "stable":
        codebase = "official release (stable)"
        postfix = ""
        filepostfix = ""
    else:
        raise ValueError("Invalid state (dev/stable)")

    library = "open-logic" + postfix
    tutorial_library = "tutorials" + postfix

    # Iterate over all areas
    for area in areas:    

        # Get all VHDL files
        os.chdir(f"{repoRoot}/src/{area}/vhdl")
        vhdlFiles = os.listdir()
        # Navigate to area
        os.chdir("..")

        # Select proper repo root or .core file as reference
        if state == "dev":
            fileDir = "vhdl/"
            targetDir = "."
        elif state == "stable":
            fileDir = f"src/{area}/vhdl/"
            targetDir = f"{repoRoot}/tools/fusesoc/stable/{VERSION}"
        else:
            raise ValueError("Invalid state (dev/stable)")

        # Generaete core-file
        template = env.get_template("core.template")
        data = {
            "area" : area,
            "fileDir" : fileDir,
            "vhdlFiles" : vhdlFiles,
            "version" : VERSION,
            "description" : DESCRIPTIONS[area],
            "dependencies" : DEPENDENCIES[area],
            "library" : library,
            "codebase" : codebase
        }
        rendered_template = template.render(data)
        with open(f"{targetDir}/olo_{area}{filepostfix}.core", "w+") as f:
            f.write(rendered_template)

    # Select proper repo root or .core file as reference
    if state == "dev":
        vivadoFileDir = ""
        quartusFileDir = ""
        vivadoTargetDir = "."
        quartusTargetDir = "."
    elif state == "stable":
        vivadoFileDir = "doc/tutorials/VivadoTutorial/Files/"
        quartusFileDir = "doc/tutorials/QuartusTutorial/Files/"
        vivadoTargetDir = f"{repoRoot}/tools/fusesoc/stable/{VERSION}"
        quartusTargetDir = f"{repoRoot}/tools/fusesoc/stable/{VERSION}"
    else:
        raise ValueError("Invalid state (dev/stable)")

    #Tutorials
    data = {
        "version": VERSION,
        "library": library,
        "codebase": codebase,
        "tutorial_library": tutorial_library
    }
    # Vivado Tutorial
    data["fileDir"] = vivadoFileDir
    os.chdir(f"{repoRoot}/doc/tutorials/VivadoTutorial/Files")
    template = env.get_template("olo_vivado_tutorial.template")
    rendered_template = template.render(data)
    with open(f"{vivadoTargetDir}/olo_vivado_tutorial{filepostfix}.core", "w+") as f:
        f.write(rendered_template)

    #Quartus Tutorial
    data["fileDir"] = quartusFileDir
    os.chdir(f"{repoRoot}/doc/tutorials/QuartusTutorial/Files")
    template = env.get_template("olo_quartus_tutorial.template")
    rendered_template = template.render(data)
    with open(f"{quartusTargetDir}/olo_quartus_tutorial{filepostfix}.core", "w+") as f:
        f.write(rendered_template)

# Navigate back to tools
os.chdir(curdir)











