# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_private_lin_approx_inv import olo_fix_private_lin_approx_inv, INV_TABLES
from .olo_fix_utils import olo_fix_utils

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

    # Maximum supported input width (same limit as in the VHDL entity)
    MAX_IN_WIDTH = 256

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
        :param in_fmt: Format of the input. Must be at least two and at most 256 bits wide.
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

        # The latency calculation in the VHDL entity is valid for inputs of up to 256 bits
        if cl_fix_width(in_fmt) > self.MAX_IN_WIDTH:
            raise ValueError(f"olo_fix_inv: in_fmt {in_fmt} must be at most {self.MAX_IN_WIDTH} "
                             f"bits wide")

        # Negative results are only representable in a signed output format
        if in_fmt.S == 1 and out_fmt.S == 0:
            raise ValueError(f"olo_fix_inv: out_fmt {out_fmt} must be signed because in_fmt "
                             f"{in_fmt} is signed")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt
        self.precision_bits = precision_bits
        self.round = round
        self.saturate = saturate

        # Absolute value of the input (lossless, hence one more integer bit for signed inputs)
        self.abs_fmt = FixFormat(0, in_fmt.I + in_fmt.S, in_fmt.F)

        # Normalization. The leading one of the normalized value is implicit, hence only the
        # mantissa fraction is passed to the approximation.
        self.mant_full_fmt = FixFormat(0, 1, cl_fix_width(self.abs_fmt) - 1)
        self.mant_fmt = FixFormat(0, 0, precision_bits + 2)
        self.approx_fmt = FixFormat(0, 1, precision_bits)
        self._approx = olo_fix_private_lin_approx_inv(self.approx_fmt, self.mant_fmt)

        # Shift. A zero input has no leading one - for it the shift is limited to its maximum, which
        # yields a mantissa of zero (like an input of 1.0).
        self.max_shift = cl_fix_width(self.abs_fmt) - 1

        # Result of the approximation shifted back (lossless)
        self.shifted_fmt = FixFormat(0, cl_fix_width(self.abs_fmt), precision_bits)
        # Reverting the normalization of the input is a shift by a constant, hence it is implemented
        # by reinterpreting the shifted result - which is pure wiring.
        self.denorm_fmt = FixFormat(0, self.shifted_fmt.I + 1 - self.abs_fmt.I,
                                    self.shifted_fmt.F + self.abs_fmt.I - 1)
        # Signed for signed inputs, because the result of a negative input is negative
        self.res_fmt = FixFormat(in_fmt.S, self.denorm_fmt.I, self.denorm_fmt.F)

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

        # Normalization into the range [1, 2). The barrel shifter operates on the bits of the
        # absolute value, hence they are reinterpreted in the normalized format (reinterpretation is
        # a shift by a constant). The shift is the number of leading zeros. For a zero input the
        # leading bit index is zero, which limits the shift to its maximum.
        norm_in = cl_fix_shift(abs_val, self.abs_fmt, 1 - self.abs_fmt.I, self.mant_full_fmt,
                               FixRound.Trunc_s, FixSaturate.None_s)
        shift = self.max_shift - olo_fix_utils.get_leading_bit_index(abs_val, self.abs_fmt)
        norm_data = cl_fix_shift(norm_in, self.mant_full_fmt, shift, self.mant_full_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Mantissa fraction - the normalized value is 1+m, the leading one is dropped. Truncating or
        # zero padding the mantissa to the resolution the approximation requires is pure wiring.
        mantissa = cl_fix_resize(norm_data, self.mant_full_fmt, self.mant_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Approximation of 1/x in the range [1, 2)
        appr_data = self._approx.process(mantissa)

        # Compensation of the normalization shift
        sft_in_data = cl_fix_resize(appr_data, self.approx_fmt, self.shifted_fmt,
                                    FixRound.Trunc_s, FixSaturate.None_s)
        sft_data = cl_fix_shift(sft_in_data, self.shifted_fmt, shift, self.shifted_fmt,
                                FixRound.Trunc_s, FixSaturate.None_s)

        # Reverting the normalization is pure wiring, hence the shifted result is reinterpreted
        # (reinterpretation is a shift by a constant)
        denorm = cl_fix_shift(sft_data, self.shifted_fmt, 1 - self.abs_fmt.I, self.denorm_fmt,
                              FixRound.Trunc_s, FixSaturate.None_s)
        result = cl_fix_resize(denorm, self.denorm_fmt, self.res_fmt,
                               FixRound.Trunc_s, FixSaturate.None_s)

        # Sign handling - the result of a negative input is negative
        if self.in_fmt.S == 1:
            negated = cl_fix_neg(result, self.res_fmt, self.res_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)
            result = np.where(data < 0, negated, result)

        # Output stage
        return cl_fix_resize(result, self.res_fmt, self.out_fmt, self.round, self.saturate)

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Input data
        :return: 1/data
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(data)
