---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a real-to-complex mixer. It multiplies a real input signal with a
-- complex local oscillator to produce a complex output using the downconversion convention:
--   Out_I = +In_SigReal x In_MixI
--   Out_Q = -In_SigReal x In_MixQ
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_mix_r2c.md
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
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_mix_r2c is
    generic (
        -- Formats / Round / Saturate
        InFmt_g    : string;
        MixFmt_g   : string;
        OutFmt_g   : string;
        Round_g    : string  := FixRound_Trunc_c;
        Saturate_g : string  := FixSaturate_Warn_c;
        -- Registers
        MultRegs_g : natural := 1
    );
    port (
        -- Control Ports
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        -- Input
        In_Valid   : in    std_logic := '1';
        In_SigReal : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_MixI    : in    std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
        In_MixQ    : in    std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0);
        -- Output
        Out_Valid  : out   std_logic;
        Out_I      : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Q      : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_mix_r2c is

    -- Formats
    constant InFmt_c  : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant MixFmt_c : FixFormat_t := cl_fix_format_from_string(MixFmt_g);
    constant OutFmt_c : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Q channel intermediate formats (mirrors olo_fix_cplx_mult MIX mode for bit-true match)
    constant MultFmt_c : FixFormat_t := cl_fix_mult_fmt(InFmt_c, MixFmt_c);
    constant NegFmt_c  : FixFormat_t := cl_fix_neg_fmt(MultFmt_c);

    -- Input register
    signal In_Valid_Reg   : std_logic;
    signal In_SigReal_Reg : std_logic_vector(cl_fix_width(InFmt_c) - 1 downto 0);
    signal In_MixI_Reg    : std_logic_vector(cl_fix_width(MixFmt_c) - 1 downto 0);
    signal In_MixQ_Reg    : std_logic_vector(cl_fix_width(MixFmt_c) - 1 downto 0);

    -- Full-precision multiplier outputs
    signal Mult_I     : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    signal Mult_Q     : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    signal Mult_Valid : std_logic;

    -- Registered pipeline stage: I pass-through, Q negation
    signal Mult_I_Reg : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
    signal Neg_Q      : std_logic_vector(cl_fix_width(NegFmt_c) - 1 downto 0);
    signal Neg_Valid  : std_logic;

begin

    -- *** Input Register ***
    p_in_reg : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            In_Valid_Reg   <= In_Valid;
            In_SigReal_Reg <= In_SigReal;
            In_MixI_Reg    <= In_MixI;
            In_MixQ_Reg    <= In_MixQ;

            -- Reset
            if Rst = '1' then
                In_Valid_Reg <= '0';
            end if;
        end if;
    end process;

    -- *** I Multiplier ***
    i_mult_i : entity work.olo_fix_mult
        generic map (
            AFmt_g      => InFmt_g,
            BFmt_g      => MixFmt_g,
            ResultFmt_g => to_string(MultFmt_c),
            Round_g     => FixRound_Trunc_c,
            Saturate_g  => FixSaturate_None_c,
            OpRegs_g    => MultRegs_g,
            RoundReg_g  => "NO",
            SatReg_g    => "NO"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid_Reg,
            In_A       => In_SigReal_Reg,
            In_B       => In_MixI_Reg,
            Out_Valid  => Mult_Valid,
            Out_Result => Mult_I
        );

    -- *** Q Multiplier ***
    i_mult_q : entity work.olo_fix_mult
        generic map (
            AFmt_g      => InFmt_g,
            BFmt_g      => MixFmt_g,
            ResultFmt_g => to_string(MultFmt_c),
            Round_g     => FixRound_Trunc_c,
            Saturate_g  => FixSaturate_None_c,
            OpRegs_g    => MultRegs_g,
            RoundReg_g  => "NO",
            SatReg_g    => "NO"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => In_Valid_Reg,
            In_A       => In_SigReal_Reg,
            In_B       => In_MixQ_Reg,
            Out_Valid  => open,
            Out_Result => Mult_Q
        );

    -- *** Negation ***
    p_pipe : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            Mult_I_Reg <= Mult_I;
            Neg_Q      <= cl_fix_neg(Mult_Q, MultFmt_c, NegFmt_c);
            Neg_Valid  <= Mult_Valid;

            -- Reset
            if Rst = '1' then
                Neg_Valid <= '0';
            end if;
        end if;
    end process;

    -- *** I resize ***
    i_resize_i : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(MultFmt_c),
            ResultFmt_g => OutFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => "YES",
            SatReg_g    => "YES"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => Neg_Valid,
            In_A       => Mult_I_Reg,
            Out_Valid  => Out_Valid,
            Out_Result => Out_I
        );

    -- *** Q resize ***
    i_resize_q : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(NegFmt_c),
            ResultFmt_g => OutFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => "YES",
            SatReg_g    => "YES"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => Neg_Valid,
            In_A       => Neg_Q,
            Out_Valid  => open,
            Out_Result => Out_Q
        );

end architecture;
