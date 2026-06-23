# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import sys
import os
import numpy as np
from scipy import signal as sps

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_fir_dec, olo_fix_plots
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Cosim Function
# ---------------------------------------------------------------------------------------------------
def cosim(output_path: str = None,
          generics:    dict = None,
          cosim_mode:  bool = True,
          test_mode: str = "normal"):

    # *** Parse Generics ***
    InFmt_g   = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    OutFmt_g  = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    CoefFmt_g = olo_fix_utils.fix_format_from_string(generics["CoefFmt_g"])
    Channels_g      = int(generics.get("Channels_g"))
    Ratio_g         = int(generics["Ratio_g"])
    Taps_g          = int(generics["Taps_g"])
    GuardBits_g     = int(generics.get("GuardBits_g", 1))
    Round_g         = FixRound[generics.get("Round_g", "NonSymPos_s")]
    Saturate_g      = FixSaturate[generics.get("Saturate_g", "Warn_s")]

    # *** Signal Lengths ***
    if cosim_mode:
        N_DIRAC  = Taps_g + 1
        N_PHASE2 = 50
    else:
        N_DIRAC  = Taps_g * 16
        N_PHASE2 = 2000

    # *** Coefficients ***
    cutoff = 1.0 / Ratio_g  # normalized cutoff (Nyquist = 1.0)
    coefs_f = sps.firwin(Taps_g, cutoff-1e-6)
    coefs =  cl_fix_from_real(coefs_f, CoefFmt_g)
    if test_mode == "overflow":
        coefs = cl_fix_from_real(np.ones(Taps_g) * 0.5, CoefFmt_g)

    # *** Build per-channel input signals ***
    in_ch  = []
    out_ch = []

    for ch in range(Channels_g):
        # --- Phase 1: Dirac on ch0, zeros on others ---
        if ch == 0:
            phase1 = np.zeros(N_DIRAC)
            phase1[0] = cl_fix_max_value(InFmt_g) * 0.5
        else:
            phase1 = np.zeros(N_DIRAC)

        # --- Phase 2: varied signals per channel ---
        scale = cl_fix_max_value(InFmt_g) * 0.5

        if ch == 0:
            rng = np.random.default_rng(ch)
            phase2 = rng.uniform(-scale, scale, N_PHASE2)
        elif ch == 1:
            step = np.zeros(N_PHASE2)
            step[N_PHASE2 // 2:] = scale * 0.7
            phase2 = step
        elif ch == 2:
            t = np.linspace(0, N_PHASE2 / 10e3, N_PHASE2)
            phase2 = sps.chirp(t, f0=0, f1=5e3-1e-6, t1=t[-1], method='linear') * scale
        else:
            rng = np.random.default_rng(ch + 100)
            phase2 = rng.uniform(-scale * (ch + 1) / Channels_g,
                                  scale * (ch + 1) / Channels_g, N_PHASE2)

        # Concatenate and quantize
        sig = np.concatenate([phase1, phase2])
        sig = cl_fix_from_real(sig, InFmt_g, FixSaturate.Sat_s)
        in_ch.append(sig)

        # --- Apply bit-true model ---
        dut = olo_fix_fir_dec(InFmt_g, OutFmt_g, CoefFmt_g, Ratio_g, coefs,
                              guard_bits=GuardBits_g, round=Round_g, saturate=Saturate_g)
        out = dut.process(sig)
        out_ch.append(out)

    # Plot if not in cosim mode
    if not cosim_mode:
        print("Coefficients:",coefs)
        for inp, out in zip(in_ch, out_ch):
            olo_fix_plots.plot_subplots({
                "Input"  : {"in"  : inp},
                "Output" : {"out" : out}
            })

    # *** Write Files ***
    if cosim_mode:
        writer = olo_fix_cosim(output_path)

        # Coefficient file (read by the testbench to initialize the DUT)
        writer.write_cosim_file(coefs, CoefFmt_g, "Coef.fix")

        # Per-channel files
        for ch in range(Channels_g):
            writer.write_cosim_file(in_ch[ch],  InFmt_g,  f"In_Ch{ch}.fix")
            writer.write_cosim_file(out_ch[ch], OutFmt_g, f"Out_Ch{ch}.fix")

        # Interleaved TDM files
        in_interleaved  = np.array(in_ch).T.flatten()
        out_interleaved = np.array(out_ch).T.flatten()
        writer.write_cosim_file(in_interleaved,  InFmt_g,  "In_Interleaved.fix")
        writer.write_cosim_file(out_interleaved, OutFmt_g, "Out_Interleaved.fix")

    return True


if __name__ == "__main__":
    generics = {
        "InFmt_g": "(1, 0, 15)",
        "OutFmt_g": "(1, 0, 15)",
        "CoefFmt_g": "(1, 1, 17)",
        "GuardBits_g": "2",
        "Channels_g": "2",
        "Ratio_g": "4",
        "Taps_g": "16",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "None_s",
    }
    cosim(generics=generics, cosim_mode=False, test_mode="overflow")
