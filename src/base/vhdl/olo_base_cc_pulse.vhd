---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows passing pulses from one clock
-- domain to another. The pulse frequency must be significantly lower than then
-- slower clock speed.
-- Note that this entity only ensures that all pulses are transferred but not
-- that pulses arriving in the same clock cycle are transmitted in the same
-- clock cycle.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_pulse.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_cc_pulse is
    generic (
        NumPulses_g     : positive              := 1;
        SyncStages_g    : positive range 2 to 4 := 2
    );
    port (
        In_Clk          : in    std_logic;
        In_RstIn        : in    std_logic := '0';
        In_RstOut       : out   std_logic;
        In_Pulse        : in    std_logic_vector(NumPulses_g - 1 downto 0);
        Out_Clk         : in    std_logic;
        Out_RstIn       : in    std_logic := '0';
        Out_RstOut      : out   std_logic;
        Out_Pulse       : out   std_logic_vector(NumPulses_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_cc_pulse is

    -- Resets
    signal RstInI  : std_logic;
    signal RstOutI : std_logic;

    -- Data transmit side
    signal ToggleIn      : std_logic_vector(NumPulses_g - 1 downto 0);
    signal ToggleLast    : std_logic_vector(NumPulses_g - 1 downto 0);
    -- Data receive side
    signal ToggleOut     : std_logic_vector(NumPulses_g - 1 downto 0);
    signal ToggleOutLast : std_logic_vector(NumPulses_g - 1 downto 0);

begin

    -- *** Reset Crossing ***
    i_rst : entity work.olo_base_cc_reset
        port map (
            A_Clk       => In_Clk,
            A_RstIn     => In_RstIn,
            A_RstOut    => RstInI,
            B_Clk       => Out_Clk,
            B_RstIn     => Out_RstIn,
            B_RstOut    => RstOutI
        );

    In_RstOut  <= RstInI;
    Out_RstOut <= RstOutI;

    -- *** Pulse Crossing ***
    p_reg : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            ToggleLast <= ToggleIn;
            if RstInI = '1' then
                ToggleLast <= (others => '0');
            end if;
        end if;
    end process;

    -- Combinatorial because register is in olo_base_cc_bits
    ToggleIn <= ToggleLast xor In_Pulse;

    -- Two-Stage synchronizer
    i_sync : entity work.olo_base_cc_bits
        generic map (
            Width_g      => NumPulses_g,
            SyncStages_g => SyncStages_g
        )
        port map (
            In_Clk   => In_Clk,
            In_Rst   => RstInI,
            In_Data  => ToggleIn,
            Out_Clk  => Out_Clk,
            Out_Rst  => RstOutI,
            Out_Data => ToggleOut
        );

    -- Data receive side (Output)
    Out_Pulse <= ToggleOutLast xor ToggleOut;

    p_pulseout : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then
            ToggleOutLast <= ToggleOut;

            -- Reset
            if RstOutI = '1' then
                ToggleOutLast <= (others => '0');
            end if;
        end if;
    end process;

end architecture;

