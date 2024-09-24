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
-- Package for Interface Simplification
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package olo_base_cam_simplified_pkg is
    constant CMD_WRITE          : std_logic_vector(1 downto 0) := "00";  -- Returns the content before write if it was occupied
    constant CMD_READ           : std_logic_vector(1 downto 0) := "01";  -- Returns the content
    constant CMD_CLEAR_ADDR     : std_logic_vector(1 downto 0) := "11";  -- Returns contente before clear
end package;

-- Split to "CAM" and "CAM Simplified"
-- Implement TDP mode (make tests safe + Add config while read test)
-- Small RAM style - same
-- Timing check


------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_cam_simplified_pkg.all;
    use work.olo_base_pkg_logic.all;

-- Remove ContentWidth and Adresses generic default values

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_cam_simplified is
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
        CamIn_Valid             : in  std_logic;
        CamIn_Ready             : out std_logic;
        CamIn_Content           : in  std_logic_vector(ContentWidth_g - 1 downto 0);

        -- CAM one hot response
        CamOneHot_Valid         : out std_logic;
        CamOneHot_Match         : out std_logic_vector(Addresses_g-1 downto 0);

        -- CAM binary response
        CamAddr_Valid           : out std_logic;
        CamAddr_Found           : out std_logic;
        CamAddr_Addr            : out std_logic_vector(log2ceil(Addresses_g)-1 downto 0);

        -- Config request
        ConfigIn_Valid          : in  std_logic;
        ConfigIn_Ready          : out std_logic;
        ConfigIn_Addr           : in  std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        ConfigIn_Cmd            : in  std_logic_vector(1 downto 0);
        ConfigIn_Content        : in  std_logic_vector(ContentWidth_g - 1 downto 0);

        -- Config Response
        ConfigOut_Valid         : out std_logic;
        ConfigOut_ErrOccupied   : out std_logic;
        ConfigOut_ErrEmpty      : out std_logic;
        ConfigOut_Content       : out std_logic_vector(ContentWidth_g - 1 downto 0)
    );         
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_cam_simplified is
    -- *** Constants ***
    constant BlockAddrBits_c    : positive := log2ceil(RamBlockDepth_g);
    constant BlocksParallel_c   : positive := integer(ceil(real(ContentWidth_g) / real(BlockAddrBits_c)));

    -- *** Types ***
    type ConfigFsm_t is (Idle_s, ReadCam_s, WaitCam_s, WaitAddrMerge_s, CalcNewOneHot_s);

    -- *** Two Process Method ***
    type two_process_r is record
        -- Stage 0
        CamValid_0              : std_logic;    
        ContentExtended_0       : std_logic_vector(BlocksParallel_c*BlockAddrBits_c - 1 downto 0);
        -- Stage 1
        CamValid_1              : std_logic;
        -- Stage 2
        CamValid_2              : std_logic;
        AddrOneHot_2            : std_logic_vector(Addresses_g-1 downto 0);
        -- Stage 3
        CamValid_3              : std_logic;
        AddrBin_3               : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Found_3                 : std_logic;
        -- Config FSM
        ConfigFsm               : ConfigFsm_t;
        ConfigAddr              : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        ConfigCmd               : std_logic_vector(1 downto 0);
        ConfigContent           : std_logic_vector(BlocksParallel_c*BlockAddrBits_c - 1 downto 0);
        ConfigIn_Ready          : std_logic;
        ConfigOut_Valid         : std_logic;
        ConfigOut_ErrOccupied   : std_logic;
        ConfigOut_ErrEmpty      : std_logic;
        ConfigRamContent        : std_logic_vector(ContentWidth_g - 1 downto 0);
        ConfigRamWr             : std_logic;
        ConfigRamWrData         : std_logic_vector(ContentWidth_g downto 0);
    end record;
    signal r, r_next : two_process_r;

    -- *** Instantiation Signals ***
    type Addr_t is array (natural range <>) of std_logic_vector(Addresses_g-1 downto 0);
    signal AddrOneHot_1 : Addr_t(0 to BlocksParallel_c-1);
    signal WriteOneHot : Addr_t(0 to BlocksParallel_c-1);
    signal WrMem : std_logic;
    signal RamRdContent   : std_logic_vector(ContentWidth_g-1 downto 0);
    signal RamRdOccupied  : std_logic;

    
begin

    --------------------------------------------------------------------------
    -- Assertions
    --------------------------------------------------------------------------   
    assert isPower2(RamBlockDepth_g)
        report "olo_base_cam_simplified - RamBlockDepth_g must be a power of 2"
        severity error;

    --------------------------------------------------------------------------
    -- Combinatorial Proccess
    --------------------------------------------------------------------------
    p_cob : process (CamIn_Valid, CamIn_Content, ConfigIn_Valid, ConfigIn_Cmd, ConfigIn_Addr, ConfigIn_Content, 
                     AddrOneHot_1, RamRdContent, RamRdOccupied, r, Rst)
        variable v : two_process_r;
        variable ClearMask_v, SetMask_v : std_logic_vector(Addresses_g-1 downto 0);
        variable CamIn_Ready_v : std_logic;
    begin
        -- *** Hold variables stable *** 
        v := r;

        -- *** Default Values ***
        if Rst = '1' or r.ConfigFsm /= Idle_s then
            CamIn_Ready_v := '0';
        else
            CamIn_Ready_v := not ConfigIn_Valid;
        end if;        
        CamIn_Ready <= CamIn_Ready_v;

        -- ****************
        -- *** CAM Read ***
        -- ****************

        -- *** Stage 0 ***
        v.CamValid_0 := CamIn_Valid and CamIn_Ready_v;
        v.ContentExtended_0 := (others => '0');
        v.ContentExtended_0(ContentWidth_g-1 downto 0) := CamIn_Content;
        
        -- *** Stage 1 ***
        v.CamValid_1 := r.CamValid_0;

        -- *** Stage 2 ***
        v.CamValid_2 := r.CamValid_1;
        -- Find one hot matching address
        v.AddrOneHot_2 := AddrOneHot_1(0);
        for i in 1 to BlocksParallel_c-1 loop
            v.AddrOneHot_2 := v.AddrOneHot_2 and AddrOneHot_1(i);
        end loop;

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

        -- ******************
        -- *** Config FSM ***
        -- ******************
        WriteOneHot <= (others => (others => 'X'));
        WrMem <= '0';
        v.ConfigOut_Valid := '0';
        v.ConfigOut_ErrOccupied := '0';
        v.ConfigOut_ErrEmpty := '0';
        v.ConfigRamWr := '0';
        case r.ConfigFsm is
            when Idle_s =>
                v.ConfigIn_Ready := '1';
                if ConfigIn_Valid = '1' and r.ConfigIn_Ready = '1' then
                    v.ConfigCmd := ConfigIn_Cmd;
                    v.ConfigAddr := ConfigIn_Addr;
                    v.ConfigContent := (others => '0');
                    v.ConfigContent(ContentWidth_g-1 downto 0) := ConfigIn_Content;
                    -- Transition to ReadCam
                    v.ConfigFsm := ReadCam_s;
                    v.ConfigIn_Ready := '0';
                end if;

            when ReadCam_s => -- Also read RAM
                v.ContentExtended_0 := r.ConfigContent;
                v.ConfigFsm := WaitCam_s;

            when WaitCam_s =>
                -- Do nothing, waiting for read value from CAM
                v.ConfigFsm := WaitAddrMerge_s;
                -- The normal ram is read, so we can react on the RAM being occupied or not
                v.ConfigRamContent := RamRdContent;
                if r.ConfigCmd = CMD_WRITE and RamRdOccupied = '1' then
                    v.ConfigOut_ErrOccupied := '1';
                    v.ConfigOut_Valid := '1';
                    v.ConfigFsm := Idle_s;
                end if;
                if (r.ConfigCmd = CMD_READ or r.ConfigCmd = CMD_CLEAR_ADDR) and RamRdOccupied = '0' then
                    v.ConfigOut_ErrEmpty := '1';
                    v.ConfigOut_Valid := '1';
                    v.ConfigFsm := Idle_s;
                end if;
                if r.ConfigCmd = CMD_READ and RamRdOccupied = '1' then
                    v.ConfigOut_Valid := '1';
                    v.ConfigFsm := Idle_s;
                end if;

                


            when WaitAddrMerge_s =>
                -- Do nothing, wait for the one-hot codes from different blocks being merged
                v.ConfigFsm := CalcNewOneHot_s;
                -- Update RAM if required
                if r.ConfigCmd = CMD_WRITE then
                    v.ConfigRamWrData(ContentWidth_g-1 downto 0) := r.ConfigContent(ContentWidth_g-1 downto 0);
                    v.ConfigRamWrData(ContentWidth_g) := '1'; -- occupied
                    v.ConfigRamWr := '1';
                end if;
                if r.ConfigCmd = CMD_CLEAR_ADDR then
                    v.ConfigRamWrData := (others => '0');
                    v.ConfigRamWr := '1';
                    v.ConfigContent := (others => '0');
                    v.ConfigContent(ContentWidth_g-1 downto 0) := r.ConfigRamContent;
                end if;


            when CalcNewOneHot_s => 
                -- Calculate Masks
                ClearMask_v := (others => '1');
                SetMask_v := (others => '0');
                case r.ConfigCmd is
                    when CMD_WRITE =>
                        SetMask_v(fromUslv(to01(r.ConfigAddr))) := '1';
                    when CMD_CLEAR_ADDR =>
                        ClearMask_v(fromUslv(to01(r.ConfigAddr))) := '0';
   
                    -- coverage off
                    when others => null; -- unreachable
                    -- coverage on
                end case;
                -- Update CAM content
                for i in 0 to BlocksParallel_c-1 loop
                    WriteOneHot(i) <= (AddrOneHot_1(i) and ClearMask_v) or SetMask_v;
                end loop;
                WrMem <= '1';
                -- End of config sequence
                v.ConfigFsm := Idle_s;
                v.ConfigOut_Valid := '1';
                        
            -- coverage off
            when others => null; -- unreachable
            -- coverage on
        end case;

        -- *** Assign to signal ***
        r_next <= v;
    end process;

    --------------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------------
    CamOneHot_Valid <= r.CamValid_2;
    CamOneHot_Match <= r.AddrOneHot_2;
    CamAddr_Valid <= r.CamValid_3;
    CamAddr_Found <= r.Found_3;
    CamAddr_Addr <= r.AddrBin_3;
    ConfigIn_Ready <= r.ConfigIn_Ready;
    ConfigOut_Valid <= r.ConfigOut_Valid;
    ConfigOut_ErrOccupied <= r.ConfigOut_ErrOccupied;
    ConfigOut_ErrEmpty <= r.ConfigOut_ErrEmpty;
    ConfigOut_Content <= r.ConfigRamContent;

    --------------------------------------------------------------------------
    -- Sequential Proccess
    --------------------------------------------------------------------------
    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.CamValid_0        <= '0';
                r.CamValid_1        <= '0';
                r.CamValid_2        <= '0';
                r.CamValid_3        <= '0';
                r.ConfigFsm         <= Idle_s;
                r.ConfigIn_Ready    <= '0';
                r.ConfigAddr        <= (others => '0');
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Instantiations
    --------------------------------------------------------------------------    
    b_ram : block
        signal RdData : std_logic_vector(ContentWidth_g downto 0);
    begin
        i_normal_ram : entity work.olo_base_ram_sp
            generic map (
                Depth_g         => Addresses_g,
                Width_g         => ContentWidth_g+1,
                RamStyle_g      => "auto",
                RamBehavior_g   => RamBehavior_g
            )
            port map (   
                Clk         => Clk,
                Addr        => r.ConfigAddr,
                WrEna       => r.ConfigRamWr,
                WrData      => r.ConfigRamWrData,
                RdData      => RdData
            );  
            
        RamRdContent <= RdData(ContentWidth_g-1 downto 0);
        RamRdOccupied <= RdData(ContentWidth_g);
    end block;

    g_addr : for i in 0 to BlocksParallel_c-1 generate
        signal RdAddr_0 : std_logic_vector(BlockAddrBits_c-1 downto 0);
        signal WrAddr   : std_logic_vector(BlockAddrBits_c-1 downto 0);
    begin
        -- Input assembly
        RdAddr_0 <= to01(r.ContentExtended_0((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));
        WrAddr <= to01(r.ConfigContent((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));

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
                Wr_Addr     => WrAddr,
                Wr_Ena      => WrMem,  
                Wr_Data     => WriteOneHot(i),
                Rd_Addr     => RdAddr_0,
                Rd_Data     => AddrOneHot_1(i)
            );   
    end generate;

    
  

end architecture;

