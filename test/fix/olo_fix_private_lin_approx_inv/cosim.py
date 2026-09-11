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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_private_lin_approx_inv, olo_fix_plots
from en_cl_fix_pkg import *

def stimuli_codes(fmt : FixFormat, samples : int, points : int):
    """
    Input codes covering the whole range of a format

    All codes are used if the format is small enough. Otherwise a sweep plus the codes at the
    segment borders (and their neighbours) are used, because those are the worst case for the
    approximation.
    """
    width = cl_fix_width(fmt)
    all_codes = 2**width

    if all_codes <= samples:
        codes = np.arange(all_codes)
    else:
        sweep = np.linspace(0, all_codes - 1, samples).astype(np.int64)
        border = np.arange(points)*(all_codes//points)
        codes = np.concatenate((sweep, border, border + 1, border - 1))
        codes = np.unique(np.mod(codes, all_codes))

    return cl_fix_from_integer(codes, fmt)

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    SAMPLES = 400 if cosim_mode else 4000

    #Parse Generics
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Calculate
    dut = olo_fix_private_lin_approx_inv(OutFmt_g, InFmt_g, Round_g, Saturate_g)

    #Generate inputs - the mantissa fraction covers [0, 1), the normalized value is 1+m
    mantissa = stimuli_codes(InFmt_g, SAMPLES, dut.tbl.points)
    result = dut.process(mantissa)

    # Plot if enabled
    if not cosim_mode:
        expected = 1.0/(1.0 + mantissa)
        in_data = {"Mantissa Fraction" : mantissa}
        out_data = {"1/(1+m)" : result}
        err_data = {"Error [LSB]" : (result - expected)*2**OutFmt_g.F}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data,
                                     "Error Data" : err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(mantissa, InFmt_g, "Mantissa.fix")
        writer.write_cosim_file(result, OutFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "OutFmt_g": "(0, 1, 18)",
        "InFmt_g": "(0, 0, 20)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
