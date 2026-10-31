---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a direct digital synthesizer (DDS) with complex output (sine and cosine)
-- for one or more TDM channels. Phase step and phase offset are taken from TDM inputs.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_dds.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_dds is
    generic (
        -- Configuration
        Channels_g    : positive := 1;
        -- Formats
        PhaseFmt_g    : string;
        OutFmt_g      : string;
        -- Round / Saturate
        Round_g       : string   := FixRound_NonSymPos_c;
        Saturate_g    : string   := FixSaturate_Sat_c;
        -- Resource control
        MemStyle_g    : string   := "auto";
        Resource_g    : string   := "AUTO";
        RamBehavior_g : string   := "RBW";
        RamStyle_g    : string   := "auto"
    );
    port (
        -- Control Ports
        Clk            : in    std_logic;
        Rst            : in    std_logic;
        -- Input
        In_Valid       : in    std_logic := '1';
        In_PhaseStep   : in    std_logic_vector(fixFmtWidthFromString(PhaseFmt_g) - 1 downto 0);
        In_PhaseOffset : in    std_logic_vector(fixFmtWidthFromString(PhaseFmt_g) - 1 downto 0);
        In_Restart     : in    std_logic := '0';
        -- Output
        Out_Valid      : out   std_logic;
        Out_Sin        : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Cos        : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Last       : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_dds is

    -- Constants
    constant EntityName_c : string      := "olo_fix_dds";
    constant PhaseFmt_c   : FixFormat_t := cl_fix_format_from_string(PhaseFmt_g);
    constant OutFmt_c     : FixFormat_t := cl_fix_format_from_string(OutFmt_g);

    -- The phase is rounded to four fractional bits more than the output before it is applied to
    -- olo_fix_sin. This keeps the error caused by phase quantization well below one LSB.
    constant SinPhaseFmt_c : FixFormat_t := (0, 0, work.olo_base_pkg_math.min(PhaseFmt_c.F, OutFmt_c.F + 4));

    -- Types
    subtype Phase_t is std_logic_vector(cl_fix_width(PhaseFmt_c) - 1 downto 0);

    -- Signals
    signal AccuStored : Phase_t;
    signal AccuCur    : Phase_t;
    signal Valid_0    : std_logic;
    signal Accu_0     : Phase_t;
    signal Phase_0    : Phase_t;
    signal Valid_1    : std_logic;
    signal SinPhase_1 : std_logic_vector(cl_fix_width(SinPhaseFmt_c) - 1 downto 0);
    signal SinValid   : std_logic;
    signal OutCnt     : integer range 0 to Channels_g - 1;

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert PhaseFmt_c.S = 0 and PhaseFmt_c.I = 0
        report errorMessage(EntityName_c, "PhaseFmt_g must be of the form (0, 0, N), got " & PhaseFmt_g)
        severity error;
    -- synthesis translate_on

    -- *** Accumulator Restart ***
    AccuCur <= (others => '0') when In_Restart = '1' else AccuStored;

    -- *** Sequential Process ***
    p_reg : process (Clk) is
    begin
        if rising_edge(Clk) then

            -- *** Stage 0: Phase Accumulation ***
            -- Both adders wrap, which implements the modulo one rotation behavior of the phase.
            Valid_0 <= In_Valid;
            if In_Valid = '1' then
                Accu_0  <= cl_fix_add(AccuCur, PhaseFmt_c, In_PhaseStep, PhaseFmt_c,
                                      PhaseFmt_c, Trunc_s, None_s);
                Phase_0 <= cl_fix_add(AccuCur, PhaseFmt_c, In_PhaseOffset, PhaseFmt_c,
                                      PhaseFmt_c, Trunc_s, None_s);
            end if;

            -- *** Stage 1: Phase Rounding ***
            -- Rounding up to one rotation wraps to zero, which is correct for a phase.
            Valid_1    <= Valid_0;
            SinPhase_1 <= cl_fix_resize(Phase_0, PhaseFmt_c, SinPhaseFmt_c, NonSymPos_s, None_s);

            -- *** Output Channel Counter ***
            if SinValid = '1' then
                if OutCnt = Channels_g - 1 then
                    OutCnt <= 0;
                else
                    OutCnt <= OutCnt + 1;
                end if;
            end if;

            -- Reset
            if Rst = '1' then
                Valid_0 <= '0';
                Accu_0  <= (others => '0');
                Valid_1 <= '0';
                OutCnt  <= 0;
            end if;
        end if;
    end process;

    -- *** Outputs ***
    Out_Valid <= SinValid;
    Out_Last  <= '1' when OutCnt = Channels_g - 1 else '0';

    -- *** Component Instantiations ***

    -- Accumulator storage. Together with the accumulator register (Accu_0) it forms a delay of
    -- Channels_g samples. After reset, zeros are returned for all channels.
    i_accu : entity work.olo_base_delay
        generic map (
            Width_g       => cl_fix_width(PhaseFmt_c),
            Delay_g       => Channels_g - 1,
            Resource_g    => Resource_g,
            RstState_g    => true,
            RamBehavior_g => RamBehavior_g,
            RamStyle_g    => RamStyle_g
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            In_Data  => Accu_0,
            In_Valid => In_Valid,
            Out_Data => AccuStored
        );

    -- Sine and cosine calculation
    i_sin : entity work.olo_fix_sin
        generic map (
            OutFmt_g    => OutFmt_g,
            InFmt_g     => to_string(SinPhaseFmt_c),
            CosOutput_g => true,
            MemStyle_g  => MemStyle_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => Valid_1,
            In_Data   => SinPhase_1,
            Out_Valid => SinValid,
            Out_Sin   => Out_Sin,
            Out_Cos   => Out_Cos
        );

end architecture;
