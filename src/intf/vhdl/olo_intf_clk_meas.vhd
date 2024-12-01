---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity measures the frequency of a clock under the assumption that
-- the frequency of the main-clock (Clk) is exactly correct.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_clk_meas.md
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_intf_clk_meas is
    generic (
        ClkFrequency_g          : real;
        MaxClkTestFrequency_g   : real := 1.0e9
    );
    port (
        -- Control Signals
        Clk           : in    std_logic;
        Rst           : in    std_logic;
        -- Test Results
        ClkTest       : in    std_logic;
        Freq_Hz       : out   std_logic_vector(31 downto 0);
        Freq_Valid    : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_intf_clk_meas is

    -- Constants
    constant MaxClkTestFrequencyInt_c : integer := integer(MaxClkTestFrequency_g);
    constant ResultWidth_c            : integer := log2ceil(integer(MaxClkTestFrequencyInt_c)+1);

    -- Signals Master Clock
    signal AwaitResult_M : std_logic;
    signal SecPulse_M    : std_logic;
    signal ResultValid_M : std_logic;
    signal Result_M      : std_logic_vector(ResultWidth_c-1 downto 0);

    -- Signals Test Clock
    signal CntrTest_T    : integer range 0 to MaxClkTestFrequencyInt_c;
    signal Rst_T         : std_logic;
    signal SecPulse_T    : std_logic;
    signal Result_T      : std_logic_vector(ResultWidth_c-1 downto 0);
    signal ResultValid_T : std_logic;

begin

    -- *** Assertions ***
    assert ClkFrequency_g >= 100.0
        report "olo_intfclk_meas: ClkFrequency_g must >= 100 Hz"
        severity failure;
    assert MaxClkTestFrequency_g >= 100.0
        report "olo_intfclk_meas: MaxClkTestFrequency_g must be >= 100 Hz"
        severity failure;

    -----------------------------------------------------------------------------------------------
    -- Master Clock Process
    -----------------------------------------------------------------------------------------------
    p_control : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- *** Normal Operation ***

            -- Default Value
            Freq_Valid <= '0';

            -- Request new result
            if SecPulse_M = '1' then
                AwaitResult_M <= '1';
                -- If no new value was detected, the clock is stopped (0 Hz)
                if AwaitResult_M = '1' then
                    Freq_Hz    <= (others => '0');
                    Freq_Valid <= '1';
                end if;
            end if;

            -- Latch new result
            if ResultValid_M = '1' then
                Freq_Hz       <= std_logic_vector(resize(unsigned(Result_M), Freq_Hz'length));
                AwaitResult_M <= '0';
                Freq_Valid    <= '1';
            end if;

            -- *** Reset ***
            if Rst = '1' then
                AwaitResult_M <= '0';
                Freq_Hz       <= (others => '0');
                Freq_Valid    <= '0';
            end if;

        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Test Clock Process
    -----------------------------------------------------------------------------------------------
    p_meas : process (ClkTest) is
    begin
        if rising_edge(ClkTest) then
            -- *** Normal Operation ***

            -- Default Value
            ResultValid_T <= '0';

            -- Every second, reset counter and output result
            if SecPulse_T = '1' then
                Result_T      <= toUslv(CntrTest_T, ResultWidth_c);
                CntrTest_T    <= 1;          -- the first edge implicitly arrived
                ResultValid_T <= '1';
            -- Otherwise count (prevent overflows!)
            elsif CntrTest_T /= MaxClkTestFrequencyInt_c then
                CntrTest_T <= CntrTest_T + 1;
            end if;

            -- *** Reset ***
            if Rst_T = '1' then
                CntrTest_T    <= 0;
                ResultValid_T <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
    -- Second pulse generation
    i_sec_pulse : entity work.olo_base_strobe_gen
        generic map (
            FreqClkHz_g    => ClkFrequency_g,
            FreqStrobeHz_g => 1.0
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            Out_Valid   => SecPulse_M
        );

    -- Second pulse and reset CC
    i_sec_pulse_cc : entity work.olo_base_cc_pulse
        port map (
            In_Clk        => Clk,
            In_RstIn      => Rst,
            In_Pulse(0)   => SecPulse_M,
            Out_Clk       => ClkTest,
            Out_RstOut    => Rst_T,
            Out_Pulse(0)  => SecPulse_T
        );

    -- Result CC
    i_result_cc : entity work.olo_base_cc_simple
        generic map (
            Width_g     => ResultWidth_c
        )
        port map (
            In_Clk      => ClkTest,
            In_Data     => Result_T,
            In_Valid    => ResultValid_T,
            Out_Clk     => Clk,
            Out_RstIn   => Rst,
            Out_Data    => Result_M,
            Out_Valid   => ResultValid_M
        );

end architecture;

---------------------------------------------------------------------------------------------------
-- EOF
---------------------------------------------------------------------------------------------------

