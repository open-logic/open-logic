# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from .olo_fix_lin_approx import olo_fix_lin_approx, olo_fix_lin_approx_cfg

# ---------------------------------------------------------------------------------------------------
# Approximated Function
# ---------------------------------------------------------------------------------------------------
# Lower bound of the range the square root is approximated in. Below it the approximation returns
# zero - see sqrt_function().
SQRT_LOWER_BOUND = 0.25

def sqrt_function(x):
    """
    Function the tables are generated for

    The square root is approximated in the range [0.25, 1). Below 0.25 the approximation returns
    zero. Only a zero input reaches this part of the table (olo_fix_sqrt normalizes everything else
    into [0.25, 1)), hence zeroing it makes the square root of zero exactly zero - for free. The
    discontinuity is at 0.25, which is a segment border for any power of two table size, hence it
    does not affect the accuracy in the range approximated.

    :param x: Input value(s)
    :return: Square root of the input for x >= 0.25, zero below
    """
    x = np.asarray(x, dtype=float)
    return np.where(x < SQRT_LOWER_BOUND, 0.0, np.sqrt(np.maximum(x, 0.0)))

# ---------------------------------------------------------------------------------------------------
# Table Configuration
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_sqrt_tbl:

    """
    Geometry of one square root table.
    """

    def __init__(self,
                 points : int,
                 offs_fmt : FixFormat,
                 grad_fmt : FixFormat):
        """
        Constructor of the olo_fix_private_lin_approx_sqrt_tbl class

        :param points: Number of segments in the table. Must be a power of two.
        :param offs_fmt: Format of the offset table (square root at the segment centers)
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
# One table exists per supported precision. The configurations are the ones with the smallest table
# memory (points times entry width) that stay within an error band of +/-1 LSB of out_fmt. The same
# precisions as for olo_fix_inv are supported, so that the two entities can be used interchangeably.
# ---------------------------------------------------------------------------------------------------
SQRT_TABLES = {
    # precision_bits : olo_fix_private_lin_approx_sqrt_tbl(points, offs_fmt, grad_fmt)
    10 : olo_fix_private_lin_approx_sqrt_tbl(32,   FixFormat(0, 0, 11), FixFormat(0, 0, 5)),
    14 : olo_fix_private_lin_approx_sqrt_tbl(128,  FixFormat(0, 0, 15), FixFormat(0, 0, 8)),
    18 : olo_fix_private_lin_approx_sqrt_tbl(512,  FixFormat(0, 0, 19), FixFormat(0, 0, 10)),
    20 : olo_fix_private_lin_approx_sqrt_tbl(1024, FixFormat(0, 0, 21), FixFormat(0, 0, 12)),
}

def sqrt_out_fmt(precision_bits : int) -> FixFormat:
    """
    Output format of the square root approximation for a given precision

    No integer bit is required because the square root of the range approximated ([0.25, 1))
    covers [0.5, 1).
    """
    return FixFormat(0, 0, precision_bits)

def sqrt_table_name(out_fmt : FixFormat) -> str:
    """
    Name of the table of an output format in the generated VHDL package

    The same name is assembled by the HDL from OutFmt_g.
    """
    return f"sqrt_f{out_fmt.F}"

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_sqrt:

    """
    Bit-true model of the olo_fix_private_lin_approx_sqrt entity.

    The entity is meant for internal use only (it is instantiated by olo_fix_sqrt, which adds the
    normalization) and hence it is not documented separately. Users shall use olo_fix_sqrt.

    The entity approximates sqrt(x) for x in the range [0.25, 1), which covers [0.5, 1). Below 0.25
    it returns zero (see sqrt_function).
    """

    _PACKAGE_NAME = "olo_fix_private_lin_approx_sqrt_pkg"

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 out_fmt : FixFormat,
                 in_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_private_lin_approx_sqrt class

        :param out_fmt: Format of the result. Must be (0, 0, P) with P being one of the supported
                        precisions (see SQRT_TABLES).
        :param in_fmt: Format of the normalized input. Must be (0, 0, N) because the normalized
                       value covers the range [0.25, 1). The format must provide more bits than the
                       table has index bits.
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Output format
        if out_fmt.S != 0 or out_fmt.I != 0 or out_fmt.F not in SQRT_TABLES:
            supported = ", ".join(str(p) for p in sorted(SQRT_TABLES.keys()))
            raise ValueError(f"olo_fix_private_lin_approx_sqrt: out_fmt {out_fmt} is not supported "
                             f"(supported: (0, 0, P) with P in {supported})")
        self.tbl = SQRT_TABLES[out_fmt.F]

        # Input format - the normalized value covers [0.25, 1) and must resolve the table index
        if in_fmt.S != 0 or in_fmt.I != 0:
            raise ValueError(f"olo_fix_private_lin_approx_sqrt: in_fmt {in_fmt} must be (0, 0, N) "
                             f"- the normalized value covers the range [0.25, 1)")
        if cl_fix_width(in_fmt) <= self.tbl.index_bits:
            raise ValueError(f"olo_fix_private_lin_approx_sqrt: in_fmt {in_fmt} must be wider than "
                             f"{self.tbl.index_bits} bits for a table with {self.tbl.points} "
                             f"points")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt

        # Square root approximation
        self.cfg = olo_fix_lin_approx_cfg(
            function=sqrt_function,
            in_fmt=in_fmt,
            out_fmt=out_fmt,
            offs_fmt=self.tbl.offs_fmt,
            grad_fmt=self.tbl.grad_fmt,
            points=self.tbl.points,
            name=sqrt_table_name(out_fmt),
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

    def next(self, data):
        """
        Process next N samples

        :param data: Normalized value in the range [0.25, 1)
        :return: sqrt(data)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(data):
            data = np.array([data])

        return self._approx.process(cl_fix_from_real(data, self.in_fmt))

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Normalized value in the range [0.25, 1)
        :return: sqrt(data)
        """
        # The approximation is stateless, hence process() and next() are identical
        return self.next(data)

    # ---------------------------------------------------------------------------------------------------
    # Code Generation
    #
    # The generated package is checked into the repository. Any drift between it and the table
    # configurations above is detected by the co-simulation, which checks the HDL (using the
    # checked-in package) against this model (using SQRT_TABLES).
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

        for precision_bits in sorted(SQRT_TABLES.keys()):
            out_fmt = sqrt_out_fmt(precision_bits)
            model   = olo_fix_private_lin_approx_sqrt._reference_model(out_fmt)
            approximations[sqrt_table_name(out_fmt)] = model._approx

        return olo_fix_lin_approx.generate_package(
            approximations, olo_fix_private_lin_approx_sqrt._PACKAGE_NAME, directory)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def _reference_model(out_fmt : FixFormat): # pragma: no cover
        """
        Model used to derive the table content of a precision

        The table content does not depend on the input resolution, hence the resolution used by
        olo_fix_sqrt is applied.
        """
        return olo_fix_private_lin_approx_sqrt(out_fmt, FixFormat(0, 0, out_fmt.F + 2))

# ---------------------------------------------------------------------------------------------------
# Command Line Interface
# ---------------------------------------------------------------------------------------------------
def main(): # pragma: no cover
    """
    Command line interface of the design helpers

    Execute it from <root>/src/fix/python, for example:
        python3 -m olo_fix.olo_fix_private_lin_approx_sqrt --generate
        python3 -m olo_fix.olo_fix_private_lin_approx_sqrt --analyze 18
    """
    import argparse
    from os.path import abspath, dirname, join

    parser = argparse.ArgumentParser(
        description="Design helpers of the square root approximation "
                    "(olo_fix_private_lin_approx_sqrt)",
        epilog="Execute from <root>/src/fix/python, e.g. "
               "python3 -m olo_fix.olo_fix_private_lin_approx_sqrt --generate")
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
        name      = olo_fix_private_lin_approx_sqrt.generate_package(directory)
        print(f"Generated {join(directory, name)}.vhd")

    if args.analyze is not None:
        try:
            model = olo_fix_private_lin_approx_sqrt._reference_model(sqrt_out_fmt(args.analyze))
        except ValueError as e:
            parser.error(f"--analyze: {e}")

        # analyze() of the wrapped approximation plots it against the ideal function and prints
        # the error plus the value ranges required by the offset/gradient tables
        model._approx.analyze()

if __name__ == "__main__": # pragma: no cover
    main()
