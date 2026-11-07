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
from olo_fix import olo_fix_private_lin_approx_log2
from olo_fix.olo_fix_private_lin_approx_log2 import (LOG2_TABLES, log2_function, log2_out_fmt,
                                                     log2_table_name,
                                                     olo_fix_private_lin_approx_log2_tbl)
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLinApproxLog2(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_private_lin_approx_log2(FixFormat(0, 0, 20), log2_out_fmt(18))
        self.in_sig = np.linspace(0, 1, 50, endpoint=False)

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_configurations(self):
        # Every configuration must stay within an error band of +/-1 LSB over the full range
        for precision_bits in LOG2_TABLES:
            out_fmt = log2_out_fmt(precision_bits)
            in_fmt = FixFormat(0, 0, precision_bits + 2)
            dut = olo_fix_private_lin_approx_log2(in_fmt, out_fmt)
            mantissa = cl_fix_from_real(np.linspace(0, cl_fix_max_value(in_fmt), 5000), in_fmt)
            result = dut.process(mantissa)
            error = np.max(np.abs(result - np.log2(1.0 + mantissa)))*2**out_fmt.F
            self.assertLessEqual(error, 1.0, f"error too large for {out_fmt}")

    def test_mantissa_zero_is_exact(self):
        # This is what makes the result for powers of two exact in olo_fix_log2
        for precision_bits in LOG2_TABLES:
            dut = olo_fix_private_lin_approx_log2(FixFormat(0, 0, precision_bits + 2),
                                                  log2_out_fmt(precision_bits))
            self.assertEqual(dut.process(0.0)[0], 0.0)

    def test_result_range(self):
        # The result of log2(1+x) for x in [0, 1) is in [0, 1)
        mantissa = cl_fix_from_real(self.in_sig, self.dut.in_fmt)
        result = self.dut.process(mantissa)
        self.assertGreaterEqual(np.min(result), 0.0)
        self.assertLess(np.max(result), 1.0)

    def test_function(self):
        # The function the tables are generated for is log2(1+x)
        self.assertEqual(log2_function(0.0), 0.0)
        self.assertEqual(log2_function(1.0), 1.0)
        np.testing.assert_array_equal(log2_function(np.array([0.0, 1.0, 3.0])), np.array([0.0, 1.0, 2.0]))

    def test_table_name(self):
        self.assertEqual(log2_table_name(log2_out_fmt(18)), "log2_f18")

    def test_table_index_bits(self):
        self.assertEqual(olo_fix_private_lin_approx_log2_tbl(512, FixFormat(0, 0, 19),
                                                             FixFormat(0, 1, 10)).index_bits, 9)

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        self.dut.reset()
        np.testing.assert_array_equal(self.dut.next(self.in_sig), self.dut.process(self.in_sig))

    def test_scalar_input(self):
        self.assertAlmostEqual(self.dut.process(0.5)[0], np.log2(1.5), places=4)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_out_fmt(self):
        # Signed output
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(0, 0, 20), FixFormat(1, 0, 18))
        # Integer bit (the result covers [0, 1), hence no integer bit is allowed)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(0, 0, 20), FixFormat(0, 1, 18))
        # Unsupported precision
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(0, 0, 20), FixFormat(0, 0, 16))

    def test_unsupported_in_fmt(self):
        # The mantissa fraction covers [0, 1) only, hence it must be (0, 0, N)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(1, 0, 20), log2_out_fmt(18))
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(0, 1, 20), log2_out_fmt(18))
        # Not enough bits to resolve the table index (512 points -> 9 index bits)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_log2(FixFormat(0, 0, 9), log2_out_fmt(18))

if __name__ == "__main__":
    unittest.main()
