# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
import os.path

from TopLevel import TopLevel
from ToolQuartus import ToolQuartus
from ToolVivado import ToolVivado
from ToolGowin import ToolGowin
from ToolEfinity import ToolEfinity
from ToolLibero import ToolLibero
from ResourceResults import ResourceResults
import os
import shutil
import argparse

# Argument parser setup
parser = argparse.ArgumentParser(description="Run inference tests with specified tools, top-levels, and configurations.")
parser.add_argument("--tool", type=str, choices=["vivado", "quartus", "gowin", "efinity", "libero"],
                    help="Specify the tool to use for synthesis (e.g., vivado, quartus, etc.).")
parser.add_argument("--top_level", type=str,
                    help="Specify the name of the top-level to test (e.g., test_olo_base_ram_sdp).")
parser.add_argument("--config", type=str,
                    help="Specify the configuration to test (e.g., NoBe-NoInit).")
args = parser.parse_args()

# Constants
TOP_PATH = os.path.abspath("./top_levels")
SYN_FILE = os.path.abspath("./test.vhd")
OUT_PATH = os.path.abspath("./results")

# Define all top files
top_files = {}

# olo_base_ram_sdp
top_file = TopLevel(f"{TOP_PATH}/test_olo_base_ram_sdp.template")
top_file.add_fix_generics({
    "Depth_g" : "512",
    "Width_g" : "16",
    "InitString_g" : "\"0x1234, 0x5678, 0xDEAD, 0xBEEF\""
})
top_file.add_config("NoBe-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "false"})
top_file.add_config("NoBe-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "false"})
top_file.add_config("Be-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "true"})
top_file.add_config("Be-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "true"})
top_files["test_olo_base_ram_sdp"] = top_file

top_file = TopLevel(f"{TOP_PATH}/test_olo_base_ram_sp.template")
top_file.add_fix_generics({
    "Depth_g" : "512",
    "Width_g" : "16",
    "InitString_g" : "\"0x1234, 0x5678, 0xDEAD, 0xBEEF\""
})
top_file.add_config("NoBe-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "false"})
top_file.add_config("NoBe-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "false"})
top_file.add_config("Be-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "true"})
top_file.add_config("Be-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "true"})
top_files["test_olo_base_ram_sp"] = top_file

top_file = TopLevel(f"{TOP_PATH}/test_olo_base_ram_tdp.template")
top_file.add_fix_generics({
    "Depth_g" : "512",
    "Width_g" : "16",
    "InitString_g" : "\"0x1234, 0x5678, 0xDEAD, 0xBEEF\"",
    "RamBehavior_g" : "\"WBR\""
})
top_file.add_config("NoBe-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "false"})
top_file.add_config("NoBe-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "false"})
top_file.add_config("Be-NoInit", {"InitFormat_g": '"NONE"', "UseByteEnable_g": "true"})
top_file.add_config("Be-Init", {"InitFormat_g": '"HEX"', "UseByteEnable_g": "true"})
top_file.add_tool_generics("quartus", {"RamBehavior_g" : '"WBR"'})
top_files["test_olo_base_ram_tdp"] = top_file

# Selected top level
if args.top_level:
    if args.top_level in top_files:
        top_files = {args.top_level: top_files[args.top_level]}
    else:
        raise ValueError(f"Invalid --top_level: {args.top_level}")


# Define all tools
tools = {"quartus" : ToolQuartus(),
         "vivado"  : ToolVivado(),
         "gowin"   : ToolGowin(),
         "efinity" : ToolEfinity(),
         "libero"  : ToolLibero()}
if args.tool:
    if args.tool in tools:
        tools = {args.tool: tools[args.tool]}
    else:
        raise ValueError(f"Invalid --tool: {args.tool}")

if __name__ == '__main__':

    # Clean output folder
    if os.path.exists(OUT_PATH):
        shutil.rmtree(OUT_PATH)
    os.makedirs(OUT_PATH)

    #Docucment version info
    print("*** Document Verion Info ***")
    with open(f"{OUT_PATH}/results.txt", "w+") as f:
        for tool_name, tool in tools.items():
            print(tool_name)
            f.write(f"### {tool_name} ###\n")
            f.write(f"{tool.get_version()}\n\n")

        print("*** Execute Tests ***")
        for top_file_name, top_file in top_files.items():
            print(f"> File: {top_file_name}")
            for tool_name, tool in tools.items():
                    print(f"  > Tool: {tool_name}")
                    resource_results = ResourceResults()

                    #Select config
                    configs = top_file.get_configs()
                    if args.config:
                        if args.config in configs:
                            configs = [args.config]
                        else:
                            raise ValueError(f"Invalid --config: {args.config}")
                        
                    # Iterate through configs
                    for config in configs:
                        print(f"    > Config: {config}")
                        top_file.create_syn_file(out_file=SYN_FILE, entity_name="test", config_name=config, tool_name=tool_name)
                        tool.sythesize(files=[SYN_FILE], top_entity="test")
                        resource_results.add_results(config, tool.get_resource_usage())
                    print(resource_results.get_table())
                    f.write(f"### {top_file_name} - {tool_name} ###\n")
                    f.write(resource_results.get_table().get_string())
                    f.write("\n\n")

    print("*** Done ***")