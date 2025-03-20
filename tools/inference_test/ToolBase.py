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

    def get_version(self) -> str:
        pass

    def get_resource_usage(self) -> dict:
        pass