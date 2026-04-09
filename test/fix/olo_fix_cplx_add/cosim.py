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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_cplx_add, olo_fix_plots
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
    ina_i = np.random.uniform(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 100)
    ina_i = cl_fix_from_real(ina_i, AFmt_g)
    ina_q = np.random.uniform(cl_fix_min_value(AFmt_g), cl_fix_max_value(AFmt_g), 100)
    ina_q = cl_fix_from_real(ina_q, AFmt_g)
    inb_i = np.random.uniform(cl_fix_min_value(BFmt_g), cl_fix_max_value(BFmt_g), 100)
    inb_i = cl_fix_from_real(inb_i, BFmt_g)
    inb_q = np.random.uniform(cl_fix_min_value(BFmt_g), cl_fix_max_value(BFmt_g), 100)
    inb_q = cl_fix_from_real(inb_q, BFmt_g)
    dut = olo_fix_cplx_add(AFmt_g, BFmt_g, ResultFmt_g, Round_g, Saturate_g)
    out_i, out_q = dut.process(ina_i, ina_q, inb_i, inb_q)

    # Plot if enabled
    if not cosim_mode:
        py_out_i = ina_i + inb_i
        py_out_q = ina_q + inb_q
        olo_fix_plots.plot_subplots({"Python vs. Fix" : {"Fix_i" : out_i, 
                                                         "Fix_q" : out_q, 
                                                         "Python_i" : py_out_i, 
                                                         "Python_q" : py_out_q}})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        # Write I/Q separately
        writer.write_cosim_file(ina_i, AFmt_g, "AI.fix")
        writer.write_cosim_file(ina_q, AFmt_g, "AQ.fix")
        writer.write_cosim_file(inb_i, BFmt_g, "BI.fix")
        writer.write_cosim_file(inb_q, BFmt_g, "BQ.fix")
        writer.write_cosim_file(out_i, ResultFmt_g, "Result_I.fix")
        writer.write_cosim_file(out_q, ResultFmt_g, "Result_Q.fix")
        writer.write_cosim_file(np.random.randint(0,2, size=len(ina_i)).astype(float), FixFormat(0,1,0), "LastPar.fix")
        # Write I/Q interleaved
        writer.write_cosim_file(np.column_stack((ina_i, ina_q)).ravel(), AFmt_g, "AIQ.fix")
        writer.write_cosim_file(np.column_stack((inb_i, inb_q)).ravel(), BFmt_g, "BIQ.fix")
        writer.write_cosim_file(np.column_stack((out_i, out_q)).ravel(), ResultFmt_g, "Result_IQ.fix")
        writer.write_cosim_file(np.random.randint(0,2, size=len(ina_i)*2).astype(float), FixFormat(0,1,0), "LastTdm.fix")

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
