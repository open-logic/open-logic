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
parser.add_argument("--cl-fix-version", help="Specify the version for cl_fix", required=False)
args = parser.parse_args()



#Constants
VERSION = args.version
CL_FIX_VERSION = args.cl_fix_version
DESCRIPTIONS = {
    "base" : "Basic Circuitry (e.g. FIFOs, CDCs, ...)",
    "axi" : "AXI related modules",
    "intf" : "Interfaces (e.g. I2C, synchronizer, SPI, ...)",
    "fix" : "Fixed point mathematics"
}
DEPENDENCIES = {
    "base" : [],
    "axi" : ["base"],
    "intf" : ["base"],
    "fix" : ["base"]
}

#Jinja setup
env = Environment(loader=FileSystemLoader(curdir))

# Navigate to src
os.chdir(f"{repoRoot}/src")

# Get all subdirectories
areas = os.listdir()

# Generate dev/stable cores
for state in ["dev", "stable"]:

    # Select library name and codebase
    if state == "dev":
        codebase = "local files (release plus WIP)"
        postfix = "-dev"
        filepostfix = "_dev"
    elif state == "stable":
        codebase = "stable release (downloaded from GitHub)"
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
            targetDir = f"{repoRoot}/tools/fusesoc/stable"
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
        # Add external dependencies where required
        if area == "fix":
            data["ext_dependencies"] = [f"^open-logic:{library}:en_cl_fix:{CL_FIX_VERSION}"]
        rendered_template = template.render(data)
        with open(f"{targetDir}/olo_{area}{filepostfix}.core", "w+") as f:
            f.write(rendered_template)

    # 3rd party repo en_cl_fix
    # Get all VHDL files
    os.chdir(f"{repoRoot}/3rdParty/en_cl_fix/hdl")
    vhdlFiles = os.listdir()
    # Navigate to cl_fix root
    os.chdir("..")
    # Select proper repo root or .core file as reference
    fileDir = "hdl/"
    if state == "dev":   
        targetDir = "."
    elif state == "stable":
        targetDir = f"{repoRoot}/tools/fusesoc/stable"
    else:
        raise ValueError("Invalid state (dev/stable)")
    # Generaete core-file
    template = env.get_template("en_cl_fix.template")
    data = {
        "submodule" : "en_cl_fix",
        "fileDir" : fileDir,
        "vhdlFiles" : vhdlFiles,
        "version" : CL_FIX_VERSION,
        "library" : library,
        "codebase" : codebase,
    }
    rendered_template = template.render(data)
    with open(f"{targetDir}/en_cl_fix{filepostfix}.core", "w+") as f:
        f.write(rendered_template)

    # Select proper repo root or .core file as reference
    if state == "dev":
        vivadoFileDir = ""
        quartusFileDir = ""
        fixFiledir = ""
        vivadoTargetDir = "."
        quartusTargetDir = "."
        fixTargetDir = "."
    elif state == "stable":
        vivadoFileDir = "doc/tutorials/VivadoTutorial/Files/"
        quartusFileDir = "doc/tutorials/QuartusTutorial/Files/"
        fixFiledir = "doc/tutorials/OloFixTutorial/Files/"
        vivadoTargetDir = f"{repoRoot}/tools/fusesoc/stable"
        quartusTargetDir = f"{repoRoot}/tools/fusesoc/stable"
        fixTargetDir = f"{repoRoot}/tools/fusesoc/stable"
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

    #OLO FIX Tutorial
    data["fileDir"] = fixFiledir
    os.chdir(f"{repoRoot}/doc/tutorials/OloFixTutorial/Files")
    template = env.get_template("olo_fix_tutorial.template")
    rendered_template = template.render(data)
    with open(f"{fixTargetDir}/olo_fix_tutorial{filepostfix}.core", "w+") as f:
        f.write(rendered_template)

# Navigate back to tools
os.chdir(curdir)











