# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from typing import Union, Iterable
from os.path import join
from jinja2 import Environment, FileSystemLoader
import os
from collections import namedtuple

# TODO: Add as_string for vectors
# TODO: Test package generation for as_string options
# TODO: VUnit unit test for VHDL package
# TODO: Add to olo_fix tutorial (VHDL)
# TODO: Add to olo_fix tutorial (Verilog)
# TODO: Document and reference ot olo_fix tutorial

# ---------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------
MemberData = namedtuple("MemberData", ["type", "value", "as_string"])

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_pkg_writer:

    """
    This class is used to write VHDL packages resp. verilog header files containing information from python.

    The most common use case is algorithms that are designed in python (olo_fix/en_cl_fix based). Often 
    constants such as parameters or number formats must be passed to the HDL implementation. olo_fix_pkg_writer allows
    to write VHDL packages or verilog header files containing these constants, which can then be used
    in the HDL implementation.
    """

    _VHDL_TYPES = {
        int: "integer",
        float: "real",
        FixFormat: "FixFormat_t",
        str: "string"}
    
    _VERILOG_TYPES = {
        int: "int",
        float: "real",
        str: "string",
        FixFormat: "NOT-SUPPORTED"
    }
    
    _TEMPLATE_DIR = os.path.abspath(join(os.path.dirname(__file__), "templates"))

    ### Construction ###
    def __init__(self):
        """
        Constructor
        """
        self._vectors = {}
        self._constants = {}

    ### Public Functions ###
    def add_constant(self, name : str, type : type, value : Union[int, float, FixFormat, str], as_string: bool = False) -> None:
        """
        Add a constant to the package
        :param name: Name of the constant
        :param type: Type of the constant (int, float, FixFormat or str)
        :param value: Value of the constant
        :param as_string: If true, the value is stored in the package as a string. This for example is useful for parameters
                          that are taken by olo_fix entities as srings (e.g. number formats).
        """
        # Check arguments
        self._check_name(name)
        if not type in [int, float, FixFormat, str]:
            raise ValueError(f"Type {type} is not supported. Only int, float, FixFormat and str are supported.")
        # Implementation
        self._constants[name] = MemberData(type, value, as_string)

    def add_vector(self, name : str, type : type, value : Iterable[Union[int, float, FixFormat]], as_string: bool = False) -> None:
        """
        Add a vector to the package
        :param name: Name of the vector
        :param type: Type of the vector (int, float or FixFormat)
        :param value: Value of the vector (iterable)
        :param as_string: If true, the value is stored in the package as a string. This for example is useful for parameters
                          that are taken by olo_fix entities as srings (e.g. number formats).
                          Note that this option is not available for FixFormat vectors.
        """
        # Check arguments
        self._check_name(name)
        if not type in [int, float, FixFormat]:
            raise ValueError(f"Type {type} is not supported. Only int, float and FixFormat are supported.")
        # Implementation
        self._vectors[name] = MemberData(type, value, as_string)

    def write_vhdl_pkg(self, pkg_name : str, directory : str, olo_library : str = "olo") -> None:
        """
        Generate the VHDL package
        :param pkg_name: VHDL package name (used as file name too, with .vhd suffix)
        :param directory: Target directory
        :param olo_library: Name of the VHDL library olo_fix_pkg is compiled into. This argument is optional and the default library is "olo".
        """
        
        # Assemble Data
        data = {
            "pkg_name" : pkg_name,
            "olo_library" : olo_library,
            "constants" : [self._vhdl_const_declaration(name, value) for name, value in self._constants.items()],
            "vectors" : [self._vhdl_vector_declaration(name, value) for name, value in self._vectors.items()]
        }

        # Render Template
        env = Environment(loader=FileSystemLoader(self._TEMPLATE_DIR))
        template = env.get_template(f"olo_fix_pkg_writer_vhdl.template")
        rendered_template = template.render(data)
        with open(join(directory, f"{pkg_name}.vhd"), "w+") as f:
            f.write(rendered_template)

    def write_verilog_header(self, pkg_name : str, directory : str) -> None:
        """
        Generate the Verilog header file
        :param pkg_name: Name of the header file (used as file name too, with .vh suffix)
        :param directory: Target directory
        """
        # Assemble Data
        data = {
            "pkg_name" : pkg_name,
            "constants" : [self._verilog_const_declaration(name, value) for name, value in self._constants.items()],
            "vectors" : [self._verilog_vector_declaration(name, value) for name, value in self._vectors.items()]
        }

        # Render Template
        env = Environment(loader=FileSystemLoader(self._TEMPLATE_DIR))
        template = env.get_template(f"olo_fix_pkg_writer_verilog.template")
        rendered_template = template.render(data)
        with open(join(directory, f"{pkg_name}.vh"), "w+") as f:
            f.write(rendered_template)

    ### Private Functions ###
    def _check_name(self, name : str) -> None:
        """
        Check if the name is valid and not already used
        :param name: Name to check
        """
        # Check if name already is used
        if name in self._constants or name in self._vectors:
            raise ValueError(f"Name {name} is already used for another constant or vector.")
        # Check if name is a valid VHDL identifier (alphanumeric plus underscores, starting with a letter)
        if not name.isidentifier() or not name[0].isalpha():
            raise ValueError(f"Name {name} is not a valid VHDL identifier.")
        
    def _vhdl_const_declaration(self, name : str, member_data : MemberData) -> str:
        """
        Generate the VHDL constant declaration for a given constant
        :param name: Name of the constant
        :param member_data: MemberData object containing type, value, and as_string
        :return: VHDL constant declaration as string
        """
        # Generaet VHDL type and value
        type_str = self._VHDL_TYPES[member_data.type]
        value_str = str(member_data.value)
        if member_data.type is float:
            value_str = self._float_str(member_data.value)
        if member_data.type is str:
            value_str = f'"{member_data.value}"'  # Enclose string in double quotes

        # Modify for string representation
        if member_data.as_string:
            type_str = self._VHDL_TYPES[str]
            if member_data.type is not str:
                value_str = f'"{value_str}"'  # Enclose in double quotes if not already a string
        return f"constant {name} : {type_str} := {value_str};"
    
    def _verilog_const_declaration(self, name : str, member_data : MemberData) -> str:
        """
        Generate the Verilog constant declaration for a given constant
        :param name: Name of the constant
        :param member_data: MemberData object containing type, value, and as_string
        :return: Verilog constant declaration as string
        """
        # Generate Verilog type and value
        value_str = str(member_data.value)
        if member_data.type is int:
            pass
        elif member_data.type is float:
            value_str = self._float_str(member_data.value)
        elif member_data.type is FixFormat:
            # Allowed in string representation but not otherwise
            if not member_data.as_string:
                raise ValueError("FixFormat type is not supported for Verilog constants")
        elif member_data.type is str:
            value_str = f'"{member_data.value}"'  # Enclose string in double quotes
        else:
            raise ValueError(f"Type {member_data.type} is not supported for Verilog constants")
        type_str = self._VERILOG_TYPES[member_data.type]

        # Modify for string representation
        if member_data.as_string:
            type_str = self._VERILOG_TYPES[str]
            if member_data.type is not str:
                value_str = f'"{value_str}"'  # Enclose in double quotes if not already a string
        return f"localparam {type_str} {name} = {value_str};"
    
    def _vhdl_vector_declaration(self, name : str, member_data : MemberData) -> str:
        """
        Generate the VHDL constant declaration for a given vector
        :param name: Name of the vector
        :param member_data: MemberData object containing type, value, and as_string
        :return: VHDL constant declaration as string
        """
        if member_data.type is int:
            type_str = "IntegerArray_t"
            value_str = ", ".join(str(v) for v in member_data.value)
        elif member_data.type is float:
            type_str = "RealArray_t"
            value_str = ", ".join(self._float_str(v) for v in member_data.value)
        elif member_data.type is FixFormat:
            type_str = "FixFormatArray_t"
            value_str = ", ".join(str(v) for v in member_data.value)
        else:
            raise ValueError(f"Type {member_data.type} is not supported for vectors")
        

        # Return sring representation of array
        if member_data.as_string:
            type_str = "string"
            return f'constant {name} : {type_str} := "{value_str}";'
        # Return array reporesentation (with parenthesis)
        else:
            range = f"(0 to {len(member_data.value)-1})"
            return f"constant {name} : {type_str}{range} := ({value_str});"
    
    def _verilog_vector_declaration(self, name : str, member_data : MemberData) -> str:
        """
        Generate the Verilog constant declaration for a given vector
        :param name: Name of the vector
        :param member_data: MemberData object containing type, value, and as_string
        :return: Verilog constant declaration as string
        """
        # Create value arrays
        if member_data.type is int:
            value_str = ", ".join(str(v) for v in member_data.value)
        elif member_data.type is float:
            value_str = ", ".join(self._float_str(v) for v in member_data.value)
        elif member_data.type is FixFormat:
            value_str = ", ".join(str(v) for v in member_data.value)
        else:
            raise ValueError(f"Type {member_data.type} is not supported for vectors")     

        # Return native representation
        if not member_data.as_string: 
            # Fix format is not avaialble natively
            if member_data.type is FixFormat:
                raise ValueError("FixFormat type is not supported for Verilog vectors")
            # Return native array
            return f"localparam {self._VERILOG_TYPES[member_data.type]} {name} [0:{len(member_data.value)-1}] = '{{{value_str}}};"
        
        # Return string representation
        else:
            return f'localparam string {name} = "{value_str}";'
    
    def _float_str(self, value : float) -> str:
        """
        Convert a float to a string with 9 significant digits, removing trailing zeros
        :param value: Float value to convert
        :return: String representation of the float
        """
        return f"{value:.1f}" if value == int(value) else f"{value:.9g}"
    


        