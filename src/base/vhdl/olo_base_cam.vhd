------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This components implements a content addressable memory.

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
        -- Basic Configuration
        Addresses_g             : positive  := 1024;                                         
        ContentWidth_g          : positive  := 32;    
        RamStyle_g              : string    := "auto";  
        RamBehavior_g           : string    := "RBW";
        RamBlockWidth_g         : positive  := 32; 
        RamBlockDepth_g         : positive  := 512;      
        -- Read/Write interleaving
        ReadPriority_g          : boolean   := false;
        StrictOrdering_g        : boolean   := true;
        -- Pipelineing
        UseAddrOut_g            : boolean   := true;
        RegisterInput_g         : boolean   := true;
        Register1Hot_g          : boolean   := true;
        OneHotDecodeLatency_g   : natural   := 3
    );  
    port (   
        -- Control Signals
        Clk                     : in  std_logic;
        Rst                     : in  std_logic;

        -- CAM read request
        CamRd_Valid             : in  std_logic                                                 := '1';
        CamRd_Ready             : out std_logic;
        CamRd_Content           : in  std_logic_vector(ContentWidth_g-1 downto 0);

        -- Cam write
        CamWr_Valid             : in  std_logic;
        CamWr_Ready             : out std_logic;
        CamWr_Content           : in  std_logic_vector(ContentWidth_g-1 downto 0);
        CamWr_Addr              : in  std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        CamWr_Write             : in  std_logic;
        CamWr_Clear             : in  std_logic                                                 := '0';

        -- CAM one hot read response
        Cam1Hot_Valid           : out std_logic;
        Cam1Hot_Match           : out std_logic_vector(Addresses_g-1 downto 0);

        -- CAM binary read response
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

    -- *** Types ***
    type Addr_t is array (natural range <>) of std_logic_vector(log2ceil(Addresses_g)-1 downto 0);

    -- *** Two Process Method ***
    type two_process_r is record
        -- Stage 0
        Content_0               : std_logic_vector(ContentWidth_g - 1 downto 0);
        Addr_0                  : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Write_0                 : std_logic;
        Clear_0                 : std_logic;
        Read_0                  : std_logic;
        -- Stage 1
        Content_1               : std_logic_vector(ContentWidth_g - 1 downto 0);
        Addr_1                  : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Write_1                 : std_logic;
        Clear_1                 : std_logic;
        Read_1                  : std_logic;
        -- Stage 2
        AddrOneHot_2            : std_logic_vector(Addresses_g-1 downto 0);
        Read_2                  : std_logic;
        -- Stage 3
        Read_3                  : std_logic;
        AddrBin_3               : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Found_3                 : std_logic;
        -- Stage 4+
        Read_N                  : std_logic_vector(4 to 4+OneHotDecodeLatency_g-2);
        AddrBin_N               : Addr_t(4 to 4+OneHotDecodeLatency_g-2);
        Found_N                 : std_logic_vector(4 to 4+OneHotDecodeLatency_g-2); 
    end record;
    signal r, r_next : two_process_r;

    -- *** Instantiation Signals ***
    type HoneHot_t is array (natural range <>) of std_logic_vector(Addresses_g-1 downto 0);
    signal AddrOneHot_1     : HoneHot_t(0 to BlocksParallel_c-1);
    signal WriteOneHot_1    : HoneHot_t(0 to BlocksParallel_c-1);
    signal WrMem_1          : std_logic;

    
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
    p_cob : process (CamRd_Valid, CamRd_Content, CamWr_Valid, CamWr_Content, CamWr_Addr, CamWr_Write, CamWr_Clear, 
                     AddrOneHot_1, Rst, r)
        variable v : two_process_r;
        variable ClearMask_v, SetMask_v : std_logic_vector(Addresses_g-1 downto 0);
        variable InRdReady_v, InWrReady_v : std_logic;
        variable OneHot_v : std_logic_vector(Addresses_g-1 downto 0);
    begin
        -- *** Hold variables stable *** 
        v := r;

        -- *** Input Ready Handling ***
        if ReadPriority_g then
            InRdReady_v     := '1';
            InWrReady_v     := not CamRd_Valid;
        else
            InWrReady_v     := '1';
            InRdReady_v     := not CamWr_Valid; 
        end if;
        -- For Write and Rad with strict ordering, wait until write is done
        if r.Write_0 = '1' or r.Clear_0 = '1' then
            InWrReady_v := '0';
            if StrictOrdering_g and RamBehavior_g = "RBW" then
                -- If the ordering is not strict or the ram writes befor read, we camm continue reading immediately
                InRdReady_v := '0';
            end if;
        end if;
        -- Handle Reset
        if Rst = '1' then
            InRdReady_v     := '0';
            InWrReady_v     := '0';
        end if;
        CamRd_Ready <= InRdReady_v;
        CamWr_Ready <= InWrReady_v;


        -- *** Stage 0 ***
        v.Addr_0    := CamWr_Addr;
        v.Write_0   := '0';
        v.Clear_0   := '0';
        v.Read_0    := '0';
        if InWrReady_v = '1' and CamWr_Valid = '1' then
            v.Content_0     := CamWr_Content;
            v.Write_0       := CamWr_Write;
            v.Clear_0       := CamWr_Clear;
        elsif InRdReady_v = '1' and CamRd_Valid = '1' then
            v.Content_0     := CamRd_Content;
            v.Read_0        := '1';
        end if;
        
        
        -- *** Stage 1 ***
        if RegisterInput_g then
            -- Wait for RAM to respond
            v.Content_1 := r.Content_0;
            v.Addr_1    := r.Addr_0;
            v.Write_1   := r.Write_0;
            v.Clear_1   := r.Clear_0;
            v.Read_1    := r.Read_0;
        else
            -- Skip one register state
            v.Content_1 := v.Content_0;
            v.Addr_1    := v.Addr_0;
            v.Write_1   := v.Write_0;
            v.Clear_1   := v.Clear_0;
            v.Read_1    := v.Read_0;
        end if;


        -- *** Stage 2 ***
        v.Read_2 := r.Read_1;
        -- Find one hot matching address
        v.AddrOneHot_2 := AddrOneHot_1(0);
        for i in 1 to BlocksParallel_c-1 loop
            v.AddrOneHot_2 := v.AddrOneHot_2 and AddrOneHot_1(i);
        end loop;
        -- Modify CAM content if required
        ClearMask_v := (others => '1');
        SetMask_v := (others => '0');
        if r.Write_1 = '1' then
            SetMask_v(fromUslv(to01(r.Addr_1))) := '1';
        end if;
        if r.Clear_1 = '1' then
            ClearMask_v(fromUslv(to01(r.Addr_1))) := '0';
        end if;
        for i in 0 to BlocksParallel_c-1 loop
            WriteOneHot_1(i) <= (AddrOneHot_1(i) and ClearMask_v) or SetMask_v;
        end loop;
        WrMem_1 <= r.Write_1 or r.Clear_1;
        -- One hot output
        if Register1Hot_g then
            Cam1Hot_Valid   <= r.Read_2;
            OneHot_v        := r.AddrOneHot_2;
            v.Read_3        := r.Read_2;
        else
            Cam1Hot_Valid   <= v.Read_2;
            OneHot_v        := v.AddrOneHot_2;
            v.Read_3        := v.Read_2;
        end if;
        Cam1Hot_Match <= OneHot_v;

        -- *** Stage 3 ***
        if UseAddrOut_g then
            -- Convert one hot to binary
            v.Found_3 := '0';
            v.AddrBin_3 := (others => '0');
            for i in 0 to Addresses_g-1 loop
                if OneHot_v(i) = '1' then
                    v.Found_3 := '1';
                    v.AddrBin_3 := toUslv(i, v.AddrBin_3'length);
                    exit;
                end if;
            end loop;

            -- Address output
            if OneHotDecodeLatency_g = 0 then
                CamAddr_Valid   <= v.Read_3;
                CamAddr_Found   <= v.Found_3;
                CamAddr_Addr    <= v.AddrBin_3; 
            elsif OneHotDecodeLatency_g = 1 then
                CamAddr_Valid   <= r.Read_3;
                CamAddr_Found   <= r.Found_3;
                CamAddr_Addr    <= r.AddrBin_3;
            else
                v.Read_N        := r.Read_3     & r.Read_N      (r.Read_N'left      to r.Read_N'right-1);
                v.AddrBin_N     := r.AddrBin_3  & r.Addrbin_N   (r.Addrbin_N'left   to r.Addrbin_N'right-1);
                v.Found_N       := r.Found_3    & r.Found_N     (r.Found_N'left     to r.Found_N'right-1);
                CamAddr_Valid   <= r.Read_N(r.Read_N'right);
                CamAddr_Found   <= r.Found_N(r.Found_N'right);
                CamAddr_Addr    <= r.AddrBin_N(r.AddrBin_N'right);                       
            end if;  
        else
            CamAddr_Valid <= '0';   
            CamAddr_Found <= '0';
            CamAddr_Addr  <= (others => '0');
        end if;

        -- *** Assign to signal ***
        r_next <= v;
    end process;

    --------------------------------------------------------------------------
    -- Sequential Proccess
    --------------------------------------------------------------------------
    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Write_0   <= '0';
                r.Clear_0   <= '0';
                r.Read_0    <= '0';
                r.Write_1   <= '0';
                r.Clear_1   <= '0';
                r.Read_1    <= '0';
                r.Read_2    <= '0';
                r.Read_3    <= '0';
                r.Read_N    <= (others => '0');
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
        ContentExtended_0(ContentWidth_g-1 downto 0) <= r.Content_0 when RegisterInput_g else
                                                        CamRd_Content;  
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

