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
from olo_fix import olo_fix_cic_dec
from en_cl_fix_pkg import *
from scipy import signal


class TestOloFixCicDec(unittest.TestCase):

    def setUp(self):

        # Test Setup
        self.config = {
            'order': 3,
            'ratio': 5,
            'diff_delay': 1,
            'in_fmt': FixFormat(1, 1, 14),
            'out_fmt': FixFormat(1, 0, 16),
            'gain_corr_coef_fmt': FixFormat(0, 1, 17),
            'round': FixRound.NonSymPos_s,
            'saturate': FixSaturate.Sat_s
        }
        self.dut = olo_fix_cic_dec(**self.config)
        
        self.input_dc = np.ones(30) * 0.5
        self.input_toggle = np.tile([0.5, -0.5], 15)


    # Test different process modes
    def test_array(self):
        result = self.dut.process(self.input_dc)
        np.testing.assert_allclose(result[-3:], [0.5, 0.5, 0.5], atol=1e-3)

        result = self.dut.process(self.input_toggle)
        print(self.input_toggle)
        print(result)
        np.testing.assert_allclose(result[-3:], [0.0, 0.0, 0.0], atol=5e-3)

    def test_sample_wise(self):
        result = np.concatenate([self.dut.next(x) for x in self.input_dc])
        np.testing.assert_allclose(result[-3:], [0.5, 0.5, 0.5], atol=1e-3)

        self.dut.clear_state()
        result = np.concatenate([self.dut.next(x) for x in self.input_toggle])
        np.testing.assert_allclose(result[-3:], [0.0, 0.0, 0.0], atol=5e-3)

    def test_partial_array(self):
        result = []
        result.append(self.dut.process(self.input_dc[:16]))
        result.append(self.dut.next(self.input_dc[16:]))
        result =  np.concatenate(result)
        np.testing.assert_allclose(result[-3:], [0.5, 0.5, 0.5], atol=1e-3)

        self.dut.clear_state()
        result = []
        result.append(self.dut.process(self.input_toggle[:13]))
        result.append(self.dut.next(self.input_toggle[13:]))
        result =  np.concatenate(result)
        np.testing.assert_allclose(result[-3:], [0.0, 0.0, 0.0], atol=5e-3)

    # Spectial Cases
    def test_no_gain_comp(self):
        config = self.config.copy()
        config['gain_corr_coef_fmt'] = "NONE"
        dut = olo_fix_cic_dec(**config)

        result = dut.process(self.input_dc)
        cic_gain = (self.config['ratio']*self.config['diff_delay'])**self.config['order']
        cic_shift = np.ceil(np.log2(cic_gain))
        expected_result = 0.5 * cic_gain / (2**cic_shift)
        np.testing.assert_allclose(result[-3:], np.array([expected_result, expected_result, expected_result]), atol=1e-3)

    # Errors
    def test_illegal_gain_comp_fmt(self):

        # Must have one integer bit
        config = self.config.copy()
        config['gain_corr_coef_fmt'] = FixFormat(0, 2, 16)  # I != 1
        with self.assertRaises(ValueError):
            dut = olo_fix_cic_dec(**config)

        # Must be "NONE" or FixFormat
        config = self.config.copy()
        config['gain_corr_coef_fmt'] = "INVALID_STRING"
        with self.assertRaises(ValueError):
            dut = olo_fix_cic_dec(**config)


if __name__ == '__main__':
    unittest.main()
