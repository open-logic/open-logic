---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_compare function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_compare.md
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

entity olo_fix_compare is
    generic (
        -- Formats / Round / Saturate
        AFmt_g       : string;
        BFmt_g       : string;
        Comparison_g : string;
        -- Registers
        OpRegs_g     : natural := 1
    );
    port (
        -- Control Ports
        Clk         : in    std_logic := '0';
        Rst         : in    std_logic := '0';
        -- Input
        In_Valid    : in    std_logic := '1';
        In_A        : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        In_B        : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Result  : out   std_logic
    );
end entity;

architecture rtl of olo_fix_compare is

    -- String to en_cl_fix
    constant AFmt_c : FixFormat_t := cl_fix_format_from_string(AFmt_g);
    constant BFmt_c : FixFormat_t := cl_fix_format_from_string(BFmt_g);

    -- Signals
    signal Comp_DataComb : std_logic;
    signal Comp_DataBool : boolean;

begin

    -- Operation
    Comp_DataBool <= cl_fix_compare(Comparison_g, In_A, AFmt_c, In_B, BFmt_c);
    Comp_DataComb <= '1' when Comp_DataBool else '0';

    -- Op Register
    i_reg : entity work.olo_fix_private_optional_reg
        generic map (
            Width_g    => 1,
            Stages_g   => OpRegs_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            In_Valid     => In_Valid,
            In_Data(0)   => Comp_DataComb,
            Out_Valid    => Out_Valid,
            Out_Data(0)  => Out_Result
        );

end architecture;
