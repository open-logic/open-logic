---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Implements full flow-control handling (including Ready/backpressure) for
-- processing entities that do not support flow-control natively.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_flowctrl_handler.md
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
entity olo_base_flowctrl_handler is
    generic (
        InWidth_g           : positive;
        OutWidth_g          : positive;
        SamplesToAbsorb_g   : positive;
        RamStyle_g          : string := "auto";
        RamBehavior_g       : string := "RBW"
    );
    port (
        -- Control Ports
        Clk            : in    std_logic;
        Rst            : in    std_logic;
        -- Input Data
        In_Data        : in    std_logic_vector(InWidth_g - 1 downto 0);
        In_Valid       : in    std_logic := '1';
        In_Ready       : out   std_logic;
        -- Output Data
        Out_Data       : out   std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Valid      : out   std_logic;
        Out_Ready      : in    std_logic := '1';
        -- Data to Processing
        ToProc_Data    : out   std_logic_vector(InWidth_g - 1 downto 0);
        ToProc_Valid   : out   std_logic;
        -- Data from Processing
        FromProc_Data  : in    std_logic_vector(OutWidth_g - 1 downto 0);
        FromProc_Valid : in    std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_flowctrl_handler is

    -- Constants
    constant FifoDepth_c  : positive := 2*(SamplesToAbsorb_g+2);
    -- FIFO Signals
    signal Fifo_InReady   : std_logic;
    signal Fifo_HalfEmpty : std_logic;

begin

    -- *** Input Logic ***
    In_Ready     <= Fifo_HalfEmpty;
    ToProc_Data  <= In_Data;
    ToProc_Valid <= In_Valid and Fifo_HalfEmpty; -- Only forward data when FIFO is guaranteed to accept result

    -- *** FIFO Instantiation ***
    i_fifo : entity work.olo_base_fifo_sync
        generic map (
            Width_g         => OutWidth_g,
            Depth_g         => FifoDepth_c,
            AlmEmptyOn_g    => true,
            AlmEmptyLevel_g => FifoDepth_c/2,
            RamStyle_g      => RamStyle_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map (
            Clk           => Clk,
            Rst           => Rst,
            In_Data       => FromProc_Data,
            In_Valid      => FromProc_Valid,
            In_Ready      => Fifo_InReady,
            Out_Data      => Out_Data,
            Out_Valid     => Out_Valid,
            Out_Ready     => Out_Ready,
            AlmEmpty      => Fifo_HalfEmpty

        );

    -- *** Assertions ***
    p_assert : process (Clk) is
    begin
        if rising_edge(Clk) then
            assert (Fifo_InReady = '1' or FromProc_Valid /= '1')
                report "olo_base_flowctrl_handler: FIFO is full upon FromProc_Valid = '1'"
                severity error;
        end if;
    end process;

end architecture;
