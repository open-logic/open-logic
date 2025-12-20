# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
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
from olo_fix import olo_fix_cordic_rot
from en_cl_fix_pkg import *


class TestOloFixCordicRot(unittest.TestCase):

    def setUp(self):

        # Test Setup
        self.config = {
            'in_mag_fmt': FixFormat(0, 0, 16),
            'in_ang_fmt': FixFormat(0, 0, 15),
            'out_fmt': FixFormat(1, 2, 16),
            'int_xy_fmt': FixFormat(1, 2, 22),
            'int_ang_fmt': FixFormat(1, -2, 23),
            'iterations': 21,
            'gain_corr_coef_fmt': FixFormat(0, 0, 17),
            'round': FixRound.NonSymPos_s,
            'sat': FixSaturate.Sat_s
        }
        self.dut = olo_fix_cordic_rot(**self.config)
        
        input = [0.5+0.0j, 0.123+0.25j, 0.7+0.76j, 0.2+0.9j, 0.9+0.01j]

        self.in_abs = np.abs(input)
        self.in_ang = np.angle(input)/(2.0*np.pi) 
        self.in_ang = np.where(self.in_ang < 0, self.in_ang + 1.0, self.in_ang)
        self.expected_i = np.real(input)
        self.expected_q = np.imag(input)

    # Test different process modes
    def test_scalar(self):
        res = self.dut.process(self.in_abs[0], self.in_ang[0])
        self.assertAlmostEqual(res[0], self.expected_i[0], delta=1e-3)
        self.assertAlmostEqual(res[1], self.expected_q[0], delta=1e-3)
        
        res = self.dut.process(self.in_abs[1], self.in_ang[1])
        self.assertAlmostEqual(res[0], self.expected_i[1], delta=1e-3)
        self.assertAlmostEqual(res[1], self.expected_q[1], delta=1e-3)

    def test_array(self):
        result = self.dut.process(self.in_abs, self.in_ang)
        np.testing.assert_allclose(result[0], self.expected_i, atol=1e-3)
        np.testing.assert_allclose(result[1], self.expected_q, atol=1e-3)

    def test_next_scalar(self):
        result = []
        for abs, ang in zip(self.in_abs, self.in_ang):
            result.append(self.dut.next(abs, ang))
        res_i, res_q = zip(*result)
        np.testing.assert_allclose(res_i, self.expected_i, atol=1e-3)
        np.testing.assert_allclose(res_q, self.expected_q, atol=1e-3)

    def test_next_list(self):
        res_i = []
        res_q = []
        i, q = self.dut.next(self.in_abs[:2], self.in_ang[:2])
        res_i.extend(i)
        res_q.extend(q)
        i, q = self.dut.next(self.in_abs[2:], self.in_ang[2:])
        res_i.extend(i)
        res_q.extend(q)
        np.testing.assert_allclose(res_i, self.expected_i, atol=1e-3)
        np.testing.assert_allclose(res_q, self.expected_q, atol=1e-3)

    # Test special cases
    def test_no_caincomp(self):
        # Create
        self.config['gain_corr_coef_fmt'] = "NONE"
        self.dut = olo_fix_cordic_rot(**self.config)
        # Execute
        result = self.dut.process(self.in_abs, self.in_ang)
        # Checksrc/fix/python/tests/test_olo_fix_cordic_rot.py
    def test_large_range(self):
        # Create
        self.config['in_mag_fmt'] = FixFormat(0, 2, 16)
        self.config['int_xy_fmt'] = FixFormat(1, 4, 22)
        self.dut = olo_fix_cordic_rot(**self.config)
        # Execute
        result = self.dut.process(self.in_abs*2, self.in_ang)
        # Check
        np.testing.assert_allclose(result[0], self.expected_i*2, atol=1e-3)
        np.testing.assert_allclose(result[1], self.expected_q*2, atol=1e-3)       

    def test_auto_fmt(self):
        # Create
        self.config['int_xy_fmt'] = "AUTO"
        self.config['int_ang_fmt'] = "AUTO"
        self.dut = olo_fix_cordic_rot(**self.config)
        # Execute
        result = self.dut.process(self.in_abs, self.in_ang)
        # Check
        np.testing.assert_allclose(result[0], self.expected_i, atol=1e-3)
        np.testing.assert_allclose(result[1], self.expected_q, atol=1e-3)         

    # Test construction errorrs
    def test_invalid_in_mag_fmt(self):
        self.config['in_mag_fmt'] = FixFormat(1, 0, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)

    def test_invalid_in_ang_fmt(self):
        self.config['in_ang_fmt'] = FixFormat(1, 0, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)

        self.config['in_ang_fmt'] = FixFormat(0, 1, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)
            
    def test_invalid_int_xy_fmt(self):
        # unsigned
        self.config['int_xy_fmt'] = FixFormat(0, 8, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)

        # Illegal string
        self.config['int_xy_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)   

    def test_invalid_int_ang_fmt(self):
        # unsigned
        self.config['int_ang_fmt'] = FixFormat(0, -2, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)

        # Too small range
        self.config['int_ang_fmt'] = FixFormat(0, -4, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)       

        # Illegal string
        self.config['int_ang_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)  

    def test_invalid_iterations(self):
        self.config['iterations'] = 40
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)

    def test_invalid_gain_corr_coef_fmt(self):
        self.config['gain_corr_coef_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_rot(**self.config)  



if __name__ == '__main__':
    unittest.main()
