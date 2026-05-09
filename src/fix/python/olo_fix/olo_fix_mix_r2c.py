# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
from .olo_fix_cplx_mult import olo_fix_cplx_mult

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_mix_r2c:
    """
    Model of olo_fix_mix_r2c entity.

    Implements real-to-complex downconversion mixing:
      Out_I = +SigReal x MixI
      Out_Q = -SigReal x MixQ
    """

    def __init__(self,
                 in_fmt : FixFormat,
                 mix_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        self._in_fmt = in_fmt
        self._cplx_mult = olo_fix_cplx_mult(in_fmt, mix_fmt, out_fmt, round, saturate, mode="MIX")

    def reset(self):
        pass  # no state

    def next(self, sig_real, mix_i, mix_q):
        """
        Process next N samples.
        :param sig_real: Real input signal
        :param mix_i: Mixer in-phase component
        :param mix_q: Mixer quadrature component
        :return: (out_i, out_q) tuple
        """
        return self._cplx_mult.next(sig_real, sig_real * 0, mix_i, mix_q)

    def process(self, sig_real, mix_i, mix_q):
        """
        Process samples (without preserving previous state).
        :param sig_real: Real input signal
        :param mix_i: Mixer in-phase component
        :param mix_q: Mixer quadrature component
        :return: (out_i, out_q) tuple
        """
        self.reset()
        return self.next(sig_real, mix_i, mix_q)
