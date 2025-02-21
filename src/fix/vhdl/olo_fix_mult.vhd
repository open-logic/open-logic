---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_mult function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_mult.md
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

entity olo_fix_mult is
    generic (
        -- Formats / Round / Saturate
        AFmt_g      : string;
        BFmt_g      : string;
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
        Clk         : in    std_logic   := '0';
        Rst         : in    std_logic   := '0';
        -- Input
        In_Valid    : in    std_logic   := '1';
        In_A        : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        In_B        : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Result  : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_mult is

    -- String to en_cl_fix
    constant AFmt_c      : FixFormat_t   := cl_fix_format_from_string(AFmt_g);
    constant BFmt_c      : FixFormat_t   := cl_fix_format_from_string(BFmt_g);
    
    -- Constants
    constant MultFmt_c         : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);

    -- Signals
    signal Mult_Valid     : std_logic;
    signal Mult_DataComb  : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    signal Mult_Data      : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);

begin

    -- Operation
    Mult_DataComb <= cl_fix_mult(In_A, AFmt_c, In_B, BFmt_c, MultFmt_c, Trunc_s, Warn_s);

    -- Op Register
    i_reg : entity work.olo_fix_private_optional_reg
        generic map (
            Width_g    => cl_fix_width(MultFmt_c),
            Stages_g   => OpRegs_g
        );
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Data   => Mult_DataComb,
            Out_Valid => Mult_Valid,
            Out_Data  => Mult_Data
        );

    -- Resize
    i_round : entity work.olo_fix_round
        generic map (
            AFmt_g      => MultFmt_c,
            ResultFmt_g => ResultFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => RoundReg_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Mult_Valid,
            In_A        => Mult_Data,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
