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
from olo_fix import olo_fix_abs
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixAbs(unittest.TestCase):

    def setUp(self):
        self.abs = olo_fix_abs(a_fmt=FixFormat(1, 8, 8), result_fmt=FixFormat(1, 8, 8))

    def test_scalar(self):
        self.assertEqual(self.abs.process(-5.5), 5.5)
        self.assertEqual(self.abs.process(5.5), 5.5)

    def test_array(self):
        a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        expected = [5.5, 3.25, 1.0, 0.0, 4.5]
        result = self.abs.process(a)
        self.assertListEqual(list(result), list(expected))

    def test_next_scalar(self):
        a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        expected = [5.5, 3.25, 1.0, 0.0, 4.5]
        result = []
        for sample in a:
            result.append(self.abs.next(sample))
        self.assertListEqual(result, expected)

    def test_next_list(self):
        a = [-5.5, 3.25, -1.0, 0.0, 4.5]
        expected = [5.5, 3.25, 1.0, 0.0, 4.5]
        result = []
        result.extend(self.abs.next(a[:2]))
        result.extend(self.abs.next(a[2:]))
        self.assertListEqual(result, expected)


if __name__ == '__main__':
    unittest.main()
