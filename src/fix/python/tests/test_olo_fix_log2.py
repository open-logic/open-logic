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
from olo_fix import olo_fix_log2, olo_fix_utils
from olo_fix.olo_fix_private_lin_approx_log2 import LOG2_TABLES
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLog2(unittest.TestCase):

    @staticmethod
    def _values(fmt : FixFormat, points : int = 200):
        """
        Input values covering the full range of a format (quantized, so that the expected results
        can be calculated from them directly). A linear sweep only reaches the top octaves, hence it
        is complemented by a logarithmic sweep starting at the smallest non-zero value.
        """
        lin = np.linspace(cl_fix_min_value(fmt), cl_fix_max_value(fmt), points)
        log = np.geomspace(2.0**-fmt.F, cl_fix_max_value(fmt), points)
        return cl_fix_from_real(np.concatenate((lin, log)), fmt)

    def _check_accuracy(self, in_fmt : FixFormat, out_frac : int):
        """
        Check the absolute error of all non-zero inputs against log2(x)

        The integer bits of the output are chosen wide enough to not saturate. The normalization
        makes the error independent of the magnitude of the input. The limit is relative to the
        LSB of the output, includes the rounding error of the output stage and is the one given in
        the documentation.
        """
        out_fmt = FixFormat(1, 9, out_frac)
        dut = olo_fix_log2(in_fmt, out_fmt)
        data = self._values(in_fmt)
        data = data[data != 0]
        result = np.array(cl_fix_to_real(dut.process(data), out_fmt), dtype=float)
        error = np.max(np.abs(result - np.log2(np.array(data, dtype=float))))
        self.assertLess(error, 1.5*2.0**-out_frac,
                        f"error too large for {in_fmt} / {out_frac}")

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_output_formats(self):
        for out_frac in range(-2, max(LOG2_TABLES) + 1):
            self._check_accuracy(FixFormat(0, 0, 24), out_frac)

    def test_accuracy_input_formats(self):
        # Integer bits, fractional bits only and formats not containing 1.0
        for in_fmt in [FixFormat(0, 0, 16), FixFormat(0, 8, 8), FixFormat(0, 16, 0),
                       FixFormat(0, -2, 18), FixFormat(0, 12, -4), FixFormat(0, 1, 1)]:
            self._check_accuracy(in_fmt, 14)

    def test_accuracy_wide_formats(self):
        # The input exceeds the width of the narrow (float based) representation
        self._check_accuracy(FixFormat(0, 20, 20), 18)

    def test_powers_of_two_are_exact(self):
        # The mantissa of a power of two is zero and log2(1.0) is exact. The output format has the
        # full resolution of the approximation, so that it does not round any error away.
        exponents = np.arange(-8, 8)
        for precision_bits in LOG2_TABLES:
            dut = olo_fix_log2(FixFormat(0, 8, 8), FixFormat(1, 4, precision_bits))
            np.testing.assert_array_equal(np.array(dut.process(2.0**exponents), dtype=float),
                                          exponents)

    def test_integer_part(self):
        # Leading zero detection delivers the integer part, the approximation the fraction
        dut = olo_fix_log2(FixFormat(0, 8, 8), FixFormat(1, 4, 8))
        self.assertEqual(dut.int_fmt, FixFormat(1, 3, 0))
        self.assertEqual(dut.res_fmt, FixFormat(1, 3, 10))
        result = dut.process(np.array([0.5, 0.75, 3.0, 100.0]))
        np.testing.assert_array_equal(np.floor(result), np.array([-1.0, -1.0, 1.0, 6.0]))

    def test_integer_format_range(self):
        # The integer part covers -F ... I-1 with the smallest signed format
        self.assertEqual(olo_fix_log2(FixFormat(0, 8, 8), FixFormat(1, 4, 8)).int_fmt, FixFormat(1, 3, 0))
        self.assertEqual(olo_fix_log2(FixFormat(0, 9, 0), FixFormat(1, 4, 8)).int_fmt, FixFormat(1, 4, 0))
        self.assertEqual(olo_fix_log2(FixFormat(0, 0, 16), FixFormat(1, 4, 8)).int_fmt, FixFormat(1, 4, 0))
        # Only positive integer parts (F negative): 4 ... 11
        self.assertEqual(olo_fix_log2(FixFormat(0, 12, -4), FixFormat(1, 4, 8)).int_fmt, FixFormat(1, 4, 0))

    def test_precision_selection(self):
        # The smallest table delivering at least the fractional bits of the output is selected
        for out_frac, precision_bits in [(-2, 10), (0, 10), (10, 10), (11, 14), (14, 14), (15, 18),
                                         (18, 18), (19, 20), (20, 20)]:
            dut = olo_fix_log2(FixFormat(0, 8, 8), FixFormat(1, 4, out_frac))
            self.assertEqual(dut.precision_bits, precision_bits)
            self.assertEqual(dut.approx_fmt, FixFormat(0, 0, precision_bits))

    def test_fraction_omitted(self):
        # Without the approximation the result must be the same as with it. The fractional part
        # of the logarithm with the highest precision serves as reference.
        in_fmt = FixFormat(0, 8, 8)
        data = cl_fix_from_real(np.arange(0, 2**16)*2.0**-8, in_fmt)
        ref = np.array(olo_fix_log2(in_fmt, FixFormat(1, 9, 20)).process(data), dtype=float)
        for out_frac, round_ in [(0, FixRound.Trunc_s), (-1, FixRound.Trunc_s), (-3, FixRound.Trunc_s),
                                 (-1, FixRound.NonSymPos_s), (-3, FixRound.NonSymPos_s)]:
            out_fmt = FixFormat(1, 6, out_frac)
            dut = olo_fix_log2(in_fmt, out_fmt, round_)
            self.assertTrue(dut.omit_frac)
            self.assertEqual(dut.res_fmt.F, 0)
            np.testing.assert_array_equal(
                dut.process(data),
                cl_fix_resize(np.floor(ref), FixFormat(1, 9, 0), out_fmt, round_, FixSaturate.Sat_s))

    def test_fraction_not_omitted(self):
        # The fractional part decides about rounding at F=0 and about ties for the other modes
        in_fmt = FixFormat(0, 8, 8)
        out_fmt = FixFormat(1, 6, 0)
        self.assertFalse(olo_fix_log2(in_fmt, out_fmt).omit_frac)
        self.assertEqual(olo_fix_log2(in_fmt, out_fmt).process(3.0)[0], 2.0)
        for round_ in FixRound:
            if round_ not in [FixRound.Trunc_s, FixRound.NonSymPos_s]:
                self.assertFalse(olo_fix_log2(in_fmt, FixFormat(1, 6, -1), round_).omit_frac)
        self.assertFalse(olo_fix_log2(in_fmt, FixFormat(1, 6, 1), FixRound.Trunc_s).omit_frac)

    # -----------------------------------------------------------------------------------------------
    # Corner Cases
    # -----------------------------------------------------------------------------------------------
    def test_zero_input(self):
        # A zero input delivers the same result as the smallest non-zero input
        for precision_bits in LOG2_TABLES:
            dut = olo_fix_log2(FixFormat(0, 0, 16), FixFormat(1, 5, precision_bits))
            self.assertEqual(dut.process(0.0)[0], dut.process(2.0**-16)[0])
            self.assertEqual(dut.process(0.0)[0], -16.0)

    def test_saturation(self):
        # Results not representable in the output format are saturated
        dut = olo_fix_log2(FixFormat(0, 8, 0), FixFormat(1, 1, 4))
        self.assertEqual(dut.process(12.0)[0], cl_fix_max_value(FixFormat(1, 1, 4)))
        # Without saturation the result wraps
        dut = olo_fix_log2(FixFormat(0, 8, 0), FixFormat(1, 1, 4), saturate=FixSaturate.None_s)
        self.assertLess(dut.process(12.0)[0], 0.0)

    def test_negative_result_in_unsigned_output(self):
        # Results below zero (inputs below 1.0) saturate in an unsigned output format
        dut = olo_fix_log2(FixFormat(0, 4, 4), FixFormat(0, 3, 4))
        self.assertEqual(dut.process(0.25)[0], 0.0)
        self.assertEqual(dut.process(4.0)[0], 2.0)

    def test_rounding(self):
        # Truncation is never above rounding
        in_fmt = FixFormat(0, 8, 8)
        trunc = olo_fix_log2(in_fmt, FixFormat(1, 4, 4), round=FixRound.Trunc_s)
        round_ = olo_fix_log2(in_fmt, FixFormat(1, 4, 4))
        data = self._values(in_fmt, 500)
        self.assertTrue(np.all(np.array(trunc.process(data), dtype=float) <=
                               np.array(round_.process(data), dtype=float)))

    def test_edge_values_all_precisions(self):
        # Limits of the range, powers of two and their neighbours
        for precision_bits in LOG2_TABLES:
            for in_fmt in [FixFormat(0, 0, 16), FixFormat(0, 8, 8), FixFormat(0, 12, -4)]:
                out_fmt = FixFormat(1, 9, precision_bits)
                dut = olo_fix_log2(in_fmt, out_fmt)
                data = olo_fix_utils.edge_values(in_fmt)
                data = data[data != 0]
                result = np.array(cl_fix_to_real(dut.process(data), out_fmt), dtype=float)
                error = np.max(np.abs(result - np.log2(data)))
                self.assertLess(error, 1.5*2.0**-precision_bits,
                                f"error too large for {in_fmt} / {precision_bits}")
                # Powers of two are exact
                powers = np.log2(data) % 1 == 0
                np.testing.assert_array_equal(result[powers], np.log2(data[powers]))

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        dut = olo_fix_log2(FixFormat(0, 0, 16), FixFormat(1, 5, 8))
        dut.reset()
        data = self._values(FixFormat(0, 0, 10))
        np.testing.assert_array_equal(dut.next(data), dut.process(data))

    def test_scalar_input(self):
        dut = olo_fix_log2(FixFormat(0, 4, 12), FixFormat(1, 4, 12))
        self.assertAlmostEqual(dut.process(3.0)[0], np.log2(3.0), places=3)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_output_too_fine(self):
        # The biggest table limits the fractional bits of the output
        olo_fix_log2(FixFormat(0, 0, 16), FixFormat(1, 4, 20))
        with self.assertRaises(ValueError):
            olo_fix_log2(FixFormat(0, 0, 16), FixFormat(1, 4, 21))

    def test_signed_input(self):
        # The logarithm of a negative number is undefined
        with self.assertRaises(ValueError):
            olo_fix_log2(FixFormat(1, 0, 16), FixFormat(1, 4, 8))

    def test_input_too_narrow(self):
        # A leading one plus at least one mantissa bit are required
        with self.assertRaises(ValueError):
            olo_fix_log2(FixFormat(0, 0, 1), FixFormat(1, 4, 8))

    def test_input_too_wide(self):
        # Inputs are limited to 256 bits to avoid too big barrel shifters
        olo_fix_log2(FixFormat(0, 0, 256), FixFormat(1, 4, 8))
        with self.assertRaises(ValueError):
            olo_fix_log2(FixFormat(0, 0, 257), FixFormat(1, 4, 8))

if __name__ == "__main__":
    unittest.main()
