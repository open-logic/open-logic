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
class olo_fix_cordic_vect:
    """
    Model of olo_fix_cordic_vect entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constants
    # ---------------------------------------------------------------------------------------------------
    _ATAN_TABLE = np.arctan(2.0 **-np.arange(0, 32))/(2*np.pi)
  
    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,  
                 in_fmt             : FixFormat,
                 out_mag_fmt        : FixFormat,
                 out_ang_fmt        : FixFormat,
                 int_xy_fmt         : Union[FixFormat,str],                        
                 int_ang_fmt        : Union[FixFormat,str],
                 iterations         : int,
                 gain_corr_coef_fmt : Union[FixFormat,str],
                 round              : FixRound               = FixRound.Trunc_s,
                 sat                : FixSaturate            = FixSaturate.Warn_s):
        """
        Constructor of a vectoring CORDIC model.

        Read the Markdown documentation of the VHDL entity for details.

        The following generics that do not impact numeric behavior and are related to FPGA implementation only are
        omitted:
        - Mode_g
        - PlStgPerIter_g

        :param in_fmt: Input fixed-point format
        :param out_mag_fmt: Output fixed-point format for the absolute value
        :param out_ang_fmt: Output fixed-point format for the angle
        :param int_xy_fmt: Internal fixed-point format for X/Y calculation (use "AUTO" for Automatic)
        :param int_ang_fmt: Internal fixed-point format for the angle calculation (use "AUTO" for Automatic)
        :param iterations: Number of CORDIC iterations
        :param gain_corr_coef_fmt: Format of the gain correction coefficient (use "NONE" for no correction)
        :param round: Rounding mode at the output
        :param sat: Saturation mode at the output
        """
        # in_fmt
        if in_fmt.S != 1:                        raise ValueError("olo_fix_cordic_vect: in_fmt_g must be signed")
        self._in_fmt = in_fmt

        # out_mag_fmt
        if out_mag_fmt.S != 0:                   raise ValueError("olo_fix_cordic_vect: out_mag_fmt_g must be unsigned")
        self._out_mag_fmt = out_mag_fmt

        # out_ang_fmt
        # Note: int_ang_fmt_g [-0.5, 0.5) is signed and out_ang_fmt_g [0.0, 1.0) is unsigned.
        if out_ang_fmt.S+out_ang_fmt.I != 0:          raise ValueError("olo_fix_cordic_vect: out_ang_fmt_g must be (0, 0, x)")
        self._out_ang_fmt = out_ang_fmt

        # int_xy_fmt
        if isinstance(int_xy_fmt, str):
            #String
            if int_xy_fmt == "AUTO":
                # Note: Ignoring CORDIC growth, abs(z) still grows by up to sqrt(2) because sqrt(1**2 + 1**2) = sqrt(2).
                #       Then, CORDIC growth is asymptotically ~1.647. So overall growth is ~2.33 ==> +2 integer bits needed in the worst case.
                self._int_xy_fmt = FixFormat(1, self._in_fmt.I + 2, max(self._out_mag_fmt.F, self._out_ang_fmt.F - self._in_fmt.I) + 4)
            else:
                raise ValueError("olo_fix_cordic_vect: int_xy_fmt_g must be 'AUTO' or a FixFormat")
        else:
            #Format
            if int_xy_fmt.S != 1:            raise ValueError("olo_fix_cordic_vect: int_xy_fmt_g must be signed")
            self._int_xy_fmt = int_xy_fmt

        # int_ang_fmt
        if isinstance(int_ang_fmt, str):
            #String
            if int_ang_fmt == "AUTO":
                self._int_ang_fmt = FixFormat(1, -1, self._out_ang_fmt.F + 3)
            else:
                raise ValueError("olo_fix_cordic_vect: int_ang_fmt_g must be 'AUTO' or a FixFormat")
        else:
            #Format
            if int_ang_fmt.S != 1:             raise ValueError("olo_fix_cordic_vect: int_ang_fmt_g must be signed")
            if int_ang_fmt.I != -1:            raise ValueError("olo_fix_cordic_vect: int_ang_fmt_g must be (1,-1,x)")
            self._int_ang_fmt = int_ang_fmt   


        # iterations
        if iterations > 32:              raise ValueError("olo_fix_cordic_vect: iterations_g must be <= 32")
        self._iterations = iterations

        # gain_corr_coef_fmt
        if isinstance(gain_corr_coef_fmt, str):
            # String
            if gain_corr_coef_fmt == "NONE":
                self._gain_comp_on = False
                self._gain_comp_coef = 0
                self._gain_comp_coef_fmt = FixFormat(0,0,0) 
            else:
                raise ValueError("olo_fix_cordic_vect: gain_corr_coef_fmt_g must be 'NONE' or a FixFormat")
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
        self._angleTable = cl_fix_from_real(self._ATAN_TABLE, self._int_ang_fmt)

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
    
    def next(self, inp_i, inp_q):
        """
        Process next N samples
        
        :param inp_i: Real-part of the input
        :param inp_q: Imaginary-part of the input
        :return: Output as tuple (abs, angle)
        """
        return self.process(inp_i, inp_q)

    def process(self, inp_i, inp_q) :
        """
        Process samples (without preserving previous state)
        
        :param inp_i: Real-part of the input
        :param inp_q: Imaginary-part of the input
        :return: Output as tuple (abs, angle)
        """
        # Map to quadrant one
        # No rounding or saturation because int_xy_fmt is checked to have sufficient int and frac bits
        x = cl_fix_abs(cl_fix_from_real(inp_i, self._in_fmt), self._in_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        y = cl_fix_abs(cl_fix_from_real(inp_q, self._in_fmt), self._in_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        z = 0.0
        for i in range(0, self._iterations):
            x_next = self._cordic_step_x(x, y, i)
            y_next = self._cordic_step_y(x, y, i)
            z_next = self._cordic_step_z(z, y, i)
            x = x_next
            y = y_next
            z = z_next
        # Normalized angles are never saturated. With 1 non-fractional bit, wrapping is correct behavior.
        zQ1 = cl_fix_resize(z, self._int_ang_fmt, self._out_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        zQ2 = cl_fix_sub(0.5, self._int_ang_fmt, z, self._int_ang_fmt, self._out_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        zQ3 = cl_fix_add(0.5, self._int_ang_fmt, z, self._int_ang_fmt, self._out_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        zQ4 = cl_fix_sub(0.0, self._int_ang_fmt, z, self._int_ang_fmt, self._out_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        zOut = np.select([ np.logical_and(inp_i >= 0, inp_q >= 0),
                        np.logical_and(inp_i < 0, inp_q >= 0),
                        np.logical_and(inp_i < 0, inp_q < 0),
                        np.logical_and(inp_i >= 0, inp_q < 0)], [zQ1, zQ2, zQ3, zQ4])
        if self._gain_comp_on:
            xOut = cl_fix_mult(x, self._int_xy_fmt, self._gain_comp_coef, self._gain_comp_coef_fmt, self._out_mag_fmt, self._round, self._sat)
        else:
            xOut = cl_fix_resize(x, self._int_xy_fmt, self._out_mag_fmt, self._round, self._sat)
        return (xOut, zOut)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    def _cordic_step_x(self, xLast, yLast, shift : int):
        yShifted = cl_fix_shift(yLast, self._int_xy_fmt, -shift, self._int_xy_fmt)
        sub = cl_fix_sub(xLast, self._int_xy_fmt, yShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        add = cl_fix_add(xLast, self._int_xy_fmt, yShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        return np.where(yLast <= 0, sub, add)

    def _cordic_step_y(self, xLast, yLast, shift: int):
        xShifted = cl_fix_shift(xLast, self._int_xy_fmt, -shift, self._int_xy_fmt)
        add = cl_fix_add(yLast, self._int_xy_fmt, xShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        sub = cl_fix_sub(yLast, self._int_xy_fmt, xShifted, self._int_xy_fmt, self._int_xy_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        out = np.where(yLast < 0, add, sub)
        return out

    def _cordic_step_z(self, zLast, yLast, iteration : int):
        add = cl_fix_add(zLast, self._int_ang_fmt, self._angleTable[iteration], self._int_ang_fmt, self._int_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        sub = cl_fix_sub(zLast, self._int_ang_fmt, self._angleTable[iteration], self._int_ang_fmt, self._int_ang_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        return np.where(yLast < 0, sub, add)
