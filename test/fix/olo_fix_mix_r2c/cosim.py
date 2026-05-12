# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import sys
import os
import numpy as np

# Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_mix_r2c, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    # Parse Generics
    InFmt_g    = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    MixFmt_g   = olo_fix_utils.fix_format_from_string(generics["MixFmt_g"])
    OutFmt_g   = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Round_g    = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    # Calculation
    np.random.seed(42)
    sig_maxval = cl_fix_max_value(InFmt_g)
    sig_minval = cl_fix_min_value(InFmt_g)
    mix_maxval = cl_fix_max_value(MixFmt_g)
    mix_minval = cl_fix_min_value(MixFmt_g)

    # Ramp: increasing signal amplitude with rotating LO
    ramp_sig = np.linspace(sig_maxval * 0.2, sig_maxval * 0.99, 25)
    rot_mix  = np.exp(1j * np.linspace(0, 2 * np.pi, 25)) * mix_maxval * 0.8

    # Rotating signal with ramp LO amplitude
    rot_sig  = np.cos(np.linspace(0, 2 * np.pi, 25)) * sig_maxval * 0.8
    ramp_mix = np.linspace(mix_maxval * 0.2, mix_maxval * 0.99, 25)

    # Boundary values
    sig_boundary = np.array([sig_maxval, sig_minval, sig_maxval, sig_minval])
    mix_i_boundary = np.array([mix_maxval, mix_maxval, mix_minval, mix_minval])
    mix_q_boundary = np.array([mix_maxval, mix_minval, mix_maxval, mix_minval])

    # Random data
    sig_rand   = np.random.uniform(sig_minval, sig_maxval, 100)
    mix_i_rand = np.random.uniform(mix_minval, mix_maxval, 100)
    mix_q_rand = np.random.uniform(mix_minval, mix_maxval, 100)

    # Concatenate all test vectors
    sig    = np.concatenate((ramp_sig, rot_sig, sig_boundary, sig_rand))
    mix_i  = np.concatenate((rot_mix.real, ramp_mix, mix_i_boundary, mix_i_rand))
    mix_q  = np.concatenate((rot_mix.imag, ramp_mix, mix_q_boundary, mix_q_rand))

    # Quantize inputs
    sig_q   = cl_fix_from_real(sig,   InFmt_g)
    mix_i_q = cl_fix_from_real(mix_i, MixFmt_g)
    mix_q_q = cl_fix_from_real(mix_q, MixFmt_g)

    # Run model
    dut = olo_fix_mix_r2c(InFmt_g, MixFmt_g, OutFmt_g, Round_g, Saturate_g)
    out_i, out_q = dut.process(sig_q, mix_i_q, mix_q_q)

    # Plot if not in cosim mode
    if not cosim_mode:
        py_out_i = sig * mix_i
        py_out_q = -sig * mix_q
        error_i = py_out_i - out_i
        error_q = py_out_q - out_q
        olo_fix_plots.plot_subplots({
            "Output" : {"out_i" : out_i, "out_q" : out_q},
            "Error"  : {"error_i" : error_i, "error_q" : error_q},
            "Input"  : {"sig" : sig_q, "mix_i" : mix_i_q, "mix_q" : mix_q_q}
        })

    # Write cosim files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(sig_q,   InFmt_g,  "SigReal.fix")
        writer.write_cosim_file(mix_i_q, MixFmt_g, "MixI.fix")
        writer.write_cosim_file(mix_q_q, MixFmt_g, "MixQ.fix")
        writer.write_cosim_file(out_i,   OutFmt_g, "Result_I.fix")
        writer.write_cosim_file(out_q,   OutFmt_g, "Result_Q.fix")

    return True

if __name__ == "__main__":
    generics = {
        "InFmt_g"   : "(1, 1, 8)",
        "MixFmt_g"  : "(1, 0, 15)",
        "OutFmt_g"  : "(1, 0, 8)",
        "Round_g"   : "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
