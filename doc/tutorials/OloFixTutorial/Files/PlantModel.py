# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# Schematic:
# 
#          Vin
#           |
#           R1
#           |
#           +-------- Vout
#           |   |
#           C   R2 (variable)
#           |   |
#           +-+-+
#             |
#           Ground

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import numpy as np
from matplotlib import pyplot as plt

# ---------------------------------------------------------------------------------------------------
# Implementation
# ---------------------------------------------------------------------------------------------------
# Class definition
class Plant:

    # Constants
    C_FIX = 100.0e-9
    R1_FIX = 330
    R2_INIT = 1.0e3

    def __init__(self, dt : float):
        """ 
        Constructor for the Plant class.

        Args:
            dt (float): Time step for the simulation in seconds.
        """
        self._c_charge = 0
        self._r2 = self.R2_INIT
        self._dt = dt

    def simulate(self, v_in : float) -> float:
        """ 
        Simulate one time- step of the plant model.

        Args:
            v_in (float): Input voltage to the plant.
        Returns:
            float: Output voltage of the plant.
        """
        #The voltage over R2/C is given by the charge in the capacitor and its capacitance
        v_c_r2 = self._c_charge / self.C_FIX

        # The current in R1 is given by the voltage over R1 and its resistance
        i_r1 = (v_in - v_c_r2)/self.R1_FIX

        # The current in R2 is given by the voltage over R2 and its resistance
        i_r2 = v_c_r2 / self._r2

        # Calculate the change in charge in the capacitor
        self._c_charge += (i_r1-i_r2)*self._dt

        # Return output voltage
        return v_c_r2

    def set_r2(self, value : float):
        """
        Set the resistance R2 to a new value.
        
        Args:
            value (float): New resistance value for R2.
        """
        self._r2 = value

# Main functio nto try out the model
if __name__ == "__main__":
    p = Plant(1.0e-6)

    input = np.concatenate([np.zeros(10), np.ones(100)*2.5, np.zeros(10)])
    output = np.zeros_like(input)

    for i, ix in enumerate(input):
        output[i] = p.simulate(ix)

        if i == 60:
            p.set_r2(800)

    plt.plot(input, color="r")
    plt.plot(output, color="b")
    plt.show()


