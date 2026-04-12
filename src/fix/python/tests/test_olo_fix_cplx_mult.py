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
from olo_fix import olo_fix_cplx_mult
from en_cl_fix_pkg import *

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixCplxMult(unittest.TestCase):

    def setUp(self):
        self.dut_mix = olo_fix_cplx_mult(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), result_fmt=FixFormat(1, 10, 10), Mode_g="MIX")
        self.dut_mult = olo_fix_cplx_mult(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), result_fmt=FixFormat(1, 10, 10), Mode_g="MULT")

        self.a = [-5.5+0j, 3.25+1.25j, -1.0-1.25j, 0.0+0.0j, 4.5-0.5j]
        self.b = [1.5+0j, -2.25-0.25j, 0.5+0.5j, 0.0+0.0j, -4.5+0.5j]
        self.expected_mult = np.array(self.a) * np.array(self.b)
        self.expected_mix = np.array(self.a) * np.conj(np.array(self.b))

    def test_scalar(self):
        resi, resq = self.dut_mult.process(np.real(self.a[0]), np.imag(self.a[0]), np.real(self.b[0]), np.imag(self.b[0]))
        self.assertEqual(resi, np.real(self.expected_mult[0]))
        self.assertEqual(resq, np.imag(self.expected_mult[0]))

        resi, resq = self.dut_mult.process(np.real(self.a[1]), np.imag(self.a[1]), np.real(self.b[1]), np.imag(self.b[1]))
        self.assertEqual(resi, np.real(self.expected_mult[1]))
        self.assertEqual(resq, np.imag(self.expected_mult[1]))

        resi, resq = self.dut_mix.process(np.real(self.a[0]), np.imag(self.a[0]), np.real(self.b[0]), np.imag(self.b[0]))
        self.assertEqual(resi, np.real(self.expected_mix[0]))
        self.assertEqual(resq, np.imag(self.expected_mix[0]))

    def test_array(self):
        resi, resq = self.dut_mult.process(np.real(self.a), np.imag(self.a), np.real(self.b), np.imag(self.b))
        self.assertListEqual(list(resi), list(np.real(self.expected_mult)))
        self.assertListEqual(list(resq), list(np.imag(self.expected_mult)))

        resi, resq = self.dut_mix.process(np.real(self.a), np.imag(self.a), np.real(self.b), np.imag(self.b))
        self.assertListEqual(list(resi), list(np.real(self.expected_mix)))
        self.assertListEqual(list(resq), list(np.imag(self.expected_mix)))

    def test_next_scalar(self):
        resi = []
        resq = []
        for sa, sb in zip(self.a, self.b):
            resi_i, resq_i = self.dut_mult.next(np.real(sa), np.imag(sa), np.real(sb), np.imag(sb))
            resi.append(resi_i)
            resq.append(resq_i)
        self.assertListEqual(resi, list(np.real(self.expected_mult)))
        self.assertListEqual(resq, list(np.imag(self.expected_mult)))

    def test_next_list(self):
        resi = []
        resq = []
        resi_i, resi_q = self.dut_mult.next(np.real(self.a[:2]), np.imag(self.a[:2]), np.real(self.b[:2]), np.imag(self.b[:2]))
        resi.extend(resi_i)
        resq.extend(resi_q)
        resi_i, resi_q = self.dut_mult.next(np.real(self.a[2:]), np.imag(self.a[2:]), np.real(self.b[2:]), np.imag(self.b[2:]))
        resi.extend(resi_i)
        resq.extend(resi_q)
        self.assertListEqual(resi, list(np.real(self.expected_mult)))
        self.assertListEqual(resq, list(np.imag(self.expected_mult)))

    def test_illegal_operation(self):
        with self.assertRaises(ValueError):
            olo_fix_cplx_mult(a_fmt=FixFormat(1, 8, 8), b_fmt=FixFormat(1,2,2), result_fmt=FixFormat(1, 10, 10), Mode_g="INVALID") 

if __name__ == '__main__':
    unittest.main()
