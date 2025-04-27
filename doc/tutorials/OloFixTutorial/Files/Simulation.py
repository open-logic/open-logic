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

# Imports
import numpy as np
from matplotlib import pyplot as plt
from PlantModel import Plant
from Controller import *
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------------------------------
FS = 1.0e6
TS = 1/FS

# Quantize Inputs
KP = cl_fix_from_real(20, FMT_KP)
KI = cl_fix_from_real(0.4, FMT_KI)
ILIM = cl_fix_from_real(3.5, FMT_ILIM)


# Setup different controller models
controllers = {"Float"    : ControllerFloat(kp=KP, ki=KI, ilim=ILIM),
               "EnClFix"  : ControllerEnClFix(kp=KP, ki=KI, ilim=ILIM),
               "OloFix"   : ControllerOloFix(kp=KP, ki=KI, ilim=ILIM)}

# Prepare Input
target = np.concatenate([np.zeros(10), np.ones(300)*1.5, np.zeros(100)])
control_values = {}
debug = {}

# Execute all controller models
for name, controller in controllers.items():

    # Prepare arrays to fetch data used later on to plot
    output = np.zeros_like(target)
    control_value = np.zeros_like(target)

    # Set up the plant model
    plant = Plant(TS)
    v_actual = 0

    # Run simulation
    for i, ix in enumerate(target):

        #quantize input
        ctrl_in = cl_fix_from_real(v_actual, FMT_IN)

        #Simulate
        ctrl_out = controller.simulate(ctrl_in)
        control_value[i] = np.clip(ctrl_out,0, 5)
        output[i] = v_actual= plant.simulate(control_value[i])
        controller.set_target(ix)

        # Change R2 at runtime
        if i == 150:
            plant.set_r2(500)

    # plot results of single simulation
    plt.figure(name)
    plt.plot(target, color="r", label="Target")
    plt.plot(output, color="b", label="Output")
    plt.plot(control_value, color="g", label="Control Value")
    plt.legend()

    # Store controller output for comparison
    control_values[name] = control_value

# Plot to compare outputs of different controller models
plt.figure("output diff")
plt.plot(control_values["EnClFix"]-control_values["Float"], color="r", label="EnClFix - Float")
plt.plot(control_values["OloFix"]-control_values["EnClFix"], color="b", label="OloFix - EnClFix")
plt.legend()
plt.show()