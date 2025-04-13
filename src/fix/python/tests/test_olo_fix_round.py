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
from olo_fix_round import olo_fix_round
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixRound(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_round(a_fmt=FixFormat(1, 8, 8), result_fmt=FixFormat(1, 9, 2), round=FixRound.NonSymPos_s)
        self.a = []
        self.expected = []
        # Append test no change
        self.a.append(2.25)
        self.expected.append(2.25)
        self.a.append(-1.0)
        self.expected.append(-1.0)
        # Append test round
        self.a.append(2.95)
        self.expected.append(3.00)
        # Append test negative number
        self.a.append(-2.95)
        self.expected.append(-3.00)

    def test_scalar(self):
        self.assertEqual(self.dut.process(self.a[0]), self.expected[0])
        self.assertEqual(self.dut.process(self.a[1]), self.expected[1])

    def test_array(self):
        result = self.dut.process(self.a)
        self.assertListEqual(list(result), list(self.expected))

    def test_next_scalar(self):
        result = []
        for sample in self.a:
            result.append(self.dut.next(sample))
        self.assertListEqual(result, self.expected)

    def test_next_list(self):
        result = []
        result.extend(self.dut.next(self.a[:2]))
        result.extend(self.dut.next(self.a[2:]))
        self.assertListEqual(result, self.expected)


if __name__ == '__main__':
    unittest.main()
