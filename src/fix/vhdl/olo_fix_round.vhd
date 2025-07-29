---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_round function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_round.md
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
entity olo_fix_round is
    generic (
        -- Formats / Round / Saturate
        AFmt_g      : string;
        ResultFmt_g : string;
        Round_g     : string  := FixRound_NonSymPos_c;
        FmtCheck_g  : boolean := true;
        -- Registers
        RoundReg_g  : string  := "YES"
    );
    port (
        -- Control Ports
        Clk         : in    std_logic := '0';
        Rst         : in    std_logic := '0';
        -- Input
        In_Valid    : in    std_logic := '1';
        In_A        : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Result  : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_round is

    -- String to en_cl_fix
    constant Round_c     : FixRound_t  := cl_fix_round_from_string(Round_g);
    constant AFmt_c      : FixFormat_t := cl_fix_format_from_string(AFmt_g);
    constant ResultFmt_c : FixFormat_t := cl_fix_format_from_string(ResultFmt_g);

    -- Constants
    constant LogicPresent_c : boolean := AFmt_c.F > ResultFmt_c.F;
    constant ImplementReg_c : boolean := fixImplementReg(LogicPresent_c, RoundReg_g);
    constant OpRegStages_c  : integer := choose(ImplementReg_c, 1, 0);

    -- Signals
    signal ResultComb : std_logic_vector(cl_fix_width(ResultFmt_c) - 1 downto 0);

begin

    -- Operation
    ResultComb <= cl_fix_round(In_A, AFmt_c, ResultFmt_c, Round_c, FmtCheck_g);

    -- Optional Register
    i_reg : entity work.olo_fix_private_optional_reg
        generic map (
            Width_g    => cl_fix_width(ResultFmt_c),
            Stages_g   => OpRegStages_c
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Data   => ResultComb,
            Out_Valid => Out_Valid,
            Out_Data  => Out_Result
        );

end architecture;
