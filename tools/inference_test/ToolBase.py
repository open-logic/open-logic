# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from typing import List
import os
import shutil


class ToolBase:

    PROJECT_FOLDER = os.path.abspath("./project")

    def __init__(self):
        self.folder = None

    def sythesize(self, files : List[str], top_entity : str):
        # Clean folder
        if os.path.exists(self.PROJECT_FOLDER):
            shutil.rmtree(self.PROJECT_FOLDER)
        os.makedirs(self.PROJECT_FOLDER)

    def _find_file_in_project(self, endswidth : str):
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
        pass

    def get_resource_usage(self) -> dict:
        pass