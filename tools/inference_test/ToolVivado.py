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

class ToolVivado(ToolBase):

    VIVADO_FOLDER = os.path.abspath("./tools/vivado")
    IMPORT_SOURCES = os.path.abspath("../vivado/import_sources.tcl")

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
        template = env.get_template(f"{self.VIVADO_FOLDER}/synthesize.template")
        rendered_template = template.render(data)
        with open(f"{self.PROJECT_FOLDER}/synthesize.tcl", "w+") as f:
            f.write(rendered_template)

        # Call Sythesis
        cur_dir = os.curdir
        os.chdir(self.PROJECT_FOLDER)
        child = pexpect.spawn("vivado -mode batch -source synthesize.tcl")
        child.expect(pexpect.EOF, timeout=30*60)
        with open("vivado.log", "w+") as f:
            f.write(child.before.decode("utf-8"))
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError(f"Vivado Compilation Failed - see log, code {child.exitstatus}")
        os.chdir(cur_dir)

    def get_version(self) -> str:
        child = pexpect.spawn("vivado -version")
        child.expect(pexpect.EOF, timeout=5*60)
        output = child.before.decode("utf-8").strip()
        child.close()
        if child.exitstatus != 0:
            raise RuntimeError("Failed to retrieve Vivado version. Command returned a non-zero exit status.")
        return output

    def _extract_resource_count(self, line) -> str:
        field = line.split("|")[2].strip()
        return float(field.replace(",",""))
    
    def get_resource_usage(self) -> dict:
        resource_usage = {
            "Block RAM Tile": 0,
            "DSPs": 0,
            "Slice LUTs": 0,
            "Slice Registers": 0
        }

        # Find summary ile
        summary_file = self._find_file_in_project("utilization_synth.rpt")

        # Extract resource usage
        with open(summary_file, "r") as f:
            for line in f:
                if "Slice LUTs*" in line:
                    resource_usage["Slice LUTs"] = self._extract_resource_count(line)
                elif "Slice Registers" in line:
                    resource_usage["Slice Registers"] = self._extract_resource_count(line)
                elif "| Block RAM Tile" in line:
                    resource_usage["Block RAM Tile"] = self._extract_resource_count(line)
                elif "DSPs" in line:
                    resource_usage["DSPs"] = self._extract_resource_count(line)

        return resource_usage

    def get_in_reduce_resources(self, size) -> dict:
        return {
            "Block RAM Tile": 0,
            "DSPs": 0,
            "Slice LUTs": 0,
            "Slice Registers": size*2
        }
    
    def get_out_reduce_resources(self, size) -> dict:
        return {
            "Block RAM Tile": 0,
            "DSPs": 0,
            "Slice LUTs": int(0.5 * size),
            "Slice Registers": size
        }
    
    def check_drc(self):
        # Latches
        log = self._find_file_in_project("vivado.log")
        with open(log, "r") as f:
            text = f.read()
            if "inferring latch" in text:
                raise RuntimeError(f"DRC Violation: Latch detected - see reports and logs")

    
