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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_mix_c2r, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    # Parse Generics
    InFmt_g      = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    MixFmt_g     = olo_fix_utils.fix_format_from_string(generics["MixFmt_g"])
    OutFmt_g     = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Round_g      = FixRound[generics["Round_g"]]
    Saturate_g   = FixSaturate[generics["Saturate_g"]]
    IqHandling_g = generics["IqHandling_g"]

    # Calculation
    np.random.seed(42)
    sig_maxval = cl_fix_max_value(InFmt_g)
    sig_minval = cl_fix_min_value(InFmt_g)
    mix_maxval = cl_fix_max_value(MixFmt_g)
    mix_minval = cl_fix_min_value(MixFmt_g)

    # Rotating signal with rotating LO
    rot_sig = np.exp(1j * np.linspace(0, 2 * np.pi, 25)) * sig_maxval * 0.8
    rot_mix = np.exp(1j * np.linspace(0, 2 * np.pi, 25)) * mix_maxval * 0.8

    # Ramp signal with ramp LO
    ramp_sig_i = np.linspace(sig_maxval * 0.2, sig_maxval * 0.99, 25)
    ramp_sig_q = np.linspace(sig_minval * 0.2, sig_minval * 0.99, 25)
    ramp_mix   = np.linspace(mix_maxval * 0.2, mix_maxval * 0.99, 25)

    # Boundary values
    sig_i_boundary = np.array([sig_maxval, sig_minval, sig_maxval, sig_minval])
    sig_q_boundary = np.array([sig_maxval, sig_maxval, sig_minval, sig_minval])
    mix_i_boundary = np.array([mix_maxval, mix_maxval, mix_minval, mix_minval])
    mix_q_boundary = np.array([mix_maxval, mix_minval, mix_maxval, mix_minval])

    # Random data
    sig_i_rand = np.random.uniform(sig_minval, sig_maxval, 100)
    sig_q_rand = np.random.uniform(sig_minval, sig_maxval, 100)
    mix_i_rand = np.random.uniform(mix_minval, mix_maxval, 100)
    mix_q_rand = np.random.uniform(mix_minval, mix_maxval, 100)

    # Concatenate all test vectors
    sig_i = np.concatenate((rot_sig.real, ramp_sig_i, sig_i_boundary, sig_i_rand))
    sig_q = np.concatenate((rot_sig.imag, ramp_sig_q, sig_q_boundary, sig_q_rand))
    mix_i = np.concatenate((rot_mix.real, ramp_mix, mix_i_boundary, mix_i_rand))
    mix_q = np.concatenate((rot_mix.imag, ramp_mix, mix_q_boundary, mix_q_rand))

    # Quantize inputs
    sig_i_q = cl_fix_from_real(sig_i, InFmt_g)
    sig_q_q = cl_fix_from_real(sig_q, InFmt_g)
    mix_i_q = cl_fix_from_real(mix_i, MixFmt_g)
    mix_q_q = cl_fix_from_real(mix_q, MixFmt_g)

    # Run model
    dut = olo_fix_mix_c2r(InFmt_g, MixFmt_g, OutFmt_g, Round_g, Saturate_g)
    out_real = dut.process(sig_i_q, sig_q_q, mix_i_q, mix_q_q)

    # Plot if not in cosim mode
    if not cosim_mode:
        py_out = sig_i * mix_i + sig_q * mix_q
        error = py_out - out_real
        olo_fix_plots.plot_subplots({
            "Output"  : {"out_real" : out_real},
            "Error"   : {"error"    : error},
            "Input"   : {"sig_i"    : sig_i_q, "sig_q" : sig_q_q,
                         "mix_i"    : mix_i_q, "mix_q" : mix_q_q}
        })

    # Write cosim files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)

        if IqHandling_g == "Parallel":
            # Parallel: separate I/Q files + Last
            last_par = np.random.randint(0, 2, size=len(sig_i_q)).astype(float)
            writer.write_cosim_file(sig_i_q,   InFmt_g,        "SigI.fix")
            writer.write_cosim_file(sig_q_q,   InFmt_g,        "SigQ.fix")
            writer.write_cosim_file(mix_i_q,   MixFmt_g,       "MixI.fix")
            writer.write_cosim_file(mix_q_q,   MixFmt_g,       "MixQ.fix")
            writer.write_cosim_file(out_real,  OutFmt_g,       "Result_Real.fix")
            writer.write_cosim_file(last_par,  FixFormat(0,1,0), "LastPar.fix")
        else:
            # TDM: interleaved I/Q files
            sig_iq  = np.column_stack((sig_i_q, sig_q_q)).ravel()
            mix_iq  = np.column_stack((mix_i_q, mix_q_q)).ravel()
            last    = np.random.randint(0, 2, size=len(sig_i_q)).astype(float)
            last_tdm = np.ravel(np.column_stack((np.zeros_like(last), last)))
            writer.write_cosim_file(sig_iq,   InFmt_g,        "SigIQ.fix")
            writer.write_cosim_file(mix_iq,   MixFmt_g,       "MixIQ.fix")
            writer.write_cosim_file(out_real, OutFmt_g,       "Result_Real.fix")
            writer.write_cosim_file(last_tdm, FixFormat(0,1,0), "LastTdm.fix")
            # Resync test: 10 TDM samples, then I marked as Last, then 10 more TDM samples
            resync_sig_iq = np.concatenate((sig_iq[0:10], sig_iq[0:1], sig_iq[0:10]))
            resync_mix_iq = np.concatenate((mix_iq[0:10], mix_iq[0:1], mix_iq[0:10]))
            resync_out    = np.concatenate((out_real[0:5], out_real[0:5]))
            resync_last   = np.concatenate((last_tdm[0:10], [1.0], last_tdm[0:10]))
            resync_last_out = np.concatenate((last_tdm[0:10], last_tdm[0:10]))
            writer.write_cosim_file(resync_sig_iq,  InFmt_g,        "Resync_SigIQ.fix")
            writer.write_cosim_file(resync_mix_iq,  MixFmt_g,       "Resync_MixIQ.fix")
            writer.write_cosim_file(resync_out,     OutFmt_g,       "Resync_ResultReal.fix")
            writer.write_cosim_file(resync_last,    FixFormat(0,1,0), "Resync_LastIn.fix")
            writer.write_cosim_file(resync_last_out, FixFormat(0,1,0), "Resync_LastOut.fix")

    return True

if __name__ == "__main__":
    generics = {
        "InFmt_g"      : "(1, 8, 8)",
        "MixFmt_g"     : "(1, 0, 15)",
        "OutFmt_g"     : "(1, 9, 8)",
        "Round_g"      : "NonSymPos_s",
        "Saturate_g"   : "Sat_s",
        "IqHandling_g" : "Parallel"
    }
    cosim(generics=generics, cosim_mode=False)
