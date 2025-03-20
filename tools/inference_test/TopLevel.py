# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from typing import List, Dict
import os
from copy import deepcopy
from jinja2 import Environment, FileSystemLoader


class TopLevel:
    def __init__(self, file_path : str):
        self.file_path = os.path.abspath(file_path)
        self.configs = {}
        self.fixGenerics = {}
        self.sub = None

    def add_fix_generics(self, fixGenerics : Dict[str, str]):
        self.fixGenerics = fixGenerics

    def add_config(self, name : str, config : Dict[str, str]):
        self.configs[name] = config

    def get_configs(self) -> List[str]:
        return list(self.configs.keys())

    def create_syn_file(self, out_file : str, entity_name : str, config_name : str = None):
        # Get complete generics list
        all_generics = deepcopy(self.fixGenerics)
        if config_name is not None:
            all_generics.update(self.configs[config_name])
        
        # Create generics text
        generics_text = ""
        if len(all_generics) > 0:
            generics_text +=   "    generic map(\n"
            generics_lines = [f"        {key} => {value}" for key, value in all_generics.items()]
            generics_text += ",\n".join(generics_lines)
            generics_text += "\n    )"
        

        # Create file
        env = Environment(loader=FileSystemLoader("/"))
        template = env.get_template(self.file_path)
        data = {
            "generics" : generics_text,
            "entity_name" : entity_name
        }
        rendered_template = template.render(data)
        with open(f"{out_file}", "w+") as f:
            f.write(rendered_template)



    