---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_abs function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_abs.md
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
entity olo_fix_abs is
    generic (
        -- Formats / Round / Saturate
        AFmt_g      : string;
        ResultFmt_g : string;
        Round_g     : string  := FixRound_Trunc_c;
        Saturate_g  : string  := FixSaturate_Warn_c;
        -- Registers
        OpRegs_g    : natural := 1;
        RoundReg_g  : string  := "YES";
        SatReg_g    : string  := "YES"
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

architecture rtl of olo_fix_abs is

    -- String to en_cl_fix
    constant AFmt_c : FixFormat_t := cl_fix_format_from_string(AFmt_g);

    -- Constants
    constant AbsFmt_c : FixFormat_t := cl_fix_abs_fmt(AFmt_c);

    -- Signals
    signal Abs_Valid    : std_logic;
    signal Abs_DataComb : std_logic_vector(cl_fix_width(AbsFmt_c) - 1 downto 0);
    signal Abs_Data     : std_logic_vector(cl_fix_width(AbsFmt_c) - 1 downto 0);

begin

    -- Operation
    Abs_DataComb <= cl_fix_abs(In_A, AFmt_c, AbsFmt_c, Trunc_s, Warn_s);

    -- Op Register
    i_reg : entity work.olo_fix_private_optional_reg
        generic map (
            Width_g    => cl_fix_width(AbsFmt_c),
            Stages_g   => OpRegs_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Data   => Abs_DataComb,
            Out_Valid => Abs_Valid,
            Out_Data  => Abs_Data
        );

    -- Resize
    i_round : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(AbsFmt_c),
            ResultFmt_g => ResultFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => RoundReg_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Abs_Valid,
            In_A        => Abs_Data,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
