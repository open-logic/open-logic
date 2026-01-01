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
from olo_fix import olo_fix_cordic_vect
from en_cl_fix_pkg import *


class TestOloFixCordicVect(unittest.TestCase):

    def angl_diff(self, a, b):
        """Compute difference between two angles in [0, 1) range, taking care of wrap-around."""
        diff = a - b
        diff = np.where(diff > 0.5, diff - 1.0, diff)
        diff = np.where(diff < -0.5, diff + 1.0, diff)
        return diff

    def setUp(self):

        # Test Setup
        self.config = {
            'in_fmt': FixFormat(1, 0, 16),
            'out_mag_fmt': FixFormat(0, 1, 16),
            'out_ang_fmt': FixFormat(0, 0, 15),
            'int_xy_fmt': FixFormat(1, 2, 22),
            'int_ang_fmt': FixFormat(1, -1, 23),
            'iterations': 21,
            'gain_corr_coef_fmt': FixFormat(0, 0, 17),
            'round': FixRound.NonSymPos_s,
            'sat': FixSaturate.Sat_s
        }
        self.dut = olo_fix_cordic_vect(**self.config)
        
        input = [0.5+0.0j, 0.123+0.25j, 0.7+0.76j, 0.2+0.9j, 0.9+0.01j]

        self.in_i = np.real(input)
        self.in_q = np.imag(input)
        self.expected_mag = np.abs(input)
        self.expected_ang = np.angle(input)/(2.0*np.pi) 
        self.expected_ang = np.where(self.expected_ang < 0, self.expected_ang + 1.0, self.expected_ang)
        
    # Test different process modes
    def test_scalar(self):
        res = self.dut.process(self.in_i[0], self.in_q[0])
        self.assertAlmostEqual(res[0], self.expected_mag[0], delta=1e-3)
        self.assertLess(abs(self.angl_diff(res[1], self.expected_ang[0])), 1e-3)
        
        res = self.dut.process(self.in_i[1], self.in_q[1])
        self.assertAlmostEqual(res[0], self.expected_mag[1], delta=1e-3)
        self.assertLess(abs(self.angl_diff(res[1], self.expected_ang[1])), 1e-3)

    def test_array(self):
        result = self.dut.process(self.in_i, self.in_q)
        np.testing.assert_allclose(result[0], self.expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(result[1], self.expected_ang), 0, atol=1e-3)

    def test_next_scalar(self):
        result = []
        for i, q in zip(self.in_i, self.in_q):
            result.append(self.dut.next(i, q))
        res_mag, res_ang = zip(*result)
        np.testing.assert_allclose(res_mag, self.expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(np.array(res_ang), self.expected_ang), 0, atol=1e-3)

    def test_next_list(self):
        res_i = []
        res_q = []
        i, q = self.dut.next(self.in_i[:2], self.in_q[:2])
        res_i.extend(i)
        res_q.extend(q)
        i, q = self.dut.next(self.in_i[2:], self.in_q[2:])
        res_i.extend(i)
        res_q.extend(q)
        np.testing.assert_allclose(res_i, self.expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(np.array(res_q), self.expected_ang), 0, atol=1e-3)

    # Test special cases
    def test_no_caincomp(self):
        # Create
        self.config['gain_corr_coef_fmt'] = "NONE"
        self.dut = olo_fix_cordic_vect(**self.config)
        # Execute
        result = self.dut.process(self.in_i, self.in_q)
        # Check
        expected_mag = self.expected_mag * self.dut.cordic_gain
        expected_ang = self.expected_ang
        np.testing.assert_allclose(result[0], expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(result[1], expected_ang), 0, atol=1e-3)

    def test_large_range(self):
        # Create
        self.config['in_fmt'] = FixFormat(1, 2, 16)
        self.config['int_xy_fmt'] = FixFormat(1, 4, 22)
        self.config['out_mag_fmt'] = FixFormat(0, 3, 16)
        self.dut = olo_fix_cordic_vect(**self.config)
        # Execute
        result = self.dut.process(self.in_i*2, self.in_q*2)
        # Check
        np.testing.assert_allclose(result[0], self.expected_mag*2, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(result[1], self.expected_ang), 0, atol=1e-3)

    def test_auto_fmt(self):
        # Create
        self.config['int_xy_fmt'] = "AUTO"
        self.config['int_ang_fmt'] = "AUTO"
        self.dut = olo_fix_cordic_vect(**self.config)
        # Execute
        result = self.dut.process(self.in_i, self.in_q)
        # Check
        np.testing.assert_allclose(result[0], self.expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(result[1], self.expected_ang), 0, atol=1e-3)    

    def test_signed_angle_fmt(self):
        # Create
        self.config['out_ang_fmt'] = FixFormat(1, -1, 16)
        self.dut = olo_fix_cordic_vect(**self.config)
        # Execute
        result = self.dut.process(self.in_i, self.in_q)
        # Check
        self.expected_ang = np.where(self.expected_ang > 0.5, self.expected_ang - 1.0, self.expected_ang)
        np.testing.assert_allclose(result[0], self.expected_mag, atol=1e-3)
        np.testing.assert_allclose(self.angl_diff(result[1], self.expected_ang), 0, atol=1e-3)    

    # Test construction errorrs
    def test_invalid_in_fmt(self):
        # unsigned
        self.config['in_fmt'] = FixFormat(0, 8, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

    def test_invalid_out_mag_fmt(self):
        # signed
        self.config['out_mag_fmt'] = FixFormat(1, 8, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

    def test_invalid_out_ang_fmt(self):
        # unsigned, range too small
        self.config['out_ang_fmt'] = FixFormat(0, -2, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

        # unsigned, range too big
        self.config['out_ang_fmt'] = FixFormat(0, 1, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

        # signed, range too small
        self.config['out_ang_fmt'] = FixFormat(1, -2, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

        # signed, range too big
        self.config['out_ang_fmt'] = FixFormat(1, 0, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)
            
    def test_invalid_int_xy_fmt(self):
        # unsigned
        self.config['int_xy_fmt'] = FixFormat(0, 8, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

        # Illegal string
        self.config['int_xy_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)   

    def test_invalid_int_ang_fmt(self):
        # unsigned
        self.config['int_ang_fmt'] = FixFormat(0, -2, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

        # Too small range
        self.config['int_ang_fmt'] = FixFormat(0, -4, 8)
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)       

        # Illegal string
        self.config['int_ang_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)  

    def test_invalid_iterations(self):
        self.config['iterations'] = 40
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)

    def test_invalid_gain_corr_coef_fmt(self):
        self.config['gain_corr_coef_fmt'] = "BadString"
        with self.assertRaises(ValueError):
            self.dut = olo_fix_cordic_vect(**self.config)  



if __name__ == '__main__':
    unittest.main()
