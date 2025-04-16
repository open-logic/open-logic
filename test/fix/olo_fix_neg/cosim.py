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
from matplotlib import pyplot as plt

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_neg
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    AFmt_g = olo_fix_utils.fix_format_from_string(generics["AFmt_g"])
    ResultFmt_g = olo_fix_utils.fix_format_from_string(generics["ResultFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Calculation
    in_data = np.linspace(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 100)
    in_data = cl_fix_from_real(in_data, AFmt_g)
    abs = olo_fix_neg(AFmt_g, ResultFmt_g, Round_g, Saturate_g)
    out_data = abs.process(in_data)

    # Plot if enabled
    if not cosim_mode:
        olo_fix_utils.plot_a_b_err(a=out_data, a_name="Output Data", 
                                   b=in_data, b_name="Input Data", 
                                   plot_error = False)


    #Write Files
    if cosim_mode:
        #Generics
        AFile_g = generics["AFile_g"]
        ResultFile_g = generics["ResultFile_g"]

        #Write Files
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(in_data, AFmt_g, AFile_g)
        writer.write_cosim_file(out_data, ResultFmt_g, ResultFile_g)
        print("Written")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "AFmt_g": "(1, 2, 10)",
        "ResultFmt_g": "(1, 1, 8)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
