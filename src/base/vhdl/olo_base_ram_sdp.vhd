------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a pure VHDL and vendor indpendent simple dual port RAM with
-- optional byte enables.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

    ------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_ram_sdp is
    generic (
        Depth_g         : positive := 1024;     
        Width_g         : positive := 16; 
        IsAsync_g       : boolean  := false;
        RamStyle_g      : string   := "auto";   -- intel "M4K", "M9K", "M20K", "M144K", or "MLAB" - amd block, distributed, ultra, auto
        RamBehavior_g   : string   := "RBW";
        UseByteEnable_g : boolean   := false
    );
    port (   
        Wr_Clk      : in  std_logic;
        Wr_Addr     : in  std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena      : in  std_logic                                         := '1';
        Wr_Be       : in  std_logic_vector(Width_g / 8 - 1 downto 0)        := (others => '1'); 
        Wr_Data     : in  std_logic_vector(Width_g - 1 downto 0);
        Rd_Clk      : in  std_logic;
        Rd_Addr     : in  std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Rd_Ena      : in  std_logic                                         := '1';
        Rd_Data     : out std_logic_vector(Width_g - 1 downto 0)
    );                          
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_ram_sdp is

    -- constants
    constant BeCount_c : integer := Width_g / 8;

    -- memory array
    type mem_t is array (Depth_g - 1 downto 0) of std_logic_vector(Width_g - 1 downto 0);
    shared variable mem : mem_t := (others => (others => '0'));

    -- AMD RAM implementation attribute
    attribute ram_style : string;
    attribute ram_style of mem : variable is RamStyle_g;

    -- Intel RAM implementation attribute
    attribute ramstyle : string;
    attribute ramstyle of mem : variable is RamStyle_g;

begin

    -- Assertions
    assert RamBehavior_g = "RBW" or RamBehavior_g = "WBR" 
        report "olo_base_ram_sdp: RamBehavior_g must Be RBW or WBR" 
        severity error;
    assert (Width_g mod 8 = 0) or (not UseByteEnable_g) 
        report "olo_base_ram_sdp: Width_g must be a multiple of 8, otherwise byte-enables must be disabled" 
        severity error;

    -- Synchronous Implementation
    g_sync : if not IsAsync_g generate
        ram_p : process(Wr_Clk)
        begin
            if rising_edge(Wr_Clk) then
                if RamBehavior_g = "RBW" then
                    if Rd_Ena = '1' then
                        Rd_Data <= mem(to_integer(unsigned(Rd_Addr)));
                    end if;
                end if;
                if Wr_Ena = '1' then
                    -- Write with byte enables
                    if UseByteEnable_g then
                        for byte in 0 to BeCount_c - 1 loop
                            if Wr_Be(byte) = '1' then
                                mem(to_integer(unsigned(Wr_Addr)))(byte * 8 + 7 downto byte * 8) := Wr_Data(byte * 8 + 7 downto byte * 8);
                            end if;
                        end loop;
                    -- Write without byte enables
                    else
                        mem(to_integer(unsigned(Wr_Addr))):= Wr_Data;
                    end if;
                end if;
                if RamBehavior_g = "WBR" then
                    if Rd_Ena = '1' then
                        Rd_Data <= mem(to_integer(unsigned(Rd_Addr)));
                    end if;
                end if;
            end if;
        end process;
    end generate;

    -- Asynchronous implementation
    g_async : if IsAsync_g generate

        write_p : process(Wr_Clk)
        begin
            if rising_edge(Wr_Clk) then
                if Wr_Ena = '1' then
                    -- Write with byte enables
                    if UseByteEnable_g then
                        for byte in 0 to BeCount_c - 1 loop
                            if Wr_Be(byte) = '1' then
                                mem(to_integer(unsigned(Wr_Addr)))(byte * 8 + 7 downto byte * 8) := Wr_Data(byte * 8 + 7 downto byte * 8);
                            end if;
                        end loop;
                    -- Write without byte enables
                    else
                        mem(to_integer(unsigned(Wr_Addr))):= Wr_Data;
                    end if;
                end if;
            end if;
        end process;

        read_p : process(Rd_Clk)
        begin
            if rising_edge(Rd_Clk) then
                if Rd_Ena = '1' then
                    Rd_Data <= mem(to_integer(unsigned(Rd_Addr)));
                end if;
            end if;
        end process;

    end generate;

end architecture;

