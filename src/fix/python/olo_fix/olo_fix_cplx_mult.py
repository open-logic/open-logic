# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_cplx_mult:
    """
    Model of olo_fix_cplx_mult entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 a_fmt : FixFormat,
                 b_fmt : FixFormat,
                 result_fmt : FixFormat,
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s,
                 mode : str = "MULT"):
        """
        Constructor of the olo_fix_cplx_mult class
        
        :param a_fmt: Format of the a input
        :param b_fmt: Format of the b input
        :param result_fmt: Format of the result
        :param round: Rounding mode
        :param saturate: Saturation mode
        :param mode: Mode of operation ("MULT" or "MIX")
        """
        self._a_fmt = a_fmt
        self._b_fmt = b_fmt
        self._result_fmt = result_fmt
        self._round = round
        self._saturate = saturate
        self._mult_fmt = cl_fix_mult_fmt(a_fmt, b_fmt)
        self._sum_fmt = cl_fix_sub_fmt(self._mult_fmt, self._mult_fmt)
        mode = mode.upper()
        if mode not in ["MULT", "MIX"]:
            raise ValueError("Invalid mode. Supported modes are 'MULT' and 'MIX'.")
        self._mode = mode

    def reset(self):
        """
        Reset state of the component
        """
        pass #Does not have state

    def next(self, a_i, a_q, b_i, b_q):
        """
        Process next N samples
        :param a_i: Input a (in-phase)
        :param a_q: Input a (quadrature)
        :param b_i: Input b (in-phase)
        :param b_q: Input b (quadrature)
        :return: Result as tuple (i, q)
        """
        # No quantization required (happens in mult/add/sub functions)

        res_II = cl_fix_mult(a_i, self._a_fmt, 
                                b_i, self._b_fmt, 
                                self._mult_fmt)
        res_QQ = cl_fix_mult(a_q, self._a_fmt, 
                                b_q, self._b_fmt, 
                                self._mult_fmt)
        res_AIBQ = cl_fix_mult(a_i, self._a_fmt, 
                                b_q, self._b_fmt, 
                                self._mult_fmt)
        res_AQBI = cl_fix_mult(a_q, self._a_fmt, 
                                b_i, self._b_fmt, 
                                self._mult_fmt)
        if self._mode == "MULT":
            res_i_full = cl_fix_sub(res_II, self._mult_fmt, 
                                    res_QQ, self._mult_fmt, 
                                    self._sum_fmt)
            res_q_full = cl_fix_add(res_AIBQ, self._mult_fmt, 
                                    res_AQBI, self._mult_fmt, 
                                    self._sum_fmt)


        else: #MIX
            res_i_full = cl_fix_add(res_II, self._mult_fmt, 
                                    res_QQ, self._mult_fmt, 
                                    self._sum_fmt)
            res_q_full = cl_fix_sub(res_AQBI, self._mult_fmt, 
                                    res_AIBQ, self._mult_fmt, 
                                    self._sum_fmt)

        res_i = cl_fix_resize(res_i_full, self._sum_fmt, self._result_fmt, self._round, self._saturate)
        res_q = cl_fix_resize(res_q_full, self._sum_fmt, self._result_fmt, self._round, self._saturate)
        return res_i, res_q

    def process(self, a_i, a_q, b_i, b_q):
        """
        Process samples (without preserving previous state)
        :param a_i: Input a (in-phase)
        :param a_q: Input a (quadrature)
        :param b_i: Input b (in-phase)
        :param b_q: Input b (quadrature)
        :return: Result as tuple (i, q)
        """
        self.reset()
        return self.next(a_i, a_q, b_i, b_q)
