# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

from .olo_fix_sin import olo_fix_sin

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_dds:

    """
    Model of olo_fix_dds entity.

    Direct digital synthesizer (DDS) with complex output (sine and cosine). Phase step and phase
    offset are given in rotations (0.0 = 0 degrees, 1.0 = 360 degrees).

    The model only implements one channel. For multi-channel (TDM) operation, multiple instances of
    the model must be created (one per channel).
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 phase_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_dds class

        :param phase_fmt: Format of phase step, phase offset and accumulator. Must be (0, 0, N).
        :param out_fmt: Format of the sine/cosine output. Must be (1, 0, 10..20) or (1, 1, 10..20).
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        if phase_fmt.S != 0 or phase_fmt.I != 0:
            raise ValueError(f"olo_fix_dds: phase_fmt {phase_fmt} must be of the form (0, 0, N)")

        self.phase_fmt = phase_fmt
        self.out_fmt = out_fmt

        # The phase is rounded to four fractional bits more than the output before the sine
        # calculation. Same rule as in the VHDL entity.
        self.sin_phase_fmt = FixFormat(0, 0, min(phase_fmt.F, out_fmt.F + 4))
        self._sin = olo_fix_sin(self.sin_phase_fmt, out_fmt, round, saturate)
        self.peak = self._sin.peak

        self.reset()

    # ---------------------------------------------------------------------------------------------------
    # Public Methods
    # ---------------------------------------------------------------------------------------------------
    def reset(self):
        """
        Reset state of the component (accumulator zero)
        """
        self._accu = 0.0

    def next(self, phase_step, phase_offset, restart = None):
        """
        Process next N samples (continuing from the current accumulator state)

        :param phase_step: Phase step per sample in rotations
        :param phase_offset: Phase offset in rotations
        :param restart: Restart flags (optional). Restart sets the accumulator to zero before the
                        sample is processed, hence the output is the phase offset.
        :return: Tuple (sine, cosine)
        """
        # Convert to arrays
        phase_step = np.atleast_1d(np.asarray(phase_step, dtype=float))
        phase_offset = np.atleast_1d(np.asarray(phase_offset, dtype=float))
        if restart is None:
            restart = np.zeros(len(phase_step), dtype=bool)
        restart = np.atleast_1d(np.asarray(restart, dtype=bool))
        if not len(phase_step) == len(phase_offset) == len(restart):
            raise ValueError("olo_fix_dds: phase_step, phase_offset and restart must have the same length")

        # Quantize inputs (wrapping, like the hardware does for any bit pattern)
        phase_step = cl_fix_resize(phase_step, self.phase_fmt, self.phase_fmt)
        phase_offset = cl_fix_resize(phase_offset, self.phase_fmt, self.phase_fmt)

        # Phase accumulation (sequential, one sample after the other)
        phase = np.zeros(len(phase_step))
        for i in range(len(phase_step)):
            accu = 0.0 if restart[i] else self._accu
            phase[i] = cl_fix_add(accu, self.phase_fmt, phase_offset[i], self.phase_fmt,
                                  self.phase_fmt, FixRound.Trunc_s, FixSaturate.None_s)
            self._accu = cl_fix_add(accu, self.phase_fmt, phase_step[i], self.phase_fmt,
                                    self.phase_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # Phase rounding (wrapping from 1.0 to 0.0)
        sin_phase = cl_fix_resize(phase, self.phase_fmt, self.sin_phase_fmt,
                                  FixRound.NonSymPos_s, FixSaturate.None_s)

        # Sine / Cosine
        return self._sin.next(sin_phase)

    def process(self, phase_step, phase_offset, restart = None):
        """
        Process samples (starting from reset state)

        :param phase_step: Phase step per sample in rotations
        :param phase_offset: Phase offset in rotations
        :param restart: Restart flags (optional)
        :return: Tuple (sine, cosine)
        """
        self.reset()
        return self.next(phase_step, phase_offset, restart)
