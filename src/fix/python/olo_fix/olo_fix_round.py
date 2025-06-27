# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_round:
    """
    Model of olo_fix_round entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 result_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s):
        """
        Constructor for the olo_fix_round class.
        :param a_fmt: Format of the a input
        :param result_fmt: Format of the result
        :param round: Rounding mode
        """
        self._a_fmt = a_fmt
        self._result_fmt = result_fmt
        self._round = round

    def reset(self):
        """
        Reset state of the component
        """
        pass #Does not have state

    def next(self, a):
        """
        Process next N samples
        :param a: Input a
        :return: Processed result
        """
        return cl_fix_round(a, self._a_fmt, self._result_fmt, self._round)

    def process(self, a):
        """
        Process samples (without preserving previous state)
        :param a: Input a
        :return: Processed result
        """
        self.reset()
        return self.next(a)
