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

    def setUp(self):
        self.dut = olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), FixFormat(0, -2, 18))
        self.in_sig = np.linspace(0, 0.25, 50);

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
            in_fmt = FixFormat(0, -2, out_fmt.F+2)
            dut = olo_fix_lin_approx_qsin(out_fmt, in_fmt)
            phase = np.linspace(cl_fix_min_value(in_fmt), cl_fix_max_value(in_fmt), 50)
            sin_val = dut.process(phase)
            sin_err = np.max(np.abs(np.sin(phase*2*np.pi)-sin_val))
            self.assertLess(sin_err, 1.0, f"sine error too large for {out_fmt}")

    def test_zero_is_exact(self):
        # The sine of zero is exact. The mirrored phase wrapping to zero is handled by the user of
        # the entity (see olo_fix_sin) and not here.
        for int_bits in [0, 1]:
            dut = olo_fix_lin_approx_qsin(FixFormat(1, 1, 16), FixFormat(0, -2, 16))
            self.assertEqual(dut.process(0.0)[0], 0.0)

    def test_peak_scaling(self):
        dut_unscaled = olo_fix_lin_approx_qsin(FixFormat(1, 1, 16), FixFormat(0, -2, 12))
        dut_scaled = olo_fix_lin_approx_qsin(FixFormat(1, 0, 16), FixFormat(0, -2, 12))
        self.assertEqual(dut_unscaled.process(0.25), 1.0)
        self.assertAlmostEqual(dut_scaled.process(0.25), 1.0-2**-16, delta=1e-6)

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        self.dut.reset()
        np.testing.assert_array_equal(self.dut.next(self.in_sig), self.dut.process(self.in_sig))

    def test_scalar_input(self):
        self.assertAlmostEqual(self.dut.process(0.125)[0], np.sin(np.pi/4)*self.dut.peak, places=4)

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
