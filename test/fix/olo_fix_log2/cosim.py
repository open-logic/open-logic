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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_log2, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    SAMPLES = 400 if cosim_mode else 4000

    #Parse Generics
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Generate inputs - a linear sweep only reaches the top octaves, hence it is complemented by a
    #logarithmic sweep starting at the smallest non-zero value
    lin = np.linspace(cl_fix_min_value(InFmt_g), cl_fix_max_value(InFmt_g), SAMPLES)
    log = np.geomspace(2.0**-InFmt_g.F, cl_fix_max_value(InFmt_g), SAMPLES)
    data = cl_fix_from_real(np.concatenate((lin, log)), InFmt_g)

    #Calculate
    dut = olo_fix_log2(InFmt_g, OutFmt_g, Round_g, Saturate_g)
    result = dut.process(data)

    # Plot if enabled
    if not cosim_mode:
        #Zero is excluded from the error because log2(0) is undefined
        nonzero = np.array(data, dtype=float) != 0.0
        expected = np.log2(np.array(data, dtype=float)[nonzero])
        abs_error = np.zeros(len(data))
        abs_error[nonzero] = np.abs(np.array(result, dtype=float)[nonzero] - expected)
        lsb_error = np.zeros(len(data))
        lsb_error[nonzero] = (np.array(result, dtype=float)[nonzero] - expected)*2**OutFmt_g.F
        in_data = {"Input" : data}
        out_data = {"log2(Input)" : result}
        abs_err_data = {"Absolute Error" : abs_error}
        lsb_err_data = {"Error [LSB of OutFmt_g]" : lsb_error}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data,
                                     "Absolute Error Data" : abs_err_data,
                                     "Error Data [LSB]" : lsb_err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(data, InFmt_g, "Input.fix")
        writer.write_cosim_file(result, OutFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "OutFmt_g": "(1, 4, 16)",
        "InFmt_g": "(0, 8, 8)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
