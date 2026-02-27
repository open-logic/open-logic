########################################################################################################################
# Imports
########################################################################################################################
import os
import sys

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../src/fix/python")))
from olo_fix import olo_fix_pkg_writer
from en_cl_fix_pkg import *


########################################################################################################################
# Code Generators
########################################################################################################################
def generate():
    #Execute from sim directory
    os.chdir(os.path.dirname(os.path.realpath(__file__)))

    # Package writer
    pkg_writer = olo_fix_pkg_writer()
    pkg_writer.add_constant("ConstInt_c", int, 42)
    pkg_writer.add_constant("ConstFloat_c", float, 3.14)
    pkg_writer.add_constant("ConstFixFormat_c", FixFormat, FixFormat(1, 8, 8))
    pkg_writer.add_constant("ConstString_c", str, "Hello")

    pkg_writer.add_vector("VectorInt_c", int, [1, 2, 3])
    pkg_writer.add_vector("VectorFloat_c", float, [1.0, 2.0, 3.0])
    pkg_writer.add_vector("VectorFixFormat_c", FixFormat, [FixFormat(1, 8, 8), FixFormat(1, 16, 16)])

    pkg_writer.add_constant("ConstIntAsString_c", int, 42, as_string=True)
    pkg_writer.add_constant("ConstFloatAsString_c", float, 3.14, as_string=True)
    pkg_writer.add_constant("ConstFixFormatAsString_c", FixFormat, FixFormat(1, 8, 8), as_string=True)

    pkg_writer.add_vector("VectorIntAsString_c", int, [1, 2, 3], as_string=True)
    pkg_writer.add_vector("VectorFloatAsString_c", float, [1.0, 2.0, 3.0], as_string=True)
    pkg_writer.add_vector("VectorFixFormatAsString_c", FixFormat, [FixFormat(1, 8, 8), FixFormat(1, 16, 16)], as_string=True)

    pkg_writer.write_vhdl_pkg("pkg_writer_test_pkg", "../test/fix/olo_fix_pkg_writer", olo_library="olo")

if __name__ == "__main__":
    generate()
