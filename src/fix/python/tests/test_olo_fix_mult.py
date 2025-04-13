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
from olo_fix import olo_fix_mult
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixMult(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_mult(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), result_fmt=FixFormat(1, 8, 2), round=FixRound.NonSymPos_s)
        self.a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        self.b = [1.5, -2.25, 0.5, 0.0, -4.5]
        self.expected = [-8.25, -7.25, -0.5, 0.0, -20.25]

    def test_scalar(self):
        self.assertEqual(self.dut.process(self.a[0], self.b[0]), self.expected[0])
        self.assertEqual(self.dut.process(self.a[1], self.b[1]), self.expected[1])

    def test_array(self):
        result = self.dut.process(self.a, self.b)
        self.assertListEqual(list(result), list(self.expected))

    def test_next_scalar(self):
        result = []
        for sa, sb in zip(self.a, self.b):
            result.append(self.dut.next(sa, sb))
        self.assertListEqual(result, self.expected)

    def test_next_list(self):
        result = []
        result.extend(self.dut.next(self.a[:2], self.b[:2]))
        result.extend(self.dut.next(self.a[2:], self.b[2:]))
        self.assertListEqual(result, self.expected)


if __name__ == '__main__':
    unittest.main()
