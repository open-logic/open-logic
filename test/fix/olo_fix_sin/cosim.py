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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_sin, olo_fix_plots
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

    #Generate inputs - one quadrant is 2**(F-2) codes, hence those are the critical angles
    phase_sweep = np.linspace(cl_fix_min_value(InFmt_g), cl_fix_max_value(InFmt_g), SAMPLES)
    phase_critical = [0, 0.25, 0.5, 0.75]
    phase = np.concatenate((phase_sweep, phase_critical))

    #quantize input
    phase = cl_fix_from_real(phase, InFmt_g)

    #Calculate
    dut = olo_fix_sin(OutFmt_g, InFmt_g, Round_g, Saturate_g)
    out_sin, out_cos = dut.process(phase)

    # Plot if enabled
    if not cosim_mode:
        expected_sin = np.sin(phase*2*np.pi)*dut.peak
        expected_cos = np.cos(phase*2*np.pi)*dut.peak
        in_data = {"Phase [rotations]" : phase}
        out_data = {"Sine" : out_sin, "Cosine" : out_cos}
        err_data = {"Error Sine [LSB]" : (out_sin - expected_sin)*2**OutFmt_g.F,
                    "Error Cosine [LSB]" : (out_cos - expected_cos)*2**OutFmt_g.F}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data,
                                     "Error Data" : err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(phase, InFmt_g, "Phase.fix")
        writer.write_cosim_file(out_sin, OutFmt_g, "Sin.fix")
        writer.write_cosim_file(out_cos, OutFmt_g, "Cos.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "OutFmt_g": "(1, 1, 16)",
        "InFmt_g": "(0, 0, 18)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
