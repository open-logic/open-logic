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
from typing import Union


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
                 coefs       : np.ndarray,
                 round       : FixRound    = FixRound.NonSymPos_s,
                 saturate    : FixSaturate = FixSaturate.Warn_s):
        """
        Create a decimating FIR filter model.

        :param in_fmt:   Input fixed-point format
        :param out_fmt:  Output fixed-point format
        :param coef_fmt: Coefficient fixed-point format
        :param coefs:    Filter coefficients (real-valued, will be quantized to coef_fmt)
        :param round:    Rounding mode at the output
        :param saturate: Saturation mode at the output
        """
        self._in_fmt   = in_fmt
        self._out_fmt  = out_fmt
        self._coef_fmt = coef_fmt
        self._round    = round
        self._saturate = saturate

        # Quantize coefficients
        self._coefs = cl_fix_from_real(np.array(coefs, dtype=float), coef_fmt)
        self._n_taps = len(self._coefs)

        # Derived formats (match VHDL AccuFmt_c)
        self._mult_fmt = cl_fix_mult_fmt(in_fmt, coef_fmt)
        self._accu_fmt = FixFormat(1, out_fmt.I + 1, in_fmt.F + coef_fmt.F)

        self.clear_state()

    # ---------------------------------------------------------------------------------------------------
    # Public Methods
    # ---------------------------------------------------------------------------------------------------
    def clear_state(self):
        """Reset the delay line to zeros (matches VHDL startup behavior)."""
        self._delay_line = np.zeros(self._n_taps)
        self._dec_phase  = 0

    def process(self, inp : np.ndarray, ratio : int, taps : int = None) -> np.ndarray:
        """
        Process data after resetting state.

        :param inp:   Input samples
        :param ratio: Decimation ratio (one output per 'ratio' inputs)
        :param taps:  Active tap count (defaults to full coefficient length)
        :return:      Output samples
        """
        self.clear_state()
        return self.next(inp, ratio, taps)

    def next(self, inp : np.ndarray, ratio : int, taps : int = None) -> np.ndarray:
        """
        Process data continuing from current state.

        :param inp:   Input samples
        :param ratio: Decimation ratio (one output per 'ratio' inputs)
        :param taps:  Active tap count (defaults to full coefficient length)
        :return:      Output samples
        """
        if taps is None:
            taps = self._n_taps
        if taps > self._n_taps:
            raise ValueError(f"olo_fix_fir_dec: taps ({taps}) must be <= len(coefs) ({self._n_taps})")

        # Quantize input
        sig = cl_fix_from_real(np.array(inp, dtype=float), self._in_fmt)

        outputs = []
        for sample in sig:
            # Shift delay line: new sample goes at index 0
            self._delay_line = np.roll(self._delay_line, 1)
            self._delay_line[0] = sample

            if self._dec_phase == 0:
                # Compute FIR output: accumulate tap products at full precision
                accu = np.zeros(1)
                for i in range(taps):
                    prod = cl_fix_mult(
                        self._delay_line[i], self._in_fmt,
                        self._coefs[i],      self._coef_fmt,
                        self._mult_fmt,      FixRound.Trunc_s, FixSaturate.None_s
                    )
                    accu = cl_fix_add(
                        prod,  self._mult_fmt,
                        accu,  self._accu_fmt,
                        self._accu_fmt, FixRound.Trunc_s, FixSaturate.None_s
                    )
                result = cl_fix_resize(accu, self._accu_fmt, self._out_fmt,
                                       self._round, self._saturate)
                outputs.append(result[0])
                self._dec_phase = ratio - 1
            else:
                self._dec_phase -= 1

        return np.array(outputs)
