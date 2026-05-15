---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a complex-to-real mixer.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_mix_c2r.md
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
entity olo_fix_mix_c2r is
    generic (
        -- Formats / Round / Saturate
        InFmt_g      : string;
        MixFmt_g     : string;
        OutFmt_g     : string;
        Round_g      : string  := FixRound_Trunc_c;
        Saturate_g   : string  := FixSaturate_Warn_c;
        -- Registers
        MultRegs_g   : natural := 1;
        -- I/Q Handling
        IqHandling_g : string  := "Parallel"
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input
        In_Valid    : in    std_logic                                                      := '1';
        In_SigI     : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)  := (others => '0');
        In_SigQ     : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)  := (others => '0');
        In_MixI     : in    std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0) := (others => '0');
        In_MixQ     : in    std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0) := (others => '0');
        In_SigIQ    : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0)  := (others => '0');
        In_MixIQ    : in    std_logic_vector(fixFmtWidthFromString(MixFmt_g) - 1 downto 0) := (others => '0');
        In_Last     : in    std_logic                                                      := '0';
        -- Output
        Out_Valid   : out   std_logic;
        Out_SigReal : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_mix_c2r is

    -- Formats
    constant InFmt_c  : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant MixFmt_c : FixFormat_t := cl_fix_format_from_string(MixFmt_g);
    constant OutFmt_c : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- Multiply and chain formats (same structure as olo_fix_cplx_mult MULT4)
    constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(InFmt_c, MixFmt_c);
    constant ChainFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);

    -- Round/Sat registers
    constant RoundReg_c : string := choose(compareNoCase(Round_g, FixRound_Trunc_c), "NO", "YES");
    constant SatReg_c   : string := choose(compareNoCase(Saturate_g, FixSaturate_Warn_c) or
                                           compareNoCase(Saturate_g, FixSaturate_None_c), "NO", "YES");

begin

    -- Assertions
    -- synthesis translate_off
    assert compareNoCase(IqHandling_g, "Parallel") or compareNoCase(IqHandling_g, "TDM")
        report "olo_fix_mix_c2r: Invalid IqHandling_g: " & IqHandling_g
        severity error;
    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Parallel I/Q Architecture
    -----------------------------------------------------------------------------------------------
    g_parallel : if compareNoCase(IqHandling_g, "Parallel") generate

        signal In_Valid_0 : std_logic;
        signal In_SigQ_0  : std_logic_vector(In_SigQ'range);
        signal In_MixQ_0  : std_logic_vector(In_MixQ'range);

        signal II_Out_N1    : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
        signal Real_Full_N2 : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
        signal Valid_N2     : std_logic;

    begin

        -- Pipeline stage
        p_reg : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Normal Operation
                In_Valid_0 <= In_Valid;
                In_SigQ_0  <= In_SigQ;
                In_MixQ_0  <= In_MixQ;

                -- Reset
                if Rst = '1' then
                    In_Valid_0 <= '0';
                end if;
            end if;
        end process;

        -- I x I multiplication
        i_ii : entity work.olo_fix_madd
            generic map (
                AFmt_g        => InFmt_g,
                BFmt_g        => MixFmt_g,
                AddChainFmt_g => to_string(ChainFmt_c),
                MultRegs_g    => MultRegs_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                InAC_Valid => In_Valid,
                InA_Data   => In_SigI,
                InB_Valid  => In_Valid,
                InB_Data   => In_MixI,
                Out_Data   => II_Out_N1
            );

        -- Q x Q multiplication (+ accumulation)
        i_qq : entity work.olo_fix_madd
            generic map (
                AFmt_g        => InFmt_g,
                BFmt_g        => MixFmt_g,
                AddChainFmt_g => to_string(ChainFmt_c),
                Operation_g   => "Add",
                MultRegs_g    => MultRegs_g
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                InAC_Valid => In_Valid_0,
                InA_Data   => In_SigQ_0,
                InB_Valid  => In_Valid_0,
                InB_Data   => In_MixQ_0,
                MaccIn     => II_Out_N1,
                Out_Data   => Real_Full_N2,
                Out_Valid  => Valid_N2
            );

        -- Resize to output format
        i_resize : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(ChainFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => RoundReg_c,
                SatReg_g    => SatReg_c
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => Valid_N2,
                In_A       => Real_Full_N2,
                Out_Valid  => Out_Valid,
                Out_Result => Out_SigReal
            );

    end generate;

    -----------------------------------------------------------------------------------------------
    -- TDM I/Q Architecture
    -----------------------------------------------------------------------------------------------
    g_tdm : if compareNoCase(IqHandling_g, "TDM") generate

        constant SumFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);
        constant Stages_c : natural     := MultRegs_g + 2;

        signal IsQ           : std_logic;
        signal Valid_I       : std_logic_vector(0 to Stages_c - 1);
        signal Valid_Q       : std_logic_vector(0 to Stages_c - 1);
        signal InSig_0       : std_logic_vector(In_SigIQ'range);
        signal InMix_0       : std_logic_vector(In_MixIQ'range);
        signal MultI_N0      : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal MultI_Hold_N1 : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal AddI_N1       : std_logic_vector(cl_fix_width(SumFmt_c) - 1 downto 0);
        signal MultI_Valid   : std_logic;

        attribute use_dsp                    : string;
        attribute use_dsp of AddI_N1 : signal is "no";

    begin

        -- Clocked process
        p_reg : process (Clk) is
        begin
            if rising_edge(Clk) then

                -- Shift valids
                Valid_I(0)                 <= In_Valid and not IsQ;
                Valid_Q(0)                 <= In_Valid and IsQ;
                Valid_I(1 to Valid_I'high) <= Valid_I(0 to Valid_I'high - 1);
                Valid_Q(1 to Valid_Q'high) <= Valid_Q(0 to Valid_Q'high - 1);

                -- I/Q detection
                if In_Valid = '1' then
                    if In_Last = '1' then
                        IsQ <= '0';
                    else
                        IsQ <= not IsQ;
                    end if;
                end if;

                -- Input registers
                if In_Valid = '1' then
                    InSig_0 <= In_SigIQ;
                    InMix_0 <= In_MixIQ;
                end if;

                -- I path: hold SigI*MixI until Q sample arrives
                if Valid_I(MultRegs_g) = '1' then
                    MultI_Hold_N1 <= MultI_N0;
                end if;

                -- I path: accumulate SigI*MixI + SigQ*MixQ (MIX mode: add)
                if Valid_Q(MultRegs_g) = '1' then
                    AddI_N1 <= cl_fix_add(MultI_Hold_N1, MultFmt_c, MultI_N0, MultFmt_c, SumFmt_c);
                end if;

                -- Reset
                if Rst = '1' then
                    IsQ     <= '0';
                    Valid_I <= (others => '0');
                    Valid_Q <= (others => '0');
                end if;

            end if;
        end process;

        -- Multiplier: alternates between SigI*MixI and SigQ*MixQ
        MultI_Valid <= Valid_I(0) or Valid_Q(0);

        i_mult_i : entity work.olo_fix_mult
            generic map (
                AFmt_g      => InFmt_g,
                BFmt_g      => MixFmt_g,
                ResultFmt_g => to_string(MultFmt_c),
                OpRegs_g    => MultRegs_g,
                RoundReg_g  => "NO",
                SatReg_g    => "NO"
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => MultI_Valid,
                In_A       => InSig_0,
                In_B       => InMix_0,
                Out_Result => MultI_N0
            );

        -- Resize to output format
        i_resize : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(SumFmt_c),
                ResultFmt_g => OutFmt_g,
                Round_g     => Round_g,
                Saturate_g  => Saturate_g,
                RoundReg_g  => RoundReg_c,
                SatReg_g    => SatReg_c
            )
            port map (
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => Valid_Q(MultRegs_g + 1),
                In_A       => AddI_N1,
                Out_Valid  => Out_Valid,
                Out_Result => Out_SigReal
            );

    end generate;

end architecture;
