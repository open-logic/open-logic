# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
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
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_limit, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None, 
          generics : dict = None, 
          cosim_mode : bool = True):

    #Parse Generics
    InFmt_g = olo_fix_utils.fix_format_from_string(generics["InFmt_g"])
    ResultFmt_g = olo_fix_utils.fix_format_from_string(generics["ResultFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]
    UseFixedLimits_g = generics["UseFixedLimits_g"]
    if not UseFixedLimits_g:
        LimLoFmt_g = olo_fix_utils.fix_format_from_string(generics["LimLoFmt_g"])
        LimHiFmt_g = olo_fix_utils.fix_format_from_string(generics["LimHiFmt_g"])
    else:
        LimLoFmt_g = InFmt_g
        LimHiFmt_g = InFmt_g
    FixedLimLo_g = float(generics["FixedLimLo_g"]) if UseFixedLimits_g else None
    FixedLimHi_g = float(generics["FixedLimHi_g"]) if UseFixedLimits_g else None

    #Generate inputs
    d_lo = cl_fix_min_value(InFmt_g)
    d_hi = cl_fix_max_value(InFmt_g)
    data = np.concatenate([np.linspace(d_lo, d_hi, 50), np.linspace(d_lo, d_hi, 50)])
    lim_lo = np.concatenate([np.ones(50)*cl_fix_min_value(LimLoFmt_g), np.ones(50)*cl_fix_min_value(LimLoFmt_g)/2])
    lim_hi = np.concatenate([np.ones(50)*cl_fix_max_value(LimHiFmt_g), np.ones(50)*cl_fix_max_value(LimHiFmt_g)/2])

    #Quantize inputs
    data = cl_fix_from_real(data, InFmt_g)
    lim_lo = cl_fix_from_real(lim_lo, LimLoFmt_g)
    lim_hi = cl_fix_from_real(lim_hi, LimHiFmt_g)

    #Calcualte
    if not UseFixedLimits_g:
        dut = olo_fix_limit(InFmt_g, LimLoFmt_g, LimHiFmt_g, ResultFmt_g, Round_g, Saturate_g)
        out_data = dut.process(data, lim_lo=lim_lo, lim_hi=lim_hi)
    else:
        dut = olo_fix_limit(InFmt_g, LimLoFmt_g, LimHiFmt_g, ResultFmt_g, Round_g, Saturate_g,
                            lim_lo_fixed=FixedLimLo_g, lim_hi_fixed=FixedLimHi_g)
        out_data = dut.process(data)

    # Plot if enabled
    if not cosim_mode:
        data = {"Input" : data, "Output" : out_data}
        if UseFixedLimits_g:
            data["LimLo"] = np.ones(100)*FixedLimLo_g
            data["LimHi"] = np.ones(100)*FixedLimHi_g
        else:
            data["LimLo"] = lim_lo
            data["LimHi"] = lim_hi
        olo_fix_plots.plot_subplots({"Limit" : data})

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(data, InFmt_g, "Data.fix")
        writer.write_cosim_file(lim_lo, LimLoFmt_g, "LimLo.fix")
        writer.write_cosim_file(lim_hi, LimHiFmt_g, "LimHi.fix")
        writer.write_cosim_file(out_data, ResultFmt_g, "Result.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "InFmt_g": "(1, 4, 4)",
        "LimLoFmt_g": "(1, 4, 4)",
        "LimHiFmt_g": "(0, 4, 4)",
        "ResultFmt_g": "(1, 4, 4)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s",
        "UseFixedLimits_g": False,
        "LimLoFixed_g": "-3.25",
        "LimHiFixed_g": "5.0"
    }
    cosim(generics=generics, cosim_mode=False)
