# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from typing import List, Dict
import os
from copy import deepcopy
from jinja2 import Environment, FileSystemLoader
from EntityCollection import EntityCollection


class TopLevel:
    def __init__(self, entity : str):
        self.configs = {}
        self.fixGenerics = {}
        self.toolGenerics = {}
        self.entity = entity

    def add_fix_generics(self, fixGenerics : Dict[str, str]):
        self.fixGenerics = fixGenerics

    def add_tool_generics(self, tool : str, generics : Dict[str, str]):
        self.toolGenerics[tool] = generics

    def add_config(self, name : str, config : Dict[str, str]):
        self.configs[name] = config

    def get_configs(self) -> List[str]:
        return list(self.configs.keys())

    def create_syn_file(self, out_file : str, entity_collection : EntityCollection, 
                        config_name : str = None, tool_name : str = None):
        entity = entity_collection.get_entity(self.entity)

        # Get list of generics
        all_generics = deepcopy(entity.generics)
        for generic, value in self.fixGenerics.items():
            all_generics[generic].default = value
        if config_name is not None:
            for generic, value in self.configs[config_name].items():
                all_generics[generic].default = value
        if tool_name is not None:
            if tool_name in self.toolGenerics: #Only if generics are set for this tool
                for generic, value in self.toolGenerics[tool_name].items():
                    all_generics[generic].default = value
                
        # Create file
        env = Environment(loader=FileSystemLoader("/"))
        template_path = os.path.join(os.path.dirname(__file__), "top.template")
        template = env.get_template(template_path)
        data = {
            "generics" : list(all_generics.values()),
            "entity_name" : self.entity,
            "ports" : list(entity.ports.values()),
        }
        rendered_template = template.render(data)
        with open(f"{out_file}", "w+") as f:
            f.write(rendered_template)



    