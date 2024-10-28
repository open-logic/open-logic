---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows passing of static-data
-- (i.e. data that is not sample based) from one clock domain to another. This
-- entity ensures that the data is passed correctly at some point of time but
-- it does not specify an exact sample point.
-- The main use cause of this entity is to pass status information or configuration
-- register values between clock domains.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_status.md
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
entity olo_base_cc_status is
    generic (
        Width_g      : positive;
        SyncStages_g : positive range 2 to 4 := 2
    );
    port (
        In_Clk      : in    std_logic;
        In_RstIn    : in    std_logic := '0';
        In_RstOut   : out   std_logic;
        In_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Out_Clk     : in    std_logic;
        Out_RstIn   : in    std_logic;
        Out_RstOut  : out   std_logic := '0';
        Out_Data    : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_cc_status is

    -- Input Domain Signals
    signal RstInI       : std_logic;
    signal Started      : std_logic := '0';
    signal RstOutI_Sync : std_logic_vector(1 downto 0);
    signal VldIn        : std_logic;
    signal VldFb        : std_logic;

    -- Output Domain Signals
    signal RstOutI : std_logic;
    signal VldOut  : std_logic;

begin

    -- Valid pulse generation
    p_vldgen : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            -- Send valid after it is received back
            VldIn <= VldFb;

            -- Generation of first vld pulse
            if (Started = '0') then
                VldIn   <= '1';
                Started <= '1';
            end if;

            -- Reset
            if RstInI = '1' then
                RstOutI_Sync <= (others => '1');
                Started      <= '0';
                VldIn        <= '0';
            end if;
        end if;
    end process;

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
            In_Valid    => VldIn,
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => RstOutI,
            Out_Data    => Out_Data,
            Out_Valid   => VldOut
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
            In_Pulse(0)     => VldOut,
            Out_Clk         => In_Clk,
            Out_RstIn       => RstInI,
            Out_Pulse(0)    => VldFb
        );

end architecture;
