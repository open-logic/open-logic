
# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from olo_fix import *
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Format Definitions
# ---------------------------------------------------------------------------------------------------
FMT_IN = FixFormat(1, 3, 8)
FMT_OUT = FixFormat(1, 3, 8)
FMT_KP = FixFormat(0, 8, 4)
FMT_KI = FixFormat(0, 4, 4)
FMT_ILIM = FixFormat(0, 4, 4)
FMT_ILIM_NEG = FixFormat(1, FMT_ILIM.I, FMT_ILIM.F)
FMT_ERR = cl_fix_sub_fmt(FMT_IN, FMT_IN)
FMT_PPART = FMT_OUT #No need to go beyond what saturates the output.
FMT_IMULT = cl_fix_mult_fmt(FMT_ERR, FMT_KI)
FMT_I = cl_fix_add_fmt(FMT_ILIM, FMT_IMULT)


# ---------------------------------------------------------------------------------------------------
# Base-class to ensure all variants of the model have the same interface
# ---------------------------------------------------------------------------------------------------
class ControllerBase:
    def __init__(self, kp, ki, ilim):
        """
        Constructor for the ControllerBase class.

        Args:
            kp (float): Proportional gain.
            ki (float): Integral gain.
            ilim (float): Integral limit.
        """
        self._kp = kp
        self._ki = ki
        self._ilim = ilim
        self._target = 0.0
        self._integrator = 0.0

    def set_target(self, value):
        """
        Set the target value for the controller.

        Args:
            value (float): Target value.
        """
        self._target = value

    def simulate(self, actual) -> float:
        """
        Simulate one time-step of the controller.

        Args:
            actual (float): Actual value.

        Returns:
            float: Control output.
        """
        raise NotImplementedError("This method should be overridden by subclasses.")

# ---------------------------------------------------------------------------------------------------
# Different Implementations
# ---------------------------------------------------------------------------------------------------

# Floating point Implementation
class ControllerFloat(ControllerBase):

    def __init__(self, kp, ki, ilim):
        super().__init__(kp, ki, ilim)


    def simulate(self, actual) -> float:
        # Error
        error = self._target - actual

        # Part
        p_part = error*self._kp

        # I Part
        i_1 = error*self._ki
        self._integrator += i_1
        self._integrator = max(min(self._integrator, +self._ilim), -self._ilim)

        # Output
        return self._integrator + p_part

# Fixed Point Implementation based on en_cl_fix
class ControllerEnClFix(ControllerBase):

    def __init__(self, kp, ki, ilim):
        super().__init__(kp, ki, ilim)
        # Static Calculation
        self._ilim_neg = cl_fix_neg(self._ilim, FMT_ILIM, FMT_ILIM_NEG)

    def simulate(self, actual) -> float:
        # Error
        error = cl_fix_sub(self._target, FMT_IN, actual, FMT_IN, FMT_ERR)

        # Part
        p_part = cl_fix_mult(error, FMT_ERR, self._kp, FMT_KP, FMT_PPART, rnd=FixRound.NonSymPos_s, sat=FixSaturate.Sat_s)

        # I Part
        i_1 = cl_fix_mult(error, FMT_ERR, self._ki, FMT_KI, FMT_IMULT)
        i_presat = cl_fix_add(self._integrator, FMT_I, i_1, FMT_IMULT, FMT_I)
        if (i_presat > self._ilim):
            self._integrator = cl_fix_resize(self._ilim, FMT_ILIM, FMT_I)
        elif (i_presat < self._ilim_neg):
            self._integrator = cl_fix_resize(self._ilim_neg, FMT_ILIM_NEG, FMT_I)
        else:
            self._integrator = i_presat

        # Output
        return cl_fix_add(self._integrator, FMT_I, p_part, FMT_PPART, FMT_OUT, rnd=FixRound.NonSymPos_s, sat=FixSaturate.Sat_s)

# Fixed Point Implementation based on olo_fix
class ControllerOloFix (ControllerBase):
    def __init__(self, kp, ki, ilim):
        super().__init__(kp, ki, ilim)
        # Static Calculation
        self._ilim_neg = olo_fix_neg(FMT_ILIM, FMT_ILIM_NEG).process(self._ilim)
        # Processing Instances
        self._error_sub = olo_fix_sub(FMT_IN, FMT_IN, FMT_ERR)
        self._p_mult = olo_fix_mult(FMT_ERR, FMT_KP, FMT_PPART, round=FixRound.NonSymPos_s, saturate=FixSaturate.Sat_s)
        self._i_mult = olo_fix_mult(FMT_ERR, FMT_KI, FMT_IMULT)
        self._i_add = olo_fix_add(FMT_I, FMT_IMULT, FMT_I)
        self._i_limit = olo_fix_limit(FMT_I, FMT_ILIM_NEG, FMT_ILIM, FMT_I)
        self._out_add = olo_fix_add(FMT_I, FMT_PPART, FMT_OUT, round=FixRound.NonSymPos_s, saturate=FixSaturate.Sat_s)

    def set_target(self, value):
        self._target = olo_fix_from_real(FMT_IN).process(value)

    def simulate(self, actual) -> float:
        # Error
        error = self._error_sub.process(self._target, actual)

        # Part
        p_part = self._p_mult.process(error, self._kp)

        # I Part
        i_1 = self._i_mult.process(error, self._ki)
        i_presat = self._i_add.process(self._integrator, i_1)
        self._integrator = self._i_limit.process(i_presat, self._ilim_neg, self._ilim)

        # Output
        return self._out_add.process(self._integrator, p_part)