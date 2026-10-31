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
from olo_fix import olo_fix_dds, olo_fix_sin
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixDds(unittest.TestCase):

    PHASE_FMT = FixFormat(0, 0, 24)
    OUT_FMT = FixFormat(1, 0, 16)

    # -----------------------------------------------------------------------------------------------
    # Parameter Checks
    # -----------------------------------------------------------------------------------------------
    def test_illegal_phase_fmt(self):
        for fmt in [FixFormat(1, 0, 24), FixFormat(0, 1, 24)]:
            with self.assertRaises(ValueError):
                olo_fix_dds(fmt, self.OUT_FMT)

    def test_length_mismatch(self):
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        with self.assertRaises(ValueError):
            dut.process([0.1, 0.1], [0.0])

    def test_sin_phase_fmt(self):
        # Phase is rounded to out_fmt.F + 4 fractional bits, but never widened
        self.assertEqual(olo_fix_dds(FixFormat(0, 0, 32), self.OUT_FMT).sin_phase_fmt, FixFormat(0, 0, 20))
        self.assertEqual(olo_fix_dds(FixFormat(0, 0, 18), self.OUT_FMT).sin_phase_fmt, FixFormat(0, 0, 18))

    # -----------------------------------------------------------------------------------------------
    # Functionality
    # -----------------------------------------------------------------------------------------------
    def test_first_sample_is_offset(self):
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        sin_val, cos_val = dut.process([0.1], [0.25])
        self.assertEqual(sin_val[0], dut.peak)
        self.assertEqual(cos_val[0], 0.0)

    def test_frequency(self):
        # Step of 1/16 rotation produces a wave with period 16, compare against olo_fix_sin
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        n = 40
        sin_val, cos_val = dut.process(np.full(n, 1/16), np.full(n, 0.125))
        phase = (np.arange(n)/16 + 0.125) % 1.0
        ref_sin, ref_cos = olo_fix_sin(dut.sin_phase_fmt, self.OUT_FMT).process(phase)
        np.testing.assert_array_equal(sin_val, ref_sin)
        np.testing.assert_array_equal(cos_val, ref_cos)

    def test_accuracy(self):
        # Odd phase step with full resolution, error must stay below one LSB (plus phase rounding)
        dut = olo_fix_dds(FixFormat(0, 0, 32), self.OUT_FMT)
        n = 3000
        step = cl_fix_from_real(0.0123456789, FixFormat(0, 0, 32))
        sin_val, cos_val = dut.process(np.full(n, step), np.zeros(n))
        phase = np.arange(n) * step
        sin_err = np.max(np.abs(sin_val - np.sin(2*np.pi*phase)*dut.peak))*2**self.OUT_FMT.F
        cos_err = np.max(np.abs(cos_val - np.cos(2*np.pi*phase)*dut.peak))*2**self.OUT_FMT.F
        self.assertLess(sin_err, 1.0)
        self.assertLess(cos_err, 1.0)

    def test_wrapping(self):
        # Negative inputs and inputs above one rotation wrap
        dut_wrap = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        dut_ref = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        n = 20
        sin_wrap, cos_wrap = dut_wrap.process(np.full(n, -0.1), np.full(n, 1.3))
        sin_ref, cos_ref = dut_ref.process(np.full(n, 0.9), np.full(n, 0.3))
        np.testing.assert_array_equal(sin_wrap, sin_ref)
        np.testing.assert_array_equal(cos_wrap, cos_ref)

    def test_phase_rounding_wraps(self):
        # A phase that rounds up to 1.0 must wrap to 0.0 (sine 0, cosine peak)
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        sin_val, cos_val = dut.process([0.0], [1.0 - 2**-24])
        self.assertEqual(sin_val[0], 0.0)
        self.assertEqual(cos_val[0], dut.peak)

    def test_restart(self):
        # Restart sets the accumulator to zero, hence the sequence starts over
        n = 10
        restart = np.zeros(n, dtype=bool)
        restart[5] = True
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        sin_val, _ = dut.process(np.full(n, 0.05), np.zeros(n), restart)
        sin_ref, _ = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT).process(np.full(n, 0.05), np.zeros(n))
        np.testing.assert_array_equal(sin_val[:5], sin_ref[:5])
        np.testing.assert_array_equal(sin_val[5:], sin_ref[:5])

    def test_next_vs_process(self):
        # next() continues with the accumulator state, process() restarts
        steps = np.linspace(0.01, 0.2, 21)
        offsets = np.linspace(0.0, 0.5, 21)
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        sin_all, _ = dut.process(steps, offsets)
        sin_a, _ = dut.process(steps[:8], offsets[:8])
        sin_b, _ = dut.next(steps[8:], offsets[8:])
        np.testing.assert_array_equal(np.concatenate((sin_a, sin_b)), sin_all)
        sin_again, _ = dut.process(steps, offsets)
        np.testing.assert_array_equal(sin_again, sin_all)

    def test_scalar_input(self):
        dut = olo_fix_dds(self.PHASE_FMT, self.OUT_FMT)
        sin_val, cos_val = dut.next(0.25, 0.0)
        self.assertEqual(sin_val[0], 0.0)
        self.assertEqual(cos_val[0], dut.peak)
        sin_val, cos_val = dut.next(0.25, 0.0)
        self.assertEqual(sin_val[0], dut.peak)
        self.assertEqual(cos_val[0], 0.0)

if __name__ == "__main__":
    unittest.main()
