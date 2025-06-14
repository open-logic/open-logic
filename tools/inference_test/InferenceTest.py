# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
import os.path
from ToolQuartus import ToolQuartus
from ToolVivado import ToolVivado
from ToolGowin import ToolGowin
from ToolEfinity import ToolEfinity
from ToolLibero import ToolLibero
from ResourceResults import ResourceResults
from EntityCollection import EntityCollection
import os
import shutil
import argparse
from YamlInterpreter import YamlInterpreter
from datetime import datetime

# Argument parser setup
parser = argparse.ArgumentParser(description="Run inference tests with specified tools, top-levels, and configurations.")
parser.add_argument("--tool", type=str, choices=["vivado", "quartus", "gowin", "efinity", "libero"],
                    help="Specify the tool to use for synthesis (e.g., vivado, quartus, etc.).", required=False)
parser.add_argument("--entity", type=str,
                    help="Specify the name of the entity to test (e.g., test_olo_base_ram_sdp).", required=False)
parser.add_argument("--config", type=str,
                    help="Specify the configuration to test (e.g., NoBe-NoInit).", required=False)
parser.add_argument("--yml", type=str, required=True,
                    help="Path to the YAML file describing the test.")
parser.add_argument("--no-tables", action="store_true",
                    help="Suppress printing resource tables to stdout.")
args = parser.parse_args()

# Constants
SYN_FILE = os.path.abspath("./test.vhd")
IN_REDUCE_FILE = os.path.abspath("./vhdl/in_reduce.vhd")
OUT_REDUCE_FILE = os.path.abspath("./vhdl/out_reduce.vhd")
OUT_PATH = os.path.abspath("./results")

# Parse the YAML file
intp = YamlInterpreter(os.path.abspath(args.yml))

# Get top level files
top_files = {x.entity : x for x in intp.get_top_levels()}

# Create Entity Collecton
ec = EntityCollection()
for file in intp.files:
    ec.parse_vhdl_file(file)

# Selected entity
if args.entity:
    if args.entity in top_files:
        top_files = {args.entity: top_files[args.entity]}
    else:
        raise ValueError(f"Invalid --entity: {args.entity}")

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

    overall_start = datetime.now()

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
        for entity_name, top_file in top_files.items():
            print(f"> File: {entity_name}")
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
                        start = datetime.now()
                        print(f"    > Config: {config:30} ", end="")
                        top_file.create_syn_file(out_file=SYN_FILE, entity_collection=ec, config_name=config, tool_name=tool_name)
                        tool.sythesize(files=[SYN_FILE, IN_REDUCE_FILE, OUT_REDUCE_FILE], top_entity="test")
                        #Calculate real resources
                        in_red_size, out_red_size = top_file.get_last_syn_reduction()
                        resources_measured = tool.get_resource_usage()
                        resources_total = {k: resources_measured[k] - tool.get_in_reduce_resources(in_red_size)[k] - tool.get_out_reduce_resources(out_red_size)[k] for k in resources_measured}
                        #Result handling
                        resource_results.add_results(config, resources_total)
                        end = datetime.now()
                        runtime = end - start
                        runtime_str = f"{runtime.seconds // 60:02}:{runtime.seconds % 60:02}"
                        print(f"[{runtime_str}]")

                    # Print to stdout
                    if not args.no_tables:
                        print(resource_results.get_table())

                    # Write to results file
                    f.write(f"### {entity_name} - {tool_name} ###\n")
                    f.write(resource_results.get_table().get_string())
                    f.write("\n\n")
                    f.flush()
    #Print Runtime
    overall_end = datetime.now()
    overall_runtime = overall_end - overall_start
    hours = overall_runtime.seconds // 3600
    minutes = (overall_runtime.seconds % 3600) // 60
    seconds = overall_runtime.seconds % 60
    overall_runtime_str = f"{hours:02}:{minutes:02}:{seconds:02}"
    print(f"Overall Runtime: {overall_runtime_str}\n")

    print("*** Done ***")
