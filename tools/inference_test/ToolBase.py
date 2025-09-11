# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bruendler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from typing import List
import os
import shutil


class ToolBase:
    """
    Base class for synthesis tools. This class provides a common interface for all synthesis tools.
    """

    PROJECT_FOLDER = os.path.abspath("./project")

    def __init__(self):
        self.folder = None

    def sythesize(self, files : List[str], top_entity : str):
        # Clean folder
        if os.path.exists(self.PROJECT_FOLDER):
            shutil.rmtree(self.PROJECT_FOLDER)
        os.makedirs(self.PROJECT_FOLDER)

        # Synthesis itself is handled by subclasses

    def _find_file_in_project(self, endswidth : str) -> str:
        """
        Private method, not part of the public interface.
        
        Searches for a file with the specified suffix in the project folder and its subdirectories.

        :param endswidth: The suffix to search for (e.g., ".vhd").
        :return: The path to the found file.
        """
        summary_file = None
        for root, _, files in os.walk(self.PROJECT_FOLDER):
            for file in files:
                if file.endswith(endswidth):
                    summary_file = os.path.join(root, file)
                    break
            if summary_file:
                break
        else:
            raise FileNotFoundError(f"No {endswidth} file found in the {self.PROJECT_FOLDER} directory or its subdirectories.")
        return summary_file

    def get_version(self) -> str:
        """
        Get the version of the synthesis tool.
        """
        pass

    def get_resource_usage(self) -> dict:
        """
        Get the resource usage of the synthesis tool.
        
        :return: A dictionary containing the resource usage. (key: resource type, value: count)
        """
        pass

    def get_in_reduce_resources(self, size) -> dict:
        """
        Get the resources used for input reduction.

        :param size: The size of the input to be reduced in bits.
        :return: A dictionary containing the resources used for input reduction.
        """
        raise NotImplementedError("This method should be implemented by subclasses.")
    
    def get_out_reduce_resources(self, size) -> dict:
        """
        Get the resources used for output reduction.

        :param size: The size of the output to be reduced in bits.
        :return: A dictionary containing the resources used for output reduction.
        """
        raise NotImplementedError("This method should be implemented by subclasses.")
    
    def check_drc(self):
        """
        Check if any open logic DRCs are violaged (e.g. if there are latches).

        In case of violations, an exception is raised.
        """
        raise NotImplementedError("This method should be implemented by subclasses.")