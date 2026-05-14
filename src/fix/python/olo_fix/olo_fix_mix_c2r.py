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
class olo_fix_mix_c2r:
    """
    Model of olo_fix_mix_c2r entity.

    Implements complex-to-real downconversion mixing (conjugate convention):
      Out_SigReal = +SigI x MixI + SigQ x MixQ
    """

    def __init__(self,
                 in_fmt : FixFormat,
                 mix_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Constructor.
        :param in_fmt: Format of input signal (SigI, SigQ)
        :param mix_fmt: Format of mixer signal (MixI, MixQ)
        :param out_fmt: Format of output signal (Out_SigReal)
        :param round: Rounding mode for output (default: truncate)
        :param saturate: Saturation mode for output (default: warn)
        """
        self._cplx_mult = olo_fix_cplx_mult(in_fmt, mix_fmt, out_fmt, round, saturate, mode="MIX")

    def reset(self):
        pass  # no state

    def next(self, sig_i, sig_q, mix_i, mix_q):
        """
        Process next N samples.
        :param sig_i: Signal I-part
        :param sig_q: Signal Q-part
        :param mix_i: Mixer in-phase component
        :param mix_q: Mixer quadrature component
        :return: real output sample(s)
        """
        out_i, _ = self._cplx_mult.next(sig_i, sig_q, mix_i, mix_q)
        return out_i

    def process(self, sig_i, sig_q, mix_i, mix_q):
        """
        Process samples (without preserving previous state).
        :param sig_i: Signal I-part
        :param sig_q: Signal Q-part
        :param mix_i: Mixer in-phase component
        :param mix_q: Mixer quadrature component
        :return: real output sample(s)
        """
        self.reset()
        return self.next(sig_i, sig_q, mix_i, mix_q)
