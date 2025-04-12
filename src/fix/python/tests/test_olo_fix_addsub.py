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
from olo_fix_addsub import olo_fix_addsub
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixAddsub(unittest.TestCase):

    def setUp(self):
        self.addsub = olo_fix_addsub(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), result_fmt=FixFormat(1, 8, 8))
        self.a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        self.b = [1.5, -2.25, 0.5, 0.0, -4.5]
        self.select = [True, False, True, False, True]
        self.expected_add = [-4.0, 1.0, -0.5, 0.0, 0.0]
        self.expected_sub = [-7.0, 5.5, -1.5, 0.0, 9.0]
        self.expected_select = [-4.0, 5.5, -0.5, 0.0, 0.0]

    def test_scalar(self):
        self.assertEqual(self.addsub.process(self.a[0], self.b[0], self.select[0]), self.expected_select[0])
        self.assertEqual(self.addsub.process(self.a[1], self.b[1], self.select[1]), self.expected_select[1])

    def test_array(self):
        result = self.addsub.process(self.a, self.b, self.select)
        self.assertListEqual(list(result), list(self.expected_select))

    def test_array_scalarSelect(self):
        result = self.addsub.process(self.a, self.b, True)
        self.assertListEqual(list(result), list(self.expected_add))

        result = self.addsub.process(self.a, self.b, False)
        self.assertListEqual(list(result), list(self.expected_sub))

    def test_next_scalar(self):
        result = []
        for sa, sb, sel in zip(self.a, self.b, self.select):
            result.append(self.addsub.next(sa, sb, sel))
        self.assertListEqual(result, self.expected_select)

    def test_next_list(self):
        result = []
        result.extend(self.addsub.next(self.a[:2], self.b[:2], self.select[:2]))
        result.extend(self.addsub.next(self.a[2:], self.b[2:], self.select[2:]))
        self.assertListEqual(result, self.expected_select)


if __name__ == '__main__':
    unittest.main()
