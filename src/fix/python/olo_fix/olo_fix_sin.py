# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_lin_approx_qsin import (olo_fix_lin_approx_qsin, QSIN_TABLES)

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_sin:

    """
    Model of olo_fix_sin entity.

    Calculates sine and cosine of a phase given in rotations (0.0 = 0 degrees, 1.0 = 360 degrees):

    The peak of the cosine/sine is 1.0 for output formats (1, 1, N) and 1 LSB less for output
    formats (1, 0, N).
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 out_fmt : FixFormat,
                 in_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_sin class

        :param out_fmt: Format of the sine/cosine output. Must be (1, 0, 10..20) or (1, 1, 10..20).
                        Without integer bit the wave is scaled to 1.0-1LSB, with integer bit it is
                        unscaled (peak at 1.0).
        :param in_fmt: Format of the phase input (in rotations). Any format with at least three
                       fractional bits is allowed.
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Two quadrant bits plus at least one bit of in-quadrant phase are required
        if in_fmt.F < 3:
            raise ValueError(f"olo_fix_sin: in_fmt {in_fmt} must have at least 3 fractional bits")
        if out_fmt.S != 1 or (out_fmt.I, out_fmt.F) not in QSIN_TABLES:
            raise ValueError(f"olo_fix_sin: out_fmt {out_fmt} is not supported "
                             f"(supported: (1, 0/1, 10..20))")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt

        # Quadrant approximation. The quarter phase is a phase in rotations covering one quadrant,
        # hence it is the in-quadrant part of the phase word without any rescaling.
        self.quadrant_fmt = FixFormat(0, 0, 2)
        self.qphase_fmt = FixFormat(0, -2, self.in_fmt.F)
        self._qsin = olo_fix_lin_approx_qsin(out_fmt, self.qphase_fmt, round, saturate)
        self.peak = self._qsin.peak

    # ---------------------------------------------------------------------------------------------------
    # Public Methods
    # ---------------------------------------------------------------------------------------------------
    def reset(self):
        """
        Reset state of the component

        The calculation is stateless, hence this function does nothing. It exists for consistency
        with the other olo_fix models.
        """
        pass

    def next(self, phase):
        """
        Process next N samples

        :param phase: Phase in rotations (0.0 = 0 degrees, 1.0 = 360 degrees)
        :return: Tuple (sine, cosine)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(phase):
            phase = np.array([phase])
        # Use resize instead of cl_fix_from_real to produce wrapping behavior
        #phase = cl_fix_from_real(phase, self.in_fmt)
        phase = cl_fix_resize(phase, self.in_fmt, self.in_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # Convert the phase into one rotation
        quadrant = cl_fix_to_integer(cl_fix_resize(phase, self.in_fmt, self.quadrant_fmt, FixRound.Trunc_s, FixSaturate.None_s), self.quadrant_fmt)
        qphase = cl_fix_resize(phase, self.in_fmt, self.qphase_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        
        # Sine / Cosine phase calculation
        qphase_neg = cl_fix_neg(qphase, self.qphase_fmt, self.qphase_fmt)
        phase_sin = np.where(quadrant % 2 == 0, qphase, qphase_neg)
        phase_cos = np.where(quadrant % 2 == 0, qphase_neg, qphase)
        qsin_val = self._qsin.process(phase_sin)
        qcos_val = self._qsin.process(phase_cos)

        # Fix critical angles - for a quarter phase of zero the mirrored phase wraps back to zero,
        # hence the mirrored port does not deliver the peak value. Both results are exact for it.
        critical = (qphase == 0)
        odd = (quadrant % 2 != 0)
        qsin_val = np.where(critical, np.where(odd, self.peak, 0.0), qsin_val)
        qcos_val = np.where(critical, np.where(odd, 0.0, self.peak), qcos_val)

        # Quadrant mapping - the quarter wave is mirrored and negated depending on the quadrant.
        # The negation is exact, because the negated value is representable in the output format.
        sin_val_out = np.choose(quadrant, [qsin_val,  qsin_val, -qsin_val, -qsin_val])
        cos_val_out = np.choose(quadrant, [qcos_val, -qcos_val, -qcos_val,  qcos_val])

        return sin_val_out, cos_val_out

    def process(self, phase):
        """
        Process samples (without preserving previous state)

        :param phase: Phase in rotations (0.0 = 0 degrees, 1.0 = 360 degrees)
        :return: Tuple (sine, cosine)
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(phase)
