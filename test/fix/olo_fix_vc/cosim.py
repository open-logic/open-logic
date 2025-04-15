# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
# Import python packages
import sys
import os
import numpy as np

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils
from en_cl_fix_pkg import *

def cosim(output_path : str = None, generics : dict = None):

    Format_g = generics["Fmt_g"] 
    FileIn_g = generics["FileIn_g"]

    fmt = olo_fix_utils.fix_format_from_string(Format_g)

    writer = olo_fix_cosim(output_path)
    # For small formats, use narrow-fix
    if cl_fix_width(fmt) < 32:
        arr = np.arange(cl_fix_min_value(fmt), cl_fix_max_value(fmt), 100)
        arr = cl_fix_from_real(arr, fmt)
    # For wide formats, use wide-fix from int conversion
    else:
        min = cl_fix_min_value(fmt)
        max = cl_fix_max_value(fmt)
        N = 100
        step = (max-min)//100
        wide_fix_list = []
        for i in range(N):
            int_val = min+i*step
            wide_fix_list.append(WideFix(int_val, fmt))
        arr = np.array(wide_fix_list, dtype=object)

    writer.write_cosim_file(arr, fmt, FileIn_g)
    return True
