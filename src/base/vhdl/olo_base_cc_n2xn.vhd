---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a clock crossing between two synchronous clocks where
-- the input clock period is an integer multiple of the output clock period
-- (output clock frequency is an integer multiple of the input clock frequency).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_n2xn.md
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_cc_n2xn is
    generic (
        Width_g       : positive := 8
    );
    port (
        In_Clk      : in    std_logic;
        In_RstIn    : in    std_logic := '0';
        In_RstOut   : out   std_logic;
        In_Valid    : in    std_logic := '1';
        In_Ready    : out   std_logic;
        In_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Out_Clk     : in    std_logic;
        Out_RstIn   : in    std_logic := '0';
        Out_RstOut  : out   std_logic;
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic := '1';
        Out_Data    : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

architecture rtl of olo_base_cc_n2xn is

    -- Input Side
    signal InRstInt  : std_logic;
    signal InDataReg : std_logic_vector(Width_g - 1 downto 0);
    signal InToggle  : std_logic;

    -- Output Side
    signal OutRstInt  : std_logic;
    signal OutDataReg : std_logic_vector(Width_g - 1 downto 0);
    signal OutDataVld : std_logic;
    signal OutToggle  : std_logic;

begin

    In_Ready <= '1' when (InToggle = OutToggle) and (InRstInt = '0') else '0';

    p_input : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            if In_Valid = '1' and (InToggle = OutToggle) then
                InDataReg <= In_Data;
                InToggle  <= not InToggle;
            end if;
            -- Reset
            if InRstInt = '1' then
                InToggle <= '0';
            end if;
        end if;
    end process;

    p_output : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then

            -- Acknowledge data
            if (OutDataVld = '1' and Out_Ready = '1') then
                OutDataVld <= '0';
            end if;

            -- Sample new data
            if (InToggle /= OutToggle)  and (OutDataVld = '0' or Out_Ready = '1') then
                OutDataReg <= InDataReg;
                OutDataVld <= '1';
                OutToggle  <= InToggle;
            end if;

            -- Reset
            if OutRstInt = '1' then
                OutDataVld <= '0';
                OutToggle  <= '0';
            end if;
        end if;
    end process;

    Out_Data  <= OutDataReg;
    Out_Valid <= OutDataVld;

    -- *** Reset Crossing ***
    i_rst_cc : entity work.olo_base_cc_reset
        port map (
            A_Clk       => In_Clk,
            A_RstIn     => In_RstIn,
            A_RstOut    => InRstInt,
            B_Clk       => Out_Clk,
            B_RstIn     => Out_RstIn,
            B_RstOut    => OutRstInt
        );

    In_RstOut  <= InRstInt;
    Out_RstOut <= OutRstInt;

end architecture;
