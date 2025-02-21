---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_add function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_add.md
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

entity olo_fix_add is
    generic (
        -- Formats / Round / Saturate
        AFmt_g      : string;
        BFmt_g      : string;
        ResultFmt_g : string;
        Round_g     : string  := FixRound_Trunc_c;
        Saturate_g  : string  := FixSaturate_Warn_c;
        -- Registers
        OpReg_g     : string := "YES";
        RoundReg_g  : string := "YES";
        SatReg_g    : string := "YES"
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

architecture rtl of olo_fix_add is

    -- String to en_cl_fix
    constant AFmt_c      : FixFormat_t   := cl_fix_format_from_string(AFmt_g);
    constant BFmt_c      : FixFormat_t   := cl_fix_format_from_string(BFmt_g);
    
    -- Constants
    constant AddFmt_c       : FixFormat_t := cl_fix_add_fmt(AFmt_c, BFmt_c);
    constant ImplementReg_c : boolean     := fixImplementReg(true, OpReg_g);

    -- Signals
    signal Add_Valid     : std_logic;
    signal Add_DataComb  : std_logic_vector(cl_fix_width(AddFmt_c) - 1 downto 0);
    signal Add_Data      : std_logic_vector(cl_fix_width(AddFmt_c) - 1 downto 0);

begin

    -- Operation
    Add_DataComb <= cl_fix_add(In_A, AFmt_c, In_B, BFmt_c, AddFmt_c, Trunc_s, Warn_s);

    -- Registered Add
    g_reg : if ImplementReg_c generate
        process(Clk)
        begin
            if rising_edge(Clk) then
                -- Normal Operation
                Add_Valid <= In_Valid;
                Add_Data <= Add_DataComb;
                -- Reset
                if Rst = '1' then
                    Add_Valid <= '0';
                end if;
            end if;
        end process;
    end generate;

    -- Combinatorial Add
    g_comb : if not ImplementReg_c generate
        Add_Valid <= In_Valid;
        Add_Data  <= Add_DataComb;
    end generate;

    -- Resize
    i_round : entity work.olo_fix_round
        generic map (
            AFmt_g      => AddFmt_c,
            ResultFmt_g => ResultFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => RoundReg_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Add_Valid,
            In_A        => Add_Data,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
