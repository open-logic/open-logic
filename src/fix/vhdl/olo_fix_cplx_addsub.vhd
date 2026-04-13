---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements complex addtion/subtraction.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cplx_addsub.md
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

entity olo_fix_cplx_addsub is
    generic (
        -- Formats / Round / Saturate
        AFmt_g       : string;
        BFmt_g       : string;
        ResultFmt_g  : string;
        Round_g      : string  := FixRound_Trunc_c;
        Saturate_g   : string  := FixSaturate_Warn_c;
        IqHandling_g : string  := "Parallel";
        Operation_g  : string  := "Add";
        -- Registers
        OpRegs_g     : natural := 1;
        RoundReg_g   : string  := "YES";
        SatReg_g     : string  := "YES"
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input
        In_Valid    : in    std_logic := '1';
        InA_I       : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        InA_Q       : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        InA_IQ      : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        InB_I       : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        InB_Q       : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        InB_IQ      : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        In_Last     : in    std_logic := '0';
        -- Output
        Out_Valid   : out   std_logic;
        Out_I       : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
        Out_Q       : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
        Out_IQ      : out   std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
        Out_Last    : out   std_logic
    );
end entity;

architecture rtl of olo_fix_cplx_addsub is

    -- TODO: Calculate latency for "AUTO" register mode

    -- Calculate Latency
    constant Latency_c : natural := OpRegs_g +
                                    choose(compareNoCase(RoundReg_g, "YES"), 1, 0) +
                                    choose(compareNoCase(SatReg_g, "YES"), 1, 0);

    constant IsAdd_c : boolean := compareNoCase(Operation_g, "Add");

begin

    -- Assertions
    -- synthesis translate_off
    assert compareNoCase(Operation_g, "Add") or compareNoCase(Operation_g, "Sub")
        report "olo_fix_cplx_addsubsub: Invalid Operation_g: " & Operation_g severity error;
    assert compareNoCase(IqHandling_g, "Parallel") or compareNoCase(IqHandling_g, "TDM")
        report "olo_fix_cplx_addsubsub: Invalid IqHandling_g: " & IqHandling_g severity error;
    -- synthesis translate_on

    -- Parallel Component Handling
    g_parallel : if compareNoCase(IqHandling_g, "Parallel") generate

        g_add : if IsAdd_c generate

            i_i : entity work.olo_fix_add
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_I,
                    In_B        => InB_I,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_I
                );

            i_q : entity work.olo_fix_add
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_Q,
                    In_B        => InB_Q,
                    Out_Valid   => open,
                    Out_Result  => Out_Q
                );

        end generate;

        i_sub : if not IsAdd_c generate

            i_i : entity work.olo_fix_sub
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_I,
                    In_B        => InB_I,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_I
                );

            i_q : entity work.olo_fix_sub
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_Q,
                    In_B        => InB_Q,
                    Out_Valid   => open,
                    Out_Result  => Out_Q
                );

        end generate;   
    end generate;

    -- TDM Component Handling
    g_tdm : if compareNoCase(IqHandling_g, "TDM") generate

        g_add : if IsAdd_c generate

            i_iq : entity work.olo_fix_add
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_IQ,
                    In_B        => InB_IQ,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_IQ
                );
        end generate;

        g_sub : if not IsAdd_c generate

            i_iq : entity work.olo_fix_sub
                generic map (
                    AFmt_g      => AFmt_g,
                    BFmt_g      => BFmt_g,
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    OpRegs_g    => OpRegs_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid,
                    In_A        => InA_IQ,
                    In_B        => InB_IQ,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_IQ
                );
        
        end generate;

    end generate;

    -- Last Signal Handling
    i_last : entity work.olo_base_delay
        generic map (
            Width_g    => 1,
            Delay_g    => Latency_c,
            Resource_g => "SRL",
            RstState_g => true
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Data(0)  => In_Last,
            In_Valid    => '1',
            Out_Data(0) => Out_Last
        );

end architecture;
