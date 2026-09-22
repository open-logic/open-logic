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
from olo_fix import olo_fix_private_lin_approx_sqrt
from olo_fix.olo_fix_private_lin_approx_sqrt import (SQRT_TABLES, SQRT_LOWER_BOUND, sqrt_function,
                                                     sqrt_out_fmt, sqrt_table_name,
                                                     olo_fix_private_lin_approx_sqrt_tbl)
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLinApproxSqrt(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_private_lin_approx_sqrt(sqrt_out_fmt(18), FixFormat(0, 0, 20))
        self.in_sig = np.linspace(SQRT_LOWER_BOUND, 1, 50, endpoint=False)

    @staticmethod
    def _normalized(fmt : FixFormat):
        """
        50 normalized values covering the approximated range [0.25, 1)
        """
        return cl_fix_from_real(np.linspace(SQRT_LOWER_BOUND, 1, 50, endpoint=False), fmt)

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_configurations(self):
        # Every configuration must stay within an error band of +/-1 LSB over the full range
        for precision_bits in SQRT_TABLES:
            out_fmt = sqrt_out_fmt(precision_bits)
            in_fmt = FixFormat(0, 0, precision_bits + 2)
            dut = olo_fix_private_lin_approx_sqrt(out_fmt, in_fmt)
            normalized = self._normalized(in_fmt)
            result = dut.process(normalized)
            error = np.max(np.abs(result - np.sqrt(normalized)))*2**out_fmt.F
            self.assertLessEqual(error, 1.0, f"error too large for {out_fmt}")

    def test_below_lower_bound_is_zero(self):
        # Below 0.25 the table returns zero. Only a zero input reaches this part of the table, so
        # this is what makes the square root of zero exactly zero in olo_fix_sqrt.
        for precision_bits in SQRT_TABLES:
            out_fmt = sqrt_out_fmt(precision_bits)
            in_fmt = FixFormat(0, 0, precision_bits + 2)
            dut = olo_fix_private_lin_approx_sqrt(out_fmt, in_fmt)
            below = cl_fix_from_real(np.linspace(0, SQRT_LOWER_BOUND, 20, endpoint=False), in_fmt)
            np.testing.assert_array_equal(np.array(dut.process(below), dtype=float),
                                          np.zeros(len(below)))

    def test_result_range(self):
        # The result of sqrt(x) for x in [0.25, 1) is in [0.5, 1)
        result = self.dut.process(self._normalized(self.dut.in_fmt))
        self.assertGreaterEqual(np.min(result), 0.5)
        self.assertLess(np.max(result), 1.0)

    def test_function(self):
        # The function the tables are generated for is the square root above the lower bound and
        # zero below it
        self.assertEqual(sqrt_function(0.0), 0.0)
        self.assertEqual(sqrt_function(SQRT_LOWER_BOUND - 0.01), 0.0)
        self.assertEqual(sqrt_function(SQRT_LOWER_BOUND), 0.5)
        np.testing.assert_array_equal(sqrt_function(np.array([0.25, 1.0])), np.array([0.5, 1.0]))

    # -----------------------------------------------------------------------------------------------
    # Table Configuration
    # -----------------------------------------------------------------------------------------------
    def test_table_geometry(self):
        for precision_bits, tbl in SQRT_TABLES.items():
            self.assertEqual(2**tbl.index_bits, tbl.points)
            self.assertEqual(sqrt_out_fmt(precision_bits), FixFormat(0, 0, precision_bits))
            self.assertEqual(sqrt_table_name(sqrt_out_fmt(precision_bits)), f"sqrt_f{precision_bits}")

    def test_table_constructor(self):
        tbl = olo_fix_private_lin_approx_sqrt_tbl(64, FixFormat(0, 0, 20), FixFormat(0, 0, 12))
        self.assertEqual(tbl.points, 64)
        self.assertEqual(tbl.index_bits, 6)
        self.assertEqual(tbl.offs_fmt, FixFormat(0, 0, 20))
        self.assertEqual(tbl.grad_fmt, FixFormat(0, 0, 12))

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        self.dut.reset()
        np.testing.assert_array_equal(self.dut.next(self.in_sig), self.dut.process(self.in_sig))

    def test_scalar_input(self):
        self.assertAlmostEqual(self.dut.process(0.5)[0], np.sqrt(0.5), places=4)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_out_fmt(self):
        # Signed output
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(FixFormat(1, 0, 18), FixFormat(0, 0, 20))
        # Integer bit (the result covers [0.5, 1), hence no integer bit is allowed)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(FixFormat(0, 1, 18), FixFormat(0, 0, 20))
        # Unsupported precision
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(FixFormat(0, 0, 16), FixFormat(0, 0, 20))

    def test_unsupported_in_fmt(self):
        # The normalized value covers [0.25, 1) only, hence it must be (0, 0, N)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(sqrt_out_fmt(18), FixFormat(1, 0, 20))
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(sqrt_out_fmt(18), FixFormat(0, 1, 20))
        # Not enough bits to resolve the table index (512 points -> 9 index bits)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_sqrt(sqrt_out_fmt(18), FixFormat(0, 0, 9))

if __name__ == "__main__":
    unittest.main()
