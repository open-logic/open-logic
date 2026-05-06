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
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_mov_avg
from en_cl_fix_pkg import *
import copy

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixMovAvg(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8))
        self.data = [1, 2, 3, 4, 5]
        self.expected = np.array([1.0/3.0, 3.0/3.0, 6.0/3.0, 9.0/3.0, 12.0/3.0])

    def test_vector(self):
        result = self.dut.process(self.data)
        for r, e in zip(result, self.expected):
            self.assertAlmostEqual(r, e, delta=0.05)

    def test_vector_scalar(self):
        result_vec = self.dut.process(self.data)
        self.dut.reset()  # Reset state to ensure same conditions for scalar processing
        result_scalar = [self.dut.next(x) for x in self.data]
        result_scalar = np.concatenate(result_scalar)
        self.assertTrue((result_vec == result_scalar).all())

    def test_vector_part_vector(self):
        result_vec = self.dut.process(self.data)
        self.dut.reset()  # Reset state to ensure same conditions for scalar processing
        result_scalar = [self.dut.next(self.data[:2]), self.dut.next(self.data[2:])]
        result_scalar = np.concatenate(result_scalar)
        self.assertTrue((result_vec == result_scalar).all())

    def test_gc_shift(self):
        self.dut = olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="SHIFT")
        result = self.dut.process(self.data)
        gain = 3.0/4.0
        for r, e in zip(result, self.expected*gain):
            self.assertAlmostEqual(r, e, delta=0.05)

    def test_gc_none(self):
        self.dut = olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="NONE")
        result = self.dut.process(self.data)
        gain = 3.0
        for r, e in zip(result, self.expected*gain):
            self.assertAlmostEqual(r, e, delta=0.05)

    def test_invalid_taps(self):
        with self.assertRaises(ValueError):
            olo_fix_mov_avg(taps=0, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8))

    def test_specific_gain_corr_fmt(self):
        gain_corr_fmt = FixFormat(0, 1, 12)
        self.dut = olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="EXACT", gain_corr_coef_fmt=gain_corr_fmt)
        result = self.dut.process(self.data)
        for r, e in zip(result, self.expected):
            self.assertAlmostEqual(r, e, delta=0.05)        

    def test_specific_gain_corr_data_fmt(self):
        gain_corr_data_fmt = FixFormat(0, 4, 12)
        self.dut = olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="EXACT", gain_corr_data_fmt=gain_corr_data_fmt)
        result = self.dut.process(self.data)
        for r, e in zip(result, self.expected):
            self.assertAlmostEqual(r, e, delta=0.05)

    def test_invalid_gain_corr_type(self):
        with self.assertRaises(ValueError):
            olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="INVALID")

    def test_invalid_gain_corr_data_fmt(self):
        with self.assertRaises(ValueError):
            olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="EXACT", gain_corr_data_fmt="INVALID")
        with self.assertRaises(ValueError):
            olo_fix_mov_avg(taps=3, in_fmt=FixFormat(1, 8, 8), out_fmt=FixFormat(1, 8, 8), gain_corr_type="EXACT", gain_corr_data_fmt=123)
if __name__ == '__main__':
    unittest.main()
