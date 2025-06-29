---------------------------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Milorad Petrovic
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- TODO

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_stream_merge is
    generic(
        Inputs_g : positive := 2);
    port(
        -- Input streams handshake signals.
        In_Valid : in  std_logic_vector(Inputs_g - 1 downto 0);
        In_Ready : out std_logic;
        -- Output stream handshake signals.
        Out_Valid : out std_logic;
        Out_Ready : in  std_logic);
end entity;

architecture rtl of olo_base_stream_merge is
    signal AllInputsValid : std_logic;
begin
    AllInputsValid <= '1' when In_Valid = (others => '1') else '0';
    Out_Valid <= AllInputsValid;
    In_Ready <= AllInputsValid and Out_Ready;
end architecture;



