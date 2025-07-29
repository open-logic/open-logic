---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_resize function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_resize.md
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
entity olo_fix_resize is
    generic (
        -- Formats / Round / Saturate
        AFmt_g      : string;
        ResultFmt_g : string;
        Round_g     : string := FixRound_Trunc_c;
        Saturate_g  : string := FixSaturate_Warn_c;
        -- Registers
        RoundReg_g  : string := "YES";
        SatReg_g    : string := "YES"
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

architecture rtl of olo_fix_resize is

    -- String to en_cl_fix
    constant AFmt_c      : FixFormat_t := cl_fix_format_from_string(AFmt_g);
    constant ResultFmt_c : FixFormat_t := cl_fix_format_from_string(ResultFmt_g);
    constant Round_c     : FixRound_t  := cl_fix_round_from_string(Round_g);

    -- Constants
    constant RoundFmt_c : FixFormat_t := cl_fix_round_fmt(AFmt_c, ResultFmt_c.F, Round_c);

    -- Signals
    signal Round_Valid : std_logic;
    signal Round_Data  : std_logic_vector(cl_fix_width(RoundFmt_c) - 1 downto 0);

    -- Dummy signal to enforce the entity being mentioned in coverage report
    signal Dummy : std_logic;

begin

    -- Dummy signal to enforce the entity being mentioned in coverage report
    Dummy <= '0';

    -- Round
    i_round : entity work.olo_fix_round
        generic map (
            AFmt_g      => AFmt_g,
            ResultFmt_g => to_string(RoundFmt_c),
            Round_g     => Round_g,
            RoundReg_g  => RoundReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_A        => In_A,
            Out_Valid   => Round_Valid,
            Out_Result  => Round_Data
        );

    -- Saturate
    i_saturate : entity work.olo_fix_saturate
        generic map (
            AFmt_g      => to_string(RoundFmt_c),
            ResultFmt_g => ResultFmt_g,
            Saturate_g  => Saturate_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Round_Valid,
            In_A        => Round_Data,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
