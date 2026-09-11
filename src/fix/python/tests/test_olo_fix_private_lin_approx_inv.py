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
from olo_fix import olo_fix_private_lin_approx_inv
from olo_fix.olo_fix_private_lin_approx_inv import (INV_TABLES, inv_out_fmt, inv_table_name,
                                                    olo_fix_private_lin_approx_inv_tbl)
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLinApproxInv(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_private_lin_approx_inv(inv_out_fmt(18), FixFormat(0, 0, 20))
        self.in_sig = np.linspace(0, 1, 50, endpoint=False)

    @staticmethod
    def _mantissa(fmt : FixFormat, points : int = 3000):
        """
        Mantissa fraction values covering [0, 1)
        """
        codes = np.unique(np.linspace(0, 2**cl_fix_width(fmt), points, endpoint=False).astype(np.int64))
        return cl_fix_from_integer(codes, fmt)

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_configurations(self):
        # Every configuration must stay below one LSB of error over the full range
        for precision_bits in INV_TABLES:
            out_fmt = inv_out_fmt(precision_bits)
            in_fmt = FixFormat(0, 0, precision_bits + 2)
            dut = olo_fix_private_lin_approx_inv(out_fmt, in_fmt)
            mantissa = self._mantissa(in_fmt)
            result = dut.process(mantissa)
            error = np.max(np.abs(result - 1.0/(1.0 + mantissa)))*2**out_fmt.F
            self.assertLess(error, 1.0, f"error too large for {out_fmt}")

    def test_one_is_exact(self):
        # A mantissa of zero means a normalized value of 1.0, whose inverse is 1.0. The result is
        # exact, hence olo_fix_inv inverts powers of two exactly.
        for precision_bits in INV_TABLES:
            out_fmt = inv_out_fmt(precision_bits)
            dut = olo_fix_private_lin_approx_inv(out_fmt, FixFormat(0, 0, precision_bits + 2))
            self.assertEqual(dut.process(0.0)[0], 1.0, f"1/1.0 is not exact for {out_fmt}")

    def test_result_range(self):
        # The result of 1/(1+m) for m in [0, 1) is in (0.5, 1.0]
        result = self.dut.process(self._mantissa(self.dut.in_fmt))
        self.assertGreater(np.min(result), 0.5)
        self.assertLessEqual(np.max(result), 1.0)

    # -----------------------------------------------------------------------------------------------
    # Table Configuration
    # -----------------------------------------------------------------------------------------------
    def test_table_geometry(self):
        for precision_bits, tbl in INV_TABLES.items():
            self.assertEqual(2**tbl.index_bits, tbl.points)
            self.assertEqual(inv_out_fmt(precision_bits), FixFormat(0, 1, precision_bits))
            self.assertEqual(inv_table_name(inv_out_fmt(precision_bits)), f"inv_f{precision_bits}")

    def test_table_constructor(self):
        tbl = olo_fix_private_lin_approx_inv_tbl(64, FixFormat(0, 1, 20), FixFormat(1, 0, 12))
        self.assertEqual(tbl.points, 64)
        self.assertEqual(tbl.index_bits, 6)
        self.assertEqual(tbl.offs_fmt, FixFormat(0, 1, 20))
        self.assertEqual(tbl.grad_fmt, FixFormat(1, 0, 12))

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        self.dut.reset()
        np.testing.assert_array_equal(self.dut.next(self.in_sig), self.dut.process(self.in_sig))

    def test_scalar_input(self):
        self.assertAlmostEqual(self.dut.process(0.5)[0], 1.0/1.5, places=4)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_out_fmt(self):
        # Signed output
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(FixFormat(1, 1, 18), FixFormat(0, 0, 20))
        # Missing integer bit (1.0 must be representable)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(FixFormat(0, 0, 18), FixFormat(0, 0, 20))
        # Unsupported precision
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(FixFormat(0, 1, 16), FixFormat(0, 0, 20))

    def test_unsupported_in_fmt(self):
        # The mantissa fraction covers [0, 1) only, hence it must be (0, 0, N)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(inv_out_fmt(18), FixFormat(1, 0, 20))
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(inv_out_fmt(18), FixFormat(0, 1, 20))
        # Not enough bits to resolve the table index (512 points -> 9 index bits)
        with self.assertRaises(ValueError):
            olo_fix_private_lin_approx_inv(inv_out_fmt(18), FixFormat(0, 0, 9))

if __name__ == "__main__":
    unittest.main()
