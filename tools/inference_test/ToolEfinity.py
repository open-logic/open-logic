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
import time

class ToolEfinity(ToolBase):

    EFINITY_FOLDER = os.path.abspath("./tools/efinity")
    IMPORT_SOURCES = os.path.abspath("../efinity/import_sources.py")

    def __init__(self):
        super().__init__()

    def sythesize(self, files : List[str], top_entity : str):
        # Call parent method
        os.chdir(f"{self.PROJECT_FOLDER}/..") # Navigate out of project to avoid errors
        super().sythesize(files, top_entity)

        # Create synthesis project
        data = {
            "top_entity" : top_entity,
            "src_files" : [os.path.abspath(p) for p in files]
        }

        # Create project
        cur_dir = os.curdir
        env = Environment(loader=FileSystemLoader("/"))
        template = env.get_template(f"{self.EFINITY_FOLDER}/project.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/project.xml", "w+") as f:
            f.write(rendered_template)

        # Add Open Logic
        os.system(f"python3 {self.IMPORT_SOURCES} --project {self.PROJECT_FOLDER}/project.xml --library olo")

        # Call Sythesis
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("efx_run --prj ./project.xml")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("efinity.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"Efinity Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        return "Efinity: Version cannot be retrieved from commandline."

    def _extract_resource_count(self, field) -> str:
        return float(field.strip().split("(")[0])
    
    def get_resource_usage(self) -> dict:

        resource_usage = {
            "FFs": 0,
            "LUTs": 0,
            "RAMs": 0,
            "DSPs": 0
        }

        # Find summary ile
        summary_file = self._find_file_in_project(".res.csv")

        # Extract resource usage
        with open(summary_file, "r") as f:
            lines = f.readlines()
            for idx, line in enumerate(lines):
                if "ADDs" in line:
                    tbl_line = lines[idx+1]
                    fields = tbl_line.split("\t")
                    resource_usage["FFs"] = self._extract_resource_count(fields[1])
                    resource_usage["LUTs"] = self._extract_resource_count(fields[3])
                    resource_usage["RAMs"] = self._extract_resource_count(fields[4])
                    resource_usage["DSPs"] = self._extract_resource_count(fields[5])

        return resource_usage
    
    def get_in_reduce_resources(self, size) -> dict:
        return {
            "FFs": size*2,
            "LUTs": 0,
            "RAMs": 0,
            "DSPs": 0
        }

    def get_out_reduce_resources(self, size) -> dict:
        return {
            "FFs": size,
            "LUTs": size,
            "RAMs": 0,
            "DSPs": 0
        }
    
    def check_drc(self):
        # Latches
        log = self._find_file_in_project(".map.out")
        with open(log, "r") as f:
            text = f.read()
            if "latch inferred" in text:
                raise RuntimeError(f"DRC Violation: Latch detected - see reports and logs")

    
