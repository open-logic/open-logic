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
class olo_fix_abs:
    """
    Model of olo_fix_abs entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 result_fmt : FixFormat,
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Constructor for the olo_fix_abs class.
        :param a_fmt: Format of the a input
        :param result_fmt: Format of the result
        :param round: Rounding mode
        :param saturate: Saturation mode
        """
        self._a_fmt = a_fmt
        self._result_fmt = result_fmt
        self._round = round
        self._saturate = saturate

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
        return cl_fix_abs(a, self._a_fmt, self._result_fmt, self._round, self._saturate)

    def process(self, a):
        """
        Process samples (without preserving previous state)
        :param a: Input a
        :return: Processed result
        """
        self.reset()
        return self.next(a)
