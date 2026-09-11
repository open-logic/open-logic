# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
#
# Based on psi_fix_inv from the PSI psi_fix library
# Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
# All rights reserved.
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_private_lin_approx_inv import (olo_fix_private_lin_approx_inv, INV_TABLES,
                                             inv_out_fmt)

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_inv:

    """
    Model of olo_fix_inv entity.

    Calculates the inverse (1/x) of the input.

    The absolute value of the input is normalized into the range [1, 2), inverted through a table
    based linear approximation and the normalization is reverted on the result. The precision of
    the approximation is selected through precision_bits - the normalization covers the rest of the
    input range.
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 out_fmt : FixFormat,
                 in_fmt : FixFormat,
                 precision_bits : int = 18,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_inv class

        :param out_fmt: Format of the result
        :param in_fmt: Format of the input. Must be at least two bits wide.
        :param precision_bits: Number of fractional bits of the inversion approximation. One table
                               exists per supported value (see INV_TABLES).
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Precision - one approximation table exists per supported precision. The same checks (and
        # the same limits) are implemented in the VHDL entity.
        if precision_bits not in INV_TABLES:
            supported = ", ".join(str(p) for p in sorted(INV_TABLES.keys()))
            raise ValueError(f"olo_fix_inv: precision_bits {precision_bits} is not supported "
                             f"(supported: {supported})")

        # The input must provide a leading one plus at least one mantissa bit
        if cl_fix_width(in_fmt) < 2:
            raise ValueError(f"olo_fix_inv: in_fmt {in_fmt} must be at least two bits wide")

        # Negative results are only representable in a signed output format
        if in_fmt.S == 1 and out_fmt.S == 0:
            raise ValueError(f"olo_fix_inv: out_fmt {out_fmt} must be signed because in_fmt "
                             f"{in_fmt} is signed")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt
        self.precision_bits = precision_bits
        self.round = round
        self.saturate = saturate

        # Absolute value (lossless, hence one more integer bit for signed inputs)
        self.abs_fmt = FixFormat(0, in_fmt.I + in_fmt.S, in_fmt.F)
        self.width = cl_fix_width(self.abs_fmt)

        # Normalized value. The leading one is implicit, hence only the mantissa fraction is
        # forwarded to the approximation.
        self.mant_full_fmt = FixFormat(0, 0, self.width - 1)
        self.mant_fmt = FixFormat(0, 0, precision_bits + 2)
        self.approx_fmt = inv_out_fmt(precision_bits)
        self._approx = olo_fix_private_lin_approx_inv(self.approx_fmt, self.mant_fmt)

        # Denormalized result. Reverting the normalization is a shift by a constant, hence the
        # format below is the shifted result format - the shift itself is pure wiring.
        self.denorm_fmt = FixFormat(0, self.width - self.abs_fmt.I + 1,
                                    precision_bits + self.abs_fmt.I - 1)
        self.signed_fmt = FixFormat(1, self.denorm_fmt.I, self.denorm_fmt.F)

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

    def next(self, data):
        """
        Process next N samples

        :param data: Input data. A zero input delivers the same result as the smallest non-zero
                     input (the largest result the entity can produce).
        :return: 1/data
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(data):
            data = np.array([data])
        data = cl_fix_from_real(data, self.in_fmt)

        # Absolute value (lossless)
        abs_val = cl_fix_abs(data, self.in_fmt, self.abs_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # Normalization - shift left until the MSB is one. A zero input has no leading one, hence
        # the shift is limited to its maximum, which yields a mantissa of zero (like 1.0).
        raw   = np.array(cl_fix_to_integer(abs_val, self.abs_fmt), dtype=object)
        shift = np.array([self.width - int(r).bit_length() if r > 0 else self.width - 1
                          for r in raw], dtype=int)

        # Mantissa fraction - the normalized value is 1+m, the leading one is dropped
        mant_mask = 2**(self.width - 1) - 1
        mant_raw  = np.array([(int(r) << int(s)) & mant_mask for r, s in zip(raw, shift)],
                             dtype=object)
        mant_full = cl_fix_from_integer(mant_raw, self.mant_full_fmt)
        mant      = cl_fix_resize(mant_full, self.mant_full_fmt, self.mant_fmt,
                                  FixRound.Trunc_s, FixSaturate.None_s)

        # Approximation of 1/(1+m)
        approx = self._approx.process(mant)

        # Denormalization - reverting the normalization of the input is a shift by a constant,
        # hence it is merged into the shift compensating the normalization shift.
        denorm = cl_fix_shift(approx, self.approx_fmt, shift + 1 - self.abs_fmt.I,
                              self.denorm_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # Sign handling - the result is negated for negative inputs
        if self.in_fmt.S == 1:
            result = cl_fix_resize(denorm, self.denorm_fmt, self.signed_fmt,
                                   FixRound.Trunc_s, FixSaturate.None_s)
            negated = cl_fix_neg(result, self.signed_fmt, self.signed_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)
            result = np.where(data < 0, negated, result)
            result_fmt = self.signed_fmt
        else:
            result = denorm
            result_fmt = self.denorm_fmt

        # Output stage
        return cl_fix_resize(result, result_fmt, self.out_fmt, self.round, self.saturate)

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Input data
        :return: 1/data
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(data)
