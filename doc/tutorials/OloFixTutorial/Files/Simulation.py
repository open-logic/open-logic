# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
# Add olo_fix to the path
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../../src/fix/python")))
from olo_fix import olo_fix_cosim
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


