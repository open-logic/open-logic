---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows passing of data with the
-- commonly used Valid/Ready handshake.
-- The clock crossing is not meant to achieve high-performance but to be
-- simple and safe.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_handshake.md
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
entity olo_base_cc_handshake is
    generic (
        Width_g         : positive;
        ReadyRstState_g : std_logic             := '1';
        SyncStages_g    : positive range 2 to 4 := 2
    );
    port (
        In_Clk      : in    std_logic;
        In_RstIn    : in    std_logic := '0';
        In_RstOut   : out   std_logic;
        In_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        In_Valid    : in    std_logic := '1';
        In_Ready    : out   std_logic;
        Out_Clk     : in    std_logic;
        Out_RstIn   : in    std_logic := '0';
        Out_RstOut  : out   std_logic;
        Out_Data    : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic := '1'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_cc_handshake is

    -- Input Domain Signals
    signal RstInI        : std_logic;
    signal In_ReadyI     : std_logic;
    signal InLatched     : std_logic := '0';
    signal InTransaction : std_logic;
    signal InAck         : std_logic;

    -- Output Domain Signals
    signal RstOutI        : std_logic;
    signal OutTransaction : std_logic;
    signal OutLatched     : std_logic := '0';
    signal OutAck         : std_logic;
    signal Out_ValidI     : std_logic;

begin

    -- Valid pulse generation
    p_in : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then

            -- Ready is set when data was acknowledged
            if InAck = '1' then
                InLatched <= '0';
            end if;

            -- Ready is reset when data was transferred
            -- This clause may override the clause above
            if In_Valid = '1' and In_ReadyI = '1' then
                InLatched <= '1';
            end if;

            -- Reset
            if RstInI = '1' then
                InLatched <= '0';
            end if;
        end if;
    end process;

    In_ReadyI     <= (not InLatched) or InAck when ReadyRstState_g = '1' else
                     ((not InLatched) or InAck) and (not RstInI); -- Actively pull Ready low during reset if required
    InTransaction <= In_Valid and In_ReadyI;
    In_Ready      <= In_ReadyI;

    -- instantiation of simple CC (path in->out)
    i_scc : entity work.olo_base_cc_simple
        generic map (
            Width_g      => Width_g,
            SyncStages_g => SyncStages_g
        )
        port map (
            In_Clk      => In_Clk,
            In_RstIn    => In_RstIn,
            In_RstOut   => RstInI,
            In_Data     => In_Data,
            In_Valid    => InTransaction,
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => RstOutI,
            Out_Data    => Out_Data,
            Out_Valid   => OutTransaction
        );

    In_RstOut  <= RstInI;
    Out_RstOut <= RstOutI;

    -- Transfer valid (path out->in)
    i_bcc : entity work.olo_base_cc_pulse
        generic map (
            NumPulses_g  => 1,
            SyncStages_g => SyncStages_g
        )
        port map (
            In_Clk          => Out_Clk,
            In_RstIn        => RstOutI,
            In_Pulse(0)     => OutAck,
            Out_Clk         => In_Clk,
            Out_RstIn       => RstInI,
            Out_Pulse(0)    => InAck
        );

    -- Latch data on output side
    p_out : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then

            -- Latch data if required
            if OutTransaction = '1' and Out_Ready = '0' then
                OutLatched <= '1';
            elsif Out_Ready = '1' then
                OutLatched <= '0';
            end if;

            -- Reset
            if RstOutI = '1' then
                OutLatched <= '0';
            end if;
        end if;
    end process;

    Out_ValidI <= OutTransaction or OutLatched;
    OutAck     <= Out_ValidI and Out_Ready;
    Out_Valid  <= Out_ValidI;

end architecture;
