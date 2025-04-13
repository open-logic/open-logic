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
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../3rdParty/en_cl_fix/bittrue/models/python")))

# Import the necessary modules
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_mult:
    """
    Model of olo_fix_mult entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 b_fmt : FixFormat,
                 result_fmt : FixFormat,
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Constructor of the olo_fix_mult class
        :param a_fmt: Format of the a input
        :param b_fmt: Format of the b input
        :param result_fmt: Format of the result
        :param round: Rounding mode
        :param saturate: Saturation mode
        """
        self._a_fmt = a_fmt
        self._b_fmt = b_fmt
        self._result_fmt = result_fmt
        self._round = round
        self._saturate = saturate

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
        return cl_fix_mult(a, self._a_fmt, 
                           b, self._b_fmt, 
                           self._result_fmt, self._round, self._saturate)

    def process(self, a, b):
        """
        Process samples (without preserving previous state)
        :param a: Input a
        :param b: Input b
        :return: Result
        """
        self.reset()
        return self.next(a, b)
