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
    _ATAN_TABLE = np.arctan(2.0 **-np.arange(0, 32))/(2*np.pi)
    _QUAD_FMT = FixFormat(0, 0, 2)

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_mag_fmt         : FixFormat,
                 in_ang_fmt         : FixFormat,
                 out_fmt            : FixFormat,
                 int_xy_fmt         : Union[FixFormat, str] = "AUTO",
                 int_ang_fmt        : Union[FixFormat, str] = "AUTO",
                 iterations         : int                    = 16,
                 gain_corr_coef_fmt : Union[FixFormat, str] = FixFormat(0, 0, 17),
                 round              : FixRound               = FixRound.Trunc_s,
                 sat                : FixSaturate            = FixSaturate.Warn_s):
        """
        Constructor of a rotating CORDIC model.

        Read the Markdown documentation of the VHDL entity for details.

        The following generics that do not impact numeric behavior and are related to FPGA implementation only are
        omitted:
        - Mode_g

        :param in_mag_fmt: Input fixed-point format for the absolute value
        :param in_ang_fmt: Input fixed-point format for the angle value
        :param out_fmt: Output fixed-point format
        :param int_xy_fmt: Internal format for X/Y values (use "AUTO" for Automatic)
        :param int_ang_fmt: Internal format for the angle calculation (use "AUTO" for Automatic)
        :param iterations: Number of CORDIC iterations
        :param gain_corr_coef_fmt: Format of the gain correction coefficient (use "NONE" for no correction)
        :param round: Rounding mode at the output
        :param sat: Saturation mode at the output
        """
        # in_mag_fmt
        if in_mag_fmt.S == 1:              raise ValueError("olo_fix_cordic_rot: in_mag_fmt_g must be unsigned")
        self._in_mag_fmt = in_mag_fmt

        # in_ang_fmt
        if in_ang_fmt.S == 1:              raise ValueError("olo_fix_cordic_rot: in_ang_fmt_g must be (0,0,x")
        if in_ang_fmt.I != 0:              raise ValueError("olo_fix_cordic_rot: in_ang_fmt_g must be (0,0,x)")
        self._in_ang_fmt = in_ang_fmt

        # out_fmt
        self._out_fmt = out_fmt

        # int_xy_fmt
        if isinstance(int_xy_fmt, str):
            #String
            if int_xy_fmt == "AUTO":
                self._int_xy_fmt = FixFormat(1, in_mag_fmt.I + 1, out_fmt.F + 3)
            else:
                raise ValueError("olo_fix_cordic_rot: int_xy_fmt_g must be 'AUTO' or a FixFormat")
        else:
            #Format
            if int_xy_fmt.S != 1:            raise ValueError("olo_fix_cordic_rot: int_xy_fmt_g must be signed")
            self._int_xy_fmt = int_xy_fmt

        # int_ang_fmt
        if isinstance(int_ang_fmt, str):
            #String
            if int_ang_fmt == "AUTO":
                self._int_ang_fmt = FixFormat(1, -2, in_ang_fmt.F + 3)
            else:
                raise ValueError("olo_fix_cordic_rot: int_ang_fmt_g must be 'AUTO' or a FixFormat")
        else:
            #Format
            if int_ang_fmt.S != 1:             raise ValueError("olo_fix_cordic_rot: int_ang_fmt_g must be signed")
            if int_ang_fmt.I != -2:            raise ValueError("olo_fix_cordic_rot: int_ang_fmt_g must be (1,-2,x)")
            self._int_ang_fmt = int_ang_fmt

        # iterations
        if iterations > 32:              raise ValueError("olo_fix_cordic_rot: iterations_g must be <= 32")
        self._iterations = iterations

        # gain_corr_coef_fmt
        if isinstance(gain_corr_coef_fmt, str):
            # String
            if gain_corr_coef_fmt == "NONE":
                self._gain_comp_on = False
                self._gain_comp_coef = 0
                self._gain_comp_coef_fmt = FixFormat(0,0,0) 
            else:
                raise ValueError("olo_fix_cordic_rot: gain_corr_coef_fmt_g must be 'NONE' or a FixFormat")
        else:
            # Format
            self._gain_comp_on = True
            self._gain_comp_coef = cl_fix_from_real(1/self.cordic_gain, gain_corr_coef_fmt)
            self._gain_comp_coef_fmt = gain_corr_coef_fmt

        # round
        self._round = round

        # sat
        self._sat = sat
        
        #Angle table for up to 32 iterations
        self._angle_table = cl_fix_from_real(self._ATAN_TABLE, self._int_ang_fmt)

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
        for i in range(self._iterations):
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
        if self._gain_comp_on:
            x = cl_fix_mult(inp_abs, self._in_mag_fmt, self._gain_comp_coef, self._gain_comp_coef_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        else:
            x = cl_fix_resize(inp_abs, self._in_mag_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        y = 0.0
        z = cl_fix_resize(inp_angle, self._in_ang_fmt, self._int_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        quad = cl_fix_resize(inp_angle, self._in_ang_fmt, self._QUAD_FMT, FixRound.Trunc_s, FixSaturate.None_s)

        #Cordic Algorithm
        for i in range(0, self._iterations):
            x_next = self._cordic_step_x(x, y, z, i)
            y_next = self._cordic_step_y(x, y, z, i)
            z_next = self._cordic_step_z(z, i)
            x = x_next
            y = y_next
            z = z_next

        #Quadrant correction
        yInv = cl_fix_neg(y, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        yFull = np.select([quad == 0, quad==0.25, quad==0.5, quad==0.75], [y, yInv, yInv, y])
        xInv = cl_fix_neg(x, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        xFull = np.select([quad == 0, quad == 0.25, quad == 0.5, quad == 0.75], [x, xInv, xInv, x])

        #Output conditioning
        xOut = cl_fix_resize(xFull, self._int_xy_fmt, self._out_fmt, self._round, self._sat)
        yOut = cl_fix_resize(yFull, self._int_xy_fmt, self._out_fmt, self._round, self._sat)
        return xOut, yOut

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    def _cordic_step_x(self, xLast, yLast, zLast, shift : int):
        yShifted = cl_fix_shift(yLast, self._int_xy_fmt, -shift, self._int_xy_fmt)
        sub = cl_fix_sub(xLast, self._int_xy_fmt, yShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        add = cl_fix_add(xLast, self._int_xy_fmt, yShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        return np.where(zLast > 0, sub, add)

    def _cordic_step_y(self, xLast, yLast, zLast, shift: int):
        xShifted = cl_fix_shift(xLast, self._int_xy_fmt, -shift, self._int_xy_fmt)
        add = cl_fix_add(yLast, self._int_xy_fmt, xShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        sub = cl_fix_sub(yLast, self._int_xy_fmt, xShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        out = np.where(zLast > 0, add, sub)
        return out

    def _cordic_step_z(self, zLast, iteration : int):
        add = cl_fix_add(zLast, self._int_ang_fmt, self._angle_table[iteration], self._int_ang_fmt, self._int_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        sub = cl_fix_sub(zLast, self._int_ang_fmt, self._angle_table[iteration], self._int_ang_fmt, self._int_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        return np.where(zLast > 0, sub, add)









