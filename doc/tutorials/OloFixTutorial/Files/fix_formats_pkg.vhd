---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;
    use olo.en_cl_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package fix_formats_pkg is

    constant FmtIn_c      : FixFormat_t := (1, 3, 8);
    constant FmtOut_c     : FixFormat_t := (1, 3, 8);
    constant FmtKp_c      : FixFormat_t := (0, 8, 4);
    constant FmtKi_c      : FixFormat_t := (0, 4, 4);
    constant FmtIlim_c    : FixFormat_t := (0, 4, 4);
    constant FmtIlimNeg_c : FixFormat_t := (1, FmtIlim_c.I, FmtIlim_c.F);
    constant FmtErr_c     : FixFormat_t := cl_fix_sub_fmt(FmtIn_c, FmtIn_c);
    constant FmtPpart_c   : FixFormat_t := FmtOut_c;
    constant FmtImult_c   : FixFormat_t := cl_fix_mult_fmt(FmtErr_c, FmtKi_c);
    constant FmtIadd_c    : FixFormat_t := cl_fix_add_fmt(FmtIlim_c, FmtImult_c);
    constant FmtI_c       : FixFormat_t := (FmtIadd_c.S, FmtIlim_c.I, FmtIadd_c.F);

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body fix_formats_pkg is

end package body;
