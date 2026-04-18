---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a complex multiplication in different architectures.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cplx_mult.md
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

-- TODO: Test synthesize all 3 implementations (16-bit formats)

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_cplx_mult is
    generic (
        -- Functionality
        Mode_g           : string  := "MULT";
        Implementation_g : string  := "MULT3";
        IqHandling_g     : string  := "Parallel";
        -- Formats / Round / Saturate
        AFmt_g           : string;
        BFmt_g           : string;
        ResultFmt_g      : string;
        Round_g          : string  := FixRound_Trunc_c;
        Saturate_g       : string  := FixSaturate_Warn_c;
        -- Registers
        MultRegs_g       : natural := 1
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

architecture rtl of olo_fix_cplx_mult is

    -- Formats
    constant AFmt_c      : FixFormat_t := cl_fix_format_from_string(AFmt_g);
    constant BFmt_c      : FixFormat_t := cl_fix_format_from_string(BFmt_g);
    constant ResultFmt_c : FixFormat_t := cl_fix_format_from_string(ResultFmt_g);

    -- Round/Sat Registers
    constant RoundReg_c : string := choose(compareNoCase(Round_g, FixRound_Trunc_c), "NO", "YES");
    constant SatReg_c : string := choose(compareNoCase(Saturate_g, FixSaturate_Warn_c) or (compareNoCase(Saturate_g, FixSaturate_None_c)), "NO", "YES");

    -- Calculate Latency
    constant LatencyRoundSat_c : natural := choose(RoundReg_c = "YES", 1, 0) + choose(SatReg_c = "YES", 1, 0);
    constant LatencyMult4_c : natural := MultRegs_g + 3 + LatencyRoundSat_c;
    constant LatencyMult3_c : natural := MultRegs_g + 5 + LatencyRoundSat_c;
    constant LatencyTDM_c : natural := MultRegs_g + 4 + LatencyRoundSat_c;
    constant Latency_c : natural := choose(compareNoCase(IqHandling_g, "TDM"), LatencyTDM_c,
                                           choose(compareNoCase(Implementation_g, "MULT4"), LatencyMult4_c, LatencyMult3_c));

    -- Mult vs. Mix Operations
    constant Op_MultAdd_MixSub_c : string := choose(compareNoCase(Mode_g, "MULT"), "Add", "Sub");
    constant Op_MultSub_MixAdd_c : string := choose(compareNoCase(Mode_g, "MULT"), "Sub", "Add");

begin

    -- Assertions
    -- synthesis translate_off
    assert compareNoCase(Mode_g, "MULT") or compareNoCase(Mode_g, "MIX")
        report "olo_fix_cplx_mult: Invalid Mode_g: " & Mode_g
        severity error;
    assert compareNoCase(IqHandling_g, "Parallel") or compareNoCase(IqHandling_g, "TDM")
        report "olo_fix_cplx_mult: Invalid IqHandling_g: " & IqHandling_g
        severity error;
    assert compareNoCase(Implementation_g, "MULT4") or compareNoCase(Implementation_g, "MULT3")
        report "olo_fix_cplx_mult: Invalid Implementation_g: " & Implementation_g
        severity error;
    -- synthesis translate_on

    -- Parallel Component Handling
    g_parallel : if compareNoCase(IqHandling_g, "Parallel") generate

        -------------------------------------------------------------------------------------------
        -- Parallel I/Q, 4 Multiplier Implementation
        -------------------------------------------------------------------------------------------

        g_mult4 : if compareNoCase(Implementation_g, "MULT4") generate
            constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);
            constant ChainFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);
            signal In_Valid_0 : std_logic;
            signal InA_Q_0 : std_logic_vector(InA_Q'range);
            signal InB_Q_0 : std_logic_vector(InB_Q'range);
            signal InA_I_0 : std_logic_vector(InA_I'range);
            signal II_Out_N1 : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal QI_Out_N1 : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Out_I_Full_N2 : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Out_Q_Full_N2 : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Valid_N2 : std_logic;
        begin

            -- Pipeline stage
            p_reg : process(Clk) is
            begin
                if rising_edge(Clk) then
                    -- Normal Operation
                    In_Valid_0 <= In_Valid;
                    InA_Q_0 <= InA_Q;
                    InB_Q_0 <= InB_Q;
                    InA_I_0 <= InA_I;

                    -- Reset
                    if Rst = '1' then
                        In_Valid_0 <= '0';
                    end if;
                end if;
            end process;

            -- I x I multiplier
            i_ii : entity work.olo_fix_madd
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    AddChainFmt_g => to_string(ChainFmt_c),
                    MultRegs_g    => MultRegs_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    InAC_Valid  => In_Valid,
                    InA_Data    => InA_I,
                    InB_Valid   => In_Valid,
                    InB_Data    => InB_I,
                    Out_Data    => II_Out_N1
                );

            -- Q x Q multiply add
            i_qq : entity work.olo_fix_madd
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    AddChainFmt_g => to_string(ChainFmt_c),
                    Operation_g   => Op_MultSub_MixAdd_c,
                    MultRegs_g    => MultRegs_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    InAC_Valid  => In_Valid_0,
                    InA_Data    => InA_Q_0,
                    InB_Valid   => In_Valid_0,
                    InB_Data    => InB_Q_0,
                    MaccIn      => II_Out_N1,
                    Out_Data    => Out_I_Full_N2,
                    Out_Valid   => Valid_N2
                );

            -- I resize
            i_resize_i : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(ChainFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_c,
                    SatReg_g    => SatReg_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Valid_N2,
                    In_A        => Out_I_Full_N2,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_I
                );

            -- Q x I multiplier
            i_qi : entity work.olo_fix_madd
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    AddChainFmt_g => to_string(ChainFmt_c),
                    MultRegs_g    => MultRegs_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    InAC_Valid  => In_Valid,
                    InA_Data    => InA_Q,
                    InB_Valid   => In_Valid,
                    InB_Data    => InB_I,
                    Out_Data    => QI_Out_N1
                );

            -- I x Q multiply add
            i_iq : entity work.olo_fix_madd
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    AddChainFmt_g => to_string(ChainFmt_c),
                    MultRegs_g    => MultRegs_g,
                    Operation_g   => Op_MultAdd_MixSub_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    InAC_Valid  => In_Valid_0,
                    InA_Data    => InA_I_0,
                    InB_Valid   => In_Valid_0,
                    InB_Data    => InB_Q_0,
                    MaccIn      => QI_Out_N1,
                    Out_Data    => Out_Q_Full_N2
                );

            -- Q resize
            i_resize_q : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(ChainFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_c,
                    SatReg_g    => SatReg_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Valid_N2,
                    In_A        => Out_Q_Full_N2,
                    Out_Result  => Out_Q
                );

        end generate;

        -------------------------------------------------------------------------------------------
        -- Parallel I/Q, 3 Multiplier Implementation
        -------------------------------------------------------------------------------------------
        g_mult3 : if compareNoCase(Implementation_g, "MULT3") generate
            -- Formats
            constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);
            constant PreAddFmt_c : FixFormat_t := cl_fix_addsub_fmt(AFmt_c, AFmt_c);
            constant K3Fmt_c : FixFormat_t := cl_fix_mult_fmt(PreAddFmt_c, PreAddFmt_c);
            constant OutIFullFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);
            constant OutQFullFmt_c : FixFormat_t := cl_fix_addsub_fmt(K3Fmt_c, cl_fix_addsub_fmt(MultFmt_c, MultFmt_c));

            -- Signals
            signal In_Valid_0 : std_logic;
            signal InA_Q_0 : std_logic_vector(InA_Q'range);
            signal InB_Q_0 : std_logic_vector(InB_Q'range);
            signal InA_I_0 : std_logic_vector(InA_I'range);
            signal InB_I_0 : std_logic_vector(InB_I'range);
            signal Mult1_Valid_N3 : std_logic;
            signal K1_N1 : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
            signal K1_N2 : std_logic_vector(K1_N1'range);
            signal K2_N1 : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
            signal K2_N2 : std_logic_vector(K2_N1'range);
            signal K2_N3 : std_logic_vector(K2_N1'range);
            signal K3_N2 : std_logic_vector(cl_fix_width(K3Fmt_c) - 1 downto 0);
            signal K3_Valid_N2 : std_logic;
            signal Preadd_A_1 : std_logic_vector(cl_fix_width(PreAddFmt_c) - 1 downto 0);
            signal Preadd_A_2 : std_logic_vector(Preadd_A_1'range);
            signal Preadd_B_1 : std_logic_vector(cl_fix_width(PreAddFmt_c) - 1 downto 0);
            signal Preadd_B_2 : std_logic_vector(Preadd_B_1'range);
            signal Preadd_Valid_1 : std_logic;
            signal Preadd_Valid_2 : std_logic;
            signal Out_I_Full_N2 : std_logic_vector(cl_fix_width(OutIFullFmt_c) - 1 downto 0);
            signal Out_I_Full_N3 : std_logic_vector(Out_I_Full_N2'range);
            signal Out_I_Full_N4 : std_logic_vector(Out_I_Full_N2'range);
            signal Out_Q_Full_N3 : std_logic_vector(cl_fix_width(OutQFullFmt_c) - 1 downto 0);
            signal Out_Q_Full_N4 : std_logic_vector(Out_Q_Full_N3'range);
            signal Out_Full_Valid_N2_N3 : std_logic;
            signal Out_Full_Valid_N2_N4 : std_logic;

            -- Attributes
            attribute use_dsp : string;
            attribute use_dsp of Out_I_Full_N2 : signal is "no";
            attribute use_dsp of Out_Q_Full_N3 : signal is "no";

        begin

            -- Pipeline stage
            p_reg : process(Clk) is
            begin
                if rising_edge(Clk) then
                    -- Normal Operation
                    In_Valid_0 <= In_Valid;
                    InA_Q_0 <= InA_Q;
                    InB_Q_0 <= InB_Q;
                    InA_I_0 <= InA_I;
                    InB_I_0 <= InB_I;

                    -- Pre adders
                    Preadd_Valid_1 <= In_Valid_0;
                    Preadd_A_1 <= cl_fix_add(InA_I_0, AFmt_c, InA_Q_0, AFmt_c, PreAddFmt_c);
                    if compareNoCase(Mode_g, "MULT") then
                        Preadd_B_1 <= cl_fix_add(InB_I_0, BFmt_c, InB_Q_0, BFmt_c, PreAddFmt_c);
                    else
                        Preadd_B_1 <= cl_fix_sub(InB_I_0, BFmt_c, InB_Q_0, BFmt_c, PreAddFmt_c);
                    end if;
                    Preadd_A_2 <= Preadd_A_1;
                    Preadd_B_2 <= Preadd_B_1;
                    Preadd_Valid_2 <= Preadd_Valid_1;

                    -- K1_N1/K2_N1 latency compensation
                    K1_N2 <= K1_N1;
                    K2_N2 <= K2_N1;
                    K2_N3 <= K2_N2;

                    -- Out I calculation
                    if compareNoCase(Mode_g, "MULT") then
                        Out_I_Full_N2 <= cl_fix_sub(K1_N1, MultFmt_c, K2_N1, MultFmt_c, OutIFullFmt_c);
                    else
                        Out_I_Full_N2 <= cl_fix_add(K1_N1, MultFmt_c, K2_N1, MultFmt_c, OutIFullFmt_c);
                    end if;
                    Out_I_Full_N3 <= Out_I_Full_N2;
                    Out_I_Full_N4 <= Out_I_Full_N3;
                    Out_Q_Full_N3 <= cl_fix_sub(K3_N2, K3Fmt_c, K1_N2, MultFmt_c, OutQFullFmt_c);
                    if compareNoCase(Mode_g, "MULT") then
                        Out_Q_Full_N4 <= cl_fix_sub(Out_Q_Full_N3, OutQFullFmt_c, K2_N3, MultFmt_c, OutQFullFmt_c);
                    else
                        Out_Q_Full_N4 <= cl_fix_add(Out_Q_Full_N3, OutQFullFmt_c, K2_N3, MultFmt_c, OutQFullFmt_c);
                    end if;
                    Out_Full_Valid_N2_N3 <= K3_Valid_N2;
                    Out_Full_Valid_N2_N4 <= Out_Full_Valid_N2_N3;

                    -- Reset
                    if Rst = '1' then
                        In_Valid_0 <= '0';
                        Preadd_Valid_1 <= '0';
                        Preadd_Valid_2 <= '0';
                        Out_Full_Valid_N2_N3 <= '0';
                        Out_Full_Valid_N2_N4 <= '0';
                    end if;
                end if;
            end process;

            -- K1_N1 multiplier
            i_k1 : entity work.olo_fix_mult
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    ResultFmt_g   => to_string(MultFmt_c),
                    OpRegs_g      => MultRegs_g+1,
                    RoundReg_g    => "NO",
                    SatReg_g      => "NO"
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid_0,
                    In_A        => InA_I_0,
                    In_B        => InB_I_0,
                    Out_Result  => K1_N1,
                    Out_Valid   => Mult1_Valid_N3
                );

            -- K2_N1 multiplier
            i_k2 : entity work.olo_fix_mult
                generic map (
                    AFmt_g        => AFmt_g,
                    BFmt_g        => BFmt_g,
                    ResultFmt_g   => to_string(MultFmt_c),
                    OpRegs_g      => MultRegs_g+1,
                    RoundReg_g    => "NO",
                    SatReg_g      => "NO"
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => In_Valid_0,
                    In_A        => InA_Q_0,
                    In_B        => InB_Q_0,
                    Out_Result  => K2_N1
                );

            -- K3_N2 multiplier
            i_k3 : entity work.olo_fix_mult
                generic map (
                    AFmt_g        => to_string(PreAddFmt_c),
                    BFmt_g        => to_string(PreAddFmt_c),
                    ResultFmt_g   => to_string(K3Fmt_c),
                    OpRegs_g      => MultRegs_g,
                    RoundReg_g    => "NO",
                    SatReg_g      => "NO"
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Preadd_Valid_2,
                    In_A        => Preadd_A_2,
                    In_B        => Preadd_B_2,
                    Out_Result  => K3_N2,
                    Out_Valid   => K3_Valid_N2
                );

            -- I resize
            i_resize_i : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(OutIFullFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_c,
                    SatReg_g    => SatReg_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Out_Full_Valid_N2_N4,
                    In_A        => Out_I_Full_N4,
                    Out_Valid   => Out_Valid,
                    Out_Result  => Out_I
                );


            -- Q resize
            i_resize_q : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(OutQFullFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_c,
                    SatReg_g    => SatReg_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Out_Full_Valid_N2_N4,
                    In_A        => Out_Q_Full_N4,
                    Out_Result  => Out_Q
                );

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

    end generate;

    -----------------------------------------------------------------------------------------------
    -- TDM I/Q
    -----------------------------------------------------------------------------------------------
    g_tdm : if compareNoCase(IqHandling_g, "TDM") generate
        -- Formats
        constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);
        constant SumFmt_c   : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);

        -- Constants
        constant Stages_c : natural := 4+MultRegs_g;

        -- TODO: Test resync

        -- Signals
        signal IsQ              : std_logic;
        signal Valid_I          : std_logic_vector(0 to Stages_c-1);
        signal Valid_Q          : std_logic_vector(0 to Stages_c-1);
        signal InA_0            : std_logic_vector(InA_IQ'range);
        signal InB_0            : std_logic_vector(InB_IQ'range);
        signal MultI_N0         : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal MultI_Hold_N1    : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal AddI_N1          : std_logic_vector(cl_fix_width(SumFmt_c) - 1 downto 0);
        signal HoldB_1          : std_logic_vector(InB_IQ'range);
        signal MultQ_InA_1      : std_logic_vector(InA_IQ'range);
        signal MultQ_InB_1      : std_logic_vector(InB_IQ'range);
        signal MultI_Valid      : std_logic;
        signal MultQ_Valid      : std_logic;
        signal MultQ_N1         : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal MultQ_Hold_N2    : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
        signal AddQ_N3          : std_logic_vector(cl_fix_width(SumFmt_c) - 1 downto 0);
        signal full_IQ_N2       : std_logic_vector(cl_fix_width(SumFmt_c) - 1 downto 0);
        signal Full_Valid_N2    : std_logic;

        signal LastMasked       : std_logic;

        -- Attributes
        attribute use_dsp : string;
        attribute use_dsp of AddI_N1 : signal is "no";
        attribute use_dsp of AddQ_N3 : signal is "no";
    begin

        -- Clocked Process
        p_reg : process(Clk) is
        begin
            if rising_edge(Clk) then

                -- Shift valids
                Valid_I(0) <= In_Valid and not IsQ;
                Valid_Q(0) <= In_Valid and IsQ;
                Valid_I(1 to Valid_I'high) <= Valid_I(0 to Valid_I'high-1);
                Valid_Q(1 to Valid_Q'high) <= Valid_Q(0 to Valid_Q'high-1);

                -- I/Q detection
                if In_Valid = '1' then
                    -- Resych - after Last the next sample is I
                    if In_Last = '1' then
                        IsQ <= '0';
                    -- otherwise toggle
                    else
                        IsQ <= not IsQ;
                    end if;
                end if;

                -- Input Registers
                if In_Valid = '1' then
                    InA_0 <= InA_IQ;
                    InB_0 <= InB_IQ;
                end if;

                -- I Path registers
                if Valid_I(MultRegs_g) = '1' then
                    MultI_Hold_N1 <= MultI_N0;
                end if;
                if Valid_Q(MultRegs_g) = '1' then
                    if compareNoCase(Mode_g, "MULT") then
                        AddI_N1 <= cl_fix_sub(MultI_Hold_N1, MultFmt_c, MultI_N0, MultFmt_c, SumFmt_c);
                    else
                        AddI_N1 <= cl_fix_add(MultI_Hold_N1, MultFmt_c, MultI_N0, MultFmt_c, SumFmt_c);
                    end if;
                end if;

                -- Q Path registers
                if Valid_I(0) = '1' or Valid_Q(0) = '1' then
                    HoldB_1 <= InB_0;
                end if;
                MultQ_InA_1 <= InA_0;
                if In_Valid = '1' and IsQ = '1' then
                    MultQ_InB_1 <= InB_IQ;
                else
                    MultQ_InB_1 <= HoldB_1; -- I part
                end if;
                if Valid_Q(MultRegs_g) = '1' then
                    MultQ_Hold_N2 <= MultQ_N1;
                end if;
                if Valid_Q(MultRegs_g+1) = '1' then
                    if compareNoCase(Mode_g, "MULT") then
                        AddQ_N3 <= cl_fix_add(MultQ_N1, MultFmt_c, MultQ_Hold_N2, MultFmt_c, SumFmt_c);
                    else
                        AddQ_N3 <= cl_fix_sub(MultQ_N1, MultFmt_c, MultQ_Hold_N2, MultFmt_c, SumFmt_c);
                    end if;

                end if;

                -- I/Q Merge
                Full_Valid_N2 <= '0';
                if Valid_Q(MultRegs_g+1) = '1' then
                    full_IQ_N2 <= AddI_N1;
                    Full_Valid_N2 <= '1';
                elsif Valid_Q(MultRegs_g+2) = '1' then
                    full_IQ_N2 <= AddQ_N3;
                    Full_Valid_N2 <= '1';
                end if;

                -- Reset
                if Rst = '1' then
                    IsQ <= '0';
                    Valid_I <= (others => '0');
                    Valid_Q <= (others => '0');
                    Full_Valid_N2 <= '0';
                end if;
            end if;
        end process;

        -- Valid merging
        MultI_Valid <= Valid_I(0) or Valid_Q(0);
        MultQ_Valid <= Valid_Q(1) or Valid_Q(0);

        -- I-path multiplier
        i_mult_i : entity work.olo_fix_mult
            generic map (
                AFmt_g        => AFmt_g,
                BFmt_g        => BFmt_g,
                ResultFmt_g   => to_string(MultFmt_c),
                OpRegs_g      => MultRegs_g,
                RoundReg_g    => "NO",
                SatReg_g      => "NO"
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => MultI_Valid,
                In_A        => InA_0,
                In_B        => InB_0,
                Out_Result  => MultI_N0
            );

        -- Q-path multiplier
        i_mult_q : entity work.olo_fix_mult
            generic map (
                AFmt_g        => AFmt_g,
                BFmt_g        => BFmt_g,
                ResultFmt_g   => to_string(MultFmt_c),
                OpRegs_g      => MultRegs_g,
                RoundReg_g    => "NO",
                SatReg_g      => "NO"
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => MultQ_Valid,
                In_A        => MultQ_InA_1,
                In_B        => MultQ_InB_1,
                Out_Result  => MultQ_N1
            );

            -- I/QQ resize
            i_resize_q : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(SumFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_c,
                    SatReg_g    => SatReg_c
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Full_Valid_N2,
                    In_A        => full_IQ_N2,
                    Out_Result  => Out_IQ,
                    Out_Valid   => Out_Valid
                );

            -- Last Signal Handling
            LastMasked <= In_Last and IsQ and In_Valid;

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
                    In_Data(0)  => LastMasked,
                    In_Valid    => '1',
                    Out_Data(0) => Out_Last
                );

    end generate;



end architecture;
