# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

import unittest
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_mix_r2c
from en_cl_fix_pkg import *

class TestOloFixMixR2c(unittest.TestCase):

    def setUp(self):
        self.dut = olo_fix_mix_r2c(
            in_fmt=FixFormat(1, 8, 8),
            mix_fmt=FixFormat(1, 2, 2),
            out_fmt=FixFormat(1, 10, 10)
        )
        self.sig = np.array([2.0, -3.0, 0.0, 1.5])
        self.mix_i = np.array([1.0, -1.0, 0.5, 0.0])
        self.mix_q = np.array([0.5, 0.25, -0.25, 1.0])

    def test_scalar(self):
        out_i, out_q = self.dut.process(self.sig[0], self.mix_i[0], self.mix_q[0])
        self.assertAlmostEqual(float(out_i), self.sig[0] * self.mix_i[0], places=3)
        self.assertAlmostEqual(float(out_q), -self.sig[0] * self.mix_q[0], places=3)

    def test_array(self):
        out_i, out_q = self.dut.process(self.sig, self.mix_i, self.mix_q)
        for i in range(len(self.sig)):
            self.assertAlmostEqual(float(out_i[i]), self.sig[i] * self.mix_i[i], places=3)
            self.assertAlmostEqual(float(out_q[i]), -self.sig[i] * self.mix_q[i], places=3)

    def test_split_array(self):
        self.dut.reset()
        out_i_1, out_q_1 = self.dut.next(self.sig[:2], self.mix_i[:2], self.mix_q[:2])
        out_i_2, out_q_2 = self.dut.next(self.sig[2:], self.mix_i[2:], self.mix_q[2:])
        out_i = np.concatenate([out_i_1, out_i_2])
        out_q = np.concatenate([out_q_1, out_q_2])
        for i in range(len(self.sig)):
            self.assertAlmostEqual(float(out_i[i]), self.sig[i] * self.mix_i[i], places=3)
            self.assertAlmostEqual(float(out_q[i]), -self.sig[i] * self.mix_q[i], places=3)

    def test_quantization(self):
        self.dut = olo_fix_mix_r2c(
            in_fmt=FixFormat(1, 2, 2),
            mix_fmt=FixFormat(1, 2, 2),
            out_fmt=FixFormat(1, 10, 10)
        )
        sig = 0.283333
        mix_i = 0.283333
        mix_q = 0.283333
        expected_i = 0.25 * 0.25
        expected_q = -0.25 * 0.25
        out_i, out_q = self.dut.process(sig, mix_i, mix_q)
        self.assertAlmostEqual(float(out_i), expected_i, places=3)
        self.assertAlmostEqual(float(out_q), expected_q, places=3)

if __name__ == '__main__':
    unittest.main()
