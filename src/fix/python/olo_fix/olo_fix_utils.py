# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
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
    def fix_to_integer(data : np.ndarray, format : FixFormat) -> np.ndarray:
        """
        Convert the given data to integer representation based on the FixFormat.
        In contrast to the cl_fix_to_integer function, this function does also for for
        WideFix data types.

        Args:
            data (np.ndarray): The data to be converted.
            format (FixFormat): The FixFormat of the data.
        Returns:
            np.ndarray: The converted integer data.
        """
        if type(data)==WideFix:
          return data.data
        else:
            return cl_fix_to_integer(data, format)
        
    @staticmethod
    def fix_format_from_string(format_str : str) -> FixFormat:
        """
        Convert a string representation of a FixFormat to a FixFormat object.
        Args:
            format_str (str): The string representation of the FixFormat.
        Returns:
            FixFormat: The corresponding FixFormat object.
        """
        format_str = format_str.strip("()").replace(" ", "")
        a, b, c = map(int, format_str.split(","))
        return FixFormat(a, b, c)
    