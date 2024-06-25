------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Benoit Stef, Oliver Bründler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a very basic strobe generator. It produces pulses with a duration
-- of one clock cycle at a given frequency.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity olo_base_strobe_gen is
    generic(
        FreqClkHz_g    : real; 
        FreqStrobeHz_g : real
    ); 
    port (   
        Clk         : in  std_logic;  
        Rst         : in  std_logic;       
        In_Sync     : in  std_logic     := '0';
        Out_Valid   : out std_logic;
        Out_Ready   : in  std_logic     := '1'
    );      
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of olo_base_strobe_gen is
    constant Ratio_c : integer                      := integer(round(FreqClkHz_g / FreqStrobeHz_g));
    signal Count     : integer range 0 to Ratio_c-1 := 0;
    signal SyncLast  : std_logic                    := '0';
begin

    p_strobe : process(Clk)
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            if (Count = Ratio_c - 1) or ((In_Sync = '1') and (SyncLast = '0')) then
                Out_Valid   <= '1';
                Count       <= 0;
            else
                -- Keep Out_Valid asserted until Out_Ready is asserted as well
                if Out_Ready = '1' then
                    Out_Valid <= '0';
                end if;
                Count  <= Count + 1;
            end if;
            SyncLast <= In_Sync;

            -- Reset
            if Rst = '1' then
                Count       <= 0;
                Out_Valid   <= '0';
                SyncLast    <= '0';
            end if;
        end if;
    end process;

end architecture;
