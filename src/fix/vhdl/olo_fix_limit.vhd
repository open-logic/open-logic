---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements the cl_fix_limit function as entity. Includes pipeline stages
-- and allows usage from Verilog.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_limit.md
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
entity olo_fix_limit is
    generic (
        -- Formats / Round / Saturate
        InFmt_g          : string;
        LimLoFmt_g       : string  := "(1,1,1)";
        LimHiFmt_g       : string  := "(1,1,1)";
        ResultFmt_g      : string;
        Round_g          : string  := FixRound_Trunc_c;
        Saturate_g       : string  := FixSaturate_Warn_c;
        -- Optional fixed limits
        UseFixedLimits_g : boolean := false;
        FixedLimLo_g     : real    := 0.0;
        FixedLimHi_g     : real    := 0.0;
        -- Registers
        RoundReg_g       : string  := "YES";
        SatReg_g         : string  := "YES"
    );
    port (
        -- Control Ports
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        -- Input
        In_Valid   : in    std_logic                                                        := '1';
        In_Data    : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_LimLo   : in    std_logic_vector(fixFmtWidthFromString(LimLoFmt_g) - 1 downto 0) := (others => '0');
        In_LimHi   : in    std_logic_vector(fixFmtWidthFromString(LimHiFmt_g) - 1 downto 0) := (others => '0');
        -- Output
        Out_Valid  : out   std_logic;
        Out_Result : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_limit is

    -- String to en_cl_fix
    constant InFmt_c    : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant LimLoFmt_c : FixFormat_t := choose(UseFixedLimits_g, InFmt_c, cl_fix_format_from_string(LimLoFmt_g));
    constant LimHiFmt_c : FixFormat_t := choose(UseFixedLimits_g, InFmt_c, cl_fix_format_from_string(LimHiFmt_g));

    -- Constants
    constant IntFmt_c : FixFormat_t := (max(max(InFmt_c.S, LimLoFmt_c.S), LimHiFmt_c.S),
                                        max(max(InFmt_c.I, LimLoFmt_c.I), LimHiFmt_c.I),
                                        max(max(InFmt_c.F, LimLoFmt_c.F), LimHiFmt_c.F));

    -- Types
    type Select_t is (LimLo_s, LimHi_s, Data_s);

    -- Signals
    signal InFull_0     : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
    signal LimLoFull_0  : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
    signal LimHiFull_0  : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
    signal Select_1     : Select_t;
    signal InFull_1     : std_logic_vector(InFull_0'range);
    signal LimLoFull_1  : std_logic_vector(LimLoFull_0'range);
    signal LimHiFull_1  : std_logic_vector(LimHiFull_0'range);
    signal Valid_1      : std_logic;
    signal ResultFull_2 : std_logic_vector(cl_fix_width(IntFmt_c) - 1 downto 0);
    signal Valid_2      : std_logic;

begin

    -- Extend all formats to the same and use fixed limits if required
    InFull_0 <= cl_fix_resize(In_Data, InFmt_c, IntFmt_c);

    g_fix_lim : if UseFixedLimits_g generate
        LimLoFull_0 <= cl_fix_from_real(FixedLimLo_g, IntFmt_c);
        LimHiFull_0 <= cl_fix_from_real(FixedLimHi_g, IntFmt_c);
    end generate;

    g_dynamic_lim : if not UseFixedLimits_g generate
        LimLoFull_0 <= cl_fix_resize(In_LimLo, LimLoFmt_c, IntFmt_c);
        LimHiFull_0 <= cl_fix_resize(In_LimHi, LimHiFmt_c, IntFmt_c);
    end generate;

    -- limit
    p_limit : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Stage 1
            if cl_fix_compare("<", InFull_0, IntFmt_c, LimLoFull_0, IntFmt_c) then
                Select_1 <= LimLo_s;
            elsif cl_fix_compare(">", InFull_0, IntFmt_c, LimHiFull_0, IntFmt_c) then
                Select_1 <= LimHi_s;
            else
                Select_1 <= Data_s;
            end if;
            InFull_1    <= InFull_0;
            LimLoFull_1 <= LimLoFull_0;
            LimHiFull_1 <= LimHiFull_0;
            Valid_1     <= In_Valid;

            -- Stage 2
            case Select_1 is
                when LimLo_s => ResultFull_2 <= LimLoFull_1;
                when LimHi_s => ResultFull_2 <= LimHiFull_1;
                when Data_s => ResultFull_2 <= InFull_1;
                -- coverage off
                when others => ResultFull_2 <= InFull_1;
                -- coverage on
            end case;

            Valid_2 <= Valid_1;

            -- Reset
            if Rst = '1' then
                Valid_1 <= '0';
                Valid_2 <= '0';
            end if;
        end if;
    end process;

    -- Resize
    i_round : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(IntFmt_c),
            ResultFmt_g => ResultFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => RoundReg_g,
            SatReg_g    => SatReg_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Valid_2,
            In_A        => ResultFull_2,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
