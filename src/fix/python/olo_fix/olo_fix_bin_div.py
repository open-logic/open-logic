# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
# Copyright (c) 2025 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_bin_div:
    """
    Model of olo_fix_bin_div entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 num_fmt   : FixFormat,
                 denom_fmt : FixFormat,
                 out_fmt   : FixFormat,
                 round     : FixRound    = FixRound.Trunc_s,
                 saturate  : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of a binary division model.

        Read the Markdown documentation of the VHDL entity for details.


        The following generics that do not impact numeric behavior and are related to FPGA implementation only are
        omitted:
        - Mode_g
        
        :param num_fmt: Numerator fixed-point format
        :param denom_fmt: Denominator fixed-point format
        :param out_fmt: Output fixed-point format
        :param round: Rounding mode at the output
        :param saturate: Saturation mode at the output
        """
        # Store parameters
        self.num_fmt = num_fmt
        self.denom_fmt = denom_fmt
        self.out_fmt = out_fmt
        self.round = round
        self.saturate = saturate
        # Derived parameters
        self.first_shift = out_fmt.I
        self.num_abs_fmt = FixFormat(0, num_fmt.I + num_fmt.S, num_fmt.F)
        self.denom_abs_fmt = FixFormat(0, denom_fmt.I + denom_fmt.S, denom_fmt.F)
        self.result_int_fmt = FixFormat(1, out_fmt.I+1, out_fmt.F+1)
        self.denom_comp_fmt = FixFormat(0, self.denom_abs_fmt.I+self.first_shift, self.denom_abs_fmt.F - self.first_shift)
        self.num_comp_fmt = FixFormat(0, max(self.denom_comp_fmt.I, self.num_abs_fmt.I), max(self.denom_comp_fmt.F, self.num_abs_fmt.F))   
        self.iterations = self.out_fmt.I + self.out_fmt.F + 2

    # ---------------------------------------------------------------------------------------------------
    # Public Methods and Properties
    # ---------------------------------------------------------------------------------------------------
    
    def next(self, num, denom):
        """
        Process next N samples
    
        :param num: Numerator value(s)
        :param denom: Denominator value(s)
        :return: Result of the binary division
        """
        return self.process(num, denom)

    def process(self, num, denom):
        """
        Process samples (without preserving previous state)
        
        :param num: Numerator value(s)
        :param denom: Denominator value(s)
        :return: Result of the binary division
        """
        #Sign Handling
        num_sign = np.where(num < 0, 1, 0)
        denom_sign = np.where(denom < 0, 1, 0)
        num_abs = cl_fix_abs(num, self.num_fmt, self.num_abs_fmt)
        denom_abs = cl_fix_abs(denom, self.denom_fmt, self.denom_abs_fmt)

        #Initialization
        denom_comp = cl_fix_shift(denom_abs, self.denom_abs_fmt, self.first_shift, self.denom_comp_fmt)
        num_comp = cl_fix_resize(num_abs, self.num_abs_fmt, self.num_comp_fmt)
        result_int = np.zeros(num_comp.size)

        #Execution
        for i in range(self.iterations): 
            result_int *= 2
            num_in_denom_fmt = cl_fix_resize(num_comp, self.num_comp_fmt, self.denom_comp_fmt, FixRound.Trunc_s, FixSaturate.None_s)    
            result_int = np.where(denom_comp <= num_in_denom_fmt, result_int + 1, result_int)
            num_comp = np.where(denom_comp <= num_in_denom_fmt, cl_fix_sub(num_comp, self.num_comp_fmt, denom_comp, self.denom_comp_fmt, self.num_comp_fmt), num_comp)
            num_comp = cl_fix_shift(num_comp, self.num_comp_fmt, 1, self.num_comp_fmt, FixRound.Trunc_s, FixSaturate.Sat_s)

        #Output handling
        res_signed = cl_fix_from_integer(result_int, self.result_int_fmt)
        res = np.where(num_sign != denom_sign, -res_signed, res_signed)
        res = cl_fix_resize(res, self.result_int_fmt, self.out_fmt, self.round, self.saturate)
        if len(res) == 1:
            return res[0]
        else:
            return res



