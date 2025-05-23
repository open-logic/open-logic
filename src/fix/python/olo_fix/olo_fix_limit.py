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
class olo_fix_limit:
    """
    Model of olo_fix_limit entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt       : FixFormat,
                 lim_lo_fmt   : FixFormat,
                 lim_hi_fmt   : FixFormat,
                 result_fmt   : FixFormat,
                 round        : FixRound = FixRound.Trunc_s,
                 saturate     : FixSaturate = FixSaturate.Warn_s,
                 lim_lo_fixed : float = None,
                 lim_hi_fixed : float = None):
        """
        Constructor of the olo_fix_add class
        :param in_fmt: Format of the input
        :param lim_lo_fmt: Format of the lower limit
        :param lim_hi_fmt: Format of the upper limit
        :param result_fmt: Format of the result
        :param round: Rounding mode
        :param saturate: Saturation mode
        :param lim_lo_fixed: Fixed lower limit value (optional). Can be used to avoid having to pass the limit
                             with every sample.
        :param lim_hi_fixed: Fixed upper limit value (optional). Can be used to avoid having to pass the limit
                             with every sample.
        """
        self._in_fmt = in_fmt
        self._lim_lo_fmt = lim_lo_fmt
        self._lim_hi_fmt = lim_hi_fmt
        self._result_fmt = result_fmt
        self._round = round
        self._saturate = saturate
        self._lim_lo_fixed = lim_lo_fixed
        self._lim_hi_fixed = lim_hi_fixed
        # Internal format is the maximum of all formats
        self._int_fmt = FixFormat(S = max(in_fmt.S, lim_lo_fmt.S, lim_hi_fmt.S),
                                  I=max(in_fmt.I, lim_lo_fmt.I, lim_hi_fmt.I), 
                                  F=max(in_fmt.F, lim_lo_fmt.F, lim_hi_fmt.F))

    def reset(self):
        """
        Reset state of the component
        """
        pass #Does not have state

    def next(self, data, lim_lo=None, lim_hi=None):
        """
        Process next N samples
        :param data: Input data
        :param lim_lo: Lower limit (optional). If not provided, the fixed limit is used.
        :param lim_hi: Upper limit (optional). If not provided, the fixed limit is used.
        :return: Result
        """
        # check if either parameter or fixed limit is set
        if lim_lo is None:
            if self._lim_lo_fixed is None:
                raise ValueError("Either lim_lo or lim_lo_fixed must be set")
            else:
                lim_lo = self._lim_lo_fixed
        if lim_hi is None:
            if self._lim_hi_fixed is None:
                raise ValueError("Either lim_hi or lim_hi_fixed must be set")
            else:
                lim_hi = self._lim_hi_fixed

        # Quantize inputs to input format
        a = cl_fix_from_real(data, self._in_fmt)
        hi = cl_fix_from_real(lim_hi, self._lim_hi_fmt)
        lo = cl_fix_from_real(lim_lo, self._lim_lo_fmt)

        # Convert values to the internal format
        a = cl_fix_resize(a, self._in_fmt, self._int_fmt)
        lo = cl_fix_resize(lo, self._lim_lo_fmt, self._int_fmt)
        hi = cl_fix_resize(hi, self._lim_hi_fmt, self._int_fmt)

        # Do the limitation
        res = np.where(a > hi, hi, a)
        res = np.where(res < lo, lo, res)

        #Resize result
        res = cl_fix_resize(res, self._int_fmt, self._result_fmt, self._round, self._saturate)
        return res

    def process(self, data, lim_lo=None, lim_hi=None):
        """
        Process samples (without preserving previous state)
        :param data: Input data
        :param lim_lo: Lower limit (optional). If not provided, the fixed limit is used.
        :param lim_hi: Upper limit (optional). If not provided, the fixed limit is used.
        :return: Result
        """
        self.reset()
        return self.next(data, lim_lo, lim_hi)
