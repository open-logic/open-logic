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
from olo_fix import olo_fix_utils as dut
from en_cl_fix_pkg import *
import numpy as np

class TestOloFixUtils_FixFormatFromString(unittest.TestCase):

    def setUp(self):
        pass

    def test_ok(self):
        self.assertEqual(dut.fix_format_from_string("(1,2,7)"), FixFormat(1,2,7))
        self.assertEqual(dut.fix_format_from_string("(1, -2, 7 )"), FixFormat(1,-2,7))

    def test_no_brackets(self):
        with self.assertRaises(ValueError):
            dut.fix_format_from_string("1,27")

    def test_tolerate_non_foirmat(self):
        self.assertEqual(dut.fix_format_from_string("not_a_format", tolerate_str=True), "not_a_format")
        with self.assertRaises(ValueError):
            dut.fix_format_from_string("not_a_format", tolerate_str=False)

class TestOloFixUtils_GetLeadingBitIndex(unittest.TestCase):

    def test_unsigned(self):
        fmt = FixFormat(0, 4, 4)
        data = np.array([0.0, 0.0625, 0.5, 1.0, 1.5, 15.9375])
        np.testing.assert_array_equal(dut.get_leading_bit_index(data, fmt), [0, 0, 3, 4, 4, 7])

    def test_signed(self):
        # Negative numbers are evaluated on their two's complement bit pattern (MSB is set)
        fmt = FixFormat(1, 3, 4)
        data = np.array([0.0, 1.0, 7.9375, -0.0625, -8.0])
        np.testing.assert_array_equal(dut.get_leading_bit_index(data, fmt), [0, 4, 6, 7, 7])

    def test_scalar(self):
        np.testing.assert_array_equal(dut.get_leading_bit_index(2.0, FixFormat(0, 4, 0)), [1])

    def test_wide(self):
        # Wider than a double mantissa, the LSB must still be detected correctly
        fmt = FixFormat(0, 100, 0)
        data = cl_fix_from_integer(np.array([1, 2**99, 2**99 + 1], dtype=object), fmt)
        np.testing.assert_array_equal(dut.get_leading_bit_index(data, fmt), [0, 99, 99])

if __name__ == '__main__':
    unittest.main()
