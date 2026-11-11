# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from math import *
from typing import Union
from .olo_fix_sample_hold import olo_fix_sample_hold


# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_cic_intp:
    """
    General model of a fixed point CIC interpolator. The model represents any bittrue implementation of a CIC
    interpolator, independently of its RTL implementation (multi-channel, TDM/parallel, etc.).

    The model only implements one channel. For multi-channel operation, multiple instances of the model must be created.

    The model implements the efficient structure of a CIC interpolator: The last comb stage, the zero-insertion and the
    first integrator are replaced by a running sum over diff_delay samples (at the input sample rate) followed by a
    sample and hold. This is mathematically identical to the classical structure (order combs, zero insertion and
    order integrators) but saves one comb and one integrator:

    (1 - z^-(R*M)) / (1 - z^-1) = [1 + z^-R + ... + z^-((M-1)*R)] * [1 + z^-1 + ... + z^-(R-1)]

    The first factor is the running sum over M input samples, the second factor the sample and hold.
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,  order : int,
                        ratio : int,
                        diff_delay : int,
                        in_fmt : FixFormat,
                        out_fmt : FixFormat,
                        gain_corr_coef_fmt : Union[FixFormat, str] = FixFormat(0, 1, 16),
                        round : FixRound  = FixRound.NonSymPos_s,
                        saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Creation of an interpolating CIC model

        The following generics that do not impact numeric behavior and are related to FPGA implementation only are
        omitted:
        - All implementation related generics
        - Channel Count (one model instance per channel must be created)

        :param order: CIC order
        :param ratio: CIC interpolation ratio
        :param diff_delay: Differential delay (usually 1 or 2)
        :param in_fmt: Input fixed-point format
        :param out_fmt: Output fixed-point format
        :param gain_corr_coef_fmt: Format of the gain correction coefficient (use "NONE" for no correction)
        :param round: Rounding mode at the output
        :param saturate: Saturation mode at the output
        """
        # Check arguments
        if order < 2:                             raise ValueError("olo_fix_cic_intp: order must be >= 2")
        if order > 32:                            raise ValueError("olo_fix_cic_intp: order must be <= 32")
        if ratio < 1:                             raise ValueError("olo_fix_cic_intp: ratio must be >= 1")
        if diff_delay < 1:                        raise ValueError("olo_fix_cic_intp: diff_delay must be >= 1")

        # Store Config
        self.in_fmt = in_fmt
        self.out_fmt = out_fmt
        self.order = order
        self.ratio = ratio
        self.diff_delay = diff_delay
        self.round = round
        self.saturate = saturate

        # Calculated constants
        # .. (ratio*diff_delay)**order/ratio is always an integer, hence integer arithmetic is used (exact)
        self.cic_gain = ratio**(order-1) * diff_delay**order
        self.cic_add_bits = (self.cic_gain-1).bit_length()
        self.shift = self.cic_add_bits

        # gain_corr_coef_fmt
        if isinstance(gain_corr_coef_fmt, str):
            # String
            if gain_corr_coef_fmt.upper() == "NONE":
                self._gain_comp_on = False
                self._gain_comp_coef = 0
                self._gain_comp_coef_fmt = FixFormat(0,0,0)
            else:
                raise ValueError("olo_fix_cic_intp: gain_corr_coef_fmt must be 'NONE' or a FixFormat")
        else:
            # Format
            if gain_corr_coef_fmt.I != 1:               raise ValueError("olo_fix_cic_intp: gain_corr_coef_fmt must have I=1")
            if gain_corr_coef_fmt.S != 0:               raise ValueError("olo_fix_cic_intp: gain_corr_coef_fmt must have S=0")
            self._gain_comp_on = True
            self._gain_comp_coef = cl_fix_from_real(2**self.cic_add_bits/self.cic_gain, gain_corr_coef_fmt)
            self._gain_comp_coef_fmt = gain_corr_coef_fmt

        # Formats
        # .. Gain correction is applied at the input. One additional integer bit is required because the
        #    gain correction factor is in the range 1.0 ... 2.0.
        if self._gain_comp_on:
            self.gc_out_fmt = FixFormat(in_fmt.S, in_fmt.I+1, min(out_fmt.F+2, in_fmt.F+self._gain_comp_coef_fmt.F))
            self.cic_in_fmt = self.gc_out_fmt
        else:
            self.cic_in_fmt = in_fmt
        # .. order-1 comb stages (gain 2 each) followed by a running sum over diff_delay samples
        self.diff_fmt = FixFormat(1, self.cic_in_fmt.I+order-1, self.cic_in_fmt.F)
        self.hold_fmt = FixFormat(1, self.diff_fmt.I+ceil(log2(diff_delay)), self.diff_fmt.F)
        self.accu_fmt = FixFormat(self.cic_in_fmt.S, self.cic_in_fmt.I+self.cic_add_bits, self.cic_in_fmt.F)
        self.sft_fmt = FixFormat(self.cic_in_fmt.S, self.cic_in_fmt.I, self.cic_in_fmt.F+self.shift)
        # .. Model limitation: olo_fix_sample_hold takes real values as input (convention for all models), this
        #    is not possible for wide formats without loss of precision.
        if cl_fix_is_wide(self.hold_fmt):
            raise ValueError("olo_fix_cic_intp: formats wider than 53 bits before the integrators are not supported")

        # state
        self.clear_state()

    # ---------------------------------------------------------------------------------------------------
    # Public Methods and Properties
    # ---------------------------------------------------------------------------------------------------
    def clear_state(self):
        """
        Reset the internal state of the CIC model
        """
        self._state_diff = [cl_fix_from_real(np.zeros(self.diff_delay), self.diff_fmt) for _ in range(self.order-1)]
        self._state_sum = np.zeros(self.diff_delay-1) # zero is exactly representable in any (narrow) format
        self._state_accu = [0 for _ in range(self.order-1)]
        self._sample_hold = olo_fix_sample_hold(self.hold_fmt)

    def process(self, inp : np.ndarray):
        """
        Process data using the CIC model object (state is cleared before processing)
        :param inp: Input data
        :return: Output data (ratio times more samples than input)
        """
        self.clear_state()
        return self.next(inp)

    def next(self, inp : np.ndarray):
        """
        Process data using the CIC model object (state is preserved from previous calls)
        :param inp: Input data
        :return: Output data (ratio times more samples than input)
        """
        # Make input fixed point
        sig = cl_fix_from_real(np.atleast_1d(inp), self.in_fmt)

        # Gain Compensation (at the input, the CIC as a whole is an FIR filter, so rounding errors do not accumulate)
        if self._gain_comp_on:
            sig = cl_fix_mult(sig, self.in_fmt,
                              self._gain_comp_coef, self._gain_comp_coef_fmt,
                              self.gc_out_fmt, self.round, self.saturate)

        # Do differentiation (order-1 stages)
        sig_diff = cl_fix_resize(sig, self.cic_in_fmt, self.diff_fmt)
        for stage in range(self.order-1):
            # Update delay line
            last = np.concatenate((self._state_diff[stage], sig_diff))
            # Delayed signal used for calculation
            last_sig = last[:-self.diff_delay]
            # Content of delay line after processing is stored
            self._state_diff[stage] = last[-self.diff_delay:]
            # Calculate output
            sig_diff = cl_fix_sub(sig_diff, self.diff_fmt,
                                  last_sig, self.diff_fmt, self.diff_fmt)

        # Running sum over diff_delay samples (replaces the last comb stage, nothing to do for diff_delay=1)
        sig_sum = cl_fix_resize(sig_diff, self.diff_fmt, self.hold_fmt)
        if self.diff_delay > 1:
            last = np.concatenate((self._state_sum, sig_diff))
            self._state_sum = last[-(self.diff_delay-1):]
            for tap in range(1, self.diff_delay):
                sig_sum = cl_fix_add(sig_sum, self.hold_fmt,
                                     last[self.diff_delay-1-tap:len(last)-tap], self.diff_fmt, self.hold_fmt)

        # Sample and hold (each sample is held for ratio output samples)
        sig_hold = self._sample_hold.next_each(input=sig_sum, out_samples=self.ratio)

        # Do integration (order-1 stages)
        # .. Integration is done in integer (modulo accumulator width) to avoid floating point precision problems.
        # .. hold_fmt and accu_fmt have the same number of fractional bits.
        accu_mod = 1 << int(cl_fix_width(self.accu_fmt))
        sig_int = np.array(cl_fix_to_integer(sig_hold, self.hold_fmt), dtype=object)
        for stage in range(self.order-1):
            # Restore state
            sig_int[0] = sig_int[0] + self._state_accu[stage]
            # Accumulate
            sig_int = np.cumsum(sig_int, dtype=object) % accu_mod
            # Store state
            self._state_accu[stage] = sig_int[-1]

        # Interpret as signed for signed formats
        if self.accu_fmt.S == 1:
            sig_int = np.where(sig_int >= accu_mod//2, sig_int - accu_mod, sig_int)

        # Shift (pure reinterpretation, sft_fmt has the same bits as accu_fmt)
        # .. For wide formats, the internal representation is the integer itself (cl_fix_from_integer() returns
        #    a WideFix object instead of the data, hence it is not used)
        if cl_fix_is_wide(self.sft_fmt):
            sig_sft = sig_int
        else:
            sig_sft = cl_fix_from_integer(sig_int, self.sft_fmt)

        # Output resize
        return cl_fix_resize(sig_sft, self.sft_fmt, self.out_fmt, self.round, self.saturate)
