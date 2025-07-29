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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_compare, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    AFmt_g = olo_fix_utils.fix_format_from_string(generics["AFmt_g"])
    BFmt_g = olo_fix_utils.fix_format_from_string(generics["BFmt_g"])
    Comparison_g = generics["Comparison_g"]

    #Calculation
    np.random.seed(42)  # Set the seed for reproducibility
    in_a = np.linspace(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 99)
    in_a = cl_fix_from_real(in_a, AFmt_g)
    in_b = in_a[::-1]  # Reverse the order of in_a
    in_b = cl_fix_from_real(in_b, BFmt_g, saturate=FixSaturate.Sat_s)
    dut = olo_fix_compare(AFmt_g, BFmt_g, Comparison_g)
    out_data = dut.process(in_a, in_b)

    # Plot if enabled
    if not cosim_mode:
        py_out = in_a * in_b
        olo_fix_plots.plot_subplots({"Inputs" : {"A" : in_a, "B" : in_b},
                                     "Output" : {"Output" : out_data}})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(in_a, AFmt_g, "A.fix")
        writer.write_cosim_file(in_b, BFmt_g, "B.fix")
        writer.write_cosim_file(out_data.astype(float), FixFormat(0,1,0), "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "AFmt_g": "(1, 4, 4)",
        "BFmt_g": "(0, 4, 4)",
        "Comparison_g": "!="
    }
    cosim(generics=generics, cosim_mode=False)
