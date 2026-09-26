# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_inv, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    SAMPLES = 400 if cosim_mode else 4000

    #Parse Generics
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    PrecisionBits_g = int(generics["PrecisionBits_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Generate inputs
    data = np.linspace(cl_fix_min_value(InFmt_g), cl_fix_max_value(InFmt_g), SAMPLES)
    data = cl_fix_from_real(data, InFmt_g)

    #Calculate
    dut = olo_fix_inv(InFmt_g, OutFmt_g, PrecisionBits_g, Round_g, Saturate_g)
    result = dut.process(data)

    # Plot if enabled
    if not cosim_mode:
        #The relative error is the meaningful metric - zero is excluded because 1/0 is undefined
        nonzero = np.array(data, dtype=float) != 0.0
        rel_error = np.zeros(len(data))
        nonzero_result = np.array(result, dtype=float)[nonzero]
        nonzero_data = np.array(data, dtype=float)[nonzero]
        rel_error[nonzero] = (nonzero_result - 1.0/nonzero_data)/nonzero_result
        abs_error = np.abs(nonzero_result - 1.0/nonzero_data)
        in_data = {"Input" : data}
        out_data = {"1/Input" : result}
        err_data = {"Relative Error" : rel_error}
        abs_err_data = {"Absolute Error" : abs_error}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data,
                                     "Error Data" : err_data, "Absolute Error Data" : abs_err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(data, InFmt_g, "Input.fix")
        writer.write_cosim_file(result, OutFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "OutFmt_g": "(0, 8, 20)",
        "InFmt_g": "(0, 0, 16)",
        "PrecisionBits_g": 18,
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
