---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a sample and hold for fixed-point numbers. The output holds the last
-- sampled value until a new sample is taken.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sample_hold.md
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
entity olo_fix_sample_hold is
    generic (
        Fmt_g        : string;
        ResetValue_g : real    := 0.0;
        ResetValid_g : boolean := true
    );
    port (
        -- Control Ports
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Data   : in    std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
        In_Valid  : in    std_logic;
        -- Output
        Out_Data  : out   std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
        Out_Valid : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_sample_hold is

    -- String to en_cl_fix
    constant Fmt_c : FixFormat_t := cl_fix_format_from_string(Fmt_g);

    -- Reset value as std_logic_vector
    constant RstVal_c : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0) := cl_fix_from_real(ResetValue_g, Fmt_c);

begin

    -- Instantiate base sample hold
    i_sample_hold : entity work.olo_base_sample_hold
        generic map (
            Width_g      => fixFmtWidthFromString(Fmt_g),
            ResetValue_g => RstVal_c,
            ResetValid_g => ResetValid_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => In_Data,
            In_Valid  => In_Valid,
            Out_Data  => Out_Data,
            Out_Valid => Out_Valid
        );

end architecture;
