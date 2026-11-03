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

    The In_Restart input of the entity is modeled by reset(): calling reset() before a sample sets
    the accumulator to zero, hence the output phase of that sample is the phase offset.
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 phase_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s):
        """
        Constructor of the olo_fix_dds class

        :param phase_fmt: Format of phase step, phase offset and accumulator. Must be (0, 0, N).
        :param out_fmt: Format of the sine/cosine output. Must be (1, 0, 10..20) or (1, 1, 10..20).
        :param round: Rounding mode of the output stage
        """
        if phase_fmt.S != 0 or phase_fmt.I != 0:
            raise ValueError(f"olo_fix_dds: phase_fmt {phase_fmt} must be of the form (0, 0, N)")

        self.phase_fmt = phase_fmt
        self.out_fmt = out_fmt

        # The phase is rounded to three fractional bits more than the output before the sine
        # calculation. Same rule as in the VHDL entity.
        self.sin_phase_fmt = FixFormat(0, 0, min(phase_fmt.F, out_fmt.F + 3))
        self._sin = olo_fix_sin(self.sin_phase_fmt, out_fmt, round, FixSaturate.None_s)
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

    def next(self, phase_step, phase_offset):
        """
        Process next N samples (continuing from the current accumulator state)

        :param phase_step: Phase step per sample in rotations
        :param phase_offset: Phase offset in rotations
        :return: Tuple (sine, cosine)
        """
        # Convert to arrays
        phase_step = np.atleast_1d(np.asarray(phase_step, dtype=float))
        phase_offset = np.atleast_1d(np.asarray(phase_offset, dtype=float))
        if not len(phase_step) == len(phase_offset):
            raise ValueError("olo_fix_dds: phase_step and phase_offset must have the same length")

        # Quantize inputs (wrapping, like the hardware does for any bit pattern)
        phase_step = cl_fix_resize(phase_step, self.phase_fmt, self.phase_fmt)
        phase_offset = cl_fix_resize(phase_offset, self.phase_fmt, self.phase_fmt)

        # Phase accumulation (vectorized, unsigned 64 bit integer arithmetic).
        # The accumulator before sample i is the stored accumulator plus all steps before sample i.
        # The sum of N+1 values below 2^F needs F + bit_length(N) bits. Ensure this fits into 64 bits.
        required_bits = self.phase_fmt.F + len(phase_step).bit_length()
        if required_bits > 64:
            raise ValueError(f"olo_fix_dds: {len(phase_step)} samples with phase format {self.phase_fmt} "
                             f"need {required_bits} bits for the accumulation (max. 64 for the bit-true model). "
                             f"Split the input into smaller chunks (next() keeps the state).")
        mask = np.uint64(2**self.phase_fmt.F - 1)
        step_int = np.asarray(cl_fix_to_integer(phase_step, self.phase_fmt), dtype=np.uint64)
        offset_int = np.asarray(cl_fix_to_integer(phase_offset, self.phase_fmt), dtype=np.uint64)
        accu_int = np.uint64(cl_fix_to_integer(self._accu, self.phase_fmt))
        accu_before = (accu_int + np.cumsum(step_int, dtype=np.uint64) - step_int) & mask
        phase = cl_fix_from_integer((accu_before + offset_int) & mask, self.phase_fmt)
        if len(step_int) > 0:
            self._accu = cl_fix_from_integer((accu_before[-1] + step_int[-1]) & mask, self.phase_fmt)

        # Phase rounding (wrapping from 1.0 to 0.0)
        sin_phase = cl_fix_resize(phase, self.phase_fmt, self.sin_phase_fmt,
                                  FixRound.NonSymPos_s, FixSaturate.None_s)

        # Sine / Cosine
        return self._sin.next(sin_phase)

    def process(self, phase_step, phase_offset):
        """
        Process samples (starting from reset state)

        :param phase_step: Phase step per sample in rotations
        :param phase_offset: Phase offset in rotations
        :return: Tuple (sine, cosine)
        """
        self.reset()
        return self.next(phase_step, phase_offset)
