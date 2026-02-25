# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------

# Import en_cl_fix
import unittest
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from olo_fix import olo_fix_pkg_writer, MemberData
from en_cl_fix_pkg import *
import tempfile
import shutil

# Note: Test coverage is OK for the Open Logic code, it does not cover all numerics because
#       this is covered by en_cl_fix_pkg tests already.
class TestOloFixPkgWriter(unittest.TestCase):

    WRITE_DEBUG_FILES = False

    def setUp(self):
        self.dut = olo_fix_pkg_writer()

    # Internal functions
    def test_check_name(self):
        # Check that valid names are accepted
        self.dut._check_name("valid_name")
        self.dut._check_name("validName2")
        self.dut._check_name("Valid_Name_3")
        self.dut.add_constant("validConstant", int, 42)
        self.dut.add_vector("validVector", int, [1,2])

        # Check that invalid names are rejected
        with self.assertRaises(ValueError):
            self.dut._check_name("1invalidName")  # Starts with a digit
        with self.assertRaises(ValueError):
            self.dut._check_name("invalid-name")  # Contains a hyphen
        with self.assertRaises(ValueError):
            self.dut._check_name("invalid name")  # Contains a space
        with self.assertRaises(ValueError):
            self.dut._check_name("invalid$name")  # Contains a special character
        with self.assertRaises(ValueError):
            self.dut._check_name("_validName2")  # Starting with underscor

        # Check that already used names are rejected
        with self.assertRaises(ValueError):
            self.dut._check_name("validConstant")  # Already used for a constant
        with self.assertRaises(ValueError):
            self.dut._check_name("validVector")  # Already used for a vector

    def test_vhdl_const_declaration(self):
        self.assertEqual(self.dut._vhdl_const_declaration("constInt", MemberData(int, 42, False)), "constant constInt : integer := 42;")
        self.assertEqual(self.dut._vhdl_const_declaration("constFloat", MemberData(float, 3.14, False)), "constant constFloat : real := 3.14;")
        self.assertEqual(self.dut._vhdl_const_declaration("constFixFormat", MemberData(FixFormat, FixFormat(1, 3, 8), False)), "constant constFixFormat : FixFormat_t := (1, 3, 8);")
        self.assertEqual(self.dut._vhdl_const_declaration("constString", MemberData(str, "Hello", False)), 'constant constString : string := "Hello";')
        self.assertEqual(self.dut._vhdl_const_declaration("constFloatSmall", MemberData(float, 3.14e-15, False)), "constant constFloatSmall : real := 3.14e-15;")  # Check that float is formatted with 9 significant digits

    def test_vhdl_const_declaration_as_string(self):
        self.assertEqual(self.dut._vhdl_const_declaration("constIntAsString", MemberData(int, 42, True)), 'constant constIntAsString : string := "42";')
        self.assertEqual(self.dut._vhdl_const_declaration("constFloatAsString", MemberData(float, 3.14, True)), 'constant constFloatAsString : string := "3.14";')
        self.assertEqual(self.dut._vhdl_const_declaration("constFixFormatAsString", MemberData(FixFormat, FixFormat(1, 3, 8), True)), 'constant constFixFormatAsString : string := "(1, 3, 8)";')
        self.assertEqual(self.dut._vhdl_const_declaration("constStringAsString", MemberData(str, "Hello", True)), 'constant constStringAsString : string := "Hello";')

    def test_verilog_const_declaration(self):
        self.assertEqual(self.dut._verilog_const_declaration("constInt", MemberData(int, 42, False)), "localparam int constInt = 42;")
        self.assertEqual(self.dut._verilog_const_declaration("constFloat", MemberData(float, 3.14, False)), "localparam real constFloat = 3.14;")
        self.assertEqual(self.dut._verilog_const_declaration("constString", MemberData(str, "Hello", False)), 'localparam string constString = "Hello";')
        self.assertEqual(self.dut._verilog_const_declaration("constFloatSmall", MemberData(float, 3.14e-15, False)), "localparam real constFloatSmall = 3.14e-15;")  # Check that float is formatted with 9 significant digits

    def test_verilog_const_declaration_as_string(self):
        self.assertEqual(self.dut._verilog_const_declaration("constIntAsString", MemberData(int, 42, True)), 'localparam string constIntAsString = "42";')
        self.assertEqual(self.dut._verilog_const_declaration("constFloatAsString", MemberData(float, 3.14, True)), 'localparam string constFloatAsString = "3.14";')
        self.assertEqual(self.dut._verilog_const_declaration("constStringAsString", MemberData(str, "Hello", True)), 'localparam string constStringAsString = "Hello";')
        self.assertEqual(self.dut._verilog_const_declaration("constFixFormatAsString", MemberData(FixFormat, FixFormat(1, 3, 8), True)), 'localparam string constFixFormatAsString = "(1, 3, 8)";')

        # Fix format is not supported in Verilog
        with self.assertRaises(ValueError):
            self.dut._verilog_const_declaration("constFixFormat", MemberData(FixFormat, FixFormat(1, 3, 8), False))

        # Unsupported type
        with self.assertRaises(ValueError):
            self.dut._verilog_const_declaration("invalidConst", MemberData(list, [], False))  # Unsupported type

    def test_vhdl_vector_declaration(self):
        self.assertEqual(self.dut._vhdl_vector_declaration("vectorInt", MemberData(int, [1, 2, 3], False)), "constant vectorInt : IntegerArray_t(0 to 2) := (1, 2, 3);")
        self.assertEqual(self.dut._vhdl_vector_declaration("vectorFloat", MemberData(float, [1.0, 2.0, 3.0], False)), "constant vectorFloat : RealArray_t(0 to 2) := (1.0, 2.0, 3.0);")
        self.assertEqual(self.dut._vhdl_vector_declaration("vectorFixFormat", MemberData(FixFormat, [FixFormat(1, 3, 8), FixFormat(1, 5, 16)], False)), "constant vectorFixFormat : FixFormatArray_t(0 to 1) := ((1, 3, 8), (1, 5, 16));")    

        # Unsupported type
        with self.assertRaises(ValueError):
            self.dut._vhdl_vector_declaration("invalidVector", MemberData(list, [[1], [2], [3]], False))  # Unsupported type

    def test_verilog_vector_declaration(self):
        self.assertEqual(self.dut._verilog_vector_declaration("vectorInt", MemberData(int, [1, 2, 3], False)), "localparam int vectorInt [0:2] = '{1, 2, 3};")
        self.assertEqual(self.dut._verilog_vector_declaration("vectorFloat", MemberData(float, [1.0, 2.0, 3.0], False)), "localparam real vectorFloat [0:2] = '{1.0, 2.0, 3.0};")

        # Fix format is not supported in Verilog
        with self.assertRaises(ValueError):
            self.dut._verilog_vector_declaration("vectorFixFormat", MemberData(FixFormat, [FixFormat(1, 3, 8), FixFormat(1, 5, 16)], False))

        # Unsupported type
        with self.assertRaises(ValueError):
            self.dut._verilog_vector_declaration("invalidVector", MemberData(list, [[1], [2], [3]], False))  # Unsupported type

    # Add Constants
    def test_add_constant(self):
        self.dut.add_constant("constInt", int, 42)
        self.dut.add_constant("constFloat", float, 3.14)
        self.dut.add_constant("constFixFormat", FixFormat, FixFormat(1, 8, 8))
        self.dut.add_constant("constString", str, "Hello")

        with self.assertRaises(ValueError):
            self.dut.add_constant("invalidType", list, [])  # Unsupported type

    # Add Vectors
    def test_add_vector(self):
        self.dut.add_vector("vectorInt", int, [1, 2, 3])
        self.dut.add_vector("vectorFloat", float, [1.0, 2.0, 3.0])
        self.dut.add_vector("vectorFixFormat", FixFormat, [FixFormat(1, 8, 8), FixFormat(1, 16, 16)])

        with self.assertRaises(ValueError):
            self.dut.add_vector("invalidTypeVector", list, [[1], [2], [3]])  # Unsupported type
        with self.assertRaises(ValueError):
            self.dut.add_vector("invalidElementTypeVector", str, ["bla", "blub"])  # Unsupported element type

    # Test VHDL Package generation
    def test_write_vhdl_pkg(self):
        self.dut.add_constant("constInt", int, 42)
        self.dut.add_constant("constFloat", float, 3.14)
        self.dut.add_constant("constFixFormat", FixFormat, FixFormat(1, 8, 8))
        self.dut.add_constant("constString", str, "Hello")

        self.dut.add_vector("vectorInt", int, [1, 2, 3])
        self.dut.add_vector("vectorFloat", float, [1.0, 2.0, 3.0])
        self.dut.add_vector("vectorFixFormat", FixFormat, [FixFormat(1, 8, 8), FixFormat(1, 16, 16)])

        temp_dir = tempfile.mkdtemp()
        try:
            self.dut.write_vhdl_pkg("my_pkg", temp_dir, olo_library="olo_lib")

            # Write file that is not deleted for debugging purposes
            if self.WRITE_DEBUG_FILES:
                self.dut.write_vhdl_pkg("my_pkg", self.dut._TEMPLATE_DIR, olo_library="olo_lib")

            # Read the file content into a string
            with open(os.path.join(temp_dir, "my_pkg.vhd"), "r") as f:
                content = f.read()  
            self.assertIn("constant constInt : integer := 42;", content)
            self.assertIn("constant constFloat : real := 3.14;", content)
            self.assertIn("constant constFixFormat : FixFormat_t := (1, 8, 8);", content)
            self.assertIn('constant constString : string := "Hello";', content)
            self.assertIn("constant vectorInt : IntegerArray_t(0 to 2) := (1, 2, 3);", content)
            self.assertIn("constant vectorFloat : RealArray_t(0 to 2) := (1.0, 2.0, 3.0);", content)
            self.assertIn("constant vectorFixFormat : FixFormatArray_t(0 to 1) := ((1, 8, 8), (1, 16, 16));", content)
        finally:
            shutil.rmtree(temp_dir)

    # Test Verilog Package generation
    def test_write_verilog_pkg(self):
        self.dut.add_constant("constInt", int, 42)
        self.dut.add_constant("constFloat", float, 3.14)
        self.dut.add_constant("constString", str, "Hello")

        self.dut.add_vector("vectorInt", int, [1, 2, 3])
        self.dut.add_vector("vectorFloat", float, [1.0, 2.0, 3.0])

        temp_dir = tempfile.mkdtemp()
        try:
            self.dut.write_verilog_header("my_pkg", temp_dir)

            # Write file that is not deleted for debugging purposes
            if self.WRITE_DEBUG_FILES:
                self.dut.write_verilog_header("my_pkg", self.dut._TEMPLATE_DIR)

            # Read the file content into a string
            with open(os.path.join(temp_dir, "my_pkg.vh"), "r") as f:
                content = f.read()  
            self.assertIn("localparam int constInt = 42;", content)
            self.assertIn("localparam real constFloat = 3.14;", content)
            self.assertIn('localparam string constString = "Hello";', content)
            self.assertIn("localparam int vectorInt [0:2] = '{1, 2, 3};", content)
            self.assertIn("localparam real vectorFloat [0:2] = '{1.0, 2.0, 3.0};", content)
        finally:
            shutil.rmtree(temp_dir)


if __name__ == '__main__':
    unittest.main()
