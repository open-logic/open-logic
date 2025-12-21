# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_cordic_vect, olo_fix_plots
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
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    OutMagFmt_g = olo_fix_utils.fix_format_from_string(generics["OutMagFmt_g"])
    OutAngFmt_g = olo_fix_utils.fix_format_from_string(generics["OutAngFmt_g"])
    IntXyFmt_g = olo_fix_utils.fix_format_from_string(generics["IntXyFmt_g"], tolerate_str=True)
    IntAngFmt_g = olo_fix_utils.fix_format_from_string(generics["IntAngFmt_g"], tolerate_str=True)
    Iterations_g = int(generics["Iterations_g"])
    GainCorrCoefFmt_g = olo_fix_utils.fix_format_from_string(generics["GainCorrCoefFmt_g"], tolerate_str=True)
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Generate inputs
    in_scale = cl_fix_max_value(InFmt_g)
    # Random Signal
    np.random.seed(0)
    sig_rand_i = cl_fix_from_real(np.random.rand(SAMPLES_RAND)*in_scale, InFmt_g, FixSaturate.Sat_s)
    sig_rand_q = cl_fix_from_real(np.random.rand(SAMPLES_RAND)*in_scale, InFmt_g, FixSaturate.Sat_s)
    # Human Readable
    angles_logic = np.linspace(0, 2*np.pi, SAMPLES_LOGIC)
    abs_logic = np.linspace(0.01, in_scale, SAMPLES_LOGIC)
    sig_logic_i = cl_fix_from_real(np.cos(angles_logic)*abs_logic, InFmt_g, FixSaturate.Sat_s)
    sig_logic_q = cl_fix_from_real(np.sin(angles_logic)*abs_logic, InFmt_g, FixSaturate.Sat_s)
    # Concatenate
    sig_i = np.concatenate((sig_logic_i, sig_rand_i))
    sig_q = np.concatenate((sig_logic_q, sig_rand_q))   

    #Quantize inputs
    sig_i = cl_fix_from_real(sig_i, InFmt_g)
    sig_q = cl_fix_from_real(sig_q, InFmt_g)
    sig_cplx = sig_i + 1j*sig_q

    #Calcualte
    dut = olo_fix_cordic_vect(InFmt_g, OutMagFmt_g, OutAngFmt_g, IntXyFmt_g, IntAngFmt_g, 
                             Iterations_g, GainCorrCoefFmt_g, Round_g, Saturate_g)
    out_mag, out_ang = dut.process(sig_i, sig_q)
    
    # Plot if enabled
    if not cosim_mode:
        in_data = {"Input I" : sig_i, "Input Q" : sig_q}
        out_data = {"Output Magnitude" : out_mag, "Output Angle" : out_ang}
        # Calculate angular error accounting for circular wrapping
        ang_expected = np.angle(sig_cplx)/(2*np.pi)  # Convert to -0.5 to +0.5 range
        ang_diff = out_ang - ang_expected
        # Wrap difference to [-0.5, 0.5] range
        ang_diff = np.where(ang_diff > 0.5, ang_diff - 1.0, ang_diff)
        #Expected magnitude
        mag_exp = abs(sig_cplx)
        if str(GainCorrCoefFmt_g) == "NONE":
            mag_exp = mag_exp * dut.cordic_gain
        err_data = {"Error Magnitude [LSB]" :  (out_mag - mag_exp)*2**OutMagFmt_g.F, 
                "Error Angle [LSB]" : ang_diff * 2**OutAngFmt_g.F}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data, "Error Data" : err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(sig_i, InFmt_g, "InI.fix")
        writer.write_cosim_file(sig_q, InFmt_g, "InQ.fix")
        writer.write_cosim_file(out_mag, OutMagFmt_g, "OutMag.fix")
        writer.write_cosim_file(out_ang, OutAngFmt_g, "OutAng.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "InFmt_g": "(1, 0, 15)",
        "OutMagFmt_g": "(0, 2, 16)",
        "OutAngFmt_g": "(0, 0, 15)",
        "IntXyFmt_g": "(1,2,22)",
        "IntAngFmt_g": "AUTO",
        "Iterations_g": "13",
        "GainCorrCoefFmt_g": "(0, 0, 17)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
