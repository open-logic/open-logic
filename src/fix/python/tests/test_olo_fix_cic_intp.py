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
from olo_fix import olo_fix_cic_intp
from en_cl_fix_pkg import *
from scipy import signal


class TestOloFixCicIntp(unittest.TestCase):

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
        self.dut = olo_fix_cic_intp(**self.config)

        # Step: Two zero samples followed by a constant value
        self.zeros_before_step = 2
        self.input_step = np.concatenate((np.zeros(self.zeros_before_step), np.ones(30) * 0.5))
        # Random signal (exercises state handling)
        np.random.seed(3)
        self.input_rand = np.random.uniform(-0.9, 0.9, 30)

    @staticmethod
    def float_cic(inp, order, ratio, diff_delay):
        """
        Floating point reference: Zero stuffing followed by CIC impulse response (normalized to gain 1.0)
        """
        h = np.ones(ratio*diff_delay)
        for _ in range(order-1):
            h = np.convolve(h, np.ones(ratio*diff_delay))
        h = h / np.sum(h) * ratio
        return signal.upfirdn(h, inp, up=ratio)[:len(inp)*ratio]

    def check_step(self, result, ratio, final, atol):
        """
        Check a step response: The CIC impulse response is non-negative, hence the step response must be exactly
        zero before the step, monotonic, free of overshoot and settle at the final value.
        """
        lsb = 2.0**-self.config['out_fmt'].F
        before = self.zeros_before_step * ratio
        self.assertEqual(len(result), len(self.input_step) * ratio)
        np.testing.assert_array_equal(result[:before], np.zeros(before))
        step = result[before:] * np.sign(final)
        self.assertTrue(np.all(np.diff(step) >= 0), "step response not monotonic")
        self.assertLessEqual(np.max(step), abs(final) + lsb, "step response overshoots")
        self.assertNotEqual(result[before], 0.0, "step does not start immediately")
        np.testing.assert_allclose(result[-3:], [final]*3, atol=atol)

    # Test different process modes
    def test_step(self):
        for order, ratio, diff_delay in [(3, 5, 1), (4, 4, 2), (2, 7, 3)]:
            config = self.config | {'order': order, 'ratio': ratio, 'diff_delay': diff_delay}
            dut = olo_fix_cic_intp(**config)
            # Positive and negative step
            self.check_step(dut.process(self.input_step), ratio, 0.5, 1e-3)
            self.check_step(dut.process(-self.input_step), ratio, -0.5, 1e-3)

    def test_sample_wise(self):
        expected = self.dut.process(self.input_rand)
        self.dut.clear_state()
        result = np.concatenate([self.dut.next(x) for x in self.input_rand])
        np.testing.assert_array_equal(result, expected)

    def test_partial_array(self):
        expected = self.dut.process(self.input_rand)
        result = []
        result.append(self.dut.process(self.input_rand[:16]))
        result.append(self.dut.next(self.input_rand[16:]))
        result = np.concatenate(result)
        np.testing.assert_array_equal(result, expected)

    def test_vs_float(self):
        np.random.seed(0)
        inp = np.random.uniform(-0.9, 0.9, 200)
        for order, ratio, diff_delay in [(3, 5, 1), (4, 4, 2), (2, 7, 1)]:
            config = self.config | {'order': order, 'ratio': ratio, 'diff_delay': diff_delay}
            dut = olo_fix_cic_intp(**config)
            result = dut.process(inp)
            expected = self.float_cic(cl_fix_from_real(inp, config['in_fmt']), order, ratio, diff_delay)
            np.testing.assert_allclose(result, expected, atol=1e-4)

    # Special Cases
    def test_no_gain_comp(self):
        config = self.config.copy()
        config['gain_corr_coef_fmt'] = "NONE"
        dut = olo_fix_cic_intp(**config)

        result = dut.process(self.input_step)
        cic_gain = (self.config['ratio']*self.config['diff_delay'])**self.config['order']/self.config['ratio']
        cic_shift = np.ceil(np.log2(cic_gain))
        expected_result = 0.5 * cic_gain / (2**cic_shift)
        self.check_step(result, self.config['ratio'], expected_result, 1e-3)

    def test_unsigned(self):
        config = self.config | {'in_fmt': FixFormat(0, 0, 8), 'out_fmt': FixFormat(0, 0, 10)}
        dut = olo_fix_cic_intp(**config)
        inp = np.linspace(0, 0.99, 50)
        result = dut.process(inp)
        expected = self.float_cic(cl_fix_from_real(inp, config['in_fmt']), 3, 5, 1)
        np.testing.assert_allclose(result, expected, atol=2e-3)

    def test_wide(self):
        # Formats wider than 53 bits use the wide (arbitrary precision) representation (only integrators are wide)
        config = self.config | {'in_fmt': FixFormat(1, 0, 45), 'out_fmt': FixFormat(1, 0, 45),
                                'order': 4, 'ratio': 8, 'gain_corr_coef_fmt': "NONE"}
        dut = olo_fix_cic_intp(**config)
        self.assertTrue(cl_fix_is_wide(dut.accu_fmt))
        self.assertFalse(cl_fix_is_wide(dut.hold_fmt))
        result = dut.process(self.input_step)
        result = cl_fix_to_real(result, config['out_fmt'])
        np.testing.assert_allclose(result[-3:], [0.5, 0.5, 0.5], atol=1e-3)

    def test_classic_structure(self):
        # The model (running sum + sample and hold) must be bit-true to the classical structure
        # (order combs, zero insertion, order integrators), calculated here in plain integers
        np.random.seed(2)
        for order, ratio, diff_delay in [(3, 5, 1), (4, 4, 2), (2, 7, 3), (5, 3, 1)]:
            in_fmt = FixFormat(1, 0, 10)
            add_bits = int(np.ceil(np.log2(ratio**(order-1) * diff_delay**order)))
            config = {'order': order, 'ratio': ratio, 'diff_delay': diff_delay, 'in_fmt': in_fmt,
                      'out_fmt': FixFormat(1, 0, 10+add_bits), 'gain_corr_coef_fmt': "NONE",
                      'round': FixRound.Trunc_s, 'saturate': FixSaturate.None_s}
            dut = olo_fix_cic_intp(**config)
            inp = cl_fix_from_real(np.random.uniform(-1, 1, 100), in_fmt)
            # Classical structure
            sig = [int(x) for x in cl_fix_to_integer(inp, in_fmt)]
            for _ in range(order):
                sig = [sig[i] - (sig[i-diff_delay] if i >= diff_delay else 0) for i in range(len(sig))]
            stuffed = []
            for x in sig:
                stuffed += [x] + [0]*(ratio-1)
            for _ in range(order):
                stuffed = list(np.cumsum(np.array(stuffed, dtype=object)))
            expected = np.array([x / 2**(10+add_bits) for x in stuffed])
            np.testing.assert_array_equal(dut.process(inp), expected)

    def test_wide_hold_not_supported(self):
        config = self.config | {'in_fmt': FixFormat(1, 0, 60), 'gain_corr_coef_fmt': "NONE"}
        with self.assertRaises(ValueError):
            olo_fix_cic_intp(**config)

    def test_ratio_1(self):
        # Ratio 1 with diff_delay 1 is a pass-through (gain 1, no growth)
        config = self.config | {'ratio': 1, 'gain_corr_coef_fmt': "NONE", 'out_fmt': FixFormat(1, 1, 14)}
        dut = olo_fix_cic_intp(**config)
        self.assertEqual(dut.cic_add_bits, 0)
        np.random.seed(1)
        inp = cl_fix_from_real(np.random.uniform(-1, 1, 50), config['in_fmt'])
        np.testing.assert_array_equal(dut.process(inp), inp)

    # Errors
    def test_illegal_params(self):
        for key, val in [('order', 1), ('order', 33), ('ratio', 0), ('diff_delay', 0)]:
            config = self.config | {key: val}
            with self.assertRaises(ValueError):
                olo_fix_cic_intp(**config)

    def test_illegal_gain_comp_fmt(self):
        for fmt in [FixFormat(0, 2, 16), FixFormat(1, 1, 16), "INVALID_STRING"]:
            config = self.config | {'gain_corr_coef_fmt': fmt}
            with self.assertRaises(ValueError):
                olo_fix_cic_intp(**config)


if __name__ == '__main__':
    unittest.main()
