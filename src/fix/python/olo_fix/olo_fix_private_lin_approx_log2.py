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
def log2_function(x):
    """
    Function the tables are generated for

    The fractional part of the logarithm is approximated: log2(1+x) for the mantissa fraction x in
    the range [0, 1). The result covers [0, 1).

    :param x: Mantissa fraction (the leading one of the normalized value is not included)
    :return: log2(1+x)
    """
    return np.log2(1.0 + np.asarray(x, dtype=float))

# ---------------------------------------------------------------------------------------------------
# Table Configuration
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_log2_tbl:

    """
    Geometry of one logarithm table.
    """

    def __init__(self,
                 points : int,
                 offs_fmt : FixFormat,
                 grad_fmt : FixFormat):
        """
        Constructor of the olo_fix_private_lin_approx_log2_tbl class

        :param points: Number of segments in the table. Must be a power of two.
        :param offs_fmt: Format of the offset table (see olo_fix_lin_approx_cfg)
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
# memory (points times entry width) that stay within an error band of +/-1 LSB of out_fmt for every
# possible input code and that return exactly zero for a mantissa fraction of zero (which makes the
# result for powers of two exact). The same precisions as for olo_fix_inv and olo_fix_sqrt are supported, so
# that the entities can be used interchangeably.
# ---------------------------------------------------------------------------------------------------
LOG2_TABLES = {
    # precision_bits : olo_fix_private_lin_approx_log2_tbl(points, offs_fmt, grad_fmt)
    10 : olo_fix_private_lin_approx_log2_tbl(16,   FixFormat(0, 0, 13), FixFormat(0, 1, 5)),
    14 : olo_fix_private_lin_approx_log2_tbl(64,   FixFormat(0, 0, 16), FixFormat(0, 1, 9)),
    18 : olo_fix_private_lin_approx_log2_tbl(256,  FixFormat(0, 0, 21), FixFormat(0, 1, 11)),
    20 : olo_fix_private_lin_approx_log2_tbl(512,  FixFormat(0, 0, 22), FixFormat(0, 1, 12)),
}

def log2_out_fmt(precision_bits : int) -> FixFormat:
    """
    Output format of the logarithm approximation for a given precision

    No integer bit is required because log2(1+x) covers [0, 1) for the mantissa fraction x in
    [0, 1).
    """
    return FixFormat(0, 0, precision_bits)

def log2_table_name(out_fmt : FixFormat) -> str:
    """
    Name of the table of an output format in the generated VHDL package

    The same name is assembled by the HDL from OutFmt_g.
    """
    return f"log2_f{out_fmt.F}"

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_private_lin_approx_log2:

    """
    Bit-true model of the olo_fix_private_lin_approx_log2 entity.

    The entity is meant for internal use only (it is instantiated by olo_fix_log2, which adds the
    normalization) and hence it is not documented separately. Users shall use olo_fix_log2.

    The entity approximates log2(1+x) for the mantissa fraction x in the range [0, 1), which covers
    [0, 1).
    """

    _PACKAGE_NAME = "olo_fix_private_lin_approx_log2_pkg"

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 in_fmt : FixFormat,
                 out_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_private_lin_approx_log2 class

        :param in_fmt: Format of the mantissa fraction. Must be (0, 0, N) because the mantissa
                       fraction covers the range [0, 1). The format must provide more bits than the
                       table has index bits.
        :param out_fmt: Format of the result. Must be (0, 0, P) with P being one of the supported
                        precisions (see LOG2_TABLES).
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Output format
        if out_fmt.S != 0 or out_fmt.I != 0 or out_fmt.F not in LOG2_TABLES:
            supported = ", ".join(str(p) for p in sorted(LOG2_TABLES.keys()))
            raise ValueError(f"olo_fix_private_lin_approx_log2: out_fmt {out_fmt} is not supported "
                             f"(supported: (0, 0, P) with P in {supported})")
        self.tbl = LOG2_TABLES[out_fmt.F]

        # Input format - the mantissa fraction covers [0, 1) and must resolve the table index
        if in_fmt.S != 0 or in_fmt.I != 0:
            raise ValueError(f"olo_fix_private_lin_approx_log2: in_fmt {in_fmt} must be (0, 0, N) "
                             f"- the mantissa fraction covers the range [0, 1)")
        if cl_fix_width(in_fmt) <= self.tbl.index_bits:
            raise ValueError(f"olo_fix_private_lin_approx_log2: in_fmt {in_fmt} must be wider than "
                             f"{self.tbl.index_bits} bits for a table with {self.tbl.points} "
                             f"points")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt

        # Logarithm approximation
        self.cfg = olo_fix_lin_approx_cfg(
            function=log2_function,
            in_fmt=in_fmt,
            out_fmt=out_fmt,
            offs_fmt=self.tbl.offs_fmt,
            grad_fmt=self.tbl.grad_fmt,
            points=self.tbl.points,
            name=log2_table_name(out_fmt),
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

        :param data: Mantissa fraction in the range [0, 1)
        :return: log2(1+data)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(data):
            data = np.array([data])

        return self._approx.process(cl_fix_from_real(data, self.in_fmt))

    def process(self, data):
        """
        Process samples (without preserving previous state)

        :param data: Mantissa fraction in the range [0, 1)
        :return: log2(1+data)
        """
        # The approximation is stateless, hence process() and next() are identical
        return self.next(data)

    # ---------------------------------------------------------------------------------------------------
    # Code Generation
    #
    # The generated package is checked into the repository. Any drift between it and the table
    # configurations above is detected by the co-simulation, which checks the HDL (using the
    # checked-in package) against this model (using LOG2_TABLES).
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

        for precision_bits in sorted(LOG2_TABLES.keys()):
            model = olo_fix_private_lin_approx_log2._reference_model(precision_bits)
            approximations[log2_table_name(model.out_fmt)] = model._approx

        return olo_fix_lin_approx.generate_package(
            approximations, olo_fix_private_lin_approx_log2._PACKAGE_NAME, directory)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def _reference_model(precision_bits : int): # pragma: no cover
        """
        Model used to derive the table content of a precision

        The table content does not depend on the input resolution, hence the resolution used by
        olo_fix_log2 is applied.
        """
        return olo_fix_private_lin_approx_log2(FixFormat(0, 0, precision_bits + 2),
                                              log2_out_fmt(precision_bits))

# ---------------------------------------------------------------------------------------------------
# Command Line Interface
# ---------------------------------------------------------------------------------------------------
def main(): # pragma: no cover
    """
    Command line interface of the design helpers

    Execute it from <root>/src/fix/python, for example:
        python3 -m olo_fix.olo_fix_private_lin_approx_log2 --generate
        python3 -m olo_fix.olo_fix_private_lin_approx_log2 --analyze 18
    """
    import argparse
    from os.path import abspath, dirname, join

    parser = argparse.ArgumentParser(
        description="Design helpers of the logarithm approximation "
                    "(olo_fix_private_lin_approx_log2)",
        epilog="Execute from <root>/src/fix/python, e.g. "
               "python3 -m olo_fix.olo_fix_private_lin_approx_log2 --generate")
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
        name      = olo_fix_private_lin_approx_log2.generate_package(directory)
        print(f"Generated {join(directory, name)}.vhd")

    if args.analyze is not None:
        try:
            model = olo_fix_private_lin_approx_log2._reference_model(args.analyze)
        except ValueError as e:
            parser.error(f"--analyze: {e}")

        # analyze() of the wrapped approximation plots it against the ideal function and prints
        # the error plus the value ranges required by the offset/gradient tables
        model._approx.analyze()

if __name__ == "__main__": # pragma: no cover
    main()
