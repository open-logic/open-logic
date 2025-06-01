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
entity olo_axi_stream_splitter is
    generic(
        NumberOfOutputStreams_g : positive := 2);
    port(
        -- input stream
        InputStream_tvalid : in  std_logic;
        InputStream_tready : out std_logic;
        -- output streams
        OutputStreams_tvalid : out std_logic;
        OutputStreams_tready : in  std_logic_vector(NumberOfOutputStreams_g - 1 downto 0));
end entity olo_axi_stream_splitter;

architecture rtl of olo_axi_stream_splitter is
begin
    InputStream_tready <= '1' when OutputStreams_tready = (others => '1') else '0';
    OutputStreams_tvalid <= InputStream_tvalid and InputStream_tready;
end architecture rtl;
