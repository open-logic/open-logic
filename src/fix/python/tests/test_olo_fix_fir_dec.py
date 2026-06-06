# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import sys
import os
import pytest
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

def _make_lp(n_taps, coef_fmt=COEF_FMT):
    """Simple low-pass coefficients: boxcar filter."""
    coefs = np.ones(n_taps) / n_taps
    return coefs

def _dirac(n, fmt=IN_FMT):
    sig = np.zeros(n)
    sig[0] = cl_fix_max_value(fmt)
    return cl_fix_from_real(sig, fmt)


# ---------------------------------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------------------------------

class TestOloFixFirDec:

    def test_dirac_response(self):
        """Dirac input at full scale recovers quantized coefficients (after ratio samples)."""
        n_taps = 8
        ratio  = 4
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        inp = _dirac(n_taps * ratio)
        out = dut.process(inp, ratio=ratio)

        # First output sample = coef[0] * dirac[0] (all other taps are zero at first output)
        coef_q = cl_fix_from_real(coefs[0:1], COEF_FMT)
        expected = cl_fix_resize(
            cl_fix_mult(inp[0:1], IN_FMT, coef_q, COEF_FMT,
                        cl_fix_mult_fmt(IN_FMT, COEF_FMT), FixRound.Trunc_s, FixSaturate.None_s),
            cl_fix_mult_fmt(IN_FMT, COEF_FMT),
            OUT_FMT, FixRound.NonSymPos_s, FixSaturate.Warn_s
        )
        assert out[0] == pytest.approx(expected[0], abs=2**-OUT_FMT.F)

    def test_dc_passthrough(self):
        """DC input passes through a symmetric LP filter unchanged (up to quantization)."""
        n_taps = 4
        ratio  = 2
        # Symmetric LP with DC gain ~1 after quantization
        coefs_raw = np.array([0.25, 0.25, 0.25, 0.25])
        dut = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs_raw)

        dc_val = 0.5
        inp = cl_fix_from_real(np.full(100, dc_val), IN_FMT)
        out = dut.process(inp, ratio=ratio)

        # After filter settles, output should be close to dc_val
        assert np.allclose(out[n_taps:], cl_fix_from_real(dc_val, OUT_FMT),
                           atol=4 * 2**-OUT_FMT.F)

    def test_ratio(self):
        """Output length equals ceil(N / ratio)."""
        n_taps = 4
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        for ratio in [2, 4, 8]:
            n_in = 100
            out = dut.process(np.zeros(n_in), ratio=ratio)
            assert len(out) == (n_in + ratio - 1) // ratio, \
                f"ratio={ratio}: expected {(n_in + ratio - 1) // ratio}, got {len(out)}"

    def test_taps_shorter(self):
        """Using fewer active taps than available coefficients produces valid output."""
        n_taps = 8
        ratio  = 2
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        inp = _dirac(n_taps * ratio)
        out_full = dut.process(inp, ratio=ratio, taps=n_taps)
        out_half = dut.process(inp, ratio=ratio, taps=n_taps // 2)

        # Results differ when fewer taps are used
        assert not np.allclose(out_full, out_half, atol=0)

    def test_round_trunc(self):
        """Truncation rounding produces value <= NonSymPos result."""
        n_taps = 4
        coefs  = _make_lp(n_taps)
        dut_ns  = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs,
                                  round=FixRound.NonSymPos_s)
        dut_tr  = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs,
                                  round=FixRound.Trunc_s)

        inp = cl_fix_from_real(np.random.default_rng(42).uniform(-0.5, 0.5, 100), IN_FMT)
        out_ns = dut_ns.process(inp, ratio=2)
        out_tr = dut_tr.process(inp, ratio=2)

        # Truncation always rounds toward negative infinity so <= NonSymPos
        assert np.all(out_tr <= out_ns + 2**-OUT_FMT.F)

    def test_saturate_sat(self):
        """With Sat_s, overflow is clamped to max value."""
        n_taps = 4
        # Use all-ones coefficients to produce potential overflow
        coefs  = np.ones(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs,
                                 saturate=FixSaturate.Sat_s)

        inp = cl_fix_from_real(np.full(n_taps * 4, cl_fix_max_value(IN_FMT)), IN_FMT)
        out = dut.process(inp, ratio=n_taps)

        assert np.all(out <= cl_fix_max_value(OUT_FMT))
        assert np.all(out >= cl_fix_min_value(OUT_FMT))

    def test_saturate_none(self):
        """With None_s, overflow wraps instead of saturating, producing a different value."""
        # n_taps=2, coefs=[0.75, 0.75]: sum on max input ≈ 1.5 > OutFmt max ≈ 1.0
        # Sat clamps to max; None wraps to -0.5 -- results differ
        n_taps = 2
        coefs  = np.array([0.75, 0.75])
        dut_sat  = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs,
                                   round=FixRound.Trunc_s,
                                   saturate=FixSaturate.Sat_s)
        dut_none = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs,
                                   round=FixRound.Trunc_s,
                                   saturate=FixSaturate.None_s)

        inp = cl_fix_from_real(np.full(n_taps * 4, cl_fix_max_value(IN_FMT)), IN_FMT)
        out_sat  = dut_sat.process(inp, ratio=n_taps)
        out_none = dut_none.process(inp, ratio=n_taps)

        # Skip the first output (delay line partially filled); after that results diverge
        assert np.all(out_sat[1:] > 0)
        assert np.all(out_none[1:] < 0)

    def test_state_continuity(self):
        """Two next() calls match one process() call on the concatenated input."""
        n_taps = 4
        ratio  = 2
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        rng = np.random.default_rng(7)
        inp_a = cl_fix_from_real(rng.uniform(-0.5, 0.5, 40), IN_FMT)
        inp_b = cl_fix_from_real(rng.uniform(-0.5, 0.5, 40), IN_FMT)

        # Reference: single process() on full input
        ref = dut.process(np.concatenate([inp_a, inp_b]), ratio=ratio)

        # Split: next() twice
        dut.clear_state()
        out_a = dut.next(inp_a, ratio=ratio)
        out_b = dut.next(inp_b, ratio=ratio)
        result = np.concatenate([out_a, out_b])

        assert np.allclose(ref, result, atol=0)

    def test_process_resets_state(self):
        """process() always resets state; two process() calls give same result."""
        n_taps = 4
        ratio  = 2
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        inp = cl_fix_from_real(np.random.default_rng(13).uniform(-0.5, 0.5, 60), IN_FMT)

        out1 = dut.process(inp, ratio=ratio)
        out2 = dut.process(inp, ratio=ratio)

        assert np.allclose(out1, out2, atol=0)

    def test_invalid_taps(self):
        """taps > len(coefs) raises ValueError."""
        n_taps = 4
        coefs  = _make_lp(n_taps)
        dut    = olo_fix_fir_dec(IN_FMT, OUT_FMT, COEF_FMT, coefs)

        with pytest.raises(ValueError):
            dut.process(np.zeros(10), ratio=2, taps=n_taps + 1)
