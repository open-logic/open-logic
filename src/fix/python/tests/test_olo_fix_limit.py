# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
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
from olo_fix import olo_fix_limit
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLimit(unittest.TestCase):

    IN_FMT = FixFormat(1, 5, 8)
    LIM_LO_FMT = FixFormat(1, 3, 0)
    LIM_HI_FMT = FixFormat(0, 3, 10)

    def setUp(self):
        self.dut = olo_fix_limit(in_fmt=self.IN_FMT, 
                                 lim_lo_fmt=self.LIM_LO_FMT, 
                                 lim_hi_fmt=self.LIM_HI_FMT,
                                 result_fmt=self.IN_FMT)
        self.dut_fixed = olo_fix_limit(in_fmt=self.IN_FMT,
                                        lim_lo_fmt=self.LIM_LO_FMT,
                                        lim_hi_fmt=self.LIM_HI_FMT,
                                        result_fmt=self.IN_FMT,
                                        lim_lo_fixed=-1.0,
                                        lim_hi_fixed=3.25)
        self.data = [-5.5, 3.25, -1.5, 0.0, 4.5]
        self.expected_fixed = [-1.0, 3.25, -1.0, 0.0, 3.25]
        self.lim_lo = [-1.0, -1.0, -2.0, -1.0, -1.0]
        self.lim_hi = [3.25, 3.25, 2.0, 3.25, 5.0]
        self.expected = [-1.0, 3.25, -1.5, 0.0, 4.5]


    def test_scalar(self):
        for i in [0, 1]:
            self.assertEqual(self.dut.process(self.data[i], self.lim_lo[i], self.lim_hi[i]), self.expected[i])
    
    def test_scalar_fixed(self):
        for i in [0, 1]:
            self.assertEqual(self.dut_fixed.process(self.data[i]), self.expected_fixed[i])

    def test_array(self):
        result = self.dut.process(self.data, self.lim_lo, self.lim_hi)
        self.assertListEqual(list(result), list(self.expected))

    def test_array_fixed(self):
        result = self.dut_fixed.process(self.data)
        self.assertListEqual(list(result), list(self.expected_fixed))

    def test_next_scalar(self):
        result = []
        for data, lo, hi in zip(self.data, self.lim_lo, self.lim_hi):
            result.append(self.dut.next(data, lo, hi))
        self.assertListEqual(result, self.expected)
        
    def test_next_scalar_fixed(self):
        result = []
        for data in self.data:
            result.append(self.dut_fixed.next(data))
        self.assertListEqual(result, self.expected_fixed)

    def test_next_list(self):
        result = []
        result.extend(self.dut.next(self.data[:2], self.lim_lo[:2], self.lim_hi[:2]))
        result.extend(self.dut.next(self.data[2:], self.lim_lo[2:], self.lim_hi[2:]))
        self.assertListEqual(result, self.expected)

    def test_next_list_fixed(self):
        result = []
        result.extend(self.dut_fixed.next(self.data[:2]))
        result.extend(self.dut_fixed.next(self.data[2:]))
        self.assertListEqual(result, self.expected_fixed)


if __name__ == '__main__':
    unittest.main()
