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
        Depth_g         : positive;     
        Width_g         : positive; 
        IsAsync_g       : boolean  := false;
        RdLatency_g     : positive := 1;  
        RamStyle_g      : string   := "auto";   -- intel "M4K", "M9K", "M20K", "M144K", or "MLAB" - amd block, distributed, ultra, auto
        RamBehavior_g   : string   := "RBW";
        UseByteEnable_g : boolean  := false
    );
    port (   
        Clk         : in  std_logic;
        Wr_Addr     : in  std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena      : in  std_logic                                         := '1';
        Wr_Be       : in  std_logic_vector(Width_g / 8 - 1 downto 0)        := (others => '1'); 
        Wr_Data     : in  std_logic_vector(Width_g - 1 downto 0);
        Rd_Clk      : in  std_logic                                         := '0';
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
    type data_t is array (natural range<>) of std_logic_vector(Width_g - 1 downto 0);
    shared variable mem : data_t(Depth_g - 1 downto 0) := (others => (others => '0'));

    -- Read registers
    signal rd_pipe      : data_t(1 to RdLatency_g);

    -- AMD RAM implementation attributes
    attribute ram_style : string;
    attribute ram_style of mem : variable is RamStyle_g;
    attribute shreg_extract : string;
    attribute shreg_extract of rd_pipe : signal is "no";

    -- Intel RAM implementation attributes
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
        ram_p : process(Clk)
        begin
            if rising_edge(Clk) then
                if RamBehavior_g = "RBW" then
                    if Rd_Ena = '1' then
                        rd_pipe(1) <= mem(to_integer(unsigned(Rd_Addr)));
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
                        rd_pipe(1) <= mem(to_integer(unsigned(Rd_Addr)));
                    end if;
                end if;

                -- Read-data pipeline registers
                rd_pipe(2 to RdLatency_g) <= rd_pipe(1 to RdLatency_g-1);
            end if;
        end process;
    end generate;

    -- Asynchronous implementation
    g_async : if IsAsync_g generate

        write_p : process(Clk)
        begin
            if rising_edge(Clk) then
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
                    rd_pipe(1) <= mem(to_integer(unsigned(Rd_Addr)));
                end if;

                -- Read-data pipeline registers
                rd_pipe(2 to RdLatency_g) <= rd_pipe(1 to RdLatency_g-1);
            end if;
        end process;

    end generate;

    -- Output
    Rd_Data <= rd_pipe(RdLatency_g);

end architecture;

