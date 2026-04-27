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
class olo_fix_cplx_addsub:
    """
    Model of olo_fix_cplx_addsub entity
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
                 operation : str = "add"):
        """
        Constructor of the olo_fix_cplx_addsub class
        :param a_fmt: Format of the a input
        :param b_fmt: Format of the b input
        :param result_fmt: Format of the result
        :param round: Rounding mode
        :param saturate: Saturation mode
        :param operation: Operation to perform ("add" or "sub")
        """
        self._a_fmt = a_fmt
        self._b_fmt = b_fmt
        self._result_fmt = result_fmt
        self._round = round
        self._saturate = saturate
        operation = operation.lower()
        if operation not in ["add", "sub"]:
            raise ValueError("Invalid operation. Supported operations are 'add' and 'sub'.")
        self._operation = operation

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
        if self._operation == "add":
            res_i = cl_fix_add(a_i, self._a_fmt, 
                               b_i, self._b_fmt, 
                               self._result_fmt, self._round, self._saturate)
            res_q = cl_fix_add(a_q, self._a_fmt, 
                               b_q, self._b_fmt, 
                               self._result_fmt, self._round, self._saturate)
        else: #sub
            res_i = cl_fix_sub(a_i, self._a_fmt, 
                            b_i, self._b_fmt, 
                            self._result_fmt, self._round, self._saturate)
            res_q = cl_fix_sub(a_q, self._a_fmt, 
                            b_q, self._b_fmt, 
                            self._result_fmt, self._round, self._saturate)
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
