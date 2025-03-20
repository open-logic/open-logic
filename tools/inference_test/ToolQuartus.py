# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from typing import List
from jinja2 import Environment, FileSystemLoader
from ToolBase import ToolBase
import os
import subprocess
import pexpect

class ToolQuartus(ToolBase):

    QUARTUS_FOLDER = os.path.abspath("./tools/quartus")
    IMPORT_SOURCES = os.path.abspath("../quartus/import_sources.tcl")

    def __init__(self):
        super().__init__()

    def sythesize(self, files : List[str], top_entity : str):
        # Call parent method
        super().sythesize(files, top_entity)

        # Sythesize
        data = {
            "project_folder" : self.PROJECT_FOLDER,
            "top_entity" : top_entity,
            "src_files" : [os.path.abspath(p) for p in files],
            "import_sources" : self.IMPORT_SOURCES
        }

        # Create quaruts script
        env = Environment(loader=FileSystemLoader("/"))
        template = env.get_template(f"{self.QUARTUS_FOLDER}/synthesize.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/synthesize.tcl", "w+") as f:
            f.write(rendered_template)

        # Call Sythesis
        cur_dir = os.curdir
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("quartus_sh -t synthesize.tcl")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("quartus.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"Quartus Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        child = pexpect.spawn("quartus_sh -v")
        child.expect(pexpect.EOF)
        output = child.before.decode("utf-8").strip()
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError("Failed to retrieve Quartus version. Command returned a non-zero exit status.")
        return output

    def _extract_resource_count(self, line) -> int:
        return int(line.split(":")[1].split("/")[0].strip())
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "RAM_blocks": 0,
            "DSP_blocks": 0,
            "ALMs": 0,
            "Registers": 0
        }

        summary_files = [f for f in os.listdir(self.PROJECT_FOLDER) if f.endswith(".fit.summary")]
        if not summary_files:
            raise FileNotFoundError(f"No .fit.summary file found in the {self.PROJECT_FOLDER,} directory.")
        summary_file = os.path.join(self.PROJECT_FOLDER, summary_files[0])
        if not os.path.exists(summary_file):
            raise FileNotFoundError(f"Summary file not found: {summary_file}")

        with open(summary_file, "r") as f:
            for line in f:
                if "Total RAM Blocks" in line:
                    resource_usage["RAM_blocks"] = self._extract_resource_count(line)
                elif "Total DSP Blocks" in line:
                    resource_usage["DSP_blocks"] = self._extract_resource_count(line)
                elif "Logic utilization (in ALMs)" in line:
                    resource_usage["ALMs"] = self._extract_resource_count(line)
                elif "Total registers" in line:
                    resource_usage["Registers"] = self._extract_resource_count(line)

        return resource_usage

    
