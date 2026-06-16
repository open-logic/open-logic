# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from scipy.signal import lfilter

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_fir_dec:
    """
    Bit-true model of a fixed-point decimating FIR filter.

    The model is channel-independent. For multi-channel use, create one instance per channel.
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt      : FixFormat,
                 out_fmt     : FixFormat,
                 coef_fmt    : FixFormat,
                 ratio       : int,
                 coefs       : np.ndarray,
                 guard_bits  : int         = 1,
                 round       : FixRound    = FixRound.Trunc_s,
                 saturate    : FixSaturate = FixSaturate.Warn_s):
        """
        Create a decimating FIR filter model.

        :param in_fmt:   Input fixed-point format
        :param out_fmt:  Output fixed-point format
        :param coef_fmt: Coefficient fixed-point format
        :param ratio:    Decimation ratio (one output per 'ratio' inputs)
        :param coefs:    Filter coefficients (real-valued, will be quantized to coef_fmt)
        :param round:    Rounding mode at the output
        :param saturate: Saturation mode at the output
        """
        # Check parameters
        assert ratio > 0, "Ratio must be positive"
        assert guard_bits >= 0, "Guard bits must be non-negative"

        # Store parameters
        self._in_fmt   = in_fmt
        self._out_fmt  = out_fmt
        self._coef_fmt = coef_fmt
        self._ratio    = ratio
        self._round    = round
        self._saturate = saturate
        self._guard_bits = guard_bits

        # Quantize coefficients
        self._coefs = cl_fix_from_real(np.array(coefs, dtype=float), coef_fmt)
        self._n_taps = len(self._coefs)

        # Derived formats (match VHDL AccuFmt_c)
        self._mult_fmt = cl_fix_mult_fmt(in_fmt, coef_fmt)
        self._accu_fmt = FixFormat(1, self._out_fmt.I + guard_bits, self._mult_fmt.F)

        self.reset()

    # ---------------------------------------------------------------------------------------------------
    # Public Methods
    # ---------------------------------------------------------------------------------------------------
    def reset(self):
        """Reset the delay line to zeros (matches VHDL startup behavior)."""
        self._delay_line = np.zeros(self._n_taps-1)
        self._dec_phase  = 0

    def process(self, inp : np.ndarray) -> np.ndarray:
        """
        Process data after resetting state.

        :return:      Output samples
        """
        self.reset()
        return self.next(inp)

    def next(self, inp : np.ndarray) -> np.ndarray:
        """
        Process data continuing from current state.

        :param inp:   Input samples
        :return:      Output samples
        """
        # Quantize input
        sig = cl_fix_from_real(np.array(inp, dtype=float), self._in_fmt)

        # Filter
        filtered, self._delay_line = lfilter(self._coefs, [1.0], sig, zi=self._delay_line)

        # Decimate
        first_sample = (self._ratio - self._dec_phase) % self._ratio
        decimated = filtered[first_sample::self._ratio]
        self._dec_phase = (self._dec_phase + len(sig)) % self._ratio

        # Resize output
        guard = cl_fix_resize(decimated, self._accu_fmt, self._accu_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        result = cl_fix_resize(guard, self._accu_fmt, self._out_fmt, self._round, self._saturate)

        return result
