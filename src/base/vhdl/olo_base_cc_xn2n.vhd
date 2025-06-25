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
-- the output clock period is an integer multiple of the input clock period
-- (input clock frequency is an integer multiple of the output clock frequency).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_xn2n.md
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
entity olo_base_cc_xn2n is
    generic (
        Width_g       : positive
    );
    port (
        In_Clk      : in    std_logic;
        In_RstIn    : in    std_logic;
        In_RstOut   : out   std_logic;
        In_Valid    : in    std_logic;
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

architecture rtl of olo_base_cc_xn2n is

    -- Input Side
    signal InCnt         : unsigned(1 downto 0);
    signal InRstInt      : std_logic;
    signal InDataReg     : std_logic_vector(Width_g - 1 downto 0);
    signal InDataRegLast : std_logic_vector(Width_g - 1 downto 0);

    -- Output Side
    signal OutCnt      : unsigned(1 downto 0);
    signal OutRstInt   : std_logic;
    signal OutIn_Valid : std_logic;

begin

    In_Ready <= '1' when (InCnt - OutCnt /= 2) and (InRstInt = '0') else '0';

    p_input : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            if In_Valid = '1' and InCnt - OutCnt /= 2 then
                InCnt         <= InCnt + 1;
                InDataReg     <= In_Data;
                InDataRegLast <= InDataReg;
            end if;
            -- Reset
            if InRstInt = '1' then
                InCnt <= (others => '0');
            end if;
        end if;
    end process;

    p_output : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then
            -- New sample was acknowledged
            if OutIn_Valid = '1' and Out_Ready = '1' then
                OutIn_Valid <= '0';
            end if;
            -- Forward new sample to output if ready
            if InCnt /= OutCnt and (OutIn_Valid = '0' or Out_Ready = '1') then
                if InCnt - OutCnt = 1 then
                    Out_Data <= InDataReg;
                else
                    Out_Data <= InDataRegLast;
                end if;
                OutIn_Valid <= '1';
                OutCnt      <= OutCnt + 1;
            end if;
            if OutRstInt = '1' then
                OutCnt      <= (others => '0');
                OutIn_Valid <= '0';
            end if;
        end if;
    end process;

    Out_Valid <= OutIn_Valid;

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
