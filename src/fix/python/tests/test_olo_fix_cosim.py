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
from olo_fix import olo_fix_cosim
from en_cl_fix_pkg import *

class TestOloFixUtils_FixFormatFromString(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_cosim(".")

    def test_ok(self):
        self.dut.write_cosim_file([1.0,2.0,17.0,-2.0], FixFormat(1,12,2), "test_output.fix")
        
        # Read and verify the file content
        with open("test_output.fix", "r") as f:
            lines = f.read().strip().split('\n')
        
        # Expected content
        expected = [
            "(1,12,2)",
            "0004",
            "0008",
            "0044",
            "7FF8"
        ]
        
        self.assertEqual(lines, expected)
        
if __name__ == '__main__':
    unittest.main()
