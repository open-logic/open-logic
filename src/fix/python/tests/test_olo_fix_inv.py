# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------

# Import en_cl_fix
import unittest
import sys
import os
import numpy as np
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_inv
from olo_fix.olo_fix_private_lin_approx_inv import INV_TABLES
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixInv(unittest.TestCase):

    @staticmethod
    def _values(fmt : FixFormat, points : int = 2000):
        """
        Input values covering the full range of a format
        """
        width = cl_fix_width(fmt)
        codes = np.unique(np.linspace(0, 2**width, points, endpoint=False).astype(np.int64))
        if fmt.S == 1:
            codes = np.where(codes >= 2**(width - 1), codes - 2**width, codes)
        return cl_fix_from_integer(codes, fmt)

    def _check_accuracy(self, in_fmt : FixFormat, precision_bits : int):
        """
        Check the relative error of all non-zero inputs against 1/x

        The output format is chosen wide enough to not limit the accuracy, so that the error of
        the approximation is measured.
        """
        out_fmt = FixFormat(in_fmt.S, cl_fix_width(in_fmt) + 1 - in_fmt.I, precision_bits + in_fmt.I)
        dut = olo_fix_inv(out_fmt, in_fmt, precision_bits)
        data = self._values(in_fmt)
        data = data[data != 0]
        result = np.array(dut.process(data), dtype=float)
        data = np.array(data, dtype=float)
        error = np.max(np.abs((result - 1.0/data)*data))
        self.assertLess(error, 2.0**-(precision_bits - 1),
                        f"relative error too large for {in_fmt} / {precision_bits}")

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_precisions(self):
        for precision_bits in INV_TABLES:
            self._check_accuracy(FixFormat(0, 0, 16), precision_bits)

    def test_accuracy_input_formats(self):
        # Unsigned/signed, integer bits, fractional bits only and formats not containing 1.0
        for in_fmt in [FixFormat(0, 0, 16), FixFormat(0, 8, 8), FixFormat(1, 0, 15),
                       FixFormat(1, 7, 8), FixFormat(0, -2, 18), FixFormat(0, 12, -4),
                       FixFormat(1, 1, 1)]:
            self._check_accuracy(in_fmt, 14)

    def test_powers_of_two_are_exact(self):
        # The normalized value of a power of two is exactly 1.0, whose inverse is exact
        dut = olo_fix_inv(FixFormat(0, 17, 17), FixFormat(0, 0, 16))
        data = np.array([2.0**-k for k in range(1, 17)])
        np.testing.assert_array_equal(np.array(dut.process(data), dtype=float), 1.0/data)

    # -----------------------------------------------------------------------------------------------
    # Sign Handling
    # -----------------------------------------------------------------------------------------------
    def test_negative_inputs(self):
        # The result of a negative input is the negated result of its absolute value. The output
        # format is lossless, so that the asymmetric rounding of the output stage does not apply.
        in_fmt = FixFormat(1, 4, 12)
        dut = olo_fix_inv(FixFormat(1, 13, 22), in_fmt)
        self.assertEqual(dut.denorm_fmt, FixFormat(0, 13, 22))
        data = self._values(in_fmt, 500)
        data = data[data > 0]
        np.testing.assert_array_equal(dut.process(-data), -dut.process(data))

    def test_most_negative_input(self):
        # The absolute value of the most negative input needs one more integer bit
        dut = olo_fix_inv(FixFormat(1, 4, 12), FixFormat(1, 3, 4))
        self.assertEqual(dut.process(-8.0)[0], -0.125)

    # -----------------------------------------------------------------------------------------------
    # Corner Cases
    # -----------------------------------------------------------------------------------------------
    def test_zero_input(self):
        # A zero input delivers the same result as the smallest non-zero input
        dut = olo_fix_inv(FixFormat(0, 20, 4), FixFormat(0, 0, 16))
        self.assertEqual(dut.process(0.0)[0], dut.process(2.0**-16)[0])

    def test_saturation(self):
        # Results not representable in the output format are saturated
        dut = olo_fix_inv(FixFormat(0, 2, 8), FixFormat(0, 0, 16))
        self.assertEqual(dut.process(2.0**-16)[0], cl_fix_max_value(FixFormat(0, 2, 8)))
        # Without saturation the result wraps
        dut = olo_fix_inv(FixFormat(0, 2, 8), FixFormat(0, 0, 16), saturate=FixSaturate.None_s)
        self.assertEqual(dut.process(2.0**-16)[0], 0.0)

    def test_rounding(self):
        # Truncation is always closer to zero than rounding
        trunc = olo_fix_inv(FixFormat(0, 4, 4), FixFormat(0, 0, 12), round=FixRound.Trunc_s)
        round_ = olo_fix_inv(FixFormat(0, 4, 4), FixFormat(0, 0, 12))
        data = self._values(FixFormat(0, 0, 12), 500)
        data = data[data != 0]
        self.assertTrue(np.all(np.array(trunc.process(data), dtype=float) <=
                               np.array(round_.process(data), dtype=float)))

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        dut = olo_fix_inv(FixFormat(0, 8, 8), FixFormat(0, 0, 16))
        dut.reset()
        data = self._values(FixFormat(0, 0, 10))
        np.testing.assert_array_equal(dut.next(data), dut.process(data))

    def test_scalar_input(self):
        dut = olo_fix_inv(FixFormat(0, 8, 12), FixFormat(0, 4, 12))
        self.assertAlmostEqual(dut.process(3.0)[0], 1.0/3.0, places=3)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_precision(self):
        with self.assertRaises(ValueError):
            olo_fix_inv(FixFormat(0, 8, 8), FixFormat(0, 0, 16), 16)

    def test_input_too_narrow(self):
        # A leading one plus at least one mantissa bit are required
        with self.assertRaises(ValueError):
            olo_fix_inv(FixFormat(0, 8, 8), FixFormat(0, 0, 1))

    def test_unsigned_output_for_signed_input(self):
        with self.assertRaises(ValueError):
            olo_fix_inv(FixFormat(0, 8, 8), FixFormat(1, 0, 16))

if __name__ == "__main__":
    unittest.main()
