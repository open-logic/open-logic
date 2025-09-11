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

class ToolGowin(ToolBase):

    GOWIN_FOLDER = os.path.abspath("./tools/gowin")
    IMPORT_SOURCES = os.path.abspath("../gowin/import_sources.tcl")

    def __init__(self):
        super().__init__()

        # Workaround for ubutu 24.04
        os.environ["LD_PRELOAD"] = "/lib/x86_64-linux-gnu/libfreetype.so.6"

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
        template = env.get_template(f"{self.GOWIN_FOLDER}/synthesize.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/synthesize.tcl", "w+") as f:
            f.write(rendered_template)

        # Call Sythesis
        cur_dir = os.curdir
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("gw_sh synthesize.tcl")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("gowin.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"Gowin Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        return "Gowin: Version cannot be retrieved from commandline."

    def _extract_resource_count(self, line) -> str:
        field = line.split("|")[1].strip()
        res_cnt = field.split("/")[0]
        return float(res_cnt)
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "LUT": 0,
            "Register": 0,
            "BSRAM": 0,
            "DSP": 0,
        }

        # Find summary ile
        summary_file = self._find_file_in_project(".rpt.txt")

        # Extract resource usage
        with open(summary_file, "r") as f:
            for line in f:
                line_nospace = line.replace(" ", "")
                if "Logic|" in line_nospace:
                    resource_usage["LUT"] = self._extract_resource_count(line)
                elif "Register|" in line_nospace:
                    resource_usage["Register"] = self._extract_resource_count(line)
                elif "BSRAM|" in line_nospace:
                    resource_usage["BSRAM"] = self._extract_resource_count(line)
                elif "DSP|" in line_nospace:
                    resource_usage["DSP"] = self._extract_resource_count(line)

        return resource_usage
    
    def get_in_reduce_resources(self, size) -> dict:
        return {
            "LUT": 0,
            "Register": size*2,
            "BSRAM": 0,
            "DSP": 0,
        }
    
    def get_out_reduce_resources(self, size) -> dict:
        return {
            "LUT": size,
            "Register": size,
            "BSRAM": 0,
            "DSP": 0,
        }
    
    def check_drc(self):
        # Latches
        log = self._find_file_in_project("gowin.log")
        with open(log, "r") as f:
            text = f.read()
            if "Latch inferred" in text:
                raise RuntimeError(f"DRC Violation: Latch detected - see reports and logs")

    
