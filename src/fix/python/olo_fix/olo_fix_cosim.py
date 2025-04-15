# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from os.path import join

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_cosim:

    """
    This class is used to generate the cosimulation files for olo_fix verification components
    """

    def __init__(self, directory : str):
        """
        Args:
            directory (str): The directory where the cosimulation files will be written.
        """
        self._directory = directory

    def write_cosim_file(self, data : np.ndarray, format : FixFormat, file_name : str):
        """
        Write the cosimulation file with the given data and format.
        Args:
            data (np.ndarray): The data to be written to the file.
            format (FixFormat): FixFormat format of the data.
            file_name (str): The name of the file to be written.
        """
        hex_digits = (format.width + 3) // 4 
        fmt = str(format).replace(" ", "")
        if type(data[0])==WideFix:
            int_list = []
            # For wide-fix, no array operation was found, workaround is looping through elements
            for d in data:
                int_list.append(int(d.data))
            data_int = np.array(int_list, dtype=object)
        else:
            data_int = cl_fix_to_integer(data, format)

        data_int = np.where(data_int < 0, data_int + 2**cl_fix_width(format), data_int)
        np.savetxt(join(self._directory, file_name), data_int, fmt=f"%0{hex_digits}X", header=fmt, comments='')
