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
class olo_fix_saturate:
    """
    Model of olo_fix_saturate entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 result_fmt : FixFormat,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Constructor for the olo_fix_resize class.
        :param a_fmt: Format of the a input
        :param result_fmt: Format of the result
        :param saturate: Saturation mode
        """
        self._a_fmt = a_fmt
        self._result_fmt = result_fmt
        self._saturate = saturate
        self._sat_fmt = FixFormat(result_fmt.S, result_fmt.I, a_fmt.F)

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
        result_sat = cl_fix_saturate(a, self._a_fmt, self._sat_fmt, self._saturate)

        # Resize required for output format having more fractional bits than input required. This is not accepted
        # by cl_fix_saturate natively. Does not add any logic, only bit extension.
        return cl_fix_resize(result_sat, self._sat_fmt, self._result_fmt)

    def process(self, a):
        """
        Process samples (without preserving previous state)
        :param a: Input a
        :return: Processed result
        """
        self.reset()
        return self.next(a)
