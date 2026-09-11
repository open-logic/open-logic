# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
#
# Based on psi_fix_lin_approx_inv18b from the PSI psi_fix library
# Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
# All rights reserved.
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from .olo_fix_lin_approx import olo_fix_lin_approx, olo_fix_lin_approx_cfg

# ---------------------------------------------------------------------------------------------------
# Table Configuration
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_inv_tbl:

    """
    Geometry of one inversion table.
    """

    def __init__(self,
                 points : int,
                 offs_fmt : FixFormat,
                 grad_fmt : FixFormat):
        """
        Constructor of the olo_fix_private_lin_approx_inv_tbl class

        :param points: Number of segments in the table. Must be a power of two.
        :param offs_fmt: Format of the offset table (inversion at the segment centers)
        :param grad_fmt: Format of the gradient table (derivatives at the segment centers)
        """
        self.points = points
        self.offs_fmt = offs_fmt
        self.grad_fmt = grad_fmt

    @property
    def index_bits(self) -> int:
        """
        Number of table index bits (log2 of the number of points)
        """
        return int(np.log2(self.points))

# ---------------------------------------------------------------------------------------------------
# Table Configurations
#
# One table exists per supported precision. Contrary to the sine, the inversion does not suffer from
# any scaling problem (the result is simply rounded to the user format), hence a few precisions are
# sufficient and the user selects one of them through PrecisionBits_g.
# ---------------------------------------------------------------------------------------------------
INV_TABLES = {
    # precision_bits : olo_fix_private_lin_approx_inv_tbl(points, offs_fmt, grad_fmt)
    10 : olo_fix_private_lin_approx_inv_tbl(32,   FixFormat(0, 1, 13), FixFormat(1, 0, 7)),
    14 : olo_fix_private_lin_approx_inv_tbl(128,  FixFormat(0, 1, 17), FixFormat(1, 0, 10)),
    18 : olo_fix_private_lin_approx_inv_tbl(512,  FixFormat(0, 1, 21), FixFormat(1, 0, 13)),
    20 : olo_fix_private_lin_approx_inv_tbl(1024, FixFormat(0, 1, 22), FixFormat(1, 0, 11)),
}

def inv_out_fmt(precision_bits : int) -> FixFormat:
    """
    Output format of the inversion approximation for a given precision

    One integer bit is required because the result of 1/1.0 is 1.0.
    """
    return FixFormat(0, 1, precision_bits)

def inv_table_name(out_fmt : FixFormat) -> str:
    """
    Name of the table of an output format in the generated VHDL package

    The same name is assembled by the HDL from OutFmt_g.
    """
    return f"inv_f{out_fmt.F}"

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_inv:

    """
    Bit-true model of the olo_fix_private_lin_approx_inv entity.

    The entity is meant for internal use only (it is instantiated by olo_fix_inv, which adds the
    normalization) and hence it is not documented separately. Users shall use olo_fix_inv.

    The entity approximates 1/x for x in the range [1, 2). The leading one of x is implicit, hence
    the input is the mantissa fraction m in the range [0, 1) and the function approximated is
    1/(1+m), which covers the range (0.5, 1.0].
    """

    _PACKAGE_NAME = "olo_fix_private_lin_approx_inv_pkg"

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 out_fmt : FixFormat,
                 in_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_private_lin_approx_inv class

        :param out_fmt: Format of the result. Must be (0, 1, P) with P being one of the supported
                        precisions (see INV_TABLES).
        :param in_fmt: Format of the mantissa fraction input. Must be (0, 0, N) because the
                       mantissa fraction covers the range [0, 1). The format must provide more bits
                       than the table has index bits.
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Output format
        if out_fmt.S != 0 or out_fmt.I != 1 or out_fmt.F not in INV_TABLES:
            supported = ", ".join(str(p) for p in sorted(INV_TABLES.keys()))
            raise ValueError(f"olo_fix_private_lin_approx_inv: out_fmt {out_fmt} is not supported "
                             f"(supported: (0, 1, P) with P in {supported})")
        self.tbl = INV_TABLES[out_fmt.F]

        # Input format - the mantissa fraction covers [0, 1) and must resolve the table index
        if in_fmt.S != 0 or in_fmt.I != 0:
            raise ValueError(f"olo_fix_private_lin_approx_inv: in_fmt {in_fmt} must be (0, 0, N) - "
                             f"the mantissa fraction covers the range [0, 1)")
        if cl_fix_width(in_fmt) <= self.tbl.index_bits:
            raise ValueError(f"olo_fix_private_lin_approx_inv: in_fmt {in_fmt} must be wider than "
                             f"{self.tbl.index_bits} bits for a table with {self.tbl.points} "
                             f"points")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt

        # Inversion approximation. The leading one of the normalized value is implicit.
        self.cfg = olo_fix_lin_approx_cfg(
            function=lambda x: 1.0/(1.0 + x),
            in_fmt=in_fmt,
            out_fmt=out_fmt,
            offs_fmt=self.tbl.offs_fmt,
            grad_fmt=self.tbl.grad_fmt,
            points=self.tbl.points,
            name=inv_table_name(out_fmt),
            round=round,
            saturate=saturate)
        self._approx = olo_fix_lin_approx(self.cfg)

    # ---------------------------------------------------------------------------------------------------
    # Public Methods
    # ---------------------------------------------------------------------------------------------------
    def reset(self):
        """
        Reset state of the component

        The approximation is stateless, hence this function does nothing. It exists for consistency
        with the other olo_fix models.
        """
        pass

    def next(self, mantissa):
        """
        Process next N samples

        :param mantissa: Mantissa fraction in the range [0, 1), i.e. the normalized value is 1+m
        :return: 1/(1+m)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(mantissa):
            mantissa = np.array([mantissa])

        return self._approx.process(cl_fix_from_real(mantissa, self.in_fmt))

    def process(self, mantissa):
        """
        Process samples (without preserving previous state)

        :param mantissa: Mantissa fraction in the range [0, 1), i.e. the normalized value is 1+m
        :return: 1/(1+m)
        """
        # The approximation is stateless, hence process() and next() are identical
        return self.next(mantissa)

    # ---------------------------------------------------------------------------------------------------
    # Code Generation
    #
    # The generated package is checked into the repository. Any drift between it and the table
    # configurations above is detected by the co-simulation, which checks the HDL (using the
    # checked-in package) against this model (using INV_TABLES).
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def generate_package(directory : str) -> str: # pragma: no cover
        """
        Generate the VHDL package containing the tables for all supported precisions

        The package itself is generated by olo_fix_lin_approx, which implements the table package
        generation for all approximations. This function only assembles the approximations.

        :param directory: Target directory
        :return: Name of the package generated
        """
        approximations = {}

        for precision_bits in sorted(INV_TABLES.keys()):
            out_fmt = inv_out_fmt(precision_bits)
            model   = olo_fix_private_lin_approx_inv._reference_model(out_fmt)
            approximations[inv_table_name(out_fmt)] = model._approx

        return olo_fix_lin_approx.generate_package(
            approximations, olo_fix_private_lin_approx_inv._PACKAGE_NAME, directory)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def _reference_model(out_fmt : FixFormat): # pragma: no cover
        """
        Model used to derive the table content of a precision

        The table content does not depend on the mantissa resolution, hence the resolution used by
        olo_fix_inv is applied.
        """
        return olo_fix_private_lin_approx_inv(out_fmt, FixFormat(0, 0, out_fmt.F + 2))

# ---------------------------------------------------------------------------------------------------
# Command Line Interface
# ---------------------------------------------------------------------------------------------------
def main(): # pragma: no cover
    """
    Command line interface of the design helpers

    Execute it from <root>/src/fix/python, for example:
        python3 -m olo_fix.olo_fix_private_lin_approx_inv --generate
        python3 -m olo_fix.olo_fix_private_lin_approx_inv --analyze 18
    """
    import argparse
    from os.path import abspath, dirname, join

    parser = argparse.ArgumentParser(
        description="Design helpers of the inversion approximation (olo_fix_private_lin_approx_inv)",
        epilog="Execute from <root>/src/fix/python, e.g. "
               "python3 -m olo_fix.olo_fix_private_lin_approx_inv --generate")
    parser.add_argument("--generate", action="store_true",
                        help="Generate the VHDL package containing the tables of all supported "
                             "precisions into <root>/src/fix/vhdl")
    parser.add_argument("--analyze", metavar="BITS", type=int,
                        help="Plot the accuracy of the approximation for one precision (e.g. 18)")
    args = parser.parse_args()

    # Without any action there is nothing to do - print the usage instead of doing nothing silently
    if not args.generate and args.analyze is None:
        parser.print_help()
        return

    if args.generate:
        # The package is part of Open Logic itself, hence it is written next to the other sources
        directory = abspath(join(dirname(__file__), "..", "..", "vhdl"))
        name      = olo_fix_private_lin_approx_inv.generate_package(directory)
        print(f"Generated {join(directory, name)}.vhd")

    if args.analyze is not None:
        try:
            model = olo_fix_private_lin_approx_inv._reference_model(inv_out_fmt(args.analyze))
        except ValueError as e:
            parser.error(f"--analyze: {e}")

        # analyze() of the wrapped approximation plots it against the ideal function and prints
        # the error plus the value ranges required by the offset/gradient tables
        model._approx.analyze()

if __name__ == "__main__": # pragma: no cover
    main()
