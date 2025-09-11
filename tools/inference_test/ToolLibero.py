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

class ToolLibero(ToolBase):

    LIBERO_FOLDER = os.path.abspath("./tools/libero")
    IMPORT_SOURCES = os.path.abspath("../libero/import_sources.tcl")

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

        # Create libero script
        env = Environment(loader=FileSystemLoader("/"))
        template = env.get_template(f"{self.LIBERO_FOLDER}/synthesize.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/synthesize.tcl", "w+") as f:
            f.write(rendered_template)

        # Call Sythesis
        cur_dir = os.curdir
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("libero script:synthesize.tcl")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("libero.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"Libero Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        return "Efinity: Libero cannot be retrieved from commandline."
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "Block RAM": 0,
            "DSPs": 0,
            "LUTs": 0,
            "SLEs": 0
        }

        # Find summary ile
        summary_file = self._find_file_in_project(".srr")

        # Extract resource usage
        with open(summary_file, "r") as f:
            for line in f:
                if "Total Block RAMs " in line:
                    resource_usage["Block RAM"] = float(line.split(":")[1].strip().split(" ")[0])
                elif "Total LUTs" in line:
                    resource_usage["LUTs"] = float(line.split(":")[1].strip())
                elif "DSP Blocks: " in line:
                    resource_usage["DSPs"] = float(line.split(":")[1].strip().split(" ")[0])
                elif "Total number of SLEs after P&R: " in line:
                    resource_usage["SLEs"] = float(line.split("=")[1].strip().strip(";").split(" ")[0])

        return resource_usage
    
    def get_in_reduce_resources(self, size) -> dict:
        return {
            "Block RAM": 0,
            "DSPs": 0,
            "LUTs": 0,
            "SLEs": size*2
        }
    
    def get_out_reduce_resources(self, size) -> dict:
        return {
            "Block RAM": 0,
            "DSPs": 0,
            "LUTs": size,
            "SLEs": size
        }
    
    def check_drc(self):
        # Latches
        log = self._find_file_in_project(".srr")
        with open(log, "r") as f:
            text = f.read()
            if "Latch generated" in text:
                raise RuntimeError(f"DRC Violation: Latch detected - see reports and logs")

    
