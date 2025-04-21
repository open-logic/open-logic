---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_to_real function as entity. it does NOT include pipeline
-- stages because real numbers are only used for synthesis/simuation. They do not exist in the
-- hardware.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_to_real.md
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
entity olo_fix_to_real is
    generic (
        -- Formats / Saturate
        AFmt_g : string
    );
    port (
        -- Input (only used of UsePort_g is true)
        In_A      : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        -- Output
        Out_Value : out   real
    );
end entity;

architecture rtl of olo_fix_to_real is

    -- String to en_cl_fix
    constant AFmt_c : FixFormat_t := cl_fix_format_from_string(AFmt_g);

begin

    -- Convert real to fix
    Out_Value <= cl_fix_to_real(In_A, AFmt_c);

end architecture;
