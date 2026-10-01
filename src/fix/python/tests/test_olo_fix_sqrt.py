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
from olo_fix import olo_fix_sqrt
from olo_fix.olo_fix_private_lin_approx_sqrt import SQRT_TABLES
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixSqrt(unittest.TestCase):

    @staticmethod
    def _values(fmt : FixFormat, points : int = 2000):
        """
        Real input values covering the full range of a format

        Real values (and not quantized ones) are returned, because the models quantize their input
        themselves - which is not idempotent for formats wider than a double mantissa.
        """
        return np.linspace(0.0, cl_fix_max_value(fmt), points)

    def _check_accuracy(self, in_fmt : FixFormat, precision_bits : int):
        """
        Check the relative error of all non-zero inputs against sqrt(x)

        The output format is chosen wide enough to not limit the accuracy, so that the error of
        the approximation is measured.
        """
        # res_fmt is the lossless format of the result, hence it does not limit the accuracy
        out_fmt = olo_fix_sqrt(in_fmt, FixFormat(0, 1, 1), precision_bits).res_fmt
        dut = olo_fix_sqrt(in_fmt, out_fmt, precision_bits)
        data = self._values(in_fmt)
        result = np.array(cl_fix_to_real(dut.process(data), out_fmt), dtype=float)
        # The square root of zero is exact, the relative error is only defined for the rest
        quantized = np.array(cl_fix_to_real(cl_fix_from_real(data, in_fmt), in_fmt), dtype=float)
        expected = np.sqrt(quantized)
        nonzero = expected > 0.0
        error = np.max(np.abs((result[nonzero] - expected[nonzero])/expected[nonzero]))
        self.assertLessEqual(error, 2.0**-(precision_bits - 1),
                             f"relative error too large for {in_fmt} / {precision_bits}")

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_precisions(self):
        for precision_bits in SQRT_TABLES:
            self._check_accuracy(FixFormat(0, 0, 16), precision_bits)

    def test_accuracy_input_formats(self):
        # Both parities of the integer bits, fractional bits only, formats not containing 1.0 and
        # the smallest format supported (5 bits)
        for in_fmt in [FixFormat(0, 0, 16), FixFormat(0, 8, 8), FixFormat(0, 3, 13),
                       FixFormat(0, 7, 9), FixFormat(0, -2, 18), FixFormat(0, 12, -4),
                       FixFormat(0, 1, 4), FixFormat(0, 0, 5)]:
            self._check_accuracy(in_fmt, 14)

    def test_accuracy_wide_formats(self):
        # The input exceeds the width of the narrow (float based) representation, hence the
        # leading zeros must be counted on the integer representation
        self._check_accuracy(FixFormat(0, 40, 24), 18)

    # -----------------------------------------------------------------------------------------------
    # Corner Cases
    # -----------------------------------------------------------------------------------------------
    def test_zero_input(self):
        # The approximation returns zero below its lower bound, which only a zero input reaches.
        # Hence the square root of zero is exactly zero.
        for in_fmt in [FixFormat(0, 0, 16), FixFormat(0, 8, 8)]:
            dut = olo_fix_sqrt(in_fmt, FixFormat(0, 8, 16))
            self.assertEqual(dut.process(0.0)[0], 0.0)

    def test_saturation(self):
        # Results not representable in the output format are saturated
        dut = olo_fix_sqrt(FixFormat(0, 8, 8), FixFormat(0, 1, 8))
        self.assertEqual(dut.process(255.0)[0], cl_fix_max_value(FixFormat(0, 1, 8)))
        # Without saturation the result wraps
        dut = olo_fix_sqrt(FixFormat(0, 8, 8), FixFormat(0, 1, 8), saturate=FixSaturate.None_s)
        self.assertLess(dut.process(255.0)[0], 2.0)

    def test_rounding(self):
        # Truncation is always closer to zero than rounding
        trunc = olo_fix_sqrt(FixFormat(0, 4, 8), FixFormat(0, 4, 4), round=FixRound.Trunc_s)
        round_ = olo_fix_sqrt(FixFormat(0, 4, 8), FixFormat(0, 4, 4))
        data = self._values(FixFormat(0, 4, 8), 500)
        self.assertTrue(np.all(np.array(trunc.process(data), dtype=float) <=
                               np.array(round_.process(data), dtype=float)))

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        dut = olo_fix_sqrt(FixFormat(0, 0, 16), FixFormat(0, 8, 8))
        dut.reset()
        data = self._values(FixFormat(0, 0, 10))
        np.testing.assert_array_equal(dut.next(data), dut.process(data))

    def test_scalar_input(self):
        dut = olo_fix_sqrt(FixFormat(0, 4, 12), FixFormat(0, 8, 12))
        self.assertAlmostEqual(dut.process(3.0)[0], np.sqrt(3.0), places=3)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_precision(self):
        with self.assertRaises(ValueError):
            olo_fix_sqrt(FixFormat(0, 0, 16), FixFormat(0, 8, 8), 16)

    def test_signed_input(self):
        # The square root is not defined for negative numbers
        with self.assertRaises(ValueError):
            olo_fix_sqrt(FixFormat(1, 0, 16), FixFormat(0, 8, 8))

    def test_input_too_narrow(self):
        # At least 5 bits are required
        olo_fix_sqrt(FixFormat(0, 0, 5), FixFormat(0, 8, 8))
        with self.assertRaises(ValueError):
            olo_fix_sqrt(FixFormat(0, 0, 4), FixFormat(0, 8, 8))

    def test_input_too_wide(self):
        # The latency calculation of the VHDL entity supports inputs of up to 256 bits
        olo_fix_sqrt(FixFormat(0, 0, 256), FixFormat(0, 8, 8))
        with self.assertRaises(ValueError):
            olo_fix_sqrt(FixFormat(0, 0, 257), FixFormat(0, 8, 8))

if __name__ == "__main__":
    unittest.main()
