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
from olo_fix import olo_fix_bin_div
from en_cl_fix_pkg import *


class TestOloFixBinDiv(unittest.TestCase):

    def setUp(self):

        # Test Setup
        self.config = {
            'num_fmt': FixFormat(1, 2, 10),
            'denom_fmt': FixFormat(1, 3, 4),
            'out_fmt': FixFormat(1, 8, 12),
            'round': FixRound.NonSymPos_s,
            'saturate': FixSaturate.Sat_s
        }
        self.dut = olo_fix_bin_div(**self.config)
    
        # Stimuli and response
        self.in_nom = np.array([1.5, -2.75, 0.5, -0.125, 3.0])
        self.in_denom = np.array([0.5, 1.25, -0.25, -0.5, 0.75])
        self.expected = self.in_nom / self.in_denom

    # Test different process modes
    def test_scalar(self):
        res = self.dut.process(self.in_nom[0], self.in_denom[0])
        self.assertAlmostEqual(res, self.expected[0], delta=1e-3)
        
        res = self.dut.process(self.in_nom[1], self.in_denom[1])
        self.assertAlmostEqual(res, self.expected[1], delta=1e-3)

    def test_array(self):
        result = self.dut.process(self.in_nom, self.in_denom)
        np.testing.assert_allclose(result, self.expected, atol=1e-3)

    def test_next_scalar(self):
        result = []
        for nom, denom in zip(self.in_nom, self.in_denom):
            result.append(self.dut.next(nom, denom))
        np.testing.assert_allclose(result, self.expected, atol=1e-3)

    def test_next_list(self):
        res = []
        res.extend(self.dut.next(self.in_nom[:2], self.in_denom[:2]))
        res.extend(self.dut.next(self.in_nom[2:], self.in_denom[2:]))
        np.testing.assert_allclose(res, self.expected, atol=1e-3)

    # Test special cases
    def test_overflow(self):
        # Create DUT
        self.config['out_fmt'] = FixFormat(0, 0, 12)
        self.config['saturate'] = FixSaturate.None_s
        self.dut = olo_fix_bin_div(**self.config)

        # Execute
        res = self.dut.process(3.0, 0.25)  # 12.0 -> overflow
        self.assertEqual(res, 0.0)

    def test_underflow(self):
        # Create DUT
        self.config['out_fmt'] = FixFormat(0, 0, 12)
        self.config['saturate'] = FixSaturate.None_s
        self.dut = olo_fix_bin_div(**self.config)

        # Execute
        res = self.dut.process(1.0, -3.25)  # negative - underflow
        self.assertAlmostEqual(res, 1-1.0/3.25, delta=1e-3)


    def test_saturation_max(self):
        # Create DUT
        self.config['out_fmt'] = FixFormat(0, 0, 12)
        self.dut = olo_fix_bin_div(**self.config)

        # Execute
        res = self.dut.process(3.0, 0.25)
        fmt = FixFormat(0, 0, 12)
        self.assertEqual(res, cl_fix_max_value(fmt))


    def test_saturation_min(self):
        # Create DUT
        self.config['out_fmt'] = FixFormat(0, 0, 12)
        self.dut = olo_fix_bin_div(**self.config)

        # Execute
        res = self.dut.process(-3.0, 0.25)  # -12.0 -> underflow
        self.assertEqual(res, 0)    

    def test_div_by_zero(self):
   
        # Execute
        res = self.dut.process(1.0, 0.0)  # div by zero
        fmt = self.config['out_fmt']
        self.assertEqual(res, cl_fix_max_value(fmt))

    def test_dif_of_zero(self):
        # Execute
        res = self.dut.process(0.0, 2.5)  # zero numerator
        self.assertEqual(res, 0.0)       

if __name__ == '__main__':
    unittest.main()
