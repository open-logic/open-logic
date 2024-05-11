------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows passing single samples of data
-- from one clock domain to another. It only works if sample rates are significantly
-- lower than the clock speed of both domains.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_cc_simple is
    generic (
        Width_g     : positive := 1                             
    );                              
    port (   
        In_Clk      : in  std_logic;                                  
        In_RstIn    : in  std_logic := '0';                                  
        In_RstOut   : out std_logic;                                  
        In_Data     : in  std_logic_vector(Width_g - 1 downto 0);     
        In_Valid    : in  std_logic;                                  
        Out_Clk     : in  std_logic;                                  
        Out_RstIn   : in  std_logic := '0';                                  
        Out_RstOut  : out std_logic;                                  
        Out_Data    : out std_logic_vector(Width_g - 1 downto 0);     
        Out_Valid   : out std_logic                                   
    );                                  
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture struct of olo_base_cc_simple is

    -- Input Domain signals
    signal RstInI      : std_logic;
    signal DataLatchIn : std_logic_vector(Width_g - 1 downto 0);
    -- Output Domain signals
    signal RstOutI     : std_logic;
    signal VldOutI     : std_logic;

    signal Out_Data_Sig : std_logic_vector(Width_g - 1 downto 0);

        -- Synthesis attributes Xilinx
    attribute dont_touch             : boolean;
    attribute keep                   : string;
    attribute dont_touch of Out_Data_Sig       : signal is true;
    attribute keep of Out_Data_Sig             : signal is "yes"; 

begin

    i_pulse_cc : entity work.olo_base_cc_pulse
        generic map (
            NumPulses_g => 1
        )
        port map (
            In_Clk      => In_Clk,
            In_RstIn    => In_RstIn,
            In_RstOut   => RstInI,
            In_Pulse(0) => In_Valid,
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => RstOutI,
            Out_Pulse(0) => VldOutI
        );
    In_RstOut  <= RstInI;
    Out_RstOut <= RstOutI;

    -- Data transmit side (A)
    DataA_p : process(In_Clk)
    begin
        if rising_edge(In_Clk) then
            if In_Valid = '1' then
                DataLatchIn <= In_Data;
            end if;
        end if;
    end process;

    -- Data receive side (B)
    DataB_p : process(Out_Clk)
    begin
        if rising_edge(Out_Clk) then
            Out_Valid <= VldOutI;
            if VldOutI = '1' then
                Out_Data_Sig <= DataLatchIn;
            end if;
            -- Reset
            if RstOutI = '1' then
                Out_Valid <= '0';
            end if;
        end if;
    end process;
    Out_Data <= Out_Data_Sig;

end architecture;