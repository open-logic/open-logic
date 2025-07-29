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
from dataclasses import dataclass
from typing import Dict

###########################################################################
# Helper Classes 
###########################################################################

@dataclass
class GenericInfo:
    """
    Holds information about a VHDL generic.
    """
    name: str
    type: str
    default: str = None

@dataclass
class PortInfo:
    """
    Holds information about a VHDL port.
    """
    name: str
    direction: str
    type: str
    default: str = None

@dataclass
class EntityInfo:
    """
    Holds information about a VHDL entity.
    """
    entity: str
    ports: Dict[str, PortInfo]
    generics: Dict[str, GenericInfo]


###########################################################################
# Main Class
###########################################################################
class EntityCollection:
    """
    A collection of VHDL entities in scope for a certain purpose. They may be distributed over multiple files.
    This class is used to parse VHDL files and extract entity information.
    """

    def __init__(self):
        """
        Constructor for the EntityCollection class.
        """
        # Dictionary to hold entity information, indexed by entity name
        self.entities = {}

    def get_entity(self, entity_name: str) -> EntityInfo:
        """
        Returns the entity information for the given entity name.

        :param entity_name: The name of the entity to retrieve.
        :return: EntityInfo object containing the entity information.
        """
        return self.entities[entity_name]

    def parse_vhdl_file(self, file_path):
        """
        Parses a VHDL file (may contain multiple entites)

        :param file_path: The path to the VHDL file to parse.
        """
        with open(file_path, "r") as file:
            content = file.read()
            
            # Find all entity blocks: from 'entity' at line start to 'end' at line start
            entity_blocks = re.findall(r'(?m)^entity\b.*?^end\b.*?;', content, re.DOTALL)

            # Parse each entity block and store the information in the entities dictionary
            for block in entity_blocks:
                entity = self._parse_entity(block)
                self.entities[entity.entity] = entity

    def _parse_generics(self, generics_text) -> Dict[str, GenericInfo]:
        """
        Private method, not part of the public API.

        Parse the generics section of the entity

        :param generics_text: The text of the generics section (only the generics block, not the whole entity).
        :return: A dictionary of GenericInfo objects, indexed by generic name.
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

            
            # Create a GenericInfo object and add it to the dictionary
            g = GenericInfo(name=name, type=type, default=default)
            generics[g.name] = g
        
        return generics


    def _parse_ports(self, ports_text) -> Dict[str, PortInfo]:
        """
        Private method, not part of the public API.

        Parses the ports secton of an entity.

        :param ports_text: The text of the ports section (only the ports block, not the whole entity).
        :return: A dictionary of PortInfo objects, indexed by port name.
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

            # Create a PortInfo object and add it to the dictionary
            p = PortInfo(name=name, direction=dir, type=type, default=default)
            ports[p.name] = p

        return ports

    def _parse_entity(self, entity_text) -> EntityInfo:
        """
        Private method, not part of the public API.

        Parses an entity

        :param entity_text: The text of the entity (from 'entity' at line start to 'end' at line start).
        :return: An EntityInfo object containing the entity name, ports, and generics.
        """
        entity_name = re.findall(r'(?m)^entity\s+(\w+)\s+is', entity_text)[0]
        generic_block = re.search(r'^\s*generic\s*\(.*?^\s*\);\s*', entity_text, re.DOTALL | re.MULTILINE).group(0)
        ports_block = re.search(r'^\s*port\s*\(.*?^\s*\);\s*', entity_text, re.DOTALL | re.MULTILINE).group(0)

        return EntityInfo(entity=entity_name, 
                          ports=self._parse_ports(ports_block), 
                          generics=self._parse_generics(generic_block))




