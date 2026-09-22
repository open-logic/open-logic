# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_private_lin_approx_sqrt import olo_fix_private_lin_approx_sqrt, SQRT_TABLES

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_sqrt:

    """
    Model of olo_fix_sqrt entity.

    Calculates the square root of the input.

    The input is normalized into the range [0.25, 1), the square root is taken through a table
    based linear approximation and the normalization is reverted on the result. Because the square
    root halves the exponent, the normalization shift is always even - which is why the
    approximation covers two octaves instead of one. The precision of the approximation is selected
    through precision_bits - the normalization covers the rest of the input range.
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
        Constructor of the olo_fix_sqrt class

        :param out_fmt: Format of the result
        :param in_fmt: Format of the input. Must be unsigned (the square root is not defined for
                       negative numbers) and at least two and at most 256 bits wide.
        :param precision_bits: Number of fractional bits of the square root approximation. One
                               table exists per supported value (see SQRT_TABLES).
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Precision - one approximation table exists per supported precision. The same checks (and
        # the same limits) are implemented in the VHDL entity.
        if precision_bits not in SQRT_TABLES:
            supported = ", ".join(str(p) for p in sorted(SQRT_TABLES.keys()))
            raise ValueError(f"olo_fix_sqrt: precision_bits {precision_bits} is not supported "
                             f"(supported: {supported})")

        # The square root is not defined for negative numbers
        if in_fmt.S != 0:
            raise ValueError(f"olo_fix_sqrt: in_fmt {in_fmt} must be unsigned")

        # The input must provide a leading one plus at least one bit below it
        if cl_fix_width(in_fmt) < 2:
            raise ValueError(f"olo_fix_sqrt: in_fmt {in_fmt} must be at least two bits wide")

        # The latency calculation in the VHDL entity is valid for inputs of up to 256 bits
        if cl_fix_width(in_fmt) > self.MAX_IN_WIDTH:
            raise ValueError(f"olo_fix_sqrt: in_fmt {in_fmt} must be at most {self.MAX_IN_WIDTH} "
                             f"bits wide")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt
        self.precision_bits = precision_bits
        self.round = round
        self.saturate = saturate

        # Normalization. The input bits are reinterpreted as a value in [0, 0.5) - the additional
        # bit at the top guarantees that the normalization shift is never negative.
        width = cl_fix_width(in_fmt)
        self.norm_fmt = FixFormat(0, 0, width + 1)
        self.norm_sft = in_fmt.I + 1

        # Shift. The exponent left after the normalization must be even, because the square root
        # halves it. Hence the normalization shift has a fixed parity, given by self.parity.
        self.max_shift = width
        self.parity = self.norm_sft % 2

        # Approximation of the square root in the range [0.25, 1)
        self.mant_fmt = FixFormat(0, 0, precision_bits + 2)
        self.approx_fmt = FixFormat(0, 0, precision_bits)
        self._approx = olo_fix_private_lin_approx_sqrt(self.approx_fmt, self.mant_fmt)

        # Result of the approximation shifted back (lossless). The shift is halved because the
        # square root halves the exponent.
        self.max_shift_out = max(1, (self.max_shift - self.parity)//2)
        self.shifted_fmt = FixFormat(0, 0, precision_bits + self.max_shift_out)
        # The remaining part of the normalization is a shift by a constant, hence it is implemented
        # by reinterpreting the shifted result - which is pure wiring.
        self.const_sft = (self.norm_sft - self.parity)//2
        self.res_fmt = FixFormat(0, self.shifted_fmt.I + self.const_sft,
                                 self.shifted_fmt.F - self.const_sft)

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

        :param data: Input data. A zero input delivers exactly zero.
        :return: sqrt(data)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(data):
            data = np.array([data])
        data = cl_fix_from_real(data, self.in_fmt)

        # Normalization shift - the number of leading zeros, rounded up to the required parity.
        # For a zero input the shift is limited to its maximum (like for the smallest non-zero
        # input), which yields a normalized value of zero.
        shift = self._leading_zeros(data)
        shift = shift + np.mod(shift + self.parity, 2)

        # Normalization into the range [0.25, 1). The barrel shifter operates on the bits of the
        # input, hence they are reinterpreted in the normalized format (reinterpretation is a shift
        # by a constant).
        norm_in = cl_fix_shift(data, self.in_fmt, -self.norm_sft, self.norm_fmt,
                               FixRound.Trunc_s, FixSaturate.None_s)
        norm_data = cl_fix_shift(norm_in, self.norm_fmt, shift, self.norm_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Truncating the normalized value to the resolution the approximation requires is pure
        # wiring
        mantissa = cl_fix_resize(norm_data, self.norm_fmt, self.mant_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Approximation of the square root in the range [0.25, 1)
        appr_data = self._approx.process(mantissa)

        # Compensation of the normalization shift (halved, because the square root halves the
        # exponent)
        sft_in_data = cl_fix_resize(appr_data, self.approx_fmt, self.shifted_fmt,
                                    FixRound.Trunc_s, FixSaturate.None_s)
        sft_data = cl_fix_shift(sft_in_data, self.shifted_fmt, -(shift - self.parity)//2,
                                self.shifted_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # The remaining part of the normalization is pure wiring, hence the shifted result is
        # reinterpreted (reinterpretation is a shift by a constant)
        result = cl_fix_shift(sft_data, self.shifted_fmt, self.const_sft, self.res_fmt,
                              FixRound.Trunc_s, FixSaturate.None_s)

        # Output stage
        return cl_fix_resize(result, self.res_fmt, self.out_fmt, self.round, self.saturate)

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Input data
        :return: sqrt(data)
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(data)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    def _leading_zeros(self, data):
        """
        Number of leading zeros of the input data

        The calculation is done on the integer representation, because the floating point
        representation is not exact for inputs wider than a double mantissa. For a zero input the
        maximum is returned - the same value the HDL implementation produces (getLeadingSetBitIndex
        returns index zero for a zero input).

        :param data: Input data (quantized to in_fmt)
        :return: Number of leading zeros, limited to width(in_fmt)-1
        """
        width = cl_fix_width(self.in_fmt)
        codes = np.atleast_1d(cl_fix_to_integer(data, self.in_fmt))
        zeros = np.array([width - int(code).bit_length() for code in codes], dtype=int)
        return np.minimum(zeros, width - 1)
