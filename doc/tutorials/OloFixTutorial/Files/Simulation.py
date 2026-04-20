# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
# Add olo_fix to the path
import string
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_pkg_writer
from en_cl_fix_pkg import *

# Imports
import numpy as np
from matplotlib import pyplot as plt
from PlantModel import Plant
from Controller import *


# ---------------------------------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------------------------------
FS = 1.0e6
TS = 1/FS

# Quantize Inputs
KP = 20
KI = 0.4
ILIM = 3.5
KP_FIX = cl_fix_from_real(20, FMT_KP)
KI_FIX = cl_fix_from_real(0.4, FMT_KI)
ILIM_FIX = cl_fix_from_real(3.5, FMT_ILIM)


# Setup different controller models
controllers = {"Float"    : ControllerFloat(kp=KP, ki=KI, ilim=ILIM),
               "EnClFix"  : ControllerEnClFix(kp=KP_FIX, ki=KI_FIX, ilim=ILIM_FIX),
               "OloFix"   : ControllerOloFix(kp=KP_FIX, ki=KI_FIX, ilim=ILIM_FIX)}

# Prepare Input
target = np.concatenate([np.zeros(10), np.ones(300)*1.5, np.zeros(100)])
control_values = {}
actual_values = {}

# Execute all controller models
for name, controller in controllers.items():

    # Prepare arrays to fetch data used later on to plot
    output = np.zeros_like(target)
    control_value = np.zeros_like(target)
    actual_value = np.zeros_like(target)

    # Set up the plant model
    plant = Plant(TS)
    v_actual = 0

    # Run simulation
    for i, ix in enumerate(target):

        #quantize input (ADC)
        if name == "Float":
            ctrl_in = v_actual
        else:
            ctrl_in = cl_fix_from_real(v_actual, FMT_IN)
        actual_value[i] = ctrl_in

        #Simulate Controller
        controller.set_target(ix)
        ctrl_out = controller.simulate(ctrl_in)
        control_value[i] = ctrl_out

        # Clip output (DAC)
        v_in = np.clip(ctrl_out, 0, 5)

        #Simulate Plant
        output[i] = v_actual= plant.simulate(v_in)  

        # Change R2 at runtime
        if i == 150:
            plant.set_r2(500)

    # plot results of single simulation
    plt.figure(name)
    plt.title(name)
    plt.plot(target, color="r", label="Target")
    plt.plot(output, color="b", label="Output")
    plt.plot(control_value, color="g", label="Control Value")
    plt.legend()

    # Store controller output for comparison
    control_values[name] = control_value
    actual_values[name] = actual_value

# Plot to compare outputs of different controller models
plt.figure("output diff")
plt.title("Output diff")
plt.plot(control_values["EnClFix"]-control_values["Float"], color="r", label="EnClFix - Float")
plt.plot(control_values["OloFix"]-control_values["EnClFix"], color="b", label="OloFix - EnClFix")
plt.legend()
plt.show()

#Write cosimulation files
out_dir = os.path.abspath(os.path.dirname(__file__))
writer = olo_fix_cosim(out_dir)
writer.write_cosim_file(actual_values["EnClFix"], FMT_IN, "InputActual.fix")
writer.write_cosim_file(target, FMT_IN, "InputTarget.fix")
writer.write_cosim_file(control_values["EnClFix"], FMT_OUT, "Output.fix")

# Write VHDL Formats Package
out_dir = os.path.abspath(os.path.dirname(__file__))
vhdl_pkg_writer = olo_fix_pkg_writer()
vhdl_pkg_writer.add_constant("FmtIn_c", FixFormat, FMT_IN)
vhdl_pkg_writer.add_constant("FmtOut_c", FixFormat, FMT_OUT)
vhdl_pkg_writer.add_constant("FmtKp_c", FixFormat, FMT_KP)
vhdl_pkg_writer.add_constant("FmtKi_c", FixFormat, FMT_KI)
vhdl_pkg_writer.add_constant("FmtIlim_c", FixFormat, FMT_ILIM)
vhdl_pkg_writer.add_constant("FmtIlimNeg_c", FixFormat, FMT_ILIM_NEG)
vhdl_pkg_writer.add_constant("FmtErr_c", FixFormat, FMT_ERR)
vhdl_pkg_writer.add_constant("FmtPpart_c", FixFormat, FMT_PPART)
vhdl_pkg_writer.add_constant("FmtImult_c", FixFormat, FMT_IMULT)
vhdl_pkg_writer.add_constant("FmtIadd_c", FixFormat, FMT_IADD)
vhdl_pkg_writer.add_constant("FmtI_c", FixFormat, FMT_I)
vhdl_pkg_writer.write_vhdl_pkg("fix_formats_pkg", out_dir)

# Write Verilog Formats Package
verilog_pkg_writer = olo_fix_pkg_writer()
# Formats (as string because Verilog does not have a fix format)
verilog_pkg_writer.add_constant("FmtIn_c", FixFormat, FMT_IN, as_string=True)
verilog_pkg_writer.add_constant("FmtOut_c", FixFormat, FMT_OUT, as_string=True)
verilog_pkg_writer.add_constant("FmtKp_c", FixFormat, FMT_KP, as_string=True)
verilog_pkg_writer.add_constant("FmtKi_c", FixFormat, FMT_KI, as_string=True)
verilog_pkg_writer.add_constant("FmtIlim_c", FixFormat, FMT_ILIM, as_string=True)
verilog_pkg_writer.add_constant("FmtIlimNeg_c", FixFormat, FMT_ILIM_NEG, as_string=True)
verilog_pkg_writer.add_constant("FmtErr_c", FixFormat, FMT_ERR, as_string=True)
verilog_pkg_writer.add_constant("FmtPpart_c", FixFormat, FMT_PPART, as_string=True)
verilog_pkg_writer.add_constant("FmtImult_c", FixFormat, FMT_IMULT, as_string=True)
verilog_pkg_writer.add_constant("FmtIadd_c", FixFormat, FMT_IADD, as_string=True)
verilog_pkg_writer.add_constant("FmtI_c", FixFormat, FMT_I, as_string=True)
# Widths for siganl declarations
verilog_pkg_writer.add_constant("FmtIn_w", int, cl_fix_width(FMT_IN))
verilog_pkg_writer.add_constant("FmtOut_w", int, cl_fix_width(FMT_OUT))
verilog_pkg_writer.add_constant("FmtKp_w", int, cl_fix_width(FMT_KP))
verilog_pkg_writer.add_constant("FmtKi_w", int, cl_fix_width(FMT_KI))
verilog_pkg_writer.add_constant("FmtIlim_w", int, cl_fix_width(FMT_ILIM))
verilog_pkg_writer.add_constant("FmtIlimNeg_w", int, cl_fix_width(FMT_ILIM_NEG))
verilog_pkg_writer.add_constant("FmtErr_w", int, cl_fix_width(FMT_ERR))   
verilog_pkg_writer.add_constant("FmtPpart_w", int, cl_fix_width(FMT_PPART))
verilog_pkg_writer.add_constant("FmtImult_w", int, cl_fix_width(FMT_IMULT))
verilog_pkg_writer.add_constant("FmtIadd_w", int, cl_fix_width(FMT_IADD))
verilog_pkg_writer.add_constant("FmtI_w", int, cl_fix_width(FMT_I))
verilog_pkg_writer.write_verilog_header("fix_formats_hdr", out_dir)

