# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from typing import Union
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_mov_avg:
    """
    Model of olo_fix_mov_avg entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt : FixFormat,
                 out_fmt : FixFormat,
                 taps : int,
                 gain_corr_coef_fmt : FixFormat = FixFormat(0, 1, 16),
                 gain_corr_data_fmt : Union[FixFormat, str] = "AUTO",
                 gain_corr_type : str = "EXACT",
                 round : FixRound = FixRound.Trunc_s,
                 saturate : FixSaturate = FixSaturate.Warn_s):
        """
        Constructor of the olo_fix_mov_avg class
        :param in_fmt: Format of the input
        :param out_fmt: Format of the output
        :param gain_corr_coef_fmt: Format of the gain correction coefficient
        :param gain_corr_data_fmt: Format of the data for gain correction multiplier. Only used for "EXACT" gain 
                                   correction type. If "AUTO", the format is automatically determined to (out_fmt.S, out_fmt.I+1, out_fmt.F + 3).
        :param gain_corr_type: Type of gain correction: 
                               "EXACT" = correct gain precisely with a multiplier
                               "SHIFT" = correct gain into the range 0 <= gain < 1 by shifting
                               "NONE"  = do not correct gain
        :param round: Rounding mode
        :param saturate: Saturation mode
        """
        # Validate parameters
        self._in_fmt = in_fmt
        self._out_fmt = out_fmt
        self._taps = taps
        if self._taps < 1:
            raise ValueError(f"olo_fix_mov_avg: Invalid value for taps: {taps} (should be >= 1)")
        self._gain_corr_coef_fmt = gain_corr_coef_fmt
        if isinstance(gain_corr_data_fmt, str):
            if gain_corr_data_fmt.upper() == "AUTO":
                self._gain_corr_data_fmt = FixFormat(out_fmt.S, in_fmt.I, out_fmt.F + 3)
            else:
                raise ValueError(f"olo_fix_mov_avg: Invalid value for gain_corr_data_fmt: {gain_corr_data_fmt} (should be 'AUTO' or a FixFormat)")
        elif isinstance(gain_corr_data_fmt, FixFormat):
            self._gain_corr_data_fmt = gain_corr_data_fmt
        else:
            raise ValueError(f"olo_fix_mov_avg: Invalid value for gain_corr_data_fmt: {gain_corr_data_fmt} (should be 'AUTO' or a FixFormat)")
        self._gain_corr_type = gain_corr_type.upper()
        if not self._gain_corr_type.upper() in ["EXACT", "SHIFT", "NONE"]:
            raise ValueError(f"olo_fix_mov_avg: Invalid value for gain_corr_type: {gain_corr_type} (should be 'EXACT', 'SHIFT' or 'NONE')")
        self._round = round
        self._saturate = saturate

        # Set internal state
        self._add_bits = int(np.ceil(np.log2(self._taps)))
        self._gc = cl_fix_from_real((2.0**self._add_bits)/self._taps, self._gain_corr_coef_fmt)
        self._mov_sum_fmt = FixFormat(self._in_fmt.S, self._in_fmt.I + self._add_bits, self._in_fmt.F)
        self.reset()


    def reset(self):
        """
        Reset state of the component
        """
        self._state = np.zeros(self._taps)

    def next(self, in_data):
        """
        Process next N samples
        :param in_data: Input data
        :return: Result
        """
        # Convert scalars to 1d array
        if np.isscalar(in_data):
            in_data = np.array([in_data])

        # moving sum
        data = np.concatenate((self._state[1::], in_data))
        mov_sum = np.convolve(data, np.ones(self._taps), mode='valid')
        self._state = data[-self._taps:]

        # Gain correction
        if self._gain_corr_type == "EXACT":
            shift_corr = cl_fix_shift(mov_sum, self._mov_sum_fmt, -self._add_bits, self._gain_corr_data_fmt, FixRound.Trunc_s)
            return cl_fix_mult(shift_corr, self._gain_corr_data_fmt, self._gc, self._gain_corr_coef_fmt, self._out_fmt, self._round, self._saturate)
        elif self._gain_corr_type == "SHIFT":
            return cl_fix_shift(mov_sum, self._mov_sum_fmt, -self._add_bits, self._out_fmt, self._round, self._saturate)
        elif self._gain_corr_type == "NONE":
            return cl_fix_resize(mov_sum, self._mov_sum_fmt, self._out_fmt, self._round, self._saturate)

    def process(self, in_data):
        """
        Process samples (without preserving previous state)
        :param in_data: Input data
        :return: Result
        """
        self.reset()
        return self.next(in_data)
