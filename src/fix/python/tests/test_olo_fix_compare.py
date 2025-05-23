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
from olo_fix import olo_fix_compare
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloCompare(unittest.TestCase):

    def setUp(self):
        self.gt = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison=">")
        self.lt = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison="<")
        self.eq = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison="=")
        self.ne = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison="!=")
        self.ge = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison=">=")
        self.le = olo_fix_compare(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), comparison="<=")
        self.a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        self.b = [1.5, -2.25, 0.5, 0.0, -4.5]
        self.expected_gt = [False, True, False, False, True]
        self.expected_lt = [True, False, True, False, False]
        self.expected_eq = [False, False, False, True, False]
        self.expected_ne = [True, True, True, False, True]
        self.expected_ge = [True, True, False, True, True]
        self.expected_le = [True, False, True, True, False]

    def test_scalar(self):
        self.assertEqual(self.gt.process(self.a[0], self.b[0]), self.expected_gt[0])
        self.assertEqual(self.lt.process(self.a[1], self.b[1]), self.expected_lt[1])

    def test_array(self):
        result = self.gt.process(self.a, self.b)
        self.assertListEqual(list(result), list(self.expected_gt))

    def test_next_scalar(self):
        result = []
        for sa, sb in zip(self.a, self.b):
            result.append(self.gt.next(sa, sb))
        self.assertListEqual(result, self.expected_gt)

    def test_next_list(self):
        result = []
        result.extend(self.gt.next(self.a[:2], self.b[:2]))
        result.extend(self.gt.next(self.a[2:], self.b[2:]))
        self.assertListEqual(result, self.expected_gt)


if __name__ == '__main__':
    unittest.main()
