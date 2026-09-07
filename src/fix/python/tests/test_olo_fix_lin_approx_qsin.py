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
from olo_fix import olo_fix_lin_approx_qsin
from olo_fix.olo_fix_lin_approx_qsin import QSIN_TABLES, olo_fix_lin_approx_qsin_tbl
from en_cl_fix_pkg import *

def quarter_fmt(bits : int) -> FixFormat:
    """
    Quarter phase format providing the given number of significant bits

    The quarter phase covers one quadrant, i.e. the range [0, 0.25) in rotations, hence it has two
    negative integer bits.
    """
    return FixFormat(0, -2, bits + 2)

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLinApproxQsin(unittest.TestCase):

    @staticmethod
    def _quarter_phase(bits : int, points : int = 3000):
        """
        Quarter phase values covering [0, 0.25) in rotations
        """
        codes = np.unique(np.linspace(0, 2**bits, points, endpoint=False).astype(np.int64))
        return codes*2.0**-quarter_fmt(bits).F

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_configurations(self):
        # Every configuration must stay below one LSB of error over the full quadrant
        for (int_bits, frac_bits), tbl in QSIN_TABLES.items():
            out_fmt = FixFormat(1, int_bits, frac_bits)
            bits = out_fmt.F + 2
            dut = olo_fix_lin_approx_qsin(out_fmt, quarter_fmt(bits))
            phase = self._quarter_phase(bits)
            sin_val, cos_val = dut.process(phase)
            sin_err = np.max(np.abs(sin_val - np.sin(phase*2*np.pi)*dut.peak))*2**frac_bits
            cos_err = np.max(np.abs(cos_val - np.cos(phase*2*np.pi)*dut.peak))*2**frac_bits
            self.assertLess(sin_err, 1.0, f"sine error too large for {out_fmt}")
            self.assertLess(cos_err, 1.0, f"cosine error too large for {out_fmt}")

    def test_mirror_symmetry(self):
        # The cosine is the sine of the mirrored quarter phase
        dut = olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), quarter_fmt(18))
        phase = self._quarter_phase(18, 500)[1:]  # zero is the critical value, tested separately
        _, cos_val = dut.process(phase)
        sin_mirrored, _ = dut.process(0.25 - phase)
        np.testing.assert_array_equal(cos_val, sin_mirrored)

    # -----------------------------------------------------------------------------------------------
    # Critical Input Value
    # -----------------------------------------------------------------------------------------------
    def test_zero_is_exact(self):
        # An input of zero is exact - its mirrored address wraps and must not be taken from the table
        for int_bits in [0, 1]:
            dut = olo_fix_lin_approx_qsin(FixFormat(1, int_bits, 16), quarter_fmt(18))
            sin_val, cos_val = dut.process(0.0)
            self.assertEqual(sin_val[0], 0.0)
            self.assertEqual(cos_val[0], dut.peak)

    def test_peak_scaling(self):
        # Without integer bit the wave is scaled to 1.0-1LSB, with integer bit it is unscaled
        self.assertEqual(olo_fix_lin_approx_qsin(FixFormat(1, 0, 12), quarter_fmt(14)).peak,
                         1.0 - 2.0**-12)
        self.assertEqual(olo_fix_lin_approx_qsin(FixFormat(1, 1, 12), quarter_fmt(14)).peak,
                         1.0)

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        dut = olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), quarter_fmt(18))
        dut.reset()
        phase = self._quarter_phase(18, 100)
        sin_a, cos_a = dut.next(phase)
        sin_b, cos_b = dut.process(phase)
        np.testing.assert_array_equal(sin_a, sin_b)
        np.testing.assert_array_equal(cos_a, cos_b)

    def test_scalar_input(self):
        dut = olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), quarter_fmt(18))
        sin_val, cos_val = dut.process(0.125)
        self.assertAlmostEqual(sin_val[0], np.sin(np.pi/4)*dut.peak, places=4)
        self.assertAlmostEqual(cos_val[0], np.cos(np.pi/4)*dut.peak, places=4)

    def test_table_properties(self):
        tbl = QSIN_TABLES[(0, 16)]
        self.assertEqual(tbl.index_bits, int(np.log2(tbl.points)))
        self.assertEqual(tbl.width, cl_fix_width(tbl.offs_fmt) + cl_fix_width(tbl.grad_fmt))
        self.assertEqual(quarter_fmt(18), FixFormat(0, -2, 20))

    def test_table_config_constructor(self):
        tbl = olo_fix_lin_approx_qsin_tbl(64, FixFormat(0, 0, 14), FixFormat(0, 1, 8))
        self.assertEqual(tbl.points, 64)
        self.assertEqual(tbl.index_bits, 6)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_out_fmt(self):
        # Unsigned output
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(0, 0, 16), quarter_fmt(18))
        # Fractional bits outside of the supported range
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 9), quarter_fmt(18))
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 21), quarter_fmt(24))
        # Too many integer bits
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 2, 16), quarter_fmt(18))

    def test_unsupported_in_fmt(self):
        # The quarter phase covers one quadrant only, hence it must be (0, -2, N)
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), FixFormat(1, -2, 20))
        # Covering a full rotation instead of a quadrant
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), FixFormat(0, 0, 18))
        # Covering half a quadrant
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), FixFormat(0, -3, 20))
        # Not enough bits to resolve the table index (256 points -> 8 index bits)
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), quarter_fmt(8))

if __name__ == "__main__":
    unittest.main()
