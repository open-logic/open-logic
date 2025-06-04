###########################################################################
# Copyright (c) 2024 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
###########################################################################
# Parse a open-logic VHDL file and extract entity information to 
# generate a test synthesis wrapper for it.
# Note: Only works for VHDL strictly according to open-logic coding guidelines.
#       The parser is not meant to cover VHDL outside of open-logic guideliens.

###########################################################################
# Imports 
###########################################################################
import re
from collections import namedtuple
from dataclasses import dataclass
from typing import Dict
import fnmatch

###########################################################################
# Helper Classes 
###########################################################################

@dataclass
class GenericInfo:
    name: str
    type: str
    default: str = None

@dataclass
class PortInfo:
    name: str
    direction: str
    type: str
    default: str = None

@dataclass
class EntityInfo:
    entity: str
    ports: Dict[str, PortInfo]
    generics: Dict[str, GenericInfo]


###########################################################################
# Main Class
###########################################################################
class EntityCollection:

    def __init__(self):
        self.entities = {}

    def get_entity(self, entity_name: str) -> EntityInfo:
        """
        Returns the entity information for the given entity name.
        """
        return self.entities[entity_name]

    def parse_vhdl_file(self, file_path) -> Dict[str, EntityInfo]:
        """
        Parses a VHDL file (may contain multiple entites)
        """

        entities = {}

        with open(file_path, "r") as file:
            content = file.read()
            
            # Find all entity blocks: from 'entity' at line start to 'end' at line start
            entity_blocks = re.findall(r'(?m)^entity\b.*?^end\b.*?;', content, re.DOTALL)
            for block in entity_blocks:
                entity = self._parse_entity(block)
                self.entities[entity.entity] = entity

    def _parse_generics(self, generics_text) -> Dict[str, GenericInfo]:
        """
        Parse the generics section of the entity
        """
        generics = {}

        lines = generics_text.strip().splitlines()
        for line in lines:
            # Remove pre/post whitespaces
            line = line.strip()

            #Skip lines that do not hold generics according to OLO coding conventions
            if line.startswith("generic") or line.startswith(")") or line.startswith("--") or line == "":
                continue

            #Parse generic
            name, rem = line.split(":", 1)
            name = name.strip()
            default = None
            if ":=" in rem:
                type, rem = rem.strip().split(":=", 1)
                default = rem.strip().split(";")[0].strip()
            else:
                type = rem.strip().split(";")[0]
            type = type.strip()

            
            g = GenericInfo(name=name, type=type, default=default)
            generics[g.name] = g
        
        return generics


    def _parse_ports(self, ports_text) -> Dict[str, PortInfo]:
        """
        Parses the ports secton of an entity.
        """
        ports = {}

        lines = ports_text.strip().splitlines()
        for line in lines:
            # Remove pre/post whitespaces
            line = line.strip()

            #Skip lines that do not hold generics according to OLO coding conventions
            if line.startswith("port") or line.startswith(")") or line.startswith("--") or line == "":
                continue

            #Parse generic
            name, rem = line.split(":", 1)
            name = name.strip()
            dir, rem = rem.strip().split(" ", 1)
            dir = dir.strip()
            default = None
            if ":=" in rem:
                type, rem = rem.strip().split(":=", 1)
                default = rem.strip().split(";", 1)[0].strip()
            else:
                type = rem.strip().split(";", 1)[0]
            type = type.strip()

            
            p = PortInfo(name=name, direction=dir, type=type, default=default)
            ports[p.name] = p

        return ports


    def _parse_entity(self, entity_text) -> EntityInfo:
        """
        Parses an entity
        """
        entity_name = re.findall(r'(?m)^entity\s+(\w+)\s+is', entity_text)[0]
        generic_block = re.search(r'^\s*generic\s*\(.*?^\s*\);\s*', entity_text, re.DOTALL | re.MULTILINE).group(0)
        ports_block = re.search(r'^\s*port\s*\(.*?^\s*\);\s*', entity_text, re.DOTALL | re.MULTILINE).group(0)

        return EntityInfo(entity=entity_name, 
                          ports=self._parse_ports(ports_block), 
                          generics=self._parse_generics(generic_block))




