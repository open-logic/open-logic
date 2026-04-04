# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------

import unittest
import sys
import os
import numpy as np
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_sample_hold
from en_cl_fix_pkg import *

class TestOloFixSampleHold(unittest.TestCase):

    FMT = FixFormat(1, 4, 8)

    def test_hold_single_sample(self):
        """Input a single sample, then read it back"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=1.5)
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(1.5, self.FMT))

    def test_hold_persists(self):
        """Value is held across multiple reads"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=2.25)
        r1 = dut.next(out_samples=1)
        r2 = dut.next(out_samples=1)
        self.assertEqual(r1, cl_fix_from_real(2.25, self.FMT))
        self.assertEqual(r2, cl_fix_from_real(2.25, self.FMT))

    def test_hold_updates(self):
        """New input replaces held value"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=1.0)
        self.assertEqual(dut.next(out_samples=1), cl_fix_from_real(1.0, self.FMT))
        dut.next(input=3.0)
        self.assertEqual(dut.next(out_samples=1), cl_fix_from_real(3.0, self.FMT))

    def test_hold_last_of_sequence(self):
        """When multiple input samples are given, the last one is held"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=[1.0, 2.0, 3.5])
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(3.5, self.FMT))

    def test_reset_value_default(self):
        """Default reset value is 0.0"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(0.0, self.FMT))

    def test_reset_value_custom(self):
        """Custom reset value is returned before any input"""
        dut = olo_fix_sample_hold(fmt=self.FMT, reset_value=1.25)
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(1.25, self.FMT))

    def test_reset(self):
        """After reset, held value returns to reset value"""
        dut = olo_fix_sample_hold(fmt=self.FMT, reset_value=-0.5)
        dut.next(input=5.0)
        dut.reset()
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(-0.5, self.FMT))

    def test_out_samples_multiple(self):
        """out_samples > 1 returns an array of held values"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=2.0)
        result = dut.next(out_samples=3)
        expected = cl_fix_from_real(2.0, self.FMT)
        np.testing.assert_array_equal(result, np.full(3, expected))

    def test_out_samples_zero(self):
        """out_samples=0 returns None"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=1.0)
        result = dut.next(out_samples=0)
        self.assertIsNone(result)

    def test_no_input_no_output(self):
        """No input and no output returns None"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        result = dut.next()
        self.assertIsNone(result)

    def test_process_resets_state(self):
        """process() resets state before operating"""
        dut = olo_fix_sample_hold(fmt=self.FMT, reset_value=0.0)
        dut.next(input=5.0)
        result = dut.process(input=2.0, out_samples=1)
        self.assertEqual(result, cl_fix_from_real(2.0, self.FMT))

    def test_process_without_input(self):
        """process() without input returns reset value"""
        dut = olo_fix_sample_hold(fmt=self.FMT, reset_value=1.5)
        dut.next(input=5.0)
        result = dut.process(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(1.5, self.FMT))

    def test_input_and_output_same_call(self):
        """Input and output in the same next() call"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        # next
        result = dut.next(input=4.0, out_samples=1)
        self.assertEqual(result, cl_fix_from_real(4.0, self.FMT))
        # process
        result = dut.process(input=3.0, out_samples=1)
        self.assertEqual(result, cl_fix_from_real(3.0, self.FMT))

    def test_input_and_output_same_call_multiple_samples(self):
        """When input and output are in the same call, the last input sample is held and returned"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        # next
        result = dut.next(input=[1.0, 2.0, 3.0], out_samples=1)
        self.assertEqual(result, cl_fix_from_real(3.0, self.FMT))
        # process
        result = dut.process(input=[4.0, 5.0], out_samples=3)
        expected = cl_fix_from_real(5.0, self.FMT)
        np.testing.assert_array_equal(result, np.full(3, expected))

    def test_integer_input(self):
        """Integer input is accepted"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=3)
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(3.0, self.FMT))

    def test_negative_values(self):
        """Negative values are correctly held"""
        dut = olo_fix_sample_hold(fmt=self.FMT)
        dut.next(input=-2.75)
        result = dut.next(out_samples=1)
        self.assertEqual(result, cl_fix_from_real(-2.75, self.FMT))

if __name__ == '__main__':
    unittest.main()
