---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_array.all;
    use olo.en_cl_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Package Declaration
---------------------------------------------------------------------------------------------------
package fix_formats_pkg is

    -- Constants

    constant FmtIn_c : FixFormat_t := (1, 3, 8);

    constant FmtOut_c : FixFormat_t := (1, 3, 8);

    constant FmtKp_c : FixFormat_t := (0, 8, 4);

    constant FmtKi_c : FixFormat_t := (0, 4, 4);

    constant FmtIlim_c : FixFormat_t := (0, 4, 4);

    constant FmtIlimNeg_c : FixFormat_t := (1, 4, 4);

    constant FmtErr_c : FixFormat_t := (1, 4, 8);

    constant FmtPpart_c : FixFormat_t := (1, 3, 8);

    constant FmtImult_c : FixFormat_t := (1, 8, 12);

    constant FmtIadd_c : FixFormat_t := (1, 9, 12);

    constant FmtI_c : FixFormat_t := (1, 4, 12);

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body fix_formats_pkg is

end package body;
