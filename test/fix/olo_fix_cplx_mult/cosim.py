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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_cplx_mult, olo_fix_plots
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
    Mode_g = generics["Mode_g"]


    #Calculation
    np.random.seed(42)  # Set the seed for reproducibility
    a_maxval = cl_fix_max_value(AFmt_g)
    b_maxval = cl_fix_max_value(BFmt_g)
    a_minval = cl_fix_min_value(AFmt_g)
    b_minval = cl_fix_min_value(BFmt_g)
    ramp_a = np.linspace(a_maxval*0.2, a_maxval*0.99, 25)
    ramp_b = np.linspace(b_maxval*0.2, b_maxval*0.99, 25)
    rot_a = np.exp(1j * np.linspace(0, 2 * np.pi, 25))*a_maxval*0.8
    rot_b = np.exp(1j * np.linspace(0, 2 * np.pi, 25))*b_maxval*0.8
    a_rand = np.random.uniform(a_minval, a_maxval, 100) + 1j * np.random.uniform(a_minval, a_maxval, 100)
    b_rand = np.random.uniform(b_minval, b_maxval, 100) + 1j * np.random.uniform(b_minval, b_maxval, 100)
    a_max = [1+1j, -1+1j, -1-1j, 1-1j]*a_maxval
    b_max = [1+1j, -1+1j, -1-1j, 1-1j]*b_maxval
    ina = np.concatenate((ramp_a, rot_a, np.repeat(a_max, 4), a_rand))
    inb = np.concatenate((rot_b, ramp_b, np.tile(b_max, 4), b_rand))
    ina_i = cl_fix_from_real(ina.real, AFmt_g)
    ina_q = cl_fix_from_real(ina.imag, AFmt_g)
    inb_i = cl_fix_from_real(inb.real, BFmt_g)
    inb_q = cl_fix_from_real(inb.imag, BFmt_g)
    dut = olo_fix_cplx_mult(AFmt_g, BFmt_g, ResultFmt_g, Round_g, Saturate_g, Mode_g)
    out_i, out_q = dut.process(ina_i, ina_q, inb_i, inb_q)

    # Plot if enabled
    if not cosim_mode:
        py_ina = ina_i + 1j*ina_q
        py_inb = inb_i + 1j*inb_q
        if Mode_g == "MULT":
            py_out = py_ina * py_inb
        elif Mode_g == "MIX":
            py_out = py_ina * np.conj(py_inb)
        error = py_out - (out_i + 1j*out_q)
        olo_fix_plots.plot_subplots({"Python vs. Fix" : {"Fix_i" : out_i, 
                                                         "Fix_q" : out_q, 
                                                         "Python_i" : py_out.real, 
                                                         "Python_q" : py_out.imag},
                                     "Error" : {"Error_i" : error.real, 
                                                "Error_q" : error.imag},
                                     "Input" : {"ina_i" : ina_i, 
                                                "ina_q" : ina_q, 
                                                "inb_i" : inb_i, 
                                                "inb_q" : inb_q}})

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
        last_spl = np.random.randint(0,2, size=len(ina_i)).astype(float)
        writer.write_cosim_file(last_spl, FixFormat(0,1,0), "LastPar.fix")
        # Write I/Q interleaved
        writer.write_cosim_file(np.column_stack((ina_i, ina_q)).ravel(), AFmt_g, "AIQ.fix")
        writer.write_cosim_file(np.column_stack((inb_i, inb_q)).ravel(), BFmt_g, "BIQ.fix")
        writer.write_cosim_file(np.column_stack((out_i, out_q)).ravel(), ResultFmt_g, "Result_IQ.fix")
        last_q_only = np.ravel(np.column_stack((np.zeros_like(last_spl), last_spl)))
        writer.write_cosim_file(last_q_only, FixFormat(0,1,0), "LastTdm.fix")

    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "AFmt_g": "(1, 4, 4)",
        "BFmt_g": "(1, 4, 4)",
        "ResultFmt_g": "(1, 16, 4)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s",
        "Mode_g": "MULT"
    }
    cosim(generics=generics, cosim_mode=False)
