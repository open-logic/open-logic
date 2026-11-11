# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_sample_hold:
    """
    Model of olo_fix_sample_hold entity
    """

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 fmt : FixFormat,
                 reset_value : float = 0.0):
        """
        Constructor of the olo_fix_sample_hold class
        :param fmt: Format of the input and output
        :param reset_value: Value to apply to output before the first input sample arrives
        """
        self._fmt = fmt
        # Values are stored quantized (and are not quantized again when output, which would be wrong for
        # wide formats where the internal representation is an integer)
        self._reset_value = cl_fix_from_real(reset_value, fmt)
        self._hold_value = self._reset_value


    def reset(self):
        """
        Reset state of the component
        """
        self._hold_value = self._reset_value

    def next(self, input=None, out_samples=0):
        """
        Process next N samples (last input sample is held at the output until next call of next())

        Can be used to apply input only:
        inst.next(input=sample)

        Or to generate output only:
        x = inst.next(out_samles=1)

        :param input: Input samples (float or iterable of floats). None implies no new input samples.
        :param out_samples: Number of output samples to produce (with the same held value)
        :return: Result (float if out_samples=1, otherwise numpy array of floats)
        """
        #  Apply new input
        if input is not None:
            # Quantize input
            input = cl_fix_from_real(input, self._fmt)

            if isinstance(input, (float, int)) or (isinstance(input, np.ndarray) and input.ndim == 0):
                self._hold_value = input
            else:
                self._hold_value = input[-1] #Hold the last sample of the input sequence

        # Product output
        if out_samples == 1:
            return self._hold_value
        elif out_samples > 1:
            return np.full(out_samples, self._hold_value, dtype=object if cl_fix_is_wide(self._fmt) else None)
        else:
            return None

    def next_each(self, input, out_samples : int):
        """
        Vectorized processing: Apply each input sample and produce out_samples output samples for every input sample
        (i.e. each input sample is held for out_samples output samples). The last input sample stays held after the
        call.

        Example: inst.next_each(input=[1.0, 2.0], out_samples=3) returns [1.0, 1.0, 1.0, 2.0, 2.0, 2.0]

        :param input: Input samples (float or iterable of floats)
        :param out_samples: Number of output samples to produce per input sample
        :return: Result (numpy array of floats with len(input)*out_samples elements)
        """
        input = np.atleast_1d(input)
        if input.size == 0:
            return np.array([])
        input = cl_fix_from_real(input, self._fmt)
        self._hold_value = input[-1]
        return np.repeat(input, out_samples)

    def process(self, input=None, out_samples=0):
        """
        Process samples (without preserving previous state)

        For details, refer to the documentation of next()

        :param input: Input samples (float or iterable of floats). None implies no new input samples.
        :param out_samples: Number of output samples to produce (with the same held value)
        :return: Result (float if out_samples=1, otherwise numpy array of floats)
        """
        self.reset()
        return self.next(input=input, out_samples=out_samples)
