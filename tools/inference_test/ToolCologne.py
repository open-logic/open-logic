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

class ToolCologne(ToolBase):

    COLOGNE_FOLDER = os.path.abspath("./tools/cologne")
    COMPILE_OLO = os.path.abspath("../yosys/compile_olo.py")

    def __init__(self):
        super().__init__()

    def sythesize(self, files : List[str], top_entity : str):
        # Call parent method
        super().sythesize(files, top_entity)

        # Sythesize
        data = {
            "top_entity" : top_entity,
            "src_files" : [os.path.abspath(p) for p in files],
            "compile_olo" : self.COMPILE_OLO
        }

        # Create oss-cad-suite script
        env = Environment(loader=FileSystemLoader("/"))
        template = env.get_template(f"{self.COLOGNE_FOLDER}/synthesize.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/synthesize.sh", "w+") as f:
            f.write(rendered_template)

        # Call Sythesis
        cur_dir = os.curdir
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("bash -c 'pwd; source ./synthesize.sh'")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("cologne.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"oss-cad-suite Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        child = pexpect.spawn("yosys --version")
        child.expect(pexpect.EOF, timeout=5*60)
        output = child.before.decode("utf-8").strip()
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError("Failed to retrieve Vivado version. Command returned a non-zero exit status.")
        return output

    def _extract_resource_count(self, line) -> str:
        field = line.split(":")[2].split("/")[0].strip()
        return float(field.replace(",",""))
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "RAM_HALF": 0,
            "CPE LT": 0,
            "CPE FF": 0
        }

        # Find summary ile
        summary_file = self._find_file_in_project("nexpnr.log")

        # Extract resource usage
        with open(summary_file, "r") as f:
            for line in f:
                # Resource lines end in %
                if not line.strip().endswith("%"):
                    continue
                if "RAM_HALF" in line:
                    resource_usage["RAM_HALF"] = self._extract_resource_count(line)
                elif "CPE_LT" in line:
                    resource_usage["CPE LT"] = self._extract_resource_count(line)
                elif "CPE_FF" in line:
                    resource_usage["CPE FF"] = self._extract_resource_count(line)

        return resource_usage

    def get_in_reduce_resources(self, size) -> dict:
        return {
            "RAM_HALF": 0,
            "CPE LT": int(size*3+4),
            "CPE FF": int(size*2+1)
        }
    
    def get_out_reduce_resources(self, size) -> dict:
        return {
            "RAM_HALF": 0,
            "CPE LT": int(size+1),
            "CPE FF": int(size)
        }
    
    def check_drc(self):
        # Not required because oss-cad-suite does fail compilation if there are
        # latches
        pass
    
