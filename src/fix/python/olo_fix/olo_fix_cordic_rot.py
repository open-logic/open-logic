# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
# Copyright (c) 2025 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
from typing import Union
import numpy as np

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_cordic_rot:
    """
    Model of olo_fix_cordic_rot entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constants
    # ---------------------------------------------------------------------------------------------------
    ATAN_TABLE = np.arctan(2.0 **-np.arange(0, 32))/(2*np.pi)
    GAIN_COMP_FMT = FixFormat(0, 0, 17)
    QUAD_FMT = FixFormat(0, 0, 2)

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_mag_fmt         : FixFormat,
                 in_ang_fmt         : FixFormat,
                 out_fmt            : FixFormat,
                 internal_fmt       : Union[FixFormat, str] = "AUTO",
                 int_ang_fmt        : Union[FixFormat, str] = "AUTO",
                 iterations         : int                    = 16,
                 mode               : str                    = "PIPELINED",
                 gain_corr_coef_fmt : Union[FixFormat, str] = FixFormat(0, 0, 17),
                 round              : FixRound               = FixRound.Trunc_s,
                 sat                : FixSaturate            = FixSaturate.Warn_s):
        """
        Constructor of a rotating CORDIC model.¨

        Read the Markdown documentation of the VHDL entity for details.

        :param in_mag_fmt: Input fixed-point format for the absolute value
        :param in_ang_fmt: Input fixed-point format for the angle value
        :param out_fmt: Output fixed-point format
        :param internal_fmt: Internal format for X/Y values (use "AUTO" for Automatic)
        :param int_ang_fmt: Internal format for the angle calculation (use "AUTO" for Automatic)
        :param iterations: Number of CORDIC iterations
        :param gain_corr_coef_fmt: Format of the gain correction coefficient (use "NONE" for no correction)
        :param round: Rounding mode at the output
        :param sat: Saturation mode at the output
        """
        #Checks
        if in_ang_fmt.S == 1:              raise ValueError("olo_fix_cordic_rot: in_ang_fmt_g must be unsigned")
        if int_ang_fmt.S != 1:             raise ValueError("olo_fix_cordic_rot: int_ang_fmt_g must be signed")
        if int_ang_fmt.I != -2:            raise ValueError("olo_fix_cordic_rot: int_ang_fmt_g must be (1,-2,x)")
        if in_mag_fmt.S == 1:              raise ValueError("olo_fix_cordic_rot: in_mag_fmt_g must be unsigned")
        if internal_fmt.S != 1:            raise ValueError("olo_fix_cordic_rot: internal_fmt_g must be signed")
        if internal_fmt.I <= in_mag_fmt.I: raise ValueError("olo_fix_cordic_rot: internal_fmt_g must have at least one more bit than in_mag_fmt_g")
        #Implementation
        self.in_mag_fmt = in_mag_fmt
        self.in_ang_fmt = in_ang_fmt
        self.out_fmt = out_fmt
        self.internal_fmt = internal_fmt
        self.iterations = iterations
        self.round = round
        self.sat = sat
        self.int_ang_fmt = int_ang_fmt
        self.gain_comp_on = not (gain_corr_coef_fmt == "NONE")
        self.gain_comp_coef = 0
        if self.gain_comp_on:
            self.gain_comp_coef = cl_fix_from_real(1/self.cordic_gain, gain_corr_coef_fmt)
        self.angle_int_ext_fmt = FixFormat(int_ang_fmt.S, max(int_ang_fmt.I, 1), int_ang_fmt.F)
        #Angle table for up to 32 iterations
        self.angle_table = cl_fix_from_real(self.ATAN_TABLE, int_ang_fmt)

    # ---------------------------------------------------------------------------------------------------
    # Public Methods and Properties
    # ---------------------------------------------------------------------------------------------------

    @property
    def cordic_gain(self):
        """
        Get the CORDIC gain of the model (can be used if external compensation is required)
        :return: CORDIC gain
        """
        g = 1
        for i in range(self.iterations):
            g *= np.sqrt(1+2**(-2*i))
        return g
    
    def next(self, inp_abs, inp_angle) :
        """
        Process next N samples

        :param inp_abs: Absolute value input
        :param inp_angle: Angle input
        :return: CORDIC output as Tuple (I, Q)
        """      
        return self.process(inp_abs, inp_angle)  

    def process(self, inp_abs, inp_angle) :
        """
        Process samples (without preserving previous state)

        :param inp_abs: Absolute value input
        :param inp_angle: Angle input
        :return: CORDIC output as Tuple (I, Q)
        """

        #Initialization - always map to quadrant one
        x = cl_fix_resize(inp_abs, self.in_mag_fmt, self.internal_fmt, self.round, self.sat)
        y = 0
        z = cl_fix_resize(inp_angle, self.in_ang_fmt, self.int_ang_fmt, self.round, FixSaturate.Wrap)
        quad = cl_fix_resize(inp_angle, self.in_ang_fmt, self.QUAD_FMT, FixRound.Trunc, FixSaturate.Wrap)

        #Cordic Algorithm
        for i in range(0, self.iterations):
            x_next = self._cordic_step_x(x, y, z, i)
            y_next = self._cordic_step_y(x, y, z, i)
            z_next = self._cordic_step_z(z, i)
            x = x_next
            y = y_next
            z = z_next

        #Quadrant correction
        yInv = cl_fix_neg(y, self.internal_fmt, self.internal_fmt, self.round, self.sat)
        yCorr = np.select([quad == 0, quad==0.25, quad==0.5, quad==0.75], [y, yInv, yInv, y])
        xInv = cl_fix_neg(x, self.internal_fmt, self.internal_fmt, self.round, self.sat)
        xCorr = np.select([quad == 0, quad == 0.25, quad == 0.5, quad == 0.75], [x, xInv, xInv, x])

        #Gain correction
        if self.gain_comp_on:
            xOut = cl_fix_mult(xCorr, self.internal_fmt, self.gain_comp_coef, self.GAIN_COMP_FMT, self.out_fmt, self.round, self.sat)
            yOut = cl_fix_mult(yCorr, self.internal_fmt, self.gain_comp_coef, self.GAIN_COMP_FMT, self.out_fmt, self.round, self.sat)
        else:
            xOut = cl_fix_resize(xCorr, self.internal_fmt, self.out_fmt, self.round, self.sat)
            yOut = cl_fix_resize(yCorr, self.internal_fmt, self.out_fmt, self.round, self.sat)
        return xOut, yOut

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    def _cordic_step_x(self, xLast, yLast, zLast, shift : int):
        yShifted = cl_fix_shift_right(yLast, self.internal_fmt, shift, self.iterations-1, self.internal_fmt)
        sub = cl_fix_sub(xLast, self.internal_fmt, yShifted, self.internal_fmt, self.internal_fmt, FixRound.Trunc, FixSaturate.Wrap)
        add = cl_fix_add(xLast, self.internal_fmt, yShifted, self.internal_fmt, self.internal_fmt, FixRound.Trunc, FixSaturate.Wrap)
        return np.where(zLast > 0, sub, add)

    def _cordic_step_y(self, xLast, yLast, zLast, shift: int):
        xShifted = cl_fix_shift_right(xLast, self.internal_fmt, shift, self.iterations - 1, self.internal_fmt)
        add = cl_fix_add(yLast, self.internal_fmt, xShifted, self.internal_fmt, self.internal_fmt, FixRound.Trunc, FixSaturate.Wrap)
        sub = cl_fix_sub(yLast, self.internal_fmt, xShifted, self.internal_fmt, self.internal_fmt, FixRound.Trunc, FixSaturate.Wrap)
        out = np.where(zLast > 0, add, sub)
        return out

    def _cordic_step_z(self, zLast, iteration : int):
        add = cl_fix_add(zLast, self.int_ang_fmt, self.angle_table[iteration], self.int_ang_fmt, self.int_ang_fmt, FixRound.Trunc, FixSaturate.Wrap)
        sub = cl_fix_sub(zLast, self.int_ang_fmt, self.angle_table[iteration], self.int_ang_fmt, self.int_ang_fmt, FixRound.Trunc, FixSaturate.Wrap)
        return np.where(zLast > 0, sub, add)









