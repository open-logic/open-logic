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
from olo_fix import olo_fix_lin_approx, olo_fix_lin_approx_cfg
from en_cl_fix_pkg import *
import numpy as np

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixLinApprox(unittest.TestCase):

    # -----------------------------------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------------------------------
    @staticmethod
    def _cfg_unsigned(**kwargs):
        # sqrt() over the full unsigned input range - unsigned input, unsigned output
        args = dict(function=lambda x: np.sqrt(x),
                    in_fmt=FixFormat(0, 0, 12),
                    out_fmt=FixFormat(0, 0, 12),
                    offs_fmt=FixFormat(0, 0, 14),
                    grad_fmt=FixFormat(0, 4, 10),
                    points=64,
                    name="sqrt_test",
                    valid_range=(0.25, 1.0))
        args.update(kwargs)
        return olo_fix_lin_approx_cfg(**args)

    @staticmethod
    def _cfg_signed(**kwargs):
        # tanh() over the full signed input range - signed input, signed output
        args = dict(function=lambda x: np.tanh(3*x),
                    in_fmt=FixFormat(1, 0, 12),
                    out_fmt=FixFormat(1, 0, 12),
                    offs_fmt=FixFormat(1, 0, 14),
                    grad_fmt=FixFormat(0, 2, 10),
                    points=64,
                    name="tanh_test")
        args.update(kwargs)
        return olo_fix_lin_approx_cfg(**args)

    # -----------------------------------------------------------------------------------------------
    # Configuration Container
    # -----------------------------------------------------------------------------------------------
    def test_cfg_default_valid_range(self):
        # Without valid_range, the full range of in_fmt is used
        cfg = self._cfg_signed(valid_range=None)
        self.assertEqual(cfg.valid_range[0], cl_fix_min_value(cfg.in_fmt))
        self.assertEqual(cfg.valid_range[1], cl_fix_max_value(cfg.in_fmt))

    def test_cfg_valid_range_clipped(self):
        # valid_range is clipped to the range representable by in_fmt
        cfg = self._cfg_signed(valid_range=(-10.0, 10.0))
        self.assertEqual(cfg.valid_range[0], cl_fix_min_value(cfg.in_fmt))
        self.assertEqual(cfg.valid_range[1], cl_fix_max_value(cfg.in_fmt))

    def test_cfg_invalid_name(self):
        with self.assertRaises(ValueError):
            self._cfg_signed(name="1invalid")  # Starts with a digit
        with self.assertRaises(ValueError):
            self._cfg_signed(name="invalid-name")  # Contains a hyphen
        with self.assertRaises(ValueError):
            self._cfg_signed(name="_invalid")  # Starts with an underscore

    def test_cfg_invalid_points(self):
        with self.assertRaises(ValueError):
            self._cfg_signed(points=48)  # Not a power of two
        with self.assertRaises(ValueError):
            self._cfg_signed(points=1)  # Too small

    def test_cfg_too_many_points(self):
        # points must be smaller than 2**width(in_fmt)
        with self.assertRaises(ValueError):
            olo_fix_lin_approx_cfg(function=lambda x: x,
                                   in_fmt=FixFormat(0, 0, 4),
                                   out_fmt=FixFormat(0, 0, 4),
                                   offs_fmt=FixFormat(0, 0, 6),
                                   grad_fmt=FixFormat(0, 2, 6),
                                   points=16,
                                   name="too_many")

    def test_cfg_valid_range_outside_format(self):
        with self.assertRaises(ValueError):
            self._cfg_unsigned(valid_range=(2.0, 3.0))

    # -----------------------------------------------------------------------------------------------
    # Formats
    # -----------------------------------------------------------------------------------------------
    def test_formats_unsigned(self):
        dut = olo_fix_lin_approx(self._cfg_unsigned())
        # 12 input bits, 6 index bits -> 6 remainder bits
        self.assertEqual(cl_fix_width(dut._idx_fmt), 6)
        self.assertEqual(cl_fix_width(dut._rem_fmt), 6)
        self.assertEqual(cl_fix_width(dut._rem_fmt_signed), 6)
        self.assertEqual(dut._rem_fmt.F, 12)
        self.assertEqual(dut._rem_fmt_signed.S, 1)

    def test_formats_signed(self):
        dut = olo_fix_lin_approx(self._cfg_signed())
        # 13 input bits, 6 index bits -> 7 remainder bits
        self.assertEqual(cl_fix_width(dut._idx_fmt), 6)
        self.assertEqual(cl_fix_width(dut._rem_fmt), 7)
        self.assertEqual(cl_fix_width(dut._rem_fmt_signed), 7)

    def test_table_size(self):
        cfg = self._cfg_signed()
        dut = olo_fix_lin_approx(cfg)
        self.assertEqual(len(dut.offs_table), cfg.points)
        self.assertEqual(len(dut.grad_table), cfg.points)

    def test_centers_signed_are_rotated(self):
        # For signed inputs, negative values are stored in the upper half of the table
        cfg = self._cfg_signed()
        dut = olo_fix_lin_approx(cfg)
        self.assertTrue((dut.centers[:cfg.points//2] >= 0).all())
        self.assertTrue((dut.centers[cfg.points//2:] < 0).all())

    def test_centers_unsigned_are_ascending(self):
        cfg = self._cfg_unsigned()
        dut = olo_fix_lin_approx(cfg)
        self.assertTrue((np.diff(dut.centers) > 0).all())
        self.assertTrue((dut.centers >= 0).all())

    # -----------------------------------------------------------------------------------------------
    # Approximation
    # -----------------------------------------------------------------------------------------------
    def test_approximation_unsigned(self):
        cfg = self._cfg_unsigned()
        dut = olo_fix_lin_approx(cfg)
        in_data = dut.stimuli(200)
        result = dut.process(in_data)
        # The approximation must be accurate to a few LSB
        error = (result - cfg.function(in_data))*2**cfg.out_fmt.F
        self.assertLess(max(abs(error)), 4.0)

    def test_approximation_signed(self):
        cfg = self._cfg_signed()
        dut = olo_fix_lin_approx(cfg)
        in_data = dut.stimuli(200)
        result = dut.process(in_data)
        error = (result - cfg.function(in_data))*2**cfg.out_fmt.F
        self.assertLess(max(abs(error)), 4.0)

    def test_reset(self):
        # The approximation is stateless, hence reset() must not have any effect on the result
        dut = olo_fix_lin_approx(self._cfg_signed())
        in_data = dut.stimuli(20)
        before = dut.process(in_data)
        dut.reset()
        after = dut.process(in_data)
        self.assertTrue((before == after).all())

    def test_scalar_equals_vector(self):
        dut = olo_fix_lin_approx(self._cfg_signed())
        in_data = dut.stimuli(20)
        result_vec = dut.process(in_data)
        result_scalar = np.concatenate([dut.next(x) for x in in_data])
        self.assertTrue((result_vec == result_scalar).all())

    def test_output_is_quantized(self):
        cfg = self._cfg_signed()
        dut = olo_fix_lin_approx(cfg)
        result = dut.process(dut.stimuli(50))
        self.assertTrue((result == cl_fix_from_real(result, cfg.out_fmt)).all())

    def test_saturation(self):
        # Function exceeding the output range must be saturated
        cfg = self._cfg_unsigned(function=lambda x: 4.0*np.sqrt(x),
                                 offs_fmt=FixFormat(0, 2, 14),
                                 saturate=FixSaturate.Sat_s)
        dut = olo_fix_lin_approx(cfg)
        result = dut.process(dut.stimuli(50))
        self.assertEqual(max(result), cl_fix_max_value(cfg.out_fmt))

    def test_stimuli_range(self):
        dut = olo_fix_lin_approx(self._cfg_unsigned())
        # Default range is the valid range of the configuration
        in_data = dut.stimuli(100)
        self.assertGreaterEqual(min(in_data), 0.25)
        # Explicit range
        in_data = dut.stimuli(100, sim_range=(0.5, 0.75))
        self.assertGreaterEqual(min(in_data), 0.5)
        self.assertLessEqual(max(in_data), 0.75)
        self.assertEqual(len(in_data), 100)

    # -----------------------------------------------------------------------------------------------
    # Private Helpers
    # -----------------------------------------------------------------------------------------------
    def test_derivative(self):
        # Derivative of x**2 is 2*x
        result = olo_fix_lin_approx._derivative(lambda x: x**2, np.array([1.0, 2.0, 3.0]))
        for r, e in zip(result, [2.0, 4.0, 6.0]):
            self.assertAlmostEqual(r, e, delta=1e-6)

    def test_table_index(self):
        cfg = self._cfg_unsigned()
        dut = olo_fix_lin_approx(cfg)
        # The first segment is index 0, the last one is index points-1
        index = dut._table_index(cl_fix_from_real(np.array([0.0, 1.0 - 2**-12]), cfg.in_fmt))
        self.assertEqual(index[0], 0)
        self.assertEqual(index[1], cfg.points - 1)

    def test_table_index_signed(self):
        cfg = self._cfg_signed()
        dut = olo_fix_lin_approx(cfg)
        # Negative values are stored in the upper half of the table
        index = dut._table_index(cl_fix_from_real(np.array([0.0, -1.0]), cfg.in_fmt))
        self.assertEqual(index[0], 0)
        self.assertEqual(index[1], cfg.points//2)

if __name__ == '__main__':
    unittest.main()
