# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------

# Import en_cl_fix
import sys
import os
import numpy as np
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../3rdParty/en_cl_fix/bittrue/models/python")))

# Import the necessary modules
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_compare:
    """
    Model of olo_fix_compare entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 b_fmt : FixFormat,
                 comparison : str):
        """
        Constructor of the olo_fix_add class
        :param a_fmt: Format of the a input
        :param b_fmt: Format of the b input
        :param comparison: Comparison type (">", "<", "=", "!=", ">=", "<=")
        """
        self._a_fmt = a_fmt
        self._b_fmt = b_fmt
        self._comparison = comparison
        assert comparison in [">", "<", "=", "!=", ">=", "<="], \
            "Comparison type must be one of [>, <, =, !=, >=, <=]"

    def reset(self):
        """
        Reset state of the component
        """
        pass #Does not have state

    def next(self, a, b):
        """
        Process next N samples
        :param a: Input a
        :param b: Input b
        :return: Result
        """
        #Convert a and b to np.array is they are lists
        if isinstance(a, list):
            a = np.array(a)
        if isinstance(b, list):
            b = np.array(b)
        if self._comparison == ">":
            return a > b
        elif self._comparison == "<":
            return a < b
        elif self._comparison == "=":
            return a == b
        elif self._comparison == "!=":
            return a != b
        elif self._comparison == ">=":
            return a >= b
        elif self._comparison == "<=":
            return a <= b
        else:
            raise ValueError(f"Unknown comparison type: {self._comparison}")

    def process(self, a, b):
        """
        Process samples (without preserving previous state)
        :param a: Input a
        :param b: Input b
        :return: Result
        """
        self.reset()
        return self.next(a, b)
