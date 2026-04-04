# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *

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
        self._reset_value = reset_value
        self._hold_value = reset_value


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
        if input != None:
            if isinstance(input, (float, int)) or (isinstance(input, np.ndarray) and input.ndim == 0):
                self._hold_value = input
            else:
                self._hold_value = input[-1] #Hold the last sample of the input sequence

        # Product output
        if out_samples == 1:
            return cl_fix_from_real(self._hold_value, self._fmt)
        elif out_samples > 1:
            return np.full(out_samples, cl_fix_from_real(self._hold_value, self._fmt))
        else:
            return None

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
