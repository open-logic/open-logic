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
from scipy import signal as sps

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_cic_dec, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics    : dict = None, 
          cosim_mode  : bool = True):
    
    # Constants (shorter for cosim than for plotting)
    if cosim_mode:
        SAMPLES_RAND = 100
        SAMPLES_LOGIC = 200
    else:
        SAMPLES_RAND = 1000
        SAMPLES_LOGIC = 10000

    #Parse Generics
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Order_g = int(generics["Order_g"])
    Ratio_g = int(generics["Ratio_g"])
    Channels_g = int(generics.get("Channels_g", 1))
    DiffDelay_g = int(generics["DiffDelay_g"])
    GainCorrCoefFmt_g = olo_fix_utils.fix_format_from_string(generics["GainCorrCoefFmt_g"], tolerate_str=True)
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    out_ch = []
    out_rminus1_ch = []
    in_ch = []

    for ch in range(Channels_g):
        #Generate inputs
        in_scale = cl_fix_max_value(InFmt_g)*(ch+1)/Channels_g
        in_min = cl_fix_min_value(InFmt_g)*(ch+1)/Channels_g
        # Random Signal
        sig_rand = cl_fix_from_real(np.random.uniform(in_min, in_scale, SAMPLES_RAND), InFmt_g, FixSaturate.Sat_s)
        # Human Readable
        fs = 10e3
        sig_logic = sps.chirp(np.linspace(0, SAMPLES_LOGIC/fs, SAMPLES_LOGIC), t1=SAMPLES_LOGIC/fs, f0=0, f1=fs/2, method='linear')*in_scale
        # Concatenate
        sig_in = np.concatenate((sig_logic, sig_rand))

        #Quantize inputs
        sig_in = cl_fix_from_real(sig_in, InFmt_g)

        #Calcualte (main DUT)
        dut = olo_fix_cic_dec(order=Order_g, ratio=Ratio_g, diff_delay=DiffDelay_g,
                            in_fmt=InFmt_g, out_fmt=OutFmt_g,
                            gain_corr_coef_fmt=GainCorrCoefFmt_g,
                            round=Round_g, saturate=Saturate_g)
        out = dut.process(sig_in)

        # Calculate (R-1 DUT) - used for verification with variable ratio
        dut_rminus1 = olo_fix_cic_dec(order=Order_g, ratio=Ratio_g-1, diff_delay=DiffDelay_g,
                            in_fmt=InFmt_g, out_fmt=OutFmt_g,
                            gain_corr_coef_fmt=GainCorrCoefFmt_g,
                            round=Round_g, saturate=Saturate_g)
        out_rminus1 = dut_rminus1.process(sig_in)

        #Create output lists
        out_ch.append(out)
        in_ch.append(sig_in)
        out_rminus1_ch.append(out_rminus1)
    
    # Plot if enabled (only ch0)
    if not cosim_mode:
        in_data = {"Input" : in_ch[0]}
        out_data = {"Output" : out_ch[0]}
        out_log = {"Output Logarithmic" : np.log10(np.abs(out_ch[0])+1e-9)}
        olo_fix_plots.plot_subplots({"Input Data" : in_data, "Output Data" : out_data, "Output Logarithmic" : out_log},)

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        # Per Channel
        for ch in range(Channels_g):
            writer.write_cosim_file(in_ch[ch], InFmt_g, f"In_Ch{ch}.fix")
            writer.write_cosim_file(out_ch[ch], OutFmt_g, f"Out_Ch{ch}.fix")
            writer.write_cosim_file(out_rminus1_ch[ch], OutFmt_g, f"Out_Rminus1_Ch{ch}.fix")
        # Interleaved
        in_interleaved = np.array(in_ch).T.flatten()
        writer.write_cosim_file(in_interleaved, InFmt_g, "In_Interleaved.fix")
        out_interleaved = np.array(out_ch).T.flatten()
        writer.write_cosim_file(out_interleaved, OutFmt_g, "Out_Interleaved.fix")
        out_rminus1_interleaved = np.array(out_rminus1_ch).T.flatten()
        writer.write_cosim_file(out_rminus1_interleaved, OutFmt_g, "Out_Rminus1_Interleaved.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "InFmt_g": "(1, 0, 15)",
        "OutFmt_g": "(1, 0, 18)",
        "Order_g": "4",
        "Ratio_g": "4",
        "Channels_g": "1",
        "DiffDelay_g": "1",
        "GainCorrCoefFmt_g": "(0, 1, 16)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
