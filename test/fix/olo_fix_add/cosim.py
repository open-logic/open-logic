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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_add, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    AFmt_g = olo_fix_utils.fix_format_from_string(generics["AFmt_g"])
    BFmt_g = olo_fix_utils.fix_format_from_string(generics["BFmt_g"])
    ResultFmt_g = olo_fix_utils.fix_format_from_string(generics["ResultFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Calculation
    np.random.seed(42)  # Set the seed for reproducibility
    in_a = np.random.uniform(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 100)
    in_a = cl_fix_from_real(in_a, AFmt_g)
    in_b = np.random.uniform(cl_fix_min_value(BFmt_g), cl_fix_max_value(BFmt_g), 100)
    in_b = cl_fix_from_real(in_b, BFmt_g)
    dut = olo_fix_add(AFmt_g, BFmt_g, ResultFmt_g, Round_g, Saturate_g)
    out_data = dut.process(in_a, in_b)

    # Plot if enabled
    if not cosim_mode:
        py_out = in_a + in_b
        olo_fix_plots.plot_subplots({"Python vs. Fix" : {"Fix" : out_data, "Python" : py_out}})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(in_a, AFmt_g, "A.fix")
        writer.write_cosim_file(in_b, BFmt_g, "B.fix")
        writer.write_cosim_file(out_data, ResultFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "AFmt_g": "(1, 4, 4)",
        "BFmt_g": "(1, 4, 4)",
        "ResultFmt_g": "(0, 4, 4)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
