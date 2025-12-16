########################################################################################################################
#  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
#  All rights reserved.
#  Authors: Oliver Bruendler
########################################################################################################################

########################################################################################################################
# Imports
########################################################################################################################
from psi_fix_pkg import *
import numpy as np

########################################################################################################################
# Vectoring CORDIC (Cartesian to Polar)
########################################################################################################################
class psi_fix_cordic_vect:

    ####################################################################################################################
    # Constants
    ####################################################################################################################
    ATAN_TABLE = np.arctan(2.0 **-np.arange(0, 32))/(2*np.pi)
    GAIN_COMP_FMT = PsiFixFmt(0, 0, 17)

    ####################################################################################################################
    # Constructor
    ####################################################################################################################
    def __init__(self,  inFmt : PsiFixFmt,
                        outFmt : PsiFixFmt,
                        internalFmt : PsiFixFmt,
                        angleFmt : PsiFixFmt,
                        angleIntFmt : PsiFixFmt,
                        iterations : int,
                        gainComp : bool,
                        round : PsiFixRnd,
                        sat : PsiFixSat):
        """
        Constructor of a vectoring CORDIC model.
        :param inFmt: Input fixed-point format
        :param outFmt: Output fixed-point format for the absolute value
        :param internalFmt: Internal fixed-point format for X/Y calculation
        :param angleFmt: Output fixed-point format for the angle
        :param angleIntFmt: Internal fixed-point format for the angle calculation
        :param iterations: Number of CORDIC iterations
        :param gainComp: True=CORDIC gain is compensated internally, False = CORDIC gain is not compensated
        :param round: Rounding mode at the output
        :param sat: Saturation mode at the output
        """
        #Checks
        if inFmt.S != 1:                        raise ValueError("psi_fix_cordic_vect: InFmt_g must be signed")
        if outFmt.S != 0:                       raise ValueError("psi_fix_cordic_vect: OutFmt_g must be unsigned")
        if internalFmt.S != 1:                  raise ValueError("psi_fix_cordic_vect: InternalFmt_g must be signed")
        # Note: Ignoring CORDIC growth, abs(z) still grows by up to sqrt(2) because sqrt(1**2 + 1**2) = sqrt(2).
        #       Then, CORDIC growth is asymptotically ~1.647. So overall growth is ~2.33 ==> +2 integer bits needed in the worst case.
        if internalFmt.I < inFmt.I+2:           raise ValueError("psi_fix_cordic_vect: InternalFmt_g must have at least 2 more int bits than InFmt_g")
        if internalFmt.F < inFmt.F:             raise ValueError("psi_fix_cordic_vect: InternalFmt_g must have at least as many frac bits as InFmt_g")
        # Note: AngleIntFmt_g [-0.5, 0.5) is signed and AngleFmt_g [0.0, 1.0) is unsigned.
        if angleFmt.S+angleFmt.I != 0:          raise ValueError("psi_fix_cordic_vect: AngleFmt_g must be purely fractional")
        if angleIntFmt.S+angleIntFmt.I != 0:    raise ValueError("psi_fix_cordic_vect: AngleIntFmt_g must be purely fractional")
        #Implementation
        self.inFmt = inFmt
        self.outFmt = outFmt
        self.internalFmt = internalFmt
        self.iterations = iterations
        self.round = round
        self.sat = sat
        self.angleFmt = angleFmt
        self.angleIntFmt = angleIntFmt
        self.gainComp = gainComp
        self.gainCompCoef = PsiFixFromReal(1/self.CordicGain, self.GAIN_COMP_FMT)
        #Angle table for up to 32 iterations
        self.angleTable = PsiFixFromReal(self.ATAN_TABLE, angleIntFmt)

    ####################################################################################################################
    # Public Methods and Properties
    ####################################################################################################################

    @property
    def CordicGain(self):
        """
        Get the CORDIC gain of the model (can be used if external compensation is required)
        :return: CORDIC gain
        """
        g = 1
        for i in range(self.iterations):
            g *= np.sqrt(1+2**(-2*i))
        return g

    def Process(self, inpI, inpQ) :
        """
        Run the bittrue model
        :param inpI: Real-part of the input
        :param inpQ: Imaginary-part of the input
        :return: Output as tuple (abs, angle)
        """
        # Map to quadrant one
        # No rounding or saturation because internalFmt is checked to have sufficient int and frac bits
        x = PsiFixAbs(PsiFixFromReal(inpI, self.inFmt), self.inFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        y = PsiFixAbs(PsiFixFromReal(inpQ, self.inFmt), self.inFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        z = 0
        for i in range(0, self.iterations):
            x_next = self._CordicStepX(x, y, i)
            y_next = self._CordicStepY(x, y, i)
            z_next = self._CordicStepZ(z, y, i)
            x = x_next
            y = y_next
            z = z_next
        # Normalized angles are never saturated. With 1 non-fractional bit, wrapping is correct behavior.
        zQ1 = PsiFixResize(z, self.angleIntFmt, self.angleFmt, self.round, PsiFixSat.Wrap)
        zQ2 = PsiFixSub(0.5, self.angleIntFmt, z, self.angleIntFmt, self.angleFmt, self.round, PsiFixSat.Wrap)
        zQ3 = PsiFixAdd(0.5, self.angleIntFmt, z, self.angleIntFmt, self.angleFmt, self.round, PsiFixSat.Wrap)
        zQ4 = PsiFixSub(0.0, self.angleIntFmt, z, self.angleIntFmt, self.angleFmt, self.round, PsiFixSat.Wrap)
        zOut = np.select([ np.logical_and(inpI >= 0, inpQ >= 0),
                        np.logical_and(inpI < 0, inpQ >= 0),
                        np.logical_and(inpI < 0, inpQ < 0),
                        np.logical_and(inpI >= 0, inpQ < 0)], [zQ1, zQ2, zQ3, zQ4])
        if self.gainComp:
            xOut = PsiFixMult(x, self.internalFmt, self.gainCompCoef, self.GAIN_COMP_FMT, self.outFmt, self.round, self.sat)
        else:
            xOut = PsiFixResize(x, self.internalFmt, self.outFmt, self.round, self.sat)
        return (xOut, zOut)

    ####################################################################################################################
    # Private Methods (do not call!)
    ####################################################################################################################
    def _CordicStepX(self, xLast, yLast, shift : int):
        yShifted = PsiFixShiftRight(yLast, self.internalFmt, shift, self.iterations-1, self.internalFmt)
        sub = PsiFixSub(xLast, self.internalFmt, yShifted, self.internalFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        add = PsiFixAdd(xLast, self.internalFmt, yShifted, self.internalFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        return np.where(yLast < 0, sub, add)

    def _CordicStepY(self, xLast, yLast, shift: int):
        xShifted = PsiFixShiftRight(xLast, self.internalFmt, shift, self.iterations - 1, self.internalFmt)
        add = PsiFixAdd(yLast, self.internalFmt, xShifted, self.internalFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        sub = PsiFixSub(yLast, self.internalFmt, xShifted, self.internalFmt, self.internalFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        out = np.where(yLast < 0, add, sub)
        return out

    def _CordicStepZ(self, zLast, yLast, iteration : int):
        add = PsiFixAdd(zLast, self.angleIntFmt, self.angleTable[iteration], self.angleIntFmt, self.angleIntFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        sub = PsiFixSub(zLast, self.angleIntFmt, self.angleTable[iteration], self.angleIntFmt, self.angleIntFmt, PsiFixRnd.Trunc, PsiFixSat.Wrap)
        return np.where(yLast < 0, sub, add)
