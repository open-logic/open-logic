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

if __name__ == '__main__':
    unittest.main()
