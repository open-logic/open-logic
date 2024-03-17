------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a pure VHDL and vendor indpendent true dual port RAM with optional
-- byte enables.

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
-- Test synthesis: Try odd widths without BE, try 3 bits (<8) without BE
entity olo_base_ram_tdp is
    generic ( 
        Depth_g         : positive;   
        Width_g         : positive;    
        RdLatency_g     : positive  := 1;   
        RamStyle_g      : string    := "auto";   -- intel "M4K", "M9K", "M20K", "M144K", or "MLAB" - amd block, distributed, ultra, auto                 
        RamBehavior_g   : string    := "RBW";
        UseByteEnable_g : boolean   := false
    );                                                      -- "RBW" = read-before-write, "WBR" = write-before-read
    port (   
        A_Clk     : in  std_logic;
        A_Addr    : in  std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        A_Be      : in  std_logic_vector(Width_g / 8 - 1 downto 0)          := (others => '1'); 
        A_WrEna   : in  std_logic                                           := '0'; 
        A_WrData  : in  std_logic_vector(Width_g - 1 downto 0)              := (others => '0'); 
        A_RdData  : out std_logic_vector(Width_g - 1 downto 0);   
        B_Clk     : in  std_logic;
        B_Addr    : in  std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        B_Be      : in  std_logic_vector(Width_g / 8 - 1 downto 0)          := (others => '1');
        B_WrEna   : in  std_logic                                           := '0'; 
        B_WrData  : in  std_logic_vector(Width_g - 1 downto 0)              := (others => '0');
        B_RdData  : out std_logic_vector(Width_g - 1 downto 0));
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_ram_tdp is

    -- Constants
    constant BeCount_c : integer := Width_g / 8;

    -- memory array
    type data_t is array (natural range<>) of std_logic_vector(Width_g - 1 downto 0);
    shared variable mem : data_t(Depth_g - 1 downto 0) := (others => (others => '0'));

    -- Read registers
    signal a_rd_pipe, b_rd_pipe      : data_t(1 to RdLatency_g);

    -- AMD RAM implementation attribute
    attribute ram_style : string;
    attribute ram_style of mem : variable is RamStyle_g;

    -- Intel RAM implementation attribute
    attribute ramstyle : string;
    attribute ramstyle of mem : variable is RamStyle_g;

begin

    -- Assertions
    assert RamBehavior_g = "RBW" or RamBehavior_g = "WBR" 
        report "olo_base_ram_tdp: RamBehavior_g must Be RBW or WBR" 
        severity error;
    assert (Width_g mod 8 = 0) or (not UseByteEnable_g) 
        report "olo_base_ram_tdp: Width_g must be a multiple of 8, otherwise byte-enables must be disabled" 
        severity error;

    -- Port A
    porta_p : process(A_Clk)
    begin
        if rising_edge(A_Clk) then
            if RamBehavior_g = "RBW" then
                a_rd_pipe(1) <= mem(to_integer(unsigned(A_Addr)));
            end if;
            if A_WrEna = '1' then
                -- Write with byte enables
                if UseByteEnable_g then
                    for byte in 0 to BeCount_c - 1 loop
                        if A_Be(byte) = '1' then
                            mem(to_integer(unsigned(A_Addr)))(byte * 8 + 7 downto byte * 8) := A_WrData(byte * 8 + 7 downto byte * 8);
                        end if;
                    end loop;
                -- Write without byte enables
                else
                    mem(to_integer(unsigned(A_Addr))):= A_WrData;
                end if;
            end if;
            if RamBehavior_g = "WBR" then
                a_rd_pipe(1) <= mem(to_integer(unsigned(A_Addr)));
            end if;
            -- Read-data pipeline registers
            a_rd_pipe(2 to RdLatency_g) <= a_rd_pipe(1 to RdLatency_g-1);
        end if;
    end process;
    A_RdData <= a_rd_pipe(RdLatency_g);

    -- Port B
    portb_p : process(B_Clk)
    begin
        if rising_edge(B_Clk) then
            if RamBehavior_g = "RBW" then
                b_rd_pipe(1) <= mem(to_integer(unsigned(B_Addr)));
            end if;
            if B_WrEna = '1' then
                -- Write with byte enables
                if UseByteEnable_g then
                    for byte in 0 to BeCount_c - 1 loop
                        if B_Be(byte) = '1' then
                            mem(to_integer(unsigned(B_Addr)))(byte * 8 + 7 downto byte * 8) := B_WrData(byte * 8 + 7 downto byte * 8);
                        end if;
                    end loop;
                -- Write without byte enables
                else
                    mem(to_integer(unsigned(B_Addr))):= B_WrData;
                end if;
            end if;
            if RamBehavior_g = "WBR" then
                b_rd_pipe(1) <= mem(to_integer(unsigned(B_Addr)));
            end if;
            -- Read-data pipeline registers
            b_rd_pipe(2 to RdLatency_g) <= b_rd_pipe(1 to RdLatency_g-1);
        end if;
    end process;
    B_RdData <= b_rd_pipe(RdLatency_g);

end architecture;

