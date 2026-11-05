---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2026 by Oliver Bründler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a decimating FIR filter with one multiplier per tap. It supports one or
-- more channels (time-division-multiplexed) and can process one input sample on every clock cycle.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_fir_dec_par_chtdm.md
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
    use work.olo_base_pkg_array.all;
    use work.olo_base_pkg_string.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_fix_fir_dec_par_chtdm is
    generic (
        -- Formats
        InFmt_g           : string;
        OutFmt_g          : string;
        CoefFmt_g         : string;
        -- Filter parameters
        Channels_g        : positive := 1;
        Ratio_g           : positive := 1;
        Taps_g            : positive;
        IsSymmetric_g     : boolean  := false;
        -- Arithmetic
        GuardBits_g       : natural  := 1;
        Round_g           : string   := FixRound_Trunc_c;
        Saturate_g        : string   := FixSaturate_Warn_c;
        MultRegs_g        : positive := 1;
        -- Coefficients
        CoefInit_g        : string   := "0.0";
        CoefWritable_g    : boolean  := false;
        -- Data delay lines (multi-channel only)
        DataRamBehavior_g : string   := "RBW";
        DataMemStyle_g    : string   := "auto"
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Coefficient Config Port
        Coef_Addr   : in    std_logic_vector(log2Ceil(Taps_g) - 1 downto 0)                 := (others => '0');
        Coef_WrEna  : in    std_logic                                                       := '0';
        Coef_WrData : in    std_logic_vector(fixFmtWidthFromString(CoefFmt_g) - 1 downto 0) := (others => '0');
        -- Input
        In_Valid    : in    std_logic;
        In_Data     : in    std_logic_vector(fixFmtWidthFromString(InFmt_g) - 1 downto 0);
        In_Last     : in    std_logic                                                       := '0';
        -- Output
        Out_Valid   : out   std_logic;
        Out_Data    : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g) - 1 downto 0);
        Out_Last    : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_fir_dec_par_chtdm is

    -- *** Entity Name ***
    constant EntityName_c : string := "olo_fix_fir_dec_par_chtdm";

    -- *** Formats ***
    constant InFmt_c   : FixFormat_t := cl_fix_format_from_string(InFmt_g);
    constant OutFmt_c  : FixFormat_t := cl_fix_format_from_string(OutFmt_g);
    constant CoefFmt_c : FixFormat_t := cl_fix_format_from_string(CoefFmt_g);
    constant MultFmt_c : FixFormat_t := cl_fix_mult_fmt(InFmt_c, CoefFmt_c);
    -- Adder chain format (matches the bit-true Python model). Intermediate sums may wrap, this does not
    -- affect the final result. A wider format would not fit the DSP cascade for many taps.
    constant AccuFmt_c : FixFormat_t := (1, OutFmt_c.I + GuardBits_g, MultFmt_c.F);

    -- *** Tap Stages ***
    -- Symmetric filters share one multiplier between two taps. For an odd number of taps, the center tap
    -- has a multiplier of its own.
    constant Stages_c : positive := choose(IsSymmetric_g, (Taps_g + 1) / 2, Taps_g);

    -- *** Types ***
    subtype InData_t   is std_logic_vector(cl_fix_width(InFmt_c) - 1 downto 0);
    subtype CoefData_t is std_logic_vector(cl_fix_width(CoefFmt_c) - 1 downto 0);
    subtype AccuData_t is std_logic_vector(cl_fix_width(AccuFmt_c) - 1 downto 0);

    type InData_a   is array (natural range <>) of InData_t;
    type CoefData_a is array (natural range <>) of CoefData_t;
    type AccuData_a is array (natural range <>) of AccuData_t;

    -- *** Functions ***
    -- Taps not specified in the initialization string are initialized to zero
    function getCoefInit return CoefData_a is
        constant InitReal_c : RealArray_t                 := fromString(CoefInit_g);
        variable Coefs_v    : CoefData_a(0 to Taps_g - 1) := (others => (others => '0'));
    begin

        for i in 0 to Taps_g - 1 loop
            if i <= InitReal_c'high then
                Coefs_v(i) := cl_fix_from_real(InitReal_c(i), CoefFmt_c);
            end if;
        end loop;

        return Coefs_v;
    end function;

    constant CoefInit_c : CoefData_a(0 to Taps_g - 1) := getCoefInit;

    -- A multiplier is only required if the coefficient can be different from zero
    function tapRequiresMult (tap : natural) return boolean is
    begin
        return CoefWritable_g or unsigned(CoefInit_c(tap)) /= 0;
    end function;

    -- *** Signals ***
    -- Stage inputs, TapValid(i) belongs to stage i and is delayed by one clock cycle per stage
    signal TapValid   : std_logic_vector(0 to Stages_c - 1);
    signal TapData    : InData_a(0 to Stages_c - 1);
    signal ACascOut   : InData_a(0 to Stages_c - 1);
    -- Folded delay line (symmetric only), DelayLine(i) is the input delayed by i samples per channel
    signal DelayLine  : InData_a(0 to Taps_g - 1);
    -- Coefficients
    signal CoefData   : CoefData_a(0 to Stages_c - 1);
    signal CoefWe     : std_logic_vector(0 to Stages_c - 1);
    -- Adder chain, AddChain(i) is the input to stage i
    signal AddChain   : AccuData_a(0 to Stages_c);
    signal ChainValid : std_logic;
    -- Decimation
    signal ChCnt      : natural range 0 to Channels_g - 1;
    signal DecCnt     : natural range 0 to Ratio_g - 1;
    signal SumValid   : std_logic;
    -- Output
    signal OutChCnt   : natural range 0 to Channels_g - 1;
    signal OutValid_i : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    -- synthesis translate_off
    assert Taps_g >= 2
        report errorMessage(EntityName_c, "Taps_g must be >= 2.")
        severity error;

    -- Check symmetry of fixed coefficients (after quantization to CoefFmt_g)
    g_check_symmetry : if IsSymmetric_g and not CoefWritable_g generate

        g_tap : for i in 0 to Taps_g / 2 - 1 generate
            assert CoefInit_c(i) = CoefInit_c(Taps_g - 1 - i)
                report errorMessage(EntityName_c, "IsSymmetric_g=true but coefficients of taps " &
                       integer'image(i) & " and " & integer'image(Taps_g - 1 - i) & " differ.")
                severity error;
        end generate;

    end generate;

    -- Check TDM framing
    p_assert : process (Clk) is
        variable ChCnt_v : natural range 0 to Channels_g - 1;
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                ChCnt_v := 0;
            elsif In_Valid = '1' then
                if In_Last = '1' then
                    assert ChCnt_v = Channels_g - 1
                        report errorMessage(EntityName_c, "In_Last asserted at channel index " &
                               integer'image(ChCnt_v) & " but expected at " &
                               integer'image(Channels_g - 1))
                        severity error;
                end if;
                if ChCnt_v = Channels_g - 1 then
                    ChCnt_v := 0;
                else
                    ChCnt_v := ChCnt_v + 1;
                end if;
            end if;
        end if;
    end process;

    -- synthesis translate_on

    -----------------------------------------------------------------------------------------------
    -- Coefficients
    -----------------------------------------------------------------------------------------------
    -- Fixed coefficients: The inputs of all multipliers are constant
    g_coef_fixed : if not CoefWritable_g generate
        CoefData <= CoefInit_c(0 to Stages_c - 1);
        CoefWe   <= (others => '1');
    end generate;

    -- Writable coefficients: Stored in the B input registers of the multipliers
    g_coef_writable : if CoefWritable_g generate
        signal Written : std_logic := '0';
    begin

        p_coef : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Coefficient write
                CoefData <= (others => Coef_WrData);
                CoefWe   <= (others => '0');
                if Coef_WrEna = '1' and Rst = '0' then
                    Written <= '1';
                    if fromUslv(Coef_Addr) < Stages_c then
                        CoefWe(fromUslv(Coef_Addr)) <= '1';
                    end if;
                end if;

                -- Reset loads the initial values unless coefficients were written at runtime
                if Rst = '1' and Written = '0' then
                    CoefData <= CoefInit_c(0 to Stages_c - 1);
                    CoefWe   <= (others => '1');
                end if;
            end if;
        end process;

    end generate;

    -----------------------------------------------------------------------------------------------
    -- MACC Chain
    -----------------------------------------------------------------------------------------------
    TapValid(0) <= In_Valid;
    TapData(0)  <= In_Data;
    AddChain(0) <= (others => '0');

    g_tap_valid : if Stages_c > 1 generate

        p_tap_valid : process (Clk) is
        begin
            if rising_edge(Clk) then
                TapValid(1 to Stages_c - 1) <= TapValid(0 to Stages_c - 2);
                if Rst = '1' then
                    TapValid(1 to Stages_c - 1) <= (others => '0');
                end if;
            end if;
        end process;

    end generate;

    -- Symmetric: All taps read from one folded delay line that runs in the timing of the input
    g_delay_line : if IsSymmetric_g generate
        DelayLine(0) <= In_Data;

        g_sample : for i in 1 to Taps_g - 1 generate

            i_delay : entity work.olo_base_delay
                generic map (
                    Width_g       => cl_fix_width(InFmt_c),
                    Delay_g       => Channels_g,
                    RstState_g    => true,
                    RamBehavior_g => DataRamBehavior_g,
                    RamStyle_g    => DataMemStyle_g
                )
                port map (
                    Clk      => Clk,
                    Rst      => Rst,
                    In_Data  => DelayLine(i - 1),
                    In_Valid => In_Valid,
                    Out_Data => DelayLine(i)
                );

        end generate;

    end generate;

    g_tap : for i in 0 to Stages_c - 1 generate
        signal TapOutValid : std_logic;
    begin

        g_madd : if tapRequiresMult(i) and not IsSymmetric_g generate

            i_madd : entity work.olo_fix_madd
                generic map (
                    InBIsCoef_g   => true,
                    ACascade_g    => true,
                    AFmt_g        => InFmt_g,
                    BFmt_g        => CoefFmt_g,
                    AddChainFmt_g => to_string(AccuFmt_c),
                    MultRegs_g    => MultRegs_g
                )
                port map (
                    Clk        => Clk,
                    Rst        => Rst,
                    InAC_Valid => TapValid(i),
                    InA_Data   => TapData(i),
                    InB_Valid  => CoefWe(i),
                    InB_Data   => CoefData(i),
                    MaccIn     => AddChain(i),
                    ACascOut   => ACascOut(i),
                    Out_Valid  => TapOutValid,
                    Out_Data   => AddChain(i + 1)
                );

        end generate;

        -- Symmetric: Stage i is i clock cycles late because of the adder chain, the samples must be too.
        -- Free-running without reset: After a reset, the first sample only sees the cleared delay line.
        g_madd_sym : if tapRequiresMult(i) and IsSymmetric_g generate
            signal AlignedA : InData_t;
            signal AlignedC : InData_t;
        begin

            i_align_a : entity work.olo_base_delay
                generic map (
                    Width_g       => cl_fix_width(InFmt_c),
                    Delay_g       => i,
                    RstState_g    => false,
                    RamBehavior_g => DataRamBehavior_g,
                    RamStyle_g    => DataMemStyle_g
                )
                port map (
                    Clk      => Clk,
                    Rst      => Rst,
                    In_Data  => DelayLine(i),
                    Out_Data => AlignedA
                );

            i_align_c : entity work.olo_base_delay
                generic map (
                    Width_g       => cl_fix_width(InFmt_c),
                    Delay_g       => i,
                    RstState_g    => false,
                    RamBehavior_g => DataRamBehavior_g,
                    RamStyle_g    => DataMemStyle_g
                )
                port map (
                    Clk      => Clk,
                    Rst      => Rst,
                    In_Data  => DelayLine(Taps_g - 1 - i),
                    Out_Data => AlignedC
                );

            -- Odd number of taps: The center tap has no partner and hence does not use a pre-adder. There
            -- the A cascade registers provide the latency of the pre-adder and input C is unused.
            i_madd : entity work.olo_fix_madd
                generic map (
                    PreAdd_g      => 2 * i /= Taps_g - 1,
                    InBIsCoef_g   => true,
                    ACascade_g    => 2 * i = Taps_g - 1,
                    AFmt_g        => InFmt_g,
                    BFmt_g        => CoefFmt_g,
                    CFmt_g        => InFmt_g,
                    AddChainFmt_g => to_string(AccuFmt_c),
                    MultRegs_g    => MultRegs_g
                )
                port map (
                    Clk        => Clk,
                    Rst        => Rst,
                    InAC_Valid => TapValid(i),
                    InA_Data   => AlignedA,
                    InC_Data   => AlignedC,
                    InB_Valid  => CoefWe(i),
                    InB_Data   => CoefData(i),
                    MaccIn     => AddChain(i),
                    Out_Valid  => TapOutValid,
                    Out_Data   => AddChain(i + 1)
                );

        end generate;

        -- Coefficient fixed to zero: No multiplier, only the registers that keep the timing of olo_fix_madd
        g_no_madd : if not tapRequiresMult(i) generate
            signal VldPipe : std_logic_vector(0 to MultRegs_g + 2);
        begin

            -- A cascade (symmetric filters do not have one)
            g_a_cascade : if not IsSymmetric_g generate
                signal A_0 : InData_t;
            begin

                p_a_cascade : process (Clk) is
                begin
                    if rising_edge(Clk) then
                        if TapValid(i) = '1' then
                            A_0 <= TapData(i);
                        end if;
                        ACascOut(i) <= A_0;

                        -- Reset
                        if Rst = '1' then
                            A_0         <= (others => '0');
                            ACascOut(i) <= (others => '0');
                        end if;
                    end if;
                end process;

            end generate;

            p_no_madd : process (Clk) is
            begin
                if rising_edge(Clk) then
                    -- Adder chain
                    AddChain(i + 1) <= AddChain(i);

                    -- Valid
                    VldPipe <= TapValid(i) & VldPipe(0 to VldPipe'high - 1);

                    -- Reset
                    if Rst = '1' then
                        AddChain(i + 1) <= (others => '0');
                        VldPipe         <= (others => '0');
                    end if;
                end if;
            end process;

            TapOutValid <= VldPipe(VldPipe'high);

        end generate;

        -- All taps run with the same timing, the output of the last tap marks the valid sums
        g_last : if i = Stages_c - 1 generate
            ChainValid <= TapOutValid;
        end generate;

        -- Delay to the next tap: A sample of the same channel is Channels_g samples old and
        -- the A cascade already provides one sample of delay.
        g_next : if i < Stages_c - 1 and not IsSymmetric_g generate

            g_single : if Channels_g = 1 generate
                TapData(i + 1) <= ACascOut(i);
            end generate;

            g_multi : if Channels_g > 1 generate

                i_delay : entity work.olo_base_delay
                    generic map (
                        Width_g       => cl_fix_width(InFmt_c),
                        Delay_g       => Channels_g - 1,
                        RstState_g    => true,
                        RamBehavior_g => DataRamBehavior_g,
                        RamStyle_g    => DataMemStyle_g
                    )
                    port map (
                        Clk      => Clk,
                        Rst      => Rst,
                        In_Data  => ACascOut(i),
                        In_Valid => TapValid(i + 1),
                        Out_Data => TapData(i + 1)
                    );

            end generate;

        end generate;

    end generate;

    -----------------------------------------------------------------------------------------------
    -- Decimation
    -----------------------------------------------------------------------------------------------
    p_dec : process (Clk) is
    begin
        if rising_edge(Clk) then
            if ChainValid = '1' then
                if ChCnt = Channels_g - 1 then
                    ChCnt <= 0;
                    if DecCnt = Ratio_g - 1 then
                        DecCnt <= 0;
                    else
                        DecCnt <= DecCnt + 1;
                    end if;
                else
                    ChCnt <= ChCnt + 1;
                end if;
            end if;

            -- Reset
            if Rst = '1' then
                ChCnt  <= 0;
                DecCnt <= 0;
            end if;
        end if;
    end process;

    SumValid <= ChainValid when DecCnt = 0 else '0';

    -----------------------------------------------------------------------------------------------
    -- Output Resize (round + saturate accumulator to output format)
    -----------------------------------------------------------------------------------------------
    i_resize : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(AccuFmt_c),
            ResultFmt_g => OutFmt_g,
            Round_g     => Round_g,
            Saturate_g  => Saturate_g,
            RoundReg_g  => "YES",
            SatReg_g    => "YES"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => SumValid,
            In_A       => AddChain(Stages_c),
            Out_Valid  => OutValid_i,
            Out_Result => Out_Data
        );

    Out_Valid <= OutValid_i;
    Out_Last  <= OutValid_i when OutChCnt = Channels_g - 1 else '0';

    p_out : process (Clk) is
    begin
        if rising_edge(Clk) then
            if OutValid_i = '1' then
                if OutChCnt = Channels_g - 1 then
                    OutChCnt <= 0;
                else
                    OutChCnt <= OutChCnt + 1;
                end if;
            end if;

            -- Reset
            if Rst = '1' then
                OutChCnt <= 0;
            end if;
        end if;
    end process;

end architecture;
