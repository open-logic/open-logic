# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from matplotlib import pyplot as plt

# ---------------------------------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------------------------------
class olo_fix_utils:
        
    @staticmethod
    def fix_format_from_string(format_str : str, tolerate_str : bool = False) -> FixFormat:
        """
        Convert a string representation of a FixFormat to a FixFormat object.
        Args:
            format_str (str): The string representation of the FixFormat.
            tolerate_str (bool): If True, non-format strints will be returned as string
        Returns:
            FixFormat: The corresponding FixFormat object.
        """
        try:
            format_str = format_str.strip("()").replace(" ", "")
            a, b, c = map(int, format_str.split(","))
            return FixFormat(a, b, c)
        except ValueError as e:
            if not tolerate_str:
                raise e
            return format_str if tolerate_str else None

    @staticmethod
    def get_leading_bit_index(a, a_fmt : FixFormat):
        """
        Index of the leading set bit of fixed-point numbers.

        Refelects the behavior of the VHDL function olo_base_pkgt_math.getLeadingSetBitIndex().

        representation is not exact for inputs wider than a double mantissa.

        :param a: Input data (quantized to a_fmt)
        :param a_fmt: Format of the input data
        :return: Index of the leading set bit per sample (1d array)
        """
        width = cl_fix_width(a_fmt)
        codes = np.atleast_1d(cl_fix_to_integer(a, a_fmt))
        # Python integers are used to support formats wider than 64 bits. The modulo converts
        # negative numbers to their two's complement bit pattern.
        return np.array([max((int(code) % 2**width).bit_length() - 1, 0) for code in codes],
                        dtype=int)
