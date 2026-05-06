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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_mov_avg, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Taps_g = int(generics["Taps_g"])
    GainCorrCoefFmt_g = generics["GainCorrCoefFmt_g"]
    if GainCorrCoefFmt_g.upper() != "AUTO":
        GainCorrCoefFmt_g = olo_fix_utils.fix_format_from_string(GainCorrCoefFmt_g)
    GainCorrDataFmt_g = generics["GainCorrDataFmt_g"]
    GainCorrType_g = generics["GainCorrType_g"]
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Calculation
    np.random.seed(42)  # Set the seed for reproducibility
    in_step = np.concatenate(([0], cl_fix_max_value(InFmt_g)/2*np.ones(Taps_g+2)))
    in_negstep = cl_fix_min_value(InFmt_g)/2*np.ones(Taps_g+2)
    in_rand = np.random.uniform(cl_fix_min_value(InFmt_g), cl_fix_max_value(InFmt_g), 10)
    in_data = np.concatenate((in_step, in_negstep, in_rand))
    in_data = cl_fix_from_real(in_data, InFmt_g)
    dut = olo_fix_mov_avg(InFmt_g, OutFmt_g, Taps_g, GainCorrCoefFmt_g, GainCorrDataFmt_g, GainCorrType_g, Round_g, Saturate_g)
    out_data = dut.process(in_data)

    # Plot if enabled
    if not cosim_mode:
        py_out = np.convolve(np.concatenate((np.zeros(Taps_g-1), in_data)), np.ones(Taps_g)/Taps_g, mode='valid')
        olo_fix_plots.plot_subplots({"Ideal vs. Fix" : {"Fix" : out_data, "Ideal" : py_out},
                                     "Error" : {"Error" : out_data - py_out}})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(in_data, InFmt_g, "In.fix")
        writer.write_cosim_file(out_data, OutFmt_g, "Out.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "InFmt_g": "(1, 4, 8)",
        "OutFmt_g": "(1, 4, 8)",
        "Taps_g": "3",
        "GainCorrCoefFmt_g": "(0, 1, 16)",
        "GainCorrDataFmt_g": "AUTO",
        "GainCorrType_g": "EXACT",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
