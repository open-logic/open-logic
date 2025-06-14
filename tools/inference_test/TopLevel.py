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
from dataclasses import dataclass

@dataclass
class ReduceInfo:
    port: str
    high : int
    low : int


class TopLevel:
    def __init__(self, entity : str):
        self.configs = {}
        self.omitted_ports = {}
        self.in_reduce = {}
        self.out_reduce = {}
        self.fixGenerics = {}
        self.toolGenerics = {}
        self.entity = entity
        self._last_in_reduce = 0
        self._last_out_reduce = 0

    def add_fix_generics(self, fixGenerics : Dict[str, str]):
        self.fixGenerics = fixGenerics

    def add_tool_generics(self, tool : str, generics : Dict[str, str]):
        self.toolGenerics[tool] = generics

    def add_config(self, name : str, config : Dict[str, str], omitted_ports : List[str] = None, in_reduce = None , out_reduce = None):
        self.configs[name] = config
        self.omitted_ports[name] = omitted_ports if omitted_ports is not None else []
        self.in_reduce[name] = in_reduce if in_reduce is not None else {}
        self.out_reduce[name] = out_reduce if out_reduce is not None else {}


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
                
        # Get rendering template
        env = Environment(loader=FileSystemLoader("/"))
        template_path = os.path.join(os.path.dirname(__file__), "top.template")
        template = env.get_template(template_path)

        #Get ports (and omit the ones that are not needed)
        presentPorts = deepcopy(entity.ports)
        for p in self.omitted_ports[config_name]:
            presentPorts.pop(p)
        topPorts = deepcopy(presentPorts)

        # Input port reduction handling
        idx = 0
        in_reduce = []
        for port, width in self.in_reduce[config_name].items():
            if port in presentPorts:
                topPorts.pop(port)
                in_reduce.append(ReduceInfo(port=port, high=idx+width-1, low=idx))
                idx += width
        in_reduce_total = idx
        self._last_in_reduce = in_reduce_total

        # Output port reduction handling
        idx = 0
        out_reduce = []
        for port, width in self.out_reduce[config_name].items():
            if port in presentPorts:
                topPorts.pop(port)
                out_reduce.append(ReduceInfo(port=port, high=idx+width-1, low=idx))
                idx += width
        out_reduce_total = idx
        self._last_out_reduce = in_reduce_total

        # Render file
        data = {
            "generics" : list(all_generics.values()),
            "entity_name" : self.entity,
            "top_ports" : list(topPorts.values()),
            "ports" : list(presentPorts.values()),
            "in_reduce" : in_reduce,
            "out_reduce" : out_reduce,
            "in_reduce_total" : in_reduce_total,
            "out_reduce_total" : out_reduce_total
        }
        rendered_template = template.render(data)
        with open(f"{out_file}", "w+") as f:
            f.write(rendered_template)

    def get_last_syn_reduction(self) -> tuple:
        return (self._last_in_reduce, self._last_out_reduce)



    