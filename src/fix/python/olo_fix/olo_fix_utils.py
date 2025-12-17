# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from matplotlib import pyplot as plt

# ---------------------------------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------------------------------
class olo_fix_utils:
        
    @staticmethod
    def fix_format_from_string(format_str : str, tolerate_str : bool = False) -> FixFormat:
        """
        Convert a string representation of a FixFormat to a FixFormat object.
        Args:
            format_str (str): The string representation of the FixFormat.
            tolerate_str (bool): If True, non-format strints will be returned as string
        Returns:
            FixFormat: The corresponding FixFormat object.
        """
        try:
            format_str = format_str.strip("()").replace(" ", "")
            a, b, c = map(int, format_str.split(","))
            return FixFormat(a, b, c)
        except ValueError as e:
            if not tolerate_str:
                raise e
            return format_str if tolerate_str else None

    