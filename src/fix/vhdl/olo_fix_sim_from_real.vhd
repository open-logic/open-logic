---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_from_real function as entity. it does NOT include pipeline
-- stages because real numbers are only used for synthesis/simuation. They do not exist in the
-- hardware.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sim_from_real.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_sim_from_real is
    generic (
        -- Formats / Saturate
        ResultFmt_g : string;
        Saturate_g  : string := FixSaturate_SatWarn_c;
        -- Value can be passed as generic or port
        Value_g     : real   := 0.0
    );
    port (
        -- Input (only used of UsePort_g is true)
        In_Value    : in    real := Value_g;
        -- Output
        Out_Value   : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_sim_from_real is

    -- String to en_cl_fix
    constant ResultFmt_c : FixFormat_t   := cl_fix_format_from_string(ResultFmt_g);
    constant Saturate_c  : FixSaturate_t := cl_fix_saturate_from_string(Saturate_g);

begin

    -- Convert real to fix
    Out_Value <= cl_fix_from_real(In_Value, ResultFmt_c, Saturate_c);

end architecture;
