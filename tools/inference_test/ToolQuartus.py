# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bruendler
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
        child.expect(pexpect.EOF, timeout=5*60)
        output = child.before.decode("utf-8").strip()
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError("Failed to retrieve Quartus version. Command returned a non-zero exit status.")
        return output

    def _extract_resource_count(self, line) -> int:
        return float(line.split(":")[1].split("/")[0].strip().replace(",",""))
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "RAM_blocks": 0,
            "DSP_blocks": 0,
            "ALMs": 0,
            "Registers": 0
        }

        summary_file = self._find_file_in_project(".fit.summary")

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
    
    def get_in_reduce_resources(self, size) -> dict:
        return {
            "RAM_blocks": 0,
            "DSP_blocks": 0,
            "ALMs": int(0.5 * size),
            "Registers": int(-1 + 2.24*size)
        }
    
    def get_out_reduce_resources(self, size) -> dict:
        return {
            "RAM_blocks": 0,
            "DSP_blocks": 0,
            "ALMs": int(0.5 * size),
            "Registers": size
        }
    
    def check_drc(self):
        # Latches
        log = self._find_file_in_project("quartus.log")
        with open(log, "r") as f:
            text = f.read()
            if "Inferred latch" in text:
                raise RuntimeError(f"DRC Violation: Latch detected - see reports and logs")


