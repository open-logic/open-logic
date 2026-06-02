# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

import unittest
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_mix_c2r
from en_cl_fix_pkg import *

class TestOloFixMixC2r(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_mix_c2r(
            in_fmt=FixFormat(1, 8, 8),
            mix_fmt=FixFormat(1, 2, 2),
            out_fmt=FixFormat(1, 10, 10)
        )
        self.sig_i = np.array([2.0, -3.0, 0.0, 1.5])
        self.sig_q = np.array([1.0,  0.5, 2.0, -1.0])
        self.mix_i = np.array([1.0, -1.0, 0.5,  0.0])
        self.mix_q = np.array([0.5,  0.25, -0.25, 1.0])

    def test_scalar(self):
        out = self.dut.process(self.sig_i[0], self.sig_q[0], self.mix_i[0], self.mix_q[0])
        expected = self.sig_i[0] * self.mix_i[0] + self.sig_q[0] * self.mix_q[0]
        self.assertAlmostEqual(float(out), expected, places=3)

    def test_array(self):
        out = self.dut.process(self.sig_i, self.sig_q, self.mix_i, self.mix_q)
        for i in range(len(self.sig_i)):
            expected = self.sig_i[i] * self.mix_i[i] + self.sig_q[i] * self.mix_q[i]
            self.assertAlmostEqual(float(out[i]), expected, places=3)

    def test_split_array(self):
        self.dut.reset()
        out_1 = self.dut.next(self.sig_i[:2], self.sig_q[:2], self.mix_i[:2], self.mix_q[:2])
        out_2 = self.dut.next(self.sig_i[2:], self.sig_q[2:], self.mix_i[2:], self.mix_q[2:])
        out = np.concatenate([out_1, out_2])
        for i in range(len(self.sig_i)):
            expected = self.sig_i[i] * self.mix_i[i] + self.sig_q[i] * self.mix_q[i]
            self.assertAlmostEqual(float(out[i]), expected, places=3)

    def test_quantization(self):
        self.dut = olo_fix_mix_c2r(
            in_fmt=FixFormat(1, 2, 2),
            mix_fmt=FixFormat(1, 2, 2),
            out_fmt=FixFormat(1, 10, 10)
        )
        sig_i = 0.283333
        sig_q = 0.283333
        mix_i = 0.283333
        mix_q = 0.283333
        expected = (0.25 * 0.25) + (0.25 * 0.25)
        out = self.dut.process(sig_i, sig_q, mix_i, mix_q)
        self.assertAlmostEqual(float(out), expected, places=3)

if __name__ == '__main__':
    unittest.main()
