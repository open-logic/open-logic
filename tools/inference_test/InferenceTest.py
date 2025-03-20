# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
import os.path

from TopLevel import TopLevel
from ToolQuartus import ToolQuartus
import os
import shutil

# Constnatants
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


# Define all tools
tools = {"quartus" : ToolQuartus()}

if __name__ == '__main__':

    # Clean output folder
    if os.path.exists(OUT_PATH):
        shutil.rmtree(OUT_PATH)
    os.makedirs(OUT_PATH)

    #Docucment version info
    print("*** Document Verion Info ***")
    with open(f"{OUT_PATH}/versions.txt", "w+") as f:
        for tool_name, tool in tools.items():
            print(tool_name)
            f.write(f"### {tool_name} ###\n")
            f.write(f"{tool.get_version()}\n\n")

    print("*** Execute Tests ***")
    for top_file in top_files.values():
        print(f"> File: {top_file.file_path}")
        for tool_name, tool in tools.items():
                print(f"  > Tool: {tool_name}")
                for config in top_file.get_configs():
                    print(f"    > Config: {config}")
                    top_file.create_syn_file(out_file=SYN_FILE, entity_name="test", config_name=config)
                    tool.sythesize(files=[SYN_FILE], top_entity="test")
                    print(f"    - Resource Usage: {tool.get_resource_usage()}")

    print("*** Done ***")