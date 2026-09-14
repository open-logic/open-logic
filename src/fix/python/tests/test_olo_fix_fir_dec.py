# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import unittest
import sys
import os
import numpy as np
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_fir_dec
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------
IN_FMT   = FixFormat(1, 0, 15)
OUT_FMT  = FixFormat(1, 0, 15)
COEF_FMT = FixFormat(1, 0, 17)

# All numerical comparisons allow 1% deviation
RTOL = 0.01


# ---------------------------------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------------------------------
class TestOloFixFirDec(unittest.TestCase):

    def setUp(self):
        # Default filter: 15 taps, coefficients linspace from 0 to (taps-1)/taps
        self.n_taps = 15
        self.ratio  = 3
        self.coefs  = np.linspace(0, (self.n_taps - 1) / self.n_taps, self.n_taps)
        self.dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, self.ratio, self.coefs)

        # Full-scale dirac pulse (length = number of taps)
        dirac    = np.zeros(self.n_taps*2)
        dirac[0] = cl_fix_max_value(IN_FMT)
        self.dirac = cl_fix_from_real(dirac, IN_FMT)

        # For a dirac at full scale the (decimated) impulse response equals the decimated
        # coefficients scaled by the input amplitude.
        self.expected = np.zeros(self.n_taps*2//self.ratio)
        response = self.coefs[0::self.ratio] * cl_fix_max_value(IN_FMT)
        self.expected[0:len(response)] = response

        # Test Ratio 1
        self.expected_r1 = np.zeros(self.n_taps*2)
        response = self.coefs * cl_fix_max_value(IN_FMT)
        self.expected_r1[0:len(response)] = response      

    # -----------------------------------------------------------------------------------------------
    # Basic functionality
    # -----------------------------------------------------------------------------------------------
    def test_dirac_basic(self):
        out = self.dut.process(self.dirac)
        np.testing.assert_allclose(out, self.expected, atol=2 ** -OUT_FMT.F)

    def test_ratio1(self):
        dut = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, ratio=1, coefs=self.coefs)
        out = dut.process(self.dirac)
        np.testing.assert_allclose(out, self.expected_r1, atol=2 ** -OUT_FMT.F)

    def test_reset_state(self):
        out = self.dut.process([0.5, 0.5, 0.5])  # Fill delay line with non-zero values
        self.dut.reset() #reset
        out = self.dut.process(self.dirac)
        np.testing.assert_allclose(out, self.expected, atol=2 ** -OUT_FMT.F)

    def test_dirac_sample_wise(self):
        out = np.concatenate([self.dut.next(np.array([x])) for x in self.dirac])
        np.testing.assert_allclose(out, self.expected, atol=2 ** -OUT_FMT.F)

    def test_dirac_two_calls(self):
        split = 7
        out = np.concatenate([self.dut.next(self.dirac[:split]),
                              self.dut.next(self.dirac[split:])])
        np.testing.assert_allclose(out, self.expected, atol=2 ** -OUT_FMT.F)

    # -----------------------------------------------------------------------------------------------
    # Guard bits / accumulator overflow
    # -----------------------------------------------------------------------------------------------
    def test_accu_overflow(self):        
        self.n_taps = 15
        self.ratio  = 1
        self.coefs  = np.full(self.n_taps, 0.5) 
        self.dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, self.ratio, self.coefs, saturate=FixSaturate.Sat_s)

        inp = cl_fix_from_real(np.full(14, 0.5), IN_FMT)
        out = self.dut.process(inp)
        maxv = cl_fix_max_value(IN_FMT)
        minv = cl_fix_min_value(IN_FMT)
        # Up to 2.0 it is limited, at 2.0 it wraps around but is limited negatively
        #Unwrapped value 0.25, 0.5, 0.75, 1.0,  1.25, 1.5,  1.75, 2.0,  2.25, 2.5,  2.75, 3.0, 3.25, 3.5
        out_exp =       [0.25, 0.5, 0.75, maxv, maxv, maxv, maxv, minv, minv, minv, minv, minv, -0.75, -0.5]
        np.testing.assert_allclose(out, out_exp, atol=2 ** -OUT_FMT.F)


    def test_guard_bits_prevent_overflow(self):
        self.n_taps = 15
        self.ratio  = 1
        self.coefs  = np.full(self.n_taps, 0.5) 
        self.dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, self.ratio, self.coefs, guard_bits=5, saturate=FixSaturate.Sat_s)

        inp = cl_fix_from_real(np.full(14, 0.5), IN_FMT)
        out = self.dut.process(inp)
        maxv = cl_fix_max_value(IN_FMT)
        minv = cl_fix_min_value(IN_FMT)
        # Up to 2.0 it is limited, at 2.0 it wraps around but is limited negatively
        #Unwrapped value 0.25, 0.5, 0.75, 1.0,  1.25, 1.5,  1.75, 2.0,  2.25, 2.5,  2.75, 3.0, 3.25, 3.5
        out_exp =       [0.25, 0.5, 0.75, maxv, maxv, maxv, maxv, maxv, maxv, maxv, maxv, maxv, maxv, maxv]
        np.testing.assert_allclose(out, out_exp, atol=2 ** -OUT_FMT.F)

    # -----------------------------------------------------------------------------------------------
    # Parameter assertions
    # -----------------------------------------------------------------------------------------------
    def test_assert_ratio_positive(self):
        with self.assertRaises(AssertionError):
            olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, 0, self.coefs)

    def test_assert_guard_bits_nonnegative(self):
        with self.assertRaises(AssertionError):
            olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, self.ratio, self.coefs, guard_bits=-1)


if __name__ == "__main__":
    unittest.main()
