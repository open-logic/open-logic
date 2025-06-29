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
    """
    Information about a port connected to I/O reduction logic.
    This is used to reduce the number of ports in the top-level entity.
    """
    port: str   # Name of the port
    high : int  # High index of the port in the reduced signal
    low : int   # Low index of the port in the reduced signal


class TopLevel:
    """
    A class to create a top-level VHDL file for synthesis.
    """
    def __init__(self, entity : str):
        """
        Constructor
        """
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
        """
        Add generics that should be fixed to a certain value in the top-level entity for all
        configurations and tools.

        :param fixGenerics: A dictionary where the key is the generic name and the value is the fixed value.
        """
        self.fixGenerics = fixGenerics

    def add_tool_generics(self, tool : str, generics : Dict[str, str]):
        """
        Add generics that should be fixed to a certain value in the top-level entity for a specific tool.
        This is useful if a tool requires certain generics to be set to specific values.

        :param tool: The name of the tool.
        :param generics: A dictionary where the key is the generic name and the value is the fixed value.
        """
        self.toolGenerics[tool] = generics

    def add_config(self, name : str, config : Dict[str, str], omitted_ports : List[str] = None, 
                   in_reduce = None , out_reduce = None):
        """
        Add a configuration for the top-level entity.

        Port reduction (see below) is done to avoid the top-level having more ports than the target device because
        this can lead to synthesis errors. Reduced ports are mapped to logic that reduced the number of I/Os to 2 per
        direction but avoids optimization of the signals.

        :param name: The name of the configuration.
        :param config: A dictionary where the key is the generic name and the value is the generic value.
        :param omitted_ports: A list of ports that should be omitted in the top-level entity.
                             If None, no ports are omitted.
        :param in_reduce: A dictionary where the key is the port name and the value is the width of the port to be reduced.
                          If None, no input ports are reduced.
        :param out_reduce: A dictionary where the key is the port name and the value is the width of the port to be reduced.
                           If None, no output ports are reduced.
        """
        self.configs[name] = config
        self.omitted_ports[name] = omitted_ports if omitted_ports is not None else []
        self.in_reduce[name] = in_reduce if in_reduce is not None else {}
        self.out_reduce[name] = out_reduce if out_reduce is not None else {}


    def get_configs(self) -> List[str]:
        """
        Get the names of all configurations that have been added to this top-level entity.

        :return: A list of configuration names.
        """
        return list(self.configs.keys())

    def create_syn_file(self, out_file : str, entity_collection : EntityCollection, 
                        config_name : str = None, tool_name : str = None):
        
        """
        Create a top-level VHDL file for synthesis.

        :param out_file: The output file path where the top-level VHDL file will be written.
        :param entity_collection: An EntityCollection object containing the entity in scope (and its gnenerics and ports)
        :param config_name: The name of the configuration to use. If None, the default configuration is used.
        :param tool_name: The name of the tool to use. If None, no tool-specific generics are applied.
        """
        # Get entity iformation
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
        """
        Get the last input and output reduction sizes used in the top-level entity.

        This is useful to calculate the resources produced by the input and output reduction logic.
        
        :return: A tuple containing the last input reduction size and the last output reduction size.
        """
        return (self._last_in_reduce, self._last_out_reduce)



    