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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_lin_approx_qsin, olo_fix_plots
from en_cl_fix_pkg import *

def stimuli_codes(fmt : FixFormat, samples : int, critical_step : int):
    """
    Input codes covering the whole range of a format

    All codes are used if the format is small enough. Otherwise a sweep, the codes at the critical
    angles (where the mirrored address wraps) and their neighbours are used.
    """
    width = cl_fix_width(fmt)
    all_codes = 2**width

    if all_codes <= samples:
        codes = np.arange(all_codes)
    else:
        sweep = np.linspace(0, all_codes - 1, samples).astype(np.int64)
        step = min(max(critical_step, 1), all_codes)
        critical = np.arange(0, all_codes, step)
        # The neighbours of the critical codes are the worst case for the approximation
        codes = np.concatenate((sweep, critical, critical + 1, critical - 1))
        codes = np.unique(np.mod(codes, all_codes))

    # Convert to the signed integer representation expected by cl_fix_from_integer
    if fmt.S == 1:
        codes = np.where(codes >= 2**(width - 1), codes - 2**width, codes)
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

    #Generate inputs - the quarter phase covers [0, 0.25). Port A sweeps the quadrant, port B is
    #driven with the mirrored phase 0.25-t, which is how olo_fix_sin obtains the cosine.
    phase_a = stimuli_codes(InFmt_g, SAMPLES, 2**cl_fix_width(InFmt_g))
    phase_b = cl_fix_from_real((0.25 - phase_a) % 0.25, InFmt_g)

    #Calculate
    dut = olo_fix_lin_approx_qsin(OutFmt_g, InFmt_g, Round_g, Saturate_g)
    out_a = dut.process(phase_a)
    out_b = dut.process(phase_b)

    # Plot if enabled
    if not cosim_mode:
        expected_a = np.sin(phase_a*2*np.pi)*dut.peak
        expected_b = np.sin(phase_b*2*np.pi)*dut.peak
        in_data = {"Phase A [rotations]" : phase_a, "Phase B [rotations]" : phase_b}
        out_data = {"Out A" : out_a, "Out B" : out_b}
        err_data = {"Error A [LSB]" : (out_a - expected_a)*2**OutFmt_g.F,
                    "Error B [LSB]" : (out_b - expected_b)*2**OutFmt_g.F}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data,
                                     "Error Data" : err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(phase_a, InFmt_g, "PhaseA.fix")
        writer.write_cosim_file(phase_b, InFmt_g, "PhaseB.fix")
        writer.write_cosim_file(out_a, OutFmt_g, "OutA.fix")
        writer.write_cosim_file(out_b, OutFmt_g, "OutB.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "OutFmt_g": "(1, 0, 16)",
        "InFmt_g": "(0, -2, 20)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
