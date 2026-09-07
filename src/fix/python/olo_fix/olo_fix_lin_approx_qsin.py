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
# Table Configuration
# ---------------------------------------------------------------------------------------------------
class olo_fix_lin_approx_qsin_tbl:

    """
    Geometry of one quarter-sine table.
    """

    def __init__(self,
                 points : int,
                 offs_fmt : FixFormat,
                 grad_fmt : FixFormat):
        """
        Constructor of the olo_fix_lin_approx_qsin_tbl class

        :param points: Number of segments in the table. Must be a power of two.
        :param offs_fmt: Format of the offset table (quarter sine at the segment centers)
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

    @property
    def width(self) -> int:
        """
        Width of one table entry (gradient and offset concatenated)
        """
        return cl_fix_width(self.offs_fmt) + cl_fix_width(self.grad_fmt)

# ---------------------------------------------------------------------------------------------------
# Table Configurations
#
# ---------------------------------------------------------------------------------------------------
QSIN_TABLES = {
    # (int_bits, frac_bits) : olo_fix_lin_approx_qsin_tbl(points, offs_fmt, grad_fmt)

    # Scaled to 1.0 - 1 LSB (no integer bits)
    (0, 10) : olo_fix_lin_approx_qsin_tbl(32,   FixFormat(0, 0, 12), FixFormat(0, 3, 4)),
    (0, 11) : olo_fix_lin_approx_qsin_tbl(64,   FixFormat(0, 0, 13), FixFormat(0, 3, 3)),
    (0, 12) : olo_fix_lin_approx_qsin_tbl(64,   FixFormat(0, 0, 14), FixFormat(0, 3, 5)),
    (0, 13) : olo_fix_lin_approx_qsin_tbl(128,  FixFormat(0, 0, 15), FixFormat(0, 3, 4)),
    (0, 14) : olo_fix_lin_approx_qsin_tbl(128,  FixFormat(0, 0, 16), FixFormat(0, 3, 6)),
    (0, 15) : olo_fix_lin_approx_qsin_tbl(256,  FixFormat(0, 0, 17), FixFormat(0, 3, 5)),
    (0, 16) : olo_fix_lin_approx_qsin_tbl(256,  FixFormat(0, 0, 18), FixFormat(0, 3, 7)),
    (0, 17) : olo_fix_lin_approx_qsin_tbl(512,  FixFormat(0, 0, 19), FixFormat(0, 3, 6)),
    (0, 18) : olo_fix_lin_approx_qsin_tbl(512,  FixFormat(0, 0, 20), FixFormat(0, 3, 9)),
    (0, 19) : olo_fix_lin_approx_qsin_tbl(1024, FixFormat(0, 0, 21), FixFormat(0, 3, 9)),
    (0, 20) : olo_fix_lin_approx_qsin_tbl(1024, FixFormat(0, 0, 22), FixFormat(0, 3, 10)),

    # Unscaled (one integer bit, peak at 1.0)
    (1, 10) : olo_fix_lin_approx_qsin_tbl(32,   FixFormat(0, 0, 12), FixFormat(0, 3, 4)),
    (1, 11) : olo_fix_lin_approx_qsin_tbl(64,   FixFormat(0, 0, 13), FixFormat(0, 3, 3)),
    (1, 12) : olo_fix_lin_approx_qsin_tbl(64,   FixFormat(0, 0, 14), FixFormat(0, 3, 5)),
    (1, 13) : olo_fix_lin_approx_qsin_tbl(128,  FixFormat(0, 0, 15), FixFormat(0, 3, 4)),
    (1, 14) : olo_fix_lin_approx_qsin_tbl(128,  FixFormat(0, 0, 16), FixFormat(0, 3, 6)),
    (1, 15) : olo_fix_lin_approx_qsin_tbl(256,  FixFormat(0, 0, 17), FixFormat(0, 3, 5)),
    (1, 16) : olo_fix_lin_approx_qsin_tbl(256,  FixFormat(0, 0, 18), FixFormat(0, 3, 7)),
    (1, 17) : olo_fix_lin_approx_qsin_tbl(512,  FixFormat(0, 0, 19), FixFormat(0, 3, 6)),
    (1, 18) : olo_fix_lin_approx_qsin_tbl(512,  FixFormat(0, 0, 20), FixFormat(0, 3, 9)),
    (1, 19) : olo_fix_lin_approx_qsin_tbl(1024, FixFormat(0, 0, 21), FixFormat(0, 3, 9)),
    (1, 20) : olo_fix_lin_approx_qsin_tbl(1024, FixFormat(0, 0, 22), FixFormat(0, 3, 10)),
}

def qsin_table_name(out_fmt : FixFormat) -> str:
    """
    Name of the table of an output format in the generated VHDL package

    The same name is assembled by the HDL from OutFmt_g.
    """
    return f"qsin_i{out_fmt.I}f{out_fmt.F}"

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_lin_approx_qsin:

    """
    Bit-true model of the olo_fix_lin_approx_qsin entity.

    The entity approximates sine and cosine of one quadrant. The input is a phase in rotations
    covering one quadrant, i.e. the range [0, 0.25), which corresponds to 0 to 90 degrees:

    The class also generates the VHDL package containing the tables for all supported output formats.
    """

    _PACKAGE_NAME = "olo_fix_private_lin_approx_qsin_pkg"

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self,
                 out_fmt : FixFormat,
                 in_fmt : FixFormat,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_lin_approx_qsin class

        :param out_fmt: Format of the sine/cosine output. Must be (1, 0, 10..20) or (1, 1, 10..20).
                        Without integer bit the wave is scaled to 1.0-1LSB, with integer bit it is
                        unscaled (peak at 1.0).
        :param in_fmt: Format of the quarter phase input. Must be (0, -2, N) because the input
                       covers one quadrant only, i.e. the range [0, 0.25) in rotations. The format
                       must provide more bits than the table has index bits.
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Output format
        if out_fmt.S != 1 or (out_fmt.I, out_fmt.F) not in QSIN_TABLES:
            raise ValueError(f"olo_fix_lin_approx_qsin: out_fmt {out_fmt} is not supported "
                             f"(supported: (1, 0/1, 10..20))")
        self.tbl = QSIN_TABLES[(out_fmt.I, out_fmt.F)]

        # Input format - the quarter phase covers [0, 0.25) and must resolve the table index
        if in_fmt.S != 0 or in_fmt.I != -2:
            raise ValueError(f"olo_fix_lin_approx_qsin: in_fmt {in_fmt} must be (0, -2, N) - the "
                             f"quarter phase covers one quadrant only, i.e. the range [0, 0.25) "
                             f"in rotations")
        if cl_fix_width(in_fmt) <= self.tbl.index_bits:
            raise ValueError(f"olo_fix_lin_approx_qsin: in_fmt {in_fmt} must be wider than "
                             f"{self.tbl.index_bits} bits for a table with {self.tbl.points} "
                             f"points")

        self.out_fmt = out_fmt
        self.in_fmt = in_fmt

        # Peak value. Scaled to 1.0-1LSB if the output format has no integer bit.
        self.peak = 1.0 if out_fmt.I == 1 else 1.0 - 2.0**-out_fmt.F

        # Quarter sine approximation
        peak = self.peak
        self.cfg = olo_fix_lin_approx_cfg(
            function=lambda x: np.sin(x*2*np.pi)*peak,
            in_fmt=in_fmt,
            out_fmt=out_fmt,
            offs_fmt=self.tbl.offs_fmt,
            grad_fmt=self.tbl.grad_fmt,
            points=self.tbl.points,
            name=qsin_table_name(out_fmt),
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

    def next(self, phase):
        """
        Process next N samples

        :param phase: Phase in rotations, in the range [0, 0.25), i.e. 0 to 90 degrees
        :return: Tuple (sine, cosine)
        """
        # Convert scalars to 1d array and quantize
        if np.isscalar(phase):
            phase = np.array([phase])
        sin_phase = cl_fix_from_real(phase, self.in_fmt)
        cos_phase = cl_fix_from_real((0.25 - phase) % 0.25, self.in_fmt)

        # Approximation
        sin_val = self._approx.process(sin_phase)
        cos_val = self._approx.process(cos_phase)

        # An input of zero is exact and its mirrored address wraps, hence it is handled separately
        sin_val = np.where(phase == 0.0, 0.0, sin_val)
        cos_val = np.where(phase == 0.0, self.peak, cos_val)

        return sin_val, cos_val

    def process(self, quarter_phase):
        """
        Process samples (without preserving previous state)

        :param quarter_phase: Phase in rotations, in the range [0, 0.25), i.e. 0 to 90 degrees
        :return: Tuple (sine, cosine)
        """
        # The approximation is stateless, hence process() and next() are identical
        return self.next(quarter_phase)

    # ---------------------------------------------------------------------------------------------------
    # Code Generation
    #
    # The generated package is checked into the repository. Any drift between it and the table
    # configurations below is detected by the co-simulation, which checks the HDL (using the
    # checked-in package) against this model (using QSIN_TABLES).
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def generate_package(directory : str) -> str: # pragma: no cover
        """
        Generate the VHDL package containing the tables for all supported output formats

        The package itself is generated by olo_fix_lin_approx, which implements the table package
        generation for all approximations. This function only assembles the approximations.

        :param directory: Target directory
        :return: Name of the package generated
        """
        approximations = {}

        for (int_bits, frac_bits) in sorted(QSIN_TABLES.keys()):
            out_fmt = FixFormat(1, int_bits, frac_bits)
            model   = olo_fix_lin_approx_qsin._reference_model(out_fmt)
            approximations[qsin_table_name(out_fmt)] = model._approx

        return olo_fix_lin_approx.generate_package(
            approximations, olo_fix_lin_approx_qsin._PACKAGE_NAME, directory)

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def _reference_model(out_fmt : FixFormat): # pragma: no cover
        """
        Model used to derive the table content of an output format

        The table content does not depend on the phase resolution, hence the recommended resolution
        of the configuration is used.
        """
        return olo_fix_lin_approx_qsin(out_fmt, FixFormat(0, -2, out_fmt.F + 2))

# ---------------------------------------------------------------------------------------------------
# Command Line Interface
# ---------------------------------------------------------------------------------------------------
def main(): # pragma: no cover
    """
    Command line interface of the design helpers

    Execute it from <root>/src/fix/python, for example:
        python3 -m olo_fix.olo_fix_lin_approx_qsin --generate
        python3 -m olo_fix.olo_fix_lin_approx_qsin --analyze "(1,0,15)"
    """
    import argparse
    from os.path import abspath, dirname, join

    parser = argparse.ArgumentParser(
        description="Design helpers of the quarter sine approximation (olo_fix_lin_approx_qsin)",
        epilog="Execute from <root>/src/fix/python, e.g. "
               "python3 -m olo_fix.olo_fix_lin_approx_qsin --generate")
    parser.add_argument("--generate", action="store_true",
                        help="Generate the VHDL package containing the tables of all supported "
                             "output formats into <root>/src/fix/vhdl")
    parser.add_argument("--analyze", metavar="FMT",
                        help="Plot the accuracy of the approximation for one output format. The "
                             "format is given in the form \"(1,0,15)\".")
    args = parser.parse_args()

    # Without any action there is nothing to do - print the usage instead of doing nothing silently
    if not args.generate and args.analyze is None:
        parser.print_help()
        return

    if args.generate:
        # The package is part of Open Logic itself, hence it is written next to the other sources
        directory = abspath(join(dirname(__file__), "..", "..", "vhdl"))
        name      = olo_fix_lin_approx_qsin.generate_package(directory)
        print(f"Generated {join(directory, name)}.vhd")

    if args.analyze is not None:
        from .olo_fix_utils import olo_fix_utils

        try:
            out_fmt = olo_fix_utils.fix_format_from_string(args.analyze)
        except ValueError:
            parser.error(f"--analyze: '{args.analyze}' is not a number format - use the form "
                         f"\"(1,0,15)\"")

        # The table content does not depend on the phase resolution, hence the approximation is
        # analyzed at the resolution recommended for the output format
        try:
            model = olo_fix_lin_approx_qsin._reference_model(out_fmt)
        except ValueError as e:
            parser.error(f"--analyze: {e}")

        # analyze() of the wrapped approximation plots it against the ideal function and prints
        # the error plus the value ranges required by the offset/gradient tables
        model._approx.analyze()

if __name__ == "__main__": # pragma: no cover
    main()
