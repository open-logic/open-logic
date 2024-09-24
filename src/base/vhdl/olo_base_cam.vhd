------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This components implements a content addressable memory.

-- TODO:
-- Configurable latencies (read 1 hot, decode)
-- Convert to pipes
-- TDP mode for reading and writing at the same time?
-- Timing check
-- Remove ContentWidth and Adresses generic default values
-- Test: Valid directly after write, invalid directly after remove

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_cam is
    generic (
        Addresses_g     : positive  := 1024;                                         
        ContentWidth_g  : positive  := 32;    
        RamStyle_g      : string    := "auto";  
        RamBehavior_g   : string    := "RBW";
        RamBlockWidth_g : positive  := 32; 
        RamBlockDepth_g : positive  := 512
    );  
    port (   
        -- Control Signals
        Clk                     : in  std_logic;
        Rst                     : in  std_logic;

        -- CAM request Signals
        CamIn_Valid             : in  std_logic                                                 := '1';
        CamIn_Ready             : out std_logic;
        CamIn_Content           : in  std_logic_vector(ContentWidth_g - 1 downto 0);
        CamIn_Addr              : in  std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        CamIn_Add               : in  std_logic;
        CamIn_Remove            : in  std_logic                                                 := '0';

        -- CAM one hot response
        Cam1Hot_Valid           : out std_logic;
        Cam1Hot_Match           : out std_logic_vector(Addresses_g-1 downto 0);

        -- CAM binary response
        CamAddr_Valid           : out std_logic;
        CamAddr_Found           : out std_logic;
        CamAddr_Addr            : out std_logic_vector(log2ceil(Addresses_g)-1 downto 0)        
    );         
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_cam is
    -- *** Constants ***
    constant BlockAddrBits_c    : positive := log2ceil(RamBlockDepth_g);
    constant BlocksParallel_c   : positive := integer(ceil(real(ContentWidth_g) / real(BlockAddrBits_c)));
    constant TotalAddrBits_c    : positive := BlocksParallel_c * BlockAddrBits_c;

    -- *** Two Process Method ***
    type two_process_r is record
        -- General
        CamIn_Ready             : std_logic;
        -- Stage 0
        CamValid_0              : std_logic;    
        Content_0               : std_logic_vector(ContentWidth_g - 1 downto 0);
        Addr_0                  : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Add_0                   : std_logic;
        Remove_0                : std_logic;
        -- Stage 1
        CamValid_1              : std_logic;
        Addr_1                  : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Content_1               : std_logic_vector(ContentWidth_g - 1 downto 0);
        Add_1                   : std_logic;
        Remove_1                : std_logic;
        -- Stage 2
        CamValid_2              : std_logic;
        AddrOneHot_2            : std_logic_vector(Addresses_g-1 downto 0);
        -- Stage 3
        CamValid_3              : std_logic;
        AddrBin_3               : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Found_3                 : std_logic;
    end record;
    signal r, r_next : two_process_r;

    -- *** Instantiation Signals ***
    type Addr_t is array (natural range <>) of std_logic_vector(Addresses_g-1 downto 0);
    signal AddrOneHot_1 : Addr_t(0 to BlocksParallel_c-1);
    signal WriteOneHot_1 : Addr_t(0 to BlocksParallel_c-1);
    signal WrMem_1 : std_logic;

    
begin

    --------------------------------------------------------------------------
    -- Assertions
    --------------------------------------------------------------------------   
    assert isPower2(RamBlockDepth_g)
        report "olo_base_cam - RamBlockDepth_g must be a power of 2"
        severity error;

    --------------------------------------------------------------------------
    -- Combinatorial Proccess
    --------------------------------------------------------------------------
    p_cob : process (CamIn_Valid, CamIn_Content, CamIn_Addr, CamIn_Add, CamIn_Remove,
                     AddrOneHot_1, r)
        variable v : two_process_r;
        variable ClearMask_v, SetMask_v : std_logic_vector(Addresses_g-1 downto 0);
    begin
        -- *** Hold variables stable *** 
        v := r;


        -- *** Stage 0 ***
        -- Modifications of the table take one additional cycle to write back the updated entry
        if (CamIn_Add = '1' or CamIn_Remove = '1') and CamIn_Valid = '1' and r.CamIn_Ready = '1' then
            v.CamIn_Ready := '0';
        else
            v.CamIn_Ready := '1';
        end if;
        v.CamValid_0 := CamIn_Valid and r.CamIn_Ready;
        v.Content_0 := CamIn_Content;
        v.Addr_0 := CamIn_Addr;
        v.Add_0 := CamIn_Add;
        v.Remove_0 := CamIn_Remove;

        
        -- *** Stage 1 ***
        -- Wait for RAM to respond
        v.CamValid_1 := r.CamValid_0;
        v.Addr_1 := r.Addr_0;
        v.Content_1 := r.Content_0;
        v.Add_1 := r.Add_0;
        v.Remove_1 := r.Remove_0;

        -- *** Stage 2 ***
        v.CamValid_2 := r.CamValid_1;
        -- Find one hot matching address
        v.AddrOneHot_2 := AddrOneHot_1(0);
        for i in 1 to BlocksParallel_c-1 loop
            v.AddrOneHot_2 := v.AddrOneHot_2 and AddrOneHot_1(i);
        end loop;
        -- Modify CAM content if required
        ClearMask_v := (others => '1');
        SetMask_v := (others => '0');
        if r.Add_1 = '1' then
            SetMask_v(fromUslv(to01(r.Addr_1))) := '1';
        end if;
        if r.Remove_1 = '1' then
            ClearMask_v(fromUslv(to01(r.Addr_1))) := '0';
        end if;
        for i in 0 to BlocksParallel_c-1 loop
            WriteOneHot_1(i) <= (AddrOneHot_1(i) and ClearMask_v) or SetMask_v;
        end loop;
        WrMem_1 <= r.CamValid_1 and (r.Add_1 or r.Remove_1);

        -- *** Stage 3 ***
        v.CamValid_3 := r.CamValid_2;
        -- Convert one hot to binary
        v.Found_3 := '0';
        v.AddrBin_3 := (others => '0');
        for i in 0 to Addresses_g-1 loop
            if r.AddrOneHot_2(i) = '1' then
                v.Found_3 := '1';
                v.AddrBin_3 := toUslv(i, v.AddrBin_3'length);
                exit;
            end if;
        end loop;

        -- *** Assign to signal ***
        r_next <= v;
    end process;

    --------------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------------
    CamIn_Ready     <= r.CamIn_Ready;
    Cam1Hot_Valid   <= r.CamValid_2;
    Cam1Hot_Match   <= r.AddrOneHot_2;
    CamAddr_Valid   <= r.CamValid_3;
    CamAddr_Found   <= r.Found_3;
    CamAddr_Addr    <= r.AddrBin_3;


    --------------------------------------------------------------------------
    -- Sequential Proccess
    --------------------------------------------------------------------------
    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.CamIn_Ready       <= '0';
                r.CamValid_0        <= '0';
                r.CamValid_1        <= '0';
                r.CamValid_2        <= '0';
                r.CamValid_3        <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Instantiations
    --------------------------------------------------------------------------    
    -- CAM memory array
    g_addr : for i in 0 to BlocksParallel_c-1 generate
        signal ContentExtended_0  : std_logic_vector(TotalAddrBits_c-1 downto 0) := (others => '0');
        signal ContentExtended_1  : std_logic_vector(TotalAddrBits_c-1 downto 0) := (others => '0');
        signal RdAddr_0           : std_logic_vector(BlockAddrBits_c-1 downto 0);
        signal WrAddr_1           : std_logic_vector(BlockAddrBits_c-1 downto 0);
    begin
        -- Input assembly
        ContentExtended_0(ContentWidth_g-1 downto 0) <= r.Content_0;
        RdAddr_0 <= to01(ContentExtended_0((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));
        ContentExtended_1(ContentWidth_g-1 downto 0) <= r.Content_1;
        WrAddr_1 <= to01(ContentExtended_1((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));

        -- Instance
        i_ram : entity work.olo_base_ram_sdp
            generic map (
                Depth_g         => RamBlockDepth_g, 
                Width_g         => Addresses_g,
                RamStyle_g      => RamStyle_g,
                RamBehavior_g   => RamBehavior_g
            )
            port map (   
                Clk         => Clk,
                Wr_Addr     => WrAddr_1,
                Wr_Ena      => WrMem_1,  
                Wr_Data     => WriteOneHot_1(i),
                Rd_Addr     => RdAddr_0,
                Rd_Data     => AddrOneHot_1(i)
            );   
    end generate;

    
  

end architecture;

