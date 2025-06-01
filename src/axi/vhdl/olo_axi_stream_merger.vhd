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
entity olo_axi_stream_merger is
    generic(
        NumberOfInputStreams_g : positive := 2);
    port(
        -- input streams
        InputStreams_tvalid : in  std_logic_vector(NumberOfInputStreams_g downto 0);
        InputStreams_tready : out std_logic;
        -- output stream
        OutputStream_tvalid : out std_logic;
        OutputStream_tready : in  std_logic);
end entity olo_axi_stream_merger;

architecture rtl of olo_axi_stream_merger is
begin
    OutputStream_tvalid <= '1' when InputStreams_tvalid = (others => '1') else '0';
    InputStreams_tready <= OutputStream_tvalid and OutputStream_tready;
end architecture rtl;



