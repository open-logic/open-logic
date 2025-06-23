---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Benoit Stef
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic mux for Time Division Multiplxed data input
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_tdm_mux.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_tdm_mux is
    generic (
        Channels_g  : natural;
        Width_g     : natural
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        In_ChSel    : in    std_logic_vector(log2ceil(Channels_g)-1 downto 0);
        In_Valid    : in    std_logic := '1';
        In_Data     : in    std_logic_vector(Width_g-1 downto 0);
        In_Last     : in    std_logic := '0';
        Out_Valid   : out   std_logic;
        Out_Data    : out   std_logic_vector(Width_g-1 downto 0);
        Out_Last    : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_tdm_mux is

    -- Stage 0
    signal Count_0      : integer range 0 to Channels_g-1 := 0;
    -- Stage 1
    signal SelLatched_1 : std_logic_vector(In_ChSel'range);
    signal Data_1       : std_logic_vector(In_Data'range);
    signal Count_1      : integer range 0 to Channels_g-1;
    signal Vld_1        : std_logic;
    signal Last_1       : std_logic;
    -- Stage 2
    signal Data_2       : std_logic_vector(In_Data'range);
    signal Vld_2        : std_logic;
    signal Last_2       : std_logic;

begin

    p_decode : process (Clk) is
    begin
        if rising_edge(Clk) then

            -- *** Stage 0/1 ***
            if In_Valid = '1' then
                -- Latch select
                if Count_0 = 0 then
                    SelLatched_1 <= In_ChSel;
                end if;
                -- Update counter
                if (Count_0 = Channels_g-1) or (In_Last = '1') then
                    Count_0 <= 0;
                else
                    Count_0 <= Count_0 + 1;
                end if;
            end if;
            Data_1  <= In_Data;
            Vld_1   <= In_Valid;
            Count_1 <= Count_0;
            Last_1  <= In_Last;

            -- *** Stage 2 ***
            -- Latch selected value
            if Count_1 = unsigned(SelLatched_1) then
                Data_2 <= Data_1;
            end if;
            -- Assert valid at the end of TDM cycle
            Vld_2 <= '0';
            if Vld_1 = '1' and Count_1 = Channels_g-1 then
                Vld_2 <= '1';
            end if;
            Last_2 <= Last_1;

            -- *** Reset ***
            if Rst = '1' then
                Count_0 <= 0;
                Vld_2   <= '0';
                Vld_1   <= '0';
            end if;
        end if;
    end process;

    Out_Valid <= Vld_2;
    Out_Data  <= Data_2;
    Out_Last  <= Last_2;

end architecture;
