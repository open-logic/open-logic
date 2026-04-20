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


# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_cic_dec:
    """
    General model of a fixed point CIC decimator. The model represents any bittrue implementation of a CIC decimator, independently
    of tis RTL implementation (multi-channel, serial/parallel, etc.).

    The model only implements one channel. For multi-channel operation, multiple instances of the model must be created.
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
        Creation of a decimating CIC model

        The following generics that do not impact numeric behavior and are related to FPGA implementation only are
        omitted:
        - All implementation related generics
        - Channel Count (one model instance per channel must be created)        

        :param order: CIC order
        :param ratio: CIC decimation ratio
        :param diff_delay: Differential delay (usually 1 or 2)
        :param in_fmt: Input fixed-point format
        :param out_fmt: Output fixed-point format
        :param gain_corr_coef_fmt: Format of the gain correction coefficient (use "NONE" for no correction)
        :param round: Rounding mode at the output
        :param saturate: Saturation mode at the output
        """
        # Check arguments
        if order < 2:                             raise ValueError("olo_fix_cic_dec: order must be >= 2")
        if order > 32:                            raise ValueError("olo_fix_cic_dec: order must be <= 32")
        if diff_delay < 1:                        raise ValueError("olo_fix_cic_dec: diff_delay must be >= 1")

        #Store Config
        self.in_fmt = in_fmt
        self.out_fmt = out_fmt
        self.order = order
        self.ratio = ratio
        self.diff_delay = diff_delay
        self.round = round
        self.saturate = saturate

        #Calculated constants
        self.cic_gain = (ratio*diff_delay)**order
        self.cic_add_bits = ceil(log2(self.cic_gain))
        self.shift = self.cic_add_bits
        self.accu_fmt = FixFormat(in_fmt.S, in_fmt.I+self.cic_add_bits, in_fmt.F)
        self.diff_fmt = FixFormat(out_fmt.S, in_fmt.I, out_fmt.F+order+1)
        self.gcin_fmt = FixFormat(1, out_fmt.I, min(out_fmt.F+2, self.diff_fmt.F))

        # gain_corr_coef_fmt
        if isinstance(gain_corr_coef_fmt, str):
            # String
            if gain_corr_coef_fmt.upper() == "NONE":
                self._gain_comp_on = False
                self._gain_comp_coef = 0
                self._gain_comp_coef_fmt = FixFormat(0,0,0) 
            else:
                raise ValueError("olo_fix_cic_dec: gain_corr_coef_fmt_g must be 'NONE' or a FixFormat")
        else:
            # Format
            self._gain_comp_on = True
            self._gain_comp_coef = cl_fix_from_real(2**self.cic_add_bits/self.cic_gain, gain_corr_coef_fmt)
            if gain_corr_coef_fmt.I != 1:               raise ValueError("olo_fix_cic_dec: gain_corr_coef_fmt must have I=1")
            if gain_corr_coef_fmt.S != 0:               raise ValueError("olo_fix_cic_dec: gain_corr_coef_fmt must have S=0")
            self._gain_comp_coef_fmt = gain_corr_coef_fmt

        # state
        self.clear_state()

    # ---------------------------------------------------------------------------------------------------
    # Public Methods and Properties
    # ---------------------------------------------------------------------------------------------------
    def clear_state(self):
        """
        Reset the internal state of the CIC model
        """
        self._state_accu = np.zeros(self.order, dtype=object)
        self._state_diff = [np.zeros(self.diff_delay) for _ in range(self.order)]      
        self._state_phase = 0

    def process(self, inp : np.ndarray):
        """
        Process data using the CIC model object
        :param inp: Input data
        :return: Output data
        """
        # state
        self.clear_state()

        return self.next(inp)

    def next(self, inp : np.ndarray):
        """
        Process data using the CIC model object
        :param inp: Input data
        :return: Output data
        """
        #Make iniput fixed point
        sig = cl_fix_from_real(inp, self.in_fmt)

        # Do integration in integer to avoid floating point precision problems and poor performance of large
        # en_cl_fix sums
        sig_int = np.zeros([self.order+1, sig.size], dtype=object)
        sig_int[0] = np.array(cl_fix_to_integer(sig, self.in_fmt), dtype=object)
        for stage in range(self.order):
            # Initialize
            stage_out = np.zeros(sig.size, dtype=object)
            # Restore state
            sig_int[stage, 0] = (sig_int[stage, 0] + self._state_accu[stage]) % (1 << int(cl_fix_width(self.accu_fmt)))
            # Accumulate
            stage_out = np.cumsum(sig_int[stage], dtype=object) % (1 << int(cl_fix_width(self.accu_fmt)))
            # Store state
            self._state_accu[stage] = stage_out[-1]
            # Store output
            sig_int[stage+1] = stage_out
            

        # Do decimation and shift
        # Restore state of decimation phase
        first_idx = (self.ratio - self._state_phase) % self.ratio
        # Decimate
        sig_dec_full = np.array(sig_int[self.order][first_idx::self.ratio], dtype=object)
        # Update phase state
        self._state_phase = (self._state_phase + sig.size) % self.ratio
        if not cl_fix_is_wide(self.accu_fmt):
            # Because integer sums are always positive, we must first convert the unsigned format and then wrap
            # by resizing
            accu_fmt_uns = FixFormat(0, self.accu_fmt.I + self.accu_fmt.S, self.accu_fmt.F)
            sig_dec_full = cl_fix_from_integer(sig_dec_full, accu_fmt_uns)
            sig_dec_full = cl_fix_resize(sig_dec_full, accu_fmt_uns, self.accu_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        sig_dec = cl_fix_shift(sig_dec_full, self.accu_fmt, -self.shift, self.diff_fmt, FixRound.Trunc_s, FixSaturate.None_s)

        # Do differentiation
        sig_diff = []
        sig_diff.append(sig_dec)
        for stage in range(self.order):
            # Update delay line
            last = np.concatenate((self._state_diff[stage], sig_diff[stage]))
            # Output used for calculation
            last_sig = last[:-self.diff_delay]
            # Content of delay line after processing is stored
            self._state_diff[stage] = last[-self.diff_delay:]
            # Calculate output
            stage_out = cl_fix_sub(sig_diff[stage], self.diff_fmt,
                                 last_sig, self.diff_fmt, self.diff_fmt)
            sig_diff.append(stage_out)

        # Gain Compensation
        if self._gain_comp_on:
            sig_gc_in = cl_fix_resize(sig_diff[self.order], self.diff_fmt, self.gcin_fmt, FixRound.Trunc_s, self.saturate)
            sig_gc_out = cl_fix_mult(sig_gc_in, self.gcin_fmt,
                                  self._gain_comp_coef, self._gain_comp_coef_fmt,
                                  self.out_fmt, self.round, self.saturate)
            return sig_gc_out
        else:
            return cl_fix_resize(sig_diff[self.order], self.diff_fmt, self.out_fmt, self.round, self.saturate)






