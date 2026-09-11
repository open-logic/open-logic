# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
import os
from os.path import join
from typing import Callable, Tuple
from jinja2 import Environment, FileSystemLoader

from .olo_fix_cosim import olo_fix_cosim

# ---------------------------------------------------------------------------------------------------
# Configuration Container
# ---------------------------------------------------------------------------------------------------
class olo_fix_lin_approx_cfg:

    """
    Data container describing the configuration of a linear approximation.
    """

    def __init__(self,
                 function : Callable,
                 in_fmt : FixFormat,
                 out_fmt : FixFormat,
                 offs_fmt : FixFormat,
                 grad_fmt : FixFormat,
                 points : int,
                 name : str,
                 valid_range : Tuple[float, float] = None,
                 round : FixRound = FixRound.NonSymPos_s,
                 saturate : FixSaturate = FixSaturate.Sat_s):
        """
        Constructor of the olo_fix_lin_approx_cfg class

        :param function: Function to approximate over the full range of in_fmt. Lambdas (e.g.
                         lambda x: np.sin(x*2*np.pi)) can be used to scale the X/Y axes. The function
                         must be able to process numpy arrays.
        :param in_fmt: Format of the input to the approximation
        :param out_fmt: Format of the output of the approximation
        :param offs_fmt: Format of the offset table (function values at the segment centers)
        :param grad_fmt: Format of the gradient table (derivatives at the segment centers)
        :param points: Number of points (segments) in the offset/gradient table. Must be a power of two.
        :param name: Name suffix of the approximator generated (used for code generation)
        :param valid_range: Range in which the approximation is valid. The range is clipped to the
                            range representable by in_fmt. If None, the full range of in_fmt is used.
        :param round: Rounding mode of the output stage
        :param saturate: Saturation mode of the output stage
        """
        # Name (must be usable as part of a VHDL identifier)
        if not name.isidentifier() or not name[0].isalpha():
            raise ValueError(f"olo_fix_lin_approx_cfg: name '{name}' is not a valid VHDL identifier")

        # Points must be a power of two and must not consume all input bits
        if points < 2 or not float(np.log2(points)).is_integer():
            raise ValueError(f"olo_fix_lin_approx_cfg: points ({points}) must be a power of two >= 2")
        if np.log2(points) >= cl_fix_width(in_fmt):
            raise ValueError(f"olo_fix_lin_approx_cfg: points ({points}) must be smaller than "
                             f"2**width(in_fmt) ({2**cl_fix_width(in_fmt)})")

        # Valid range (clipped to the range representable by in_fmt)
        fmt_range = (cl_fix_min_value(in_fmt), cl_fix_max_value(in_fmt))
        if valid_range is None:
            valid_range = fmt_range
        self.valid_range = (max(valid_range[0], fmt_range[0]), min(valid_range[1], fmt_range[1]))
        if self.valid_range[0] >= self.valid_range[1]:
            raise ValueError(f"olo_fix_lin_approx_cfg: valid_range {valid_range} does not overlap "
                             f"with the range representable by in_fmt {fmt_range}")

        # Parameters without check
        self.function = function
        self.in_fmt = in_fmt
        self.out_fmt = out_fmt
        self.offs_fmt = offs_fmt
        self.grad_fmt = grad_fmt
        self.points = points
        self.name = name
        self.round = round
        self.saturate = saturate

# ---------------------------------------------------------------------------------------------------
# Class
# ---------------------------------------------------------------------------------------------------
class olo_fix_lin_approx:

    """
    Bit-true model and code generator of olo_fix_lin_approx_calc based function approximations.

    A function is approximated by a table containing the function value (offset) and its derivative
    (gradient) for regularly spaced points. Between those points the function is approximated
    linearly.

    The class does not only implement the bit-true model but it also generates the VHDL entity
    (containing the table) and a corresponding bit-true testbench.
    """

    _TEMPLATE_DIR = os.path.abspath(join(os.path.dirname(__file__), "templates"))

    # ---------------------------------------------------------------------------------------------------
    # Constructor
    # ---------------------------------------------------------------------------------------------------
    def __init__(self, cfg : olo_fix_lin_approx_cfg):
        """
        Constructor of the olo_fix_lin_approx class

        :param cfg: Configuration of the approximation (olo_fix_lin_approx_cfg)
        """
        self.cfg = cfg

        # Formats
        index_bits = int(np.log2(cfg.points))
        offset_bits = cl_fix_width(cfg.in_fmt) - index_bits
        # Remainder relative to the beginning of the segment (unsigned)
        self._rem_fmt = FixFormat(0, offset_bits - cfg.in_fmt.F, cfg.in_fmt.F)
        # Remainder relative to the center of the segment (signed, MSB inverted)
        self._rem_fmt_signed = FixFormat(1, self._rem_fmt.I - 1, self._rem_fmt.F)
        # Table index (unsigned, negative inputs wrap into the upper half of the table)
        # The index is the input shifted right by the number of remainder bits, hence F = -rem_fmt.I
        self._idx_fmt = FixFormat(0, cfg.in_fmt.S + cfg.in_fmt.I, -self._rem_fmt.I)
        # Intermediate results (lossless, hence no rounding/saturation is required)
        self._int_fmt = cl_fix_mult_fmt(cfg.grad_fmt, self._rem_fmt_signed)
        self._add_fmt = cl_fix_add_fmt(cfg.offs_fmt, self._int_fmt)

        # Segment centers - the first segment starts at the smallest representable input value
        lower_bound = cl_fix_min_value(cfg.in_fmt)
        step = (2.0**cfg.in_fmt.I - lower_bound) / cfg.points
        centers = lower_bound + step * (np.arange(cfg.points) + 0.5)
        # For signed inputs, negative values wrap into the upper half of the table
        if cfg.in_fmt.S == 1:
            centers = np.concatenate((centers[cfg.points//2:], centers[:cfg.points//2]))

        # Tables
        self.grad_table = cl_fix_from_real(self._derivative(cfg.function, centers),
                                           cfg.grad_fmt, FixSaturate.Sat_s)
        self.offs_table = cl_fix_from_real(cfg.function(centers),
                                           cfg.offs_fmt, FixSaturate.Sat_s)
        self.centers = centers

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

    def next(self, in_data):
        """
        Process next N samples

        :param in_data: Input data
        :return: Result
        """
        # Convert scalars to 1d array
        if np.isscalar(in_data):
            in_data = np.array([in_data])

        # Quantize input
        in_data = cl_fix_from_real(in_data, self.cfg.in_fmt)

        # Split input into table index and remainder
        index = self._table_index(in_data)
        remainder = cl_fix_resize(in_data, self.cfg.in_fmt, self._rem_fmt,
                                  FixRound.Trunc_s, FixSaturate.None_s)
        # Subtracting half of the segment width is equal to inverting the MSB in HDL
        remainder = remainder - 2.0**(self._rem_fmt.I - 1)

        # Approximation
        grad_val = cl_fix_mult(self.grad_table[index], self.cfg.grad_fmt,
                               remainder, self._rem_fmt_signed,
                               self._int_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        add_val = cl_fix_add(self.offs_table[index], self.cfg.offs_fmt,
                             grad_val, self._int_fmt,
                             self._add_fmt, FixRound.Trunc_s, FixSaturate.None_s)
        return cl_fix_resize(add_val, self._add_fmt, self.cfg.out_fmt,
                             self.cfg.round, self.cfg.saturate)

    def process(self, in_data):
        """
        Process samples (without preserving previous state)

        :param in_data: Input data
        :return: Result
        """
        # The approximation is stateless, hence process() and next() are identical
        return self.next(in_data)

    # ---------------------------------------------------------------------------------------------------
    # Code Generation
    #
    # The code generation is not covered by the python unit-tests. The generated HDL is verified against
    # the bit-true model through the co-simulation (see test/fix/olo_fix_lin_approx), which covers this
    # code end-to-end - including the templates, which unit-tests cannot check.
    # ---------------------------------------------------------------------------------------------------
    def generate_entity(self, directory : str, olo_library : str = "olo") -> str: # pragma: no cover
        """
        Generate the VHDL implementation of the approximation (entity including the table)

        :param directory: Target directory
        :param olo_library: Name of the VHDL library Open Logic is compiled into. This argument is
                            optional and the default library is "olo".
        :return: Name of the entity generated
        """
        entity_name = self.entity_name

        # Assemble data
        table = [self._bit_string(g, self.cfg.grad_fmt) + self._bit_string(o, self.cfg.offs_fmt)
                 for g, o in zip(self.grad_table, self.offs_table)]
        data = {
            "entity_name" : entity_name,
            "olo_library" : olo_library,
            "in_fmt" : self._fmt_string(self.cfg.in_fmt),
            "out_fmt" : self._fmt_string(self.cfg.out_fmt),
            "offs_fmt" : self._fmt_string(self.cfg.offs_fmt),
            "grad_fmt" : self._fmt_string(self.cfg.grad_fmt),
            "in_width" : cl_fix_width(self.cfg.in_fmt),
            "out_width" : cl_fix_width(self.cfg.out_fmt),
            "table_size" : self.cfg.points,
            "table_width" : cl_fix_width(self.cfg.grad_fmt) + cl_fix_width(self.cfg.offs_fmt),
            "table" : table,
            "round" : self.cfg.round.name,
            "saturate" : self.cfg.saturate.name
        }

        # Render template
        self._render("olo_fix_lin_approx_entity_vhdl.template", data,
                     join(directory, f"{entity_name}.vhd"))
        return entity_name

    def generate_tb(self, directory : str, olo_library : str = "olo", # pragma: no cover
                    sim_points : int = 1000, sim_range : Tuple[float, float] = None) -> str:
        """
        Generate a bit-true testbench for the approximation (including stimuli/response files)

        :param directory: Target directory (the testbench reads the data files from this directory)
        :param olo_library: Name of the VHDL library Open Logic is compiled into. This argument is
                            optional and the default library is "olo".
        :param sim_points: Number of points to simulate
        :param sim_range: Range of the values to simulate. If None, the valid range is used.
        :return: Name of the testbench entity generated
        """
        entity_name = self.entity_name

        # Calculate stimuli/response
        in_data = self.stimuli(sim_points, sim_range)
        out_data = self.process(in_data)

        # Write stimuli/response files
        writer = olo_fix_cosim(directory)
        writer.write_cosim_file(in_data, self.cfg.in_fmt, f"{entity_name}_In.fix")
        writer.write_cosim_file(out_data, self.cfg.out_fmt, f"{entity_name}_Out.fix")

        # Assemble data
        data = {
            "entity_name" : entity_name,
            "olo_library" : olo_library,
            "in_fmt" : self._fmt_string(self.cfg.in_fmt),
            "out_fmt" : self._fmt_string(self.cfg.out_fmt),
            "data_dir" : join(os.path.abspath(directory), ""),
            "in_file" : f"{entity_name}_In.fix",
            "out_file" : f"{entity_name}_Out.fix"
        }

        # Render template
        self._render("olo_fix_lin_approx_tb_vhdl.template", data,
                     join(directory, f"{entity_name}_tb.vhd"))
        return f"{entity_name}_tb"

    @staticmethod
    def generate_package(approximations : dict, package_name : str,
                         directory : str) -> str: # pragma: no cover
        """
        Generate a VHDL package containing the tables of several approximations

        This is the alternative to generate_entity() for cases where one entity must be able to
        select between several tables at elaboration time (e.g. one table per output format). The
        entity then takes the table from the package instead of containing it.

        For details, see documentation.

        :param approximations: Dictionary of name (string) to olo_fix_lin_approx. One table is
                               generated per entry. The names are the keys used by the getters.
        :param package_name: Name of the package (and of the file) generated
        :param directory: Target directory
        :return: Name of the package generated
        """
        cls = olo_fix_lin_approx

        # All entries share the same width, rounded up to a multiple of four for hex literals
        widths      = [cl_fix_width(a.cfg.offs_fmt) + cl_fix_width(a.cfg.grad_fmt)
                       for a in approximations.values()]
        entry_width = ((max(widths) + 3)//4)*4

        # Assemble the data of all tables
        tables = []

        for index, (name, approx) in enumerate(approximations.items()):
            offs_fmt = approx.cfg.offs_fmt
            grad_fmt = approx.cfg.grad_fmt
            rows     = [cls._hex_string(g, grad_fmt, o, offs_fmt, entry_width)
                        for g, o in zip(approx.grad_table, approx.offs_table)]
            tables.append({
                "index" : index,
                "name" : name,
                "points" : approx.cfg.points,
                "width" : cl_fix_width(offs_fmt) + cl_fix_width(grad_fmt),
                "offs_fmt" : cls._fmt_string(offs_fmt),
                "grad_fmt" : cls._fmt_string(grad_fmt),
                "rows" : rows
            })

        # Names listed in the error message of the lookup, wrapped so no line gets too long
        available = []
        line      = ""

        for name in approximations.keys():
            entry = name if line == "" else f", {name}"
            if len(line) + len(entry) > 100:
                available.append(line + ", ")
                line = name
            else:
                line += entry
        available.append(line)

        data = {
            "package_name" : package_name,
            "entry_width" : entry_width,
            "tables" : tables,
            "available" : available
        }

        # Render template
        cls._render("olo_fix_lin_approx_pkg_vhdl.template", data,
                    join(directory, f"{package_name}.vhd"))
        return package_name

    @staticmethod
    def _hex_string(grad, grad_fmt : FixFormat, offs, offs_fmt : FixFormat,
                    width : int) -> str: # pragma: no cover
        """
        Hex representation of one table entry (gradient in the MSBs, offset in the LSBs)

        :param grad: Gradient value
        :param grad_fmt: Format of the gradient
        :param offs: Offset value
        :param offs_fmt: Format of the offset
        :param width: Width the entry is zero padded to
        :return: Hex string with width/4 characters
        """
        # Both parts are stored in two's complement representation, hence negative values are
        # wrapped into the unsigned range their format covers
        offs_width = cl_fix_width(offs_fmt)
        grad_width = cl_fix_width(grad_fmt)
        offs_int   = int(cl_fix_to_integer(offs, offs_fmt)) & (2**offs_width - 1)
        grad_int   = int(cl_fix_to_integer(grad, grad_fmt)) & (2**grad_width - 1)
        return format((grad_int << offs_width) | offs_int, f"0{width//4}X")

    @property
    def entity_name(self) -> str: # pragma: no cover
        """
        Name of the VHDL entity generated for this approximation
        """
        return f"olo_fix_lin_approx_{self.cfg.name}"

    @staticmethod
    def _fmt_string(fmt : FixFormat) -> str: # pragma: no cover
        """
        String representation of a FixFormat as expected by olo_fix string generics
        """
        return f"({fmt.S}, {fmt.I}, {fmt.F})"

    @staticmethod
    def _bit_string(value, fmt : FixFormat) -> str: # pragma: no cover
        """
        Binary string representation (two's complement) of a fixed-point value

        :param value: Value to convert (must be representable in fmt)
        :param fmt: Format of the value
        :return: Binary string with width(fmt) characters
        """
        width = cl_fix_width(fmt)
        integer = int(cl_fix_to_integer(value, fmt))
        if integer < 0:
            integer += 2**width
        return format(integer, f"0{width}b")

    @staticmethod
    def _render(template_name : str, data : dict, file_path : str) -> None: # pragma: no cover
        """
        Render a jinja2 template into a file

        :param template_name: Name of the template file (in the templates directory)
        :param data: Data passed to the template
        :param file_path: Path of the file to write
        """
        env = Environment(loader=FileSystemLoader(olo_fix_lin_approx._TEMPLATE_DIR),
                          trim_blocks=True, lstrip_blocks=True)
        template = env.get_template(template_name)
        with open(file_path, "w+") as f:
            f.write(template.render(data))

    # ---------------------------------------------------------------------------------------------------
    # Design and Verification Helpers
    #
    # These functions are not part of the bit-true model. They support the design of a new approximation
    # and the generation of its testbench - they are not meant to be called in a normal signal
    # processing flow.
    # ---------------------------------------------------------------------------------------------------
    def stimuli(self, sim_points : int = 1000, sim_range : Tuple[float, float] = None):
        """
        Generate stimuli data covering the valid range of the approximation

        :param sim_points: Number of points to generate
        :param sim_range: Range to generate the stimuli for. If None, the valid range is used.
        :return: Stimuli data (quantized to in_fmt)
        """
        if sim_range is None:
            sim_range = self.cfg.valid_range
        return cl_fix_from_real(np.linspace(sim_range[0], sim_range[1], sim_points), self.cfg.in_fmt)

    def analyze(self, sim_points : int = 100000, sim_range : Tuple[float, float] = None): # pragma: no cover
        """
        Analyze the performance of an approximation. This function is meant to be used interactively
        while designing a new approximation - it is not part of the bit-true model.

        :param sim_points: Number of points to simulate
        :param sim_range: Range of the values to simulate. If None, the valid range is used.
        """
        from matplotlib import pyplot as plt

        # Run test
        in_data = self.stimuli(sim_points, sim_range)
        actual = self.process(in_data)
        expected = self.cfg.function(in_data)

        # Table ranges of the entries actually hit by the stimuli (helps choosing offs_fmt/grad_fmt)
        used = np.unique(self._table_index(in_data))
        print(f"gradients: {min(self.grad_table[used])} ... {max(self.grad_table[used])}")
        print(f"offsets: {min(self.offs_table[used])} ... {max(self.offs_table[used])}")
        print(f"table memory width: {cl_fix_width(self.cfg.offs_fmt) + cl_fix_width(self.cfg.grad_fmt)}")

        # Error analysis
        error = actual - expected
        error_lsb = error*2**self.cfg.out_fmt.F
        print(f"maximum error: {max(abs(error))} = {max(abs(error_lsb))} LSB")

        # Plots
        plt.figure(1)
        plt.subplot(211)
        plt.title("Output")
        plt.plot(in_data, expected, 'b', label="expected")
        plt.plot(in_data, actual, 'r', label="actual")
        plt.legend()
        plt.subplot(212)
        plt.title("Error in LSB")
        plt.plot(in_data, error_lsb)
        plt.ylabel("Error [LSB]")
        plt.tight_layout(pad=2.0)
        plt.show()

    # ---------------------------------------------------------------------------------------------------
    # Private Methods
    # ---------------------------------------------------------------------------------------------------
    @staticmethod
    def _derivative(function : Callable, x, dx : float = 1e-6):
        """
        Numeric derivative of a function (central difference)

        :param function: Function to derive
        :param x: Points to calculate the derivative for
        :param dx: Step size used for the central difference
        :return: Derivative of the function at the points passed
        """
        return (function(x + dx) - function(x - dx)) / (2.0*dx)

    def _table_index(self, in_data):
        """
        Get the table index for the given (quantized) input values
        """
        index = cl_fix_resize(in_data, self.cfg.in_fmt, self._idx_fmt,
                              FixRound.Trunc_s, FixSaturate.None_s)
        return np.array(cl_fix_to_integer(index, self._idx_fmt), dtype=int)
