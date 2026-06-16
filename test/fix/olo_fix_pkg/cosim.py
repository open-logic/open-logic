# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
import sys
import os
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim
from en_cl_fix_pkg import *

# ---------------------------------------------------------------------------------------------------
# Cosim Function
# ---------------------------------------------------------------------------------------------------
def cosim(output_path: str = None,
          generics:    dict = None,
          cosim_mode:  bool = True):

    writer = olo_fix_cosim(output_path)
    writer.write_cosim_file(np.array([0.75, -1.0]), FixFormat(1, 0, 15), "data_1_0_15.fix")
    writer.write_cosim_file(np.array([0.5, 1.5]), FixFormat(0, 1, 5), "data_0_1_5.fix")

    return True

if __name__ == "__main__":
    cosim(output_path=".", cosim_mode=False)

