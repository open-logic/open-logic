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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_saturate, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    AFmt_g = olo_fix_utils.fix_format_from_string(generics["AFmt_g"])
    ResultFmt_g = olo_fix_utils.fix_format_from_string(generics["ResultFmt_g"])
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Calculation
    in_data = np.linspace(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 100)
    in_data = cl_fix_from_real(in_data, AFmt_g)
    abs = olo_fix_saturate(AFmt_g, ResultFmt_g, Saturate_g)
    out_data = abs.process(in_data)

    # Plot if enabled
    if not cosim_mode:
        olo_fix_plots.plot_subplots({"In/Out" : {"Input" : in_data, "Output" : out_data},
                                     "Error" : {"Error" : out_data - in_data}})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(in_data, AFmt_g, "A.fix")
        writer.write_cosim_file(out_data, ResultFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "AFmt_g": "(1, 2, 8)",
        "ResultFmt_g": "(1, 1, 8)",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
