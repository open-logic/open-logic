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

-- TODO: Add missing pipelines tage to mult 4 doc figures
-- TODO: Balance pipeline stages in mult 3 doc figure (and add added pipeline stages)
-- TODO: Document - some tools require enough multiplier registers to map code to only 3 DSPs (otherwise no benefit over 4 DSP - try your tools)

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_cplx_mult is
    generic (
        -- Functionality
        Mode_g           : string  := "MULT";
        Implementation_g : string  := "MULT4";     -- TODO: Revert MULT4
        IqHandling_g     : string  := "Parallel";
        -- Formats / Round / Saturate
        AFmt_g           : string := "(1,0,15)";  -- TODO Clear
        BFmt_g           : string := "(1,0,15)";  -- TODO Clear
        ResultFmt_g      : string := "(1,0,15)";  -- TODO Clear
        Round_g          : string  := FixRound_Trunc_c;
        Saturate_g       : string  := FixSaturate_Warn_c;
        -- Registers
        MultRegs_g       : natural := 1;
        RoundReg_g       : string  := "YES";
        SatReg_g         : string  := "YES"
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

    -- TODO: Calculate latency for "AUTO" register mode
    -- TODO: Calculate Mult3 latency
    -- TODO: Add last to TB

    -- Calculate Latency
    constant LatencyRoundSat_c : natural := choose(compareNoCase(RoundReg_g, "YES"), 1, 0) + choose(compareNoCase(SatReg_g, "YES"), 1, 0);
    constant LatencyMult4_c : natural := 1 + 1 + MultRegs_g + 1 + LatencyRoundSat_c;
    constant Latency_c : natural := LatencyMult4_c;

    -- Mult vs. Mix Operations
    constant Op_MultAdd_MixSub_c : string := choose(compareNoCase(Mode_g, "MULT"), "Add", "Sub");
    constant Op_MultSub_MixAdd_c : string := choose(compareNoCase(Mode_g, "MULT"), "Sub", "Add");

begin

    -- Assertions
    -- synthesis translate_off
    assert compareNoCase(Mode_g, "MULT") or compareNoCase(Mode_g, "MIX")
        report "olo_fix_cplx_mult: Invalid Mode_g: " & Mode_g severity error;
    assert compareNoCase(IqHandling_g, "Parallel") or compareNoCase(IqHandling_g, "TDM")
        report "olo_fix_cplx_mult: Invalid IqHandling_g: " & IqHandling_g severity error;
    assert compareNoCase(Implementation_g, "MULT4") or compareNoCase(Implementation_g, "MULT3")
        report "olo_fix_cplx_mult: Invalid Implementation_g: " & Implementation_g severity error;
    -- synthesis translate_on

    -- Parallel Component Handling
    g_parallel : if compareNoCase(IqHandling_g, "Parallel") generate

        --------------------------------------------
        -- Parallel I/Q, 4 Multiplier Implementation
        --------------------------------------------

        g_mult4 : if compareNoCase(Implementation_g, "MULT4") generate
            constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);
            constant ChainFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);
            signal In_Valid_Reg : std_logic;
            signal InA_Q_Reg : std_logic_vector(InA_Q'range);
            signal InB_Q_Reg : std_logic_vector(InB_Q'range);
            signal InA_I_Reg : std_logic_vector(InA_I'range);
            signal II_Out : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal QI_Out : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Out_I_Full : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Out_Q_Full : std_logic_vector(cl_fix_width(ChainFmt_c) - 1 downto 0);
            signal Macc_Valid : std_logic;
        begin

            -- Pipeline stage
            p_reg : process(Clk) is
            begin
                if rising_edge(Clk) then  
                    -- Normal Operation
                    In_Valid_Reg <= In_Valid;
                    InA_Q_Reg <= InA_Q;
                    InB_Q_Reg <= InB_Q;
                    InA_I_Reg <= InA_I;
                    
                    -- Reset
                    if Rst = '1' then
                        In_Valid_Reg <= '0';
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
                    Out_Data    => II_Out
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
                    InAC_Valid  => In_Valid_Reg,
                    InA_Data    => InA_Q_Reg,
                    InB_Valid   => In_Valid_Reg,
                    InB_Data    => InB_Q_Reg,
                    MaccIn      => II_Out,
                    Out_Data    => Out_I_Full,
                    Out_Valid   => Macc_Valid
                );

            -- I resize
            i_resize_i : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(ChainFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Macc_Valid,
                    In_A        => Out_I_Full,
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
                    Out_Data    => QI_Out
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
                    InAC_Valid  => In_Valid_Reg,
                    InA_Data    => InA_I_Reg,
                    InB_Valid   => In_Valid_Reg,
                    InB_Data    => InB_Q_Reg,
                    MaccIn      => QI_Out,
                    Out_Data    => Out_Q_Full
                );

            -- Q resize
            i_resize_q : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(ChainFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Macc_Valid,
                    In_A        => Out_Q_Full,
                    Out_Result  => Out_Q
                );
        
        end generate;

        --------------------------------------------
        -- Parallel I/Q, 3 Multiplier Implementation
        --------------------------------------------
        g_mult3 : if compareNoCase(Implementation_g, "MULT3") generate
            -- Formats
            constant MultFmt_c  : FixFormat_t := cl_fix_mult_fmt(AFmt_c, BFmt_c);
            constant PreAddFmt_c : FixFormat_t := cl_fix_addsub_fmt(AFmt_c, AFmt_c);
            constant K3Fmt_c : FixFormat_t := cl_fix_mult_fmt(PreAddFmt_c, PreAddFmt_c);
            constant OutIFullFmt_c : FixFormat_t := cl_fix_addsub_fmt(MultFmt_c, MultFmt_c);
            constant OutQFullFmt_c : FixFormat_t := cl_fix_addsub_fmt(K3Fmt_c, cl_fix_addsub_fmt(MultFmt_c, MultFmt_c));

            -- Signals
            signal In_Valid_Reg : std_logic;
            signal InA_Q_Reg : std_logic_vector(InA_Q'range);
            signal InB_Q_Reg : std_logic_vector(InB_Q'range);
            signal InA_I_Reg : std_logic_vector(InA_I'range);
            signal InB_I_Reg : std_logic_vector(InB_I'range);
            signal Mult1_Valid : std_logic;
            signal K1 : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
            signal K1_Reg : std_logic_vector(K1'range);
            signal K2 : std_logic_vector(cl_fix_width(MultFmt_c) - 1 downto 0);
            signal K2_Reg : std_logic_vector(K2'range);
            signal K2_Reg2 : std_logic_vector(K2'range);
            signal K3 : std_logic_vector(cl_fix_width(K3Fmt_c) - 1 downto 0);
            signal K3_Valid : std_logic;
            signal Preadd_A : std_logic_vector(cl_fix_width(PreAddFmt_c) - 1 downto 0);
            signal Preadd_A_Reg : std_logic_vector(Preadd_A'range);
            signal Preadd_B : std_logic_vector(cl_fix_width(PreAddFmt_c) - 1 downto 0);
            signal Preadd_B_Reg : std_logic_vector(Preadd_B'range);
            signal Preadd_Valid : std_logic;
            signal Preadd_Valid_Reg : std_logic;
            signal Out_I_Full : std_logic_vector(cl_fix_width(OutIFullFmt_c) - 1 downto 0);
            signal Out_I_Full_Reg : std_logic_vector(Out_I_Full'range);
            signal Out_I_Full_Reg2 : std_logic_vector(Out_I_Full'range);
            signal Out_Q_Full : std_logic_vector(cl_fix_width(OutQFullFmt_c) - 1 downto 0);
            signal Out_Q_Full_Reg : std_logic_vector(Out_Q_Full'range);
            signal Out_Full_Valid : std_logic;
            signal Out_Full_Valid_Reg : std_logic;

            -- Attributes
            attribute use_dsp : string;
            attribute use_dsp of Out_I_Full : signal is "no";
            attribute use_dsp of Out_Q_Full : signal is "no";
    
        begin

            -- Pipeline stage
            p_reg : process(Clk) is
            begin
                if rising_edge(Clk) then  
                    -- Normal Operation
                    In_Valid_Reg <= In_Valid;
                    InA_Q_Reg <= InA_Q;
                    InB_Q_Reg <= InB_Q;
                    InA_I_Reg <= InA_I;
                    InB_I_Reg <= InB_I;

                    -- Pre adders
                    Preadd_Valid <= In_Valid_Reg;
                    Preadd_A <= cl_fix_add(InA_I_Reg, AFmt_c, InA_Q_Reg, AFmt_c, PreAddFmt_c);
                    if compareNoCase(Mode_g, "MULT") then
                        Preadd_B <= cl_fix_add(InB_I_Reg, BFmt_c, InB_Q_Reg, BFmt_c, PreAddFmt_c);
                    else
                        Preadd_B <= cl_fix_sub(InB_I_Reg, BFmt_c, InB_Q_Reg, BFmt_c, PreAddFmt_c);
                    end if;
                    Preadd_A_Reg <= Preadd_A;
                    Preadd_B_Reg <= Preadd_B;
                    Preadd_Valid_Reg <= Preadd_Valid;

                    -- K1/K2 latency compensation
                    K1_Reg <= K1;
                    K2_Reg <= K2;
                    K2_Reg2 <= K2_Reg;

                    -- Out I calculation
                    if compareNoCase(Mode_g, "MULT") then
                        Out_I_Full <= cl_fix_sub(K1, MultFmt_c, K2, MultFmt_c, OutIFullFmt_c);
                    else
                        Out_I_Full <= cl_fix_add(K1, MultFmt_c, K2, MultFmt_c, OutIFullFmt_c);
                    end if;
                    Out_I_Full_Reg <= Out_I_Full;
                    Out_I_Full_Reg2 <= Out_I_Full_Reg;
                    Out_Q_Full <= cl_fix_sub(K3, K3Fmt_c, K1_Reg, MultFmt_c, OutQFullFmt_c);
                    if compareNoCase(Mode_g, "MULT") then
                        Out_Q_Full_Reg <= cl_fix_sub(Out_Q_Full, OutQFullFmt_c, K2_Reg2, MultFmt_c, OutQFullFmt_c);
                    else
                        Out_Q_Full_Reg <= cl_fix_add(Out_Q_Full, OutQFullFmt_c, K2_Reg2, MultFmt_c, OutQFullFmt_c);
                    end if;
                    Out_Full_Valid <= K3_Valid;
                    Out_Full_Valid_Reg <= Out_Full_Valid;

                    -- Reset
                    if Rst = '1' then
                        In_Valid_Reg <= '0';
                        Preadd_Valid <= '0';
                        Out_Full_Valid <= '0';
                    end if;
                end if;
            end process;

            -- K1 multiplier
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
                    In_Valid    => In_Valid_Reg,
                    In_A        => InA_I_Reg,
                    In_B        => InB_I_Reg,
                    Out_Result  => K1,
                    Out_Valid   => Mult1_Valid
                );

            -- K2 multiplier
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
                    In_Valid    => In_Valid_Reg,
                    In_A        => InA_Q_Reg,
                    In_B        => InB_Q_Reg,
                    Out_Result  => K2
                );

            -- K3 multiplier
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
                    In_Valid    => Preadd_Valid_Reg,
                    In_A        => Preadd_A_Reg,
                    In_B        => Preadd_B_Reg,
                    Out_Result  => K3,
                    Out_Valid   => K3_Valid
                );

            -- I resize
            i_resize_i : entity work.olo_fix_resize
                generic map (
                    AFmt_g      => to_string(OutIFullFmt_c),
                    ResultFmt_g => ResultFmt_g,
                    Round_g     => Round_g,
                    Saturate_g  => Saturate_g,
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Out_Full_Valid_Reg,
                    In_A        => Out_I_Full_Reg2,
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
                    RoundReg_g  => RoundReg_g,
                    SatReg_g    => SatReg_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Valid    => Out_Full_Valid_Reg,
                    In_A        => Out_Q_Full_Reg,
                    Out_Result  => Out_Q
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
