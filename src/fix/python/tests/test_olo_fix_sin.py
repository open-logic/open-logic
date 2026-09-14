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
from olo_fix import olo_fix_sin
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixSin(unittest.TestCase):

    @staticmethod
    def _phase(fmt : FixFormat, points : int = 3000):
        """
        Phase values covering the full range of a format
        """
        width = cl_fix_width(fmt)
        codes = np.unique(np.linspace(0, 2**width, points, endpoint=False).astype(np.int64))
        if fmt.S == 1:
            codes = np.where(codes >= 2**(width - 1), codes - 2**width, codes)
        return cl_fix_from_integer(codes, fmt)

    def _check_accuracy(self, out_fmt : FixFormat, in_fmt : FixFormat):
        dut = olo_fix_sin(out_fmt, in_fmt)
        phase = self._phase(in_fmt)
        sin_val, cos_val = dut.process(phase)
        sin_err = np.max(np.abs(sin_val - np.sin(2*np.pi*phase)*dut.peak))*2**out_fmt.F
        cos_err = np.max(np.abs(cos_val - np.cos(2*np.pi*phase)*dut.peak))*2**out_fmt.F
        self.assertLess(sin_err, 1.0, f"sine error too large for {out_fmt} / {in_fmt}")
        self.assertLess(cos_err, 1.0, f"cosine error too large for {out_fmt} / {in_fmt}")

    # -----------------------------------------------------------------------------------------------
    # Accuracy
    # -----------------------------------------------------------------------------------------------
    def test_accuracy_all_output_formats(self):
        for int_bits in [0, 1]:
            for frac_bits in range(10, 21):
                self._check_accuracy(FixFormat(1, int_bits, frac_bits),
                                     FixFormat(0, 0, frac_bits + 4))

    def test_accuracy_input_formats(self):
        # Integer bits wrap, signed formats wrap negative values, formats covering less than one
        # rotation reach a part of the wave only and low resolutions are zero padded
        for in_fmt in [FixFormat(0, 0, 20), FixFormat(0, 2, 20), FixFormat(1, 0, 20),
                       FixFormat(1, 3, 18), FixFormat(0, -2, 20), FixFormat(1, -1, 16),
                       FixFormat(0, 0, 11)]:
            self._check_accuracy(FixFormat(1, 0, 16), in_fmt)

    def test_phase_resolution_too_low(self):
        # The in-quadrant phase (in_fmt.F-2 bits) must resolve the table index. A 256 point table
        # has 8 index bits, hence at least 11 fractional bits are required.
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 10))

    def test_pythagoras(self):
        dut = olo_fix_sin(FixFormat(1, 0, 18), FixFormat(0, 0, 22))
        sin_val, cos_val = dut.process(self._phase(FixFormat(0, 0, 22), 5000))
        error = np.abs(sin_val**2 + cos_val**2 - dut.peak**2)
        self.assertLess(np.max(error)*2**18, 4.0)

    # -----------------------------------------------------------------------------------------------
    # Quadrant Handling
    # -----------------------------------------------------------------------------------------------
    def test_critical_angles(self):
        # 0, 90, 180 and 270 degrees are exact
        for int_bits in [0, 1]:
            dut = olo_fix_sin(FixFormat(1, int_bits, 16), FixFormat(0, 0, 20))
            sin_val, cos_val = dut.process(np.array([0.0, 0.25, 0.5, 0.75]))
            peak = dut.peak
            np.testing.assert_array_equal(sin_val, np.array([0.0, peak, 0.0, -peak]))
            np.testing.assert_array_equal(cos_val, np.array([peak, 0.0, -peak, 0.0]))

    def test_quadrant_symmetry(self):
        # sin(x + 0.5) = -sin(x) and cos(x + 0.25) = -sin(x) hold exactly, because all quadrants are
        # derived from the same quarter wave
        dut = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 20))
        phase = self._phase(FixFormat(0, 0, 18), 500)/4.0  # first quadrant
        sin_q0, cos_q0 = dut.process(phase)
        sin_q2, _ = dut.process(phase + 0.5)
        _, cos_q1 = dut.process(phase + 0.25)
        np.testing.assert_array_equal(sin_q2, -sin_q0)
        np.testing.assert_array_equal(cos_q1, -sin_q0)

    def test_phase_wraps(self):
        # The phase is periodic with one rotation - integer bits are dropped
        dut = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(1, 3, 18))
        base = np.array([0.1, 0.3, 0.6, 0.9])
        sin_ref, cos_ref = dut.process(base)

        for offset in [1.0, 4.0, -1.0, -3.0]:
            sin_val, cos_val = dut.process(base + offset)
            np.testing.assert_array_equal(sin_val, sin_ref)
            np.testing.assert_array_equal(cos_val, cos_ref)

    def test_negative_phase(self):
        # Negative phases wrap into the upper part of the rotation
        dut = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(1, 0, 18))
        sin_neg, cos_neg = dut.process(np.array([-0.25, -0.1]))
        dut_u = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 18))
        sin_pos, cos_pos = dut_u.process(np.array([0.75, 0.9]))
        np.testing.assert_array_equal(sin_neg, sin_pos)
        np.testing.assert_array_equal(cos_neg, cos_pos)

    # -----------------------------------------------------------------------------------------------
    # Interface
    # -----------------------------------------------------------------------------------------------
    def test_process_equals_next(self):
        dut = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 20))
        dut.reset()
        phase = self._phase(FixFormat(0, 0, 12))
        sin_a, cos_a = dut.next(phase)
        sin_b, cos_b = dut.process(phase)
        np.testing.assert_array_equal(sin_a, sin_b)
        np.testing.assert_array_equal(cos_a, cos_b)

    def test_scalar_input(self):
        dut = olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 20))
        sin_val, cos_val = dut.process(0.125)
        self.assertAlmostEqual(sin_val[0], np.sin(np.pi/4)*dut.peak, places=4)
        self.assertAlmostEqual(cos_val[0], np.cos(np.pi/4)*dut.peak, places=4)

    # -----------------------------------------------------------------------------------------------
    # Argument Checks
    # -----------------------------------------------------------------------------------------------
    def test_unsupported_formats(self):
        # Not enough fractional bits to split off the two quadrant bits
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(1, 0, 16), FixFormat(0, 0, 2))
        # Unsigned output
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(0, 0, 16), FixFormat(0, 0, 20))
        # Unsupported number of integer bits
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(1, 2, 16), FixFormat(0, 0, 20))
        # Fractional bits outside of the supported range
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(1, 0, 21), FixFormat(0, 0, 24))
        with self.assertRaises(ValueError):
            olo_fix_sin(FixFormat(1, 0, 9), FixFormat(0, 0, 20))

if __name__ == "__main__":
    unittest.main()
