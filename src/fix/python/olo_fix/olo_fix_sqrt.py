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
from .olo_fix_utils import olo_fix_utils

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_sqrt:

    """
    Model of olo_fix_sqrt entity.

    Calculates the square root of the input.

    For documentation of the architecture, check the related entity documentation of olo_fix_sqrt.
    """

    # Minimum and maximum supported input width (same limits as in the VHDL entity)
    MIN_IN_WIDTH = 5
    MAX_IN_WIDTH = 256

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt : FixFormat,
                 out_fmt : FixFormat,
                 precision_bits : int = 18,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_sqrt class

        :param in_fmt: Format of the input. Must be unsigned (the square root is not defined for
                       negative numbers) and at least 5 and at most 256 bits wide.
        :param out_fmt: Format of the result
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

        if cl_fix_width(in_fmt) < self.MIN_IN_WIDTH:
            raise ValueError(f"olo_fix_sqrt: in_fmt {in_fmt} must be at least {self.MIN_IN_WIDTH} "
                             f"bits wide")

        # The latency calculation in the VHDL entity is valid for inputs of up to 256 bits
        if cl_fix_width(in_fmt) > self.MAX_IN_WIDTH:
            raise ValueError(f"olo_fix_sqrt: in_fmt {in_fmt} must be at most {self.MAX_IN_WIDTH} "
                             f"bits wide")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt
        self.precision_bits = precision_bits
        self.round = round
        self.saturate = saturate

        # Normalization. The input bits are reinterpreted as a value in [0, 1) by a shift of
        # norm_sft, which is the number of integer bits rounded up to an even number (must be even
        # because the compensation shift at the output is half of it).
        width = cl_fix_width(in_fmt)
        self.norm_sft = in_fmt.I + (in_fmt.I % 2)
        self.guard_bits = self.norm_sft - in_fmt.I
        self.norm_fmt = FixFormat(0, 0, width + self.guard_bits)
        self.mant_fmt = FixFormat(0, 0, precision_bits + 2)
        self.approx_fmt = FixFormat(0, 0, precision_bits)

        # Shift. The exponent left after the normalization must be even, because the square root
        # halves it. Hence the shift is the number of leading zeros (including the guard bit)
        # rounded down to an even number, which normalizes into [0.25, 1). A zero input has no
        # leading one - for it the shift is limited to its maximum, which yields a normalized value
        # of zero.
        self.max_shift = width + self.guard_bits - 1

        # Result of the approximation shifted back (lossless). The shift is halved, because the
        # square root halves the exponent.
        self.max_shift_out = max(2, self.max_shift//2)
        self.shifted_fmt = FixFormat(0, 0, precision_bits + self.max_shift_out)

        # The remaining part of the normalization is a shift by a constant, hence it is implemented
        # by reinterpreting the shifted result - which is pure wiring.
        self.const_sft = self.norm_sft//2
        self.res_fmt = FixFormat(0, self.shifted_fmt.I + self.const_sft,
                                 self.shifted_fmt.F - self.const_sft)

        # Approximation of sqrt(x) in the range [0.25, 1)
        self._approx = olo_fix_private_lin_approx_sqrt(self.mant_fmt, self.approx_fmt)

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

        # *** Shift Count Stage ***
        # The number of leading zeros of the input (including the guard bit). For a zero input the
        # function returns index zero, which limits the shift to its maximum.
        shift = self.max_shift - olo_fix_utils.get_leading_bit_index(data, self.in_fmt)
        # Round the shift down to an even number, as required by the square root
        shift = shift - np.mod(shift, 2)
        sft_out = shift//2
        # The barrel shifter operates on the bits of the input, hence they are reinterpreted in the
        # normalized format (reinterpretation is a shift by a constant)
        norm = cl_fix_shift(data, self.in_fmt, -self.norm_sft, self.norm_fmt,
                            FixRound.Trunc_s, FixSaturate.None_s)

        # Normalization of the input into the range [0.25, 1)
        norm_data = cl_fix_shift(norm, self.norm_fmt, shift, self.norm_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # *** Approximation input ***
        # Truncating the normalized value to the resolution the approximation requires is pure
        # wiring.
        mantissa = cl_fix_resize(norm_data, self.norm_fmt, self.mant_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Approximation of sqrt(x) in the range [0.25, 1)
        appr_data = self._approx.process(mantissa)

        # *** Approximation result in the format of the output shifter ***
        sft_in_data = cl_fix_resize(appr_data, self.approx_fmt, self.shifted_fmt,
                                    FixRound.Trunc_s, FixSaturate.None_s)

        # Compensation of the normalization shift
        sft_data = cl_fix_shift(sft_in_data, self.shifted_fmt, -sft_out, self.shifted_fmt,
                                FixRound.Trunc_s, FixSaturate.None_s)

        # Rounding and saturation to the user format. Reverting the remaining part of the
        # normalization is pure wiring, hence the shifted result is reinterpreted (passed in as
        # res_fmt). The model operates on values, hence the reinterpretation is a shift by a
        # constant.
        res_data = cl_fix_shift(sft_data, self.shifted_fmt, self.const_sft, self.res_fmt,
                                FixRound.Trunc_s, FixSaturate.None_s)
        return cl_fix_resize(res_data, self.res_fmt, self.out_fmt, self.round, self.saturate)

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Input data
        :return: sqrt(data)
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(data)
