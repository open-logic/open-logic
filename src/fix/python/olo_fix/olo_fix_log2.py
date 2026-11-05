# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_private_lin_approx_log2 import olo_fix_private_lin_approx_log2, LOG2_TABLES
from .olo_fix_utils import olo_fix_utils

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_log2:

    """
    Model of olo_fix_log2 entity.

    Calculates the binary logarithm log2(x) of the input.

    For details refer to the HDL documentation.
    """

    # Maximum supported input width (same limit as in the VHDL entity)
    MAX_IN_WIDTH = 256

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_log2 class

        :param in_fmt: Format of the input. Must be unsigned and at least two and at most 256 bits
                       wide.
        :param out_fmt: Format of the result. The result is negative for inputs below 1.0, hence
                        a signed format is required to represent it (otherwise it saturates).
                        At most 20 fractional bits are supported. The table of the approximation
                        is selected accordingly (see LOG2_TABLES).
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Precision - one approximation table exists per supported precision. The same checks (and
        # the same limits) are implemented in the VHDL entity.
        if out_fmt.F > max(LOG2_TABLES):
            raise ValueError(f"olo_fix_log2: out_fmt {out_fmt} must have at most {max(LOG2_TABLES)} "
                             f"fractional bits")

        # The logarithm of a negative number is undefined
        if in_fmt.S != 0:
            raise ValueError(f"olo_fix_log2: in_fmt {in_fmt} must be unsigned")

        # The input must provide a leading one plus at least one mantissa bit
        if cl_fix_width(in_fmt) < 2:
            raise ValueError(f"olo_fix_log2: in_fmt {in_fmt} must be at least two bits wide")

        # The limit avoids too big barrel shifters (the input is normalized by a barrel shifter)
        if cl_fix_width(in_fmt) > self.MAX_IN_WIDTH:
            raise ValueError(f"olo_fix_log2: in_fmt {in_fmt} must be at most {self.MAX_IN_WIDTH} "
                             f"bits wide")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt
        # Smallest table delivering at least the fractional bits of the output
        precision_bits = min(p for p in LOG2_TABLES if p >= out_fmt.F)
        self.precision_bits = precision_bits
        self.round = round
        self.saturate = saturate

        # Handle case where approximation is not needed (see HDL documentation for details)
        self.omit_frac = (out_fmt.F <= 0 and round == FixRound.Trunc_s) or \
                         (out_fmt.F < 0 and round == FixRound.NonSymPos_s)

        # Normalization. The leading one of the normalized value is implicit, hence only the
        # mantissa fraction is passed to the approximation.
        in_width = cl_fix_width(in_fmt)
        self.mant_full_fmt = FixFormat(0, 1, in_width - 1)
        self.mant_fmt = FixFormat(0, 0, precision_bits + 2)
        self.approx_fmt = FixFormat(0, 0, precision_bits)
        self._approx = olo_fix_private_lin_approx_log2(self.mant_fmt, self.approx_fmt)

        # Shift. A zero input has no leading one - for it the shift is limited to its maximum, which
        # yields a mantissa of zero (like the smallest non-zero input).
        self.max_shift = in_width - 1

        # The barrel shifter is dimensioned for a maximum shift of at least two
        self.shift_fmt = FixFormat(0, olo_fix_utils.log2ceil(max(2, self.max_shift) + 1), 0)

        # Integer part of the result.
        int_bits = max(olo_fix_utils.log2ceil(max(in_fmt.I, 0)), olo_fix_utils.log2ceil(max(in_fmt.F, 0)))
        self.int_fmt = FixFormat(1, int_bits, 0)

        # The integer part and the fractional part are concatenated (pure wiring)
        self.res_fmt = FixFormat(1, int_bits, 0 if self.omit_frac else precision_bits)

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
                     input (the smallest result the entity can produce).
        :return: log2(data)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(data):
            data = np.array([data])
        data = cl_fix_from_real(data, self.in_fmt)

        # The shift is the number of leading zeros. For a zero input the leading bit index is zero,
        # which limits the shift to its maximum.
        shift = self.max_shift - olo_fix_utils.get_leading_bit_index(data, self.in_fmt)

        # Integer part of the result (I-1-shift). It always fits, hence no rounding/saturation.
        k_const = cl_fix_from_real(self.in_fmt.I - 1, self.int_fmt)
        integer = cl_fix_sub(k_const, self.int_fmt, cl_fix_from_integer(shift, self.shift_fmt),
                             self.shift_fmt, self.int_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # The fractional part cannot affect the result
        if self.omit_frac:
            return cl_fix_resize(integer, self.res_fmt, self.out_fmt, self.round, self.saturate)

        # Normalization into the range [1, 2). The barrel shifter operates on the bits of the
        # input, hence they are reinterpreted in the normalized format (reinterpretation is a shift
        # by a constant).
        norm_in = cl_fix_shift(data, self.in_fmt, 1 - self.in_fmt.I, self.mant_full_fmt,
                               FixRound.Trunc_s, FixSaturate.None_s)
        norm_data = cl_fix_shift(norm_in, self.mant_full_fmt, shift, self.mant_full_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Mantissa fraction - the normalized value is 1+m, the leading one is dropped. Truncating or
        # zero padding the mantissa to the resolution the approximation requires is pure wiring.
        mantissa = cl_fix_resize(norm_data, self.mant_full_fmt, self.mant_fmt,
                                 FixRound.Trunc_s, FixSaturate.None_s)

        # Fractional part of the result
        frac = self._approx.process(mantissa)

        # Integer part and fractional part are concatenated, which is the same as adding them
        result = cl_fix_add(integer, self.int_fmt, frac, self.approx_fmt, self.res_fmt,
                            FixRound.Trunc_s, FixSaturate.None_s)

        # Output stage
        return cl_fix_resize(result, self.res_fmt, self.out_fmt, self.round, self.saturate)

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Input data
        :return: log2(data)
        """
        # The calculation is stateless, hence process() and next() are identical
        return self.next(data)
