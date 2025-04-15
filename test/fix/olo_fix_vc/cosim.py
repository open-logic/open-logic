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

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim
from en_cl_fix_pkg import *

def cosim(output_path : str = None, generics : dict = None):

    Format_g = generics["Fmt_g"] 
    FileIn_g = generics["FileIn_g"]

    fmt_str = Format_g.strip("()").replace(" ", "")
    a, b, c = map(int, fmt_str.split(","))
    fmt = FixFormat(a, b, c)

    writer = olo_fix_cosim(output_path)
    arr = np.arange(cl_fix_min_value(fmt), cl_fix_max_value(fmt), 100)
    writer.write_cosim_file(arr, fmt, FileIn_g)
    writer.write_cosim_file(arr+1, fmt, "FileWrong.fix")


    return True