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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_bin_div, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):
    
    # Constants (shorter for cosim than for plotting)
    if cosim_mode:
        SAMPLES_RAND = 100
        SAMPLES_LOGIC = 35
    else:
        SAMPLES_RAND = 1000
        SAMPLES_LOGIC = 361

    #Parse Generics
    NumFmt_g = olo_fix_utils.fix_format_from_string(generics["NumFmt_g"])
    DenomFmt_g = olo_fix_utils.fix_format_from_string(generics["DenomFmt_g"])
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    # Human Readable inputs
    sig_logic_num = np.hstack((np.linspace(cl_fix_min_value(NumFmt_g), cl_fix_max_value(NumFmt_g), SAMPLES_LOGIC), [1.0, 0.0]))
    sig_logic_denom = np.hstack((np.linspace(cl_fix_max_value(DenomFmt_g), cl_fix_min_value(DenomFmt_g), SAMPLES_LOGIC), [0.0, 1.0]))
    # Random Signal
    np.random.seed(0)
    sig_random_num = np.random.uniform(low=cl_fix_min_value(NumFmt_g), high=cl_fix_max_value(NumFmt_g), size=SAMPLES_RAND)
    sig_random_denom = np.random.uniform(low=cl_fix_min_value(DenomFmt_g), high=cl_fix_max_value(DenomFmt_g), size=SAMPLES_RAND)
    # Concatenate
    sig_num = np.concatenate((sig_logic_num, sig_random_num))
    sig_denom = np.concatenate((sig_logic_denom, sig_random_denom))   

    #Quantize inputs
    sig_num = cl_fix_from_real(sig_num, NumFmt_g)
    sig_denom = cl_fix_from_real(sig_denom, DenomFmt_g)

    #Calcualte
    dut = olo_fix_bin_div(NumFmt_g, DenomFmt_g, OutFmt_g, Round_g, Saturate_g)
    out = dut.process(sig_num, sig_denom)
    
    # Plot if enabled
    if not cosim_mode:
        in_num = {"Numerator" : sig_num}
        in_denom = {"Denominator" : sig_denom}
        out_quot = {"Quotient" : out}
        expected = sig_num / np.where(sig_denom == 0.0, 1e-10, sig_denom)
        expected = np.clip(expected, cl_fix_min_value(OutFmt_g), cl_fix_max_value(OutFmt_g))
        err = {"Error [LSB]" : (out - expected)*2**OutFmt_g.F}
        olo_fix_plots.plot_subplots({"Numerator" : in_num, "Denominator" : in_denom, "Quotient" : out_quot, "Error" : err})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(sig_num, NumFmt_g, "Numerator.fix")
        writer.write_cosim_file(sig_denom, DenomFmt_g, "Denominator.fix")
        writer.write_cosim_file(out, OutFmt_g, "Out.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "NumFmt_g": "(0, 2, 10)",
        "DenomFmt_g": "(1, 3, 4)",
        "OutFmt_g": "(1, 8, 12)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
