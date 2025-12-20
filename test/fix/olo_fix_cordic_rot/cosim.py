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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_cordic_rot, olo_fix_plots
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
    InMagFmt_g = olo_fix_utils.fix_format_from_string(generics["InMagFmt_g"])
    InAngFmt_g = olo_fix_utils.fix_format_from_string(generics["InAngFmt_g"])
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    IntXyFmt_g = olo_fix_utils.fix_format_from_string(generics["IntXyFmt_g"], tolerate_str=True)
    IntAngFmt_g = olo_fix_utils.fix_format_from_string(generics["IntAngFmt_g"], tolerate_str=True)
    Iterations_g = int(generics["Iterations_g"])
    GainCorrCoefFmt_g = olo_fix_utils.fix_format_from_string(generics["GainCorrCoefFmt_g"], tolerate_str=True)
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    #Generate inputs
    in_scale = cl_fix_max_value(InMagFmt_g)
    # Random Signal
    np.random.seed(0)
    sig_rand_abs = cl_fix_from_real(np.random.rand(SAMPLES_RAND)*in_scale, InMagFmt_g, FixSaturate.Sat_s)
    sig_rand_ang = cl_fix_from_real(np.random.rand(SAMPLES_RAND)*in_scale, InAngFmt_g, FixSaturate.Sat_s)
    # Human Readable
    angles_logic = np.linspace(0, 1, SAMPLES_LOGIC)
    abs_logic = np.linspace(0.01, in_scale, SAMPLES_LOGIC)
    sig_logic_abs = cl_fix_from_real(abs_logic, InMagFmt_g, FixSaturate.Sat_s)
    sig_logic_ang = cl_fix_from_real(angles_logic, InAngFmt_g, FixSaturate.Sat_s)
    # Concatenate
    sig_mag = np.concatenate((sig_logic_abs, sig_rand_abs))
    sig_ang = np.concatenate((sig_logic_ang, sig_rand_ang))   

    #Quantize inputs
    sig_mag = cl_fix_from_real(sig_mag, InMagFmt_g)
    sig_ang = cl_fix_from_real(sig_ang, InAngFmt_g)

    #Calcualte
    dut = olo_fix_cordic_rot(InMagFmt_g, InAngFmt_g, OutFmt_g, IntXyFmt_g, IntAngFmt_g, 
                             Iterations_g, GainCorrCoefFmt_g, Round_g, Saturate_g)
    out_i, out_q = dut.process(sig_mag, sig_ang)
    
    # Plot if enabled
    if not cosim_mode:
        in_data = {"Magnitude" : sig_mag, "Angle" : sig_ang}
        out_data = {"Output I" : out_i, "Output Q" : out_q}
        expected_i = np.cos(sig_ang*2*np.pi)*sig_mag
        expected_q = np.sin(sig_ang*2*np.pi)*sig_mag
        if str(GainCorrCoefFmt_g) == "NONE":
            expected_i = expected_i * dut.cordic_gain
            expected_q = expected_q * dut.cordic_gain
        err_data = {"Error I [LSB]" :  (out_i-expected_i)*2**OutFmt_g.F, 
                    "Error Q [LSB]" : (out_q-expected_q)*2**OutFmt_g.F}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data, "Error Data" : err_data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(sig_mag, InMagFmt_g, "InMag.fix")
        writer.write_cosim_file(sig_ang, InAngFmt_g, "InAng.fix")
        writer.write_cosim_file(out_i, OutFmt_g, "OutI.fix")
        writer.write_cosim_file(out_q, OutFmt_g, "OutQ.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "InMagFmt_g": "(0, 0, 16)",
        "InAngFmt_g": "(0, 0, 15)",
        "OutFmt_g": "(1, 2, 16)",
        "IntXyFmt_g": "(1, 2, 22)",
        "IntAngFmt_g": "(1, -2, 23)",
        "Iterations_g": "21",
        "GainCorrCoefFmt_g": "(0, 0, 17)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
