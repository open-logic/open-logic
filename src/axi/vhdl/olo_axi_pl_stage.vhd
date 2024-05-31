------------------------------------------------------------------------------
-- Copyright (c) 2019 by Enclustra GmbH, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Eduardo del Castillo, Oliver Bründler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This entity implements multiple pipeline stages for an axi4 interface.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_axi_pl_stage is
    generic (
        AddrWidth_g : positive  := 32;
        DataWidth_g : positive  := 32;
        IdWidth_g   : natural   := 0;
        UserWidth_g : natural   := 0;
        Stages_g    : positive  := 1
    );
    port (
        -- Control Signals
        Clk       : in  std_logic;
        Rst       : in  std_logic;

        -- Slave Interface
        -- write address channel
        S_AwId     : in  std_logic_vector(IdWidth_g - 1 downto 0)       := (others => '0');    
        S_AwAddr   : in  std_logic_vector(AddrWidth_g - 1 downto 0);
        S_AwValid  : in  std_logic;
        S_AwReady  : out std_logic;
        S_AwLen    : in  std_logic_vector(7 downto 0)                   := (others => '0');
        S_AwSize   : in  std_logic_vector(2 downto 0)                   := (others => '0');
        S_AwBurst  : in  std_logic_vector(1 downto 0)                   := (others => '0');
        S_AwLock   : in  std_logic                                      := '0';
        S_AwCache  : in  std_logic_vector(3 downto 0)                   := (others => '0');
        S_AwProt   : in  std_logic_vector(2 downto 0)                   := (others => '0');
        S_AwQos    : in  std_logic_vector(3 downto 0)                   := (others => '0');
        S_AwUser   : in  std_logic_vector(UserWidth_g - 1 downto 0)     := (others => '0');
        S_AwRegion : in  std_logic_vector(3 downto 0)                   := (others => '0');
        -- write data channel
        S_WData    : in  std_logic_vector(DataWidth_g - 1 downto 0);
        S_WStrb    : in  std_logic_vector(DataWidth_g / 8 - 1 downto 0);
        S_WValid   : in  std_logic;
        S_WReady   : out std_logic;
        S_WLast    : in  std_logic                                      := '1';
        S_WUser    : in  std_logic_vector(UserWidth_g - 1 downto 0)     := (others => '0');
        -- write response channel
        S_BId      : out  std_logic_vector(IdWidth_g - 1 downto 0);
        S_BResp    : out std_logic_vector(1 downto 0);
        S_BValid   : out std_logic;
        S_BReady   : in  std_logic;
        S_BUser    : out std_logic_vector(UserWidth_g - 1 downto 0);
        -- read address channel
        S_ArId     : in  std_logic_vector(IdWidth_g - 1 downto 0)       := (others => '0');
        S_ArAddr   : in  std_logic_vector(AddrWidth_g - 1 downto 0);
        S_ArValid  : in  std_logic;
        S_ArReady  : out std_logic;
        S_ArLen    : in  std_logic_vector(7 downto 0)                   := (others => '0');
        S_ArSize   : in  std_logic_vector(2 downto 0)                   := (others => '0');
        S_ArBurst  : in  std_logic_vector(1 downto 0)                   := (others => '0');
        S_ArLock   : in  std_logic;
        S_ArCache  : in  std_logic_vector(3 downto 0)                   := (others => '0');
        S_ArProt   : in  std_logic_vector(2 downto 0)                   := (others => '0');
        S_ArQos    : in  std_logic_vector(3 downto 0)                   := (others => '0');
        S_ArUser   : in  std_logic_vector(UserWidth_g - 1 downto 0)     := (others => '0');
        S_ArRegion : in  std_logic_vector(3 downto 0)                   := (others => '0');
        -- read data channel
        S_RId      : out std_logic_vector(IdWidth_g - 1 downto 0);
        S_RData    : out std_logic_vector(DataWidth_g - 1 downto 0);
        S_RValid   : out std_logic;
        S_RReady   : in  std_logic;
        S_RResp    : out std_logic_vector(1 downto 0);
        S_RLast    : out std_logic;
        S_RUser    : out std_logic_vector(UserWidth_g - 1 downto 0);

        -- output interface
        -- write address channel
        M_AwId     : out std_logic_vector(IdWidth_g - 1 downto 0);
        M_AwAddr   : out std_logic_vector(AddrWidth_g - 1 downto 0);
        M_AwValid  : out std_logic;
        M_AwReady  : in  std_logic;
        M_AwLen    : out std_logic_vector(7 downto 0);
        M_AwSize   : out std_logic_vector(2 downto 0);
        M_AwBurst  : out std_logic_vector(1 downto 0);
        M_AwLock   : out std_logic;
        M_AwCache  : out std_logic_vector(3 downto 0);
        M_AwProt   : out std_logic_vector(2 downto 0);
        M_AwQos    : out std_logic_vector(3 downto 0);
        M_AwUser   : out std_logic_vector(UserWidth_g - 1 downto 0);
        M_AwRegion : out std_logic_vector(3 downto 0);
        -- write data channel
        M_WData    : out std_logic_vector(DataWidth_g - 1 downto 0);
        M_WStrb    : out std_logic_vector(DataWidth_g / 8 - 1 downto 0);
        M_WValid   : out std_logic;
        M_WReady   : in  std_logic;
        M_WLast    : out std_logic;
        M_WUser    : out std_logic_vector(UserWidth_g - 1 downto 0);
        -- write response channel
        M_BId      : in  std_logic_vector(IdWidth_g - 1 downto 0)       := (others => '0');
        M_BResp    : in  std_logic_vector(1 downto 0);
        M_BValid   : in  std_logic;
        M_BReady   : out std_logic;
        M_BUser    : in  std_logic_vector(UserWidth_g - 1 downto 0)     := (others => '0');
        -- read address channel
        M_ArId     : out std_logic_vector(IdWidth_g - 1 downto 0);
        M_ArAddr   : out std_logic_vector(AddrWidth_g - 1 downto 0);
        M_ArValid  : out std_logic;
        M_ArReady  : in  std_logic;
        M_ArLen    : out std_logic_vector(7 downto 0);
        M_ArSize   : out std_logic_vector(2 downto 0);
        M_ArBurst  : out std_logic_vector(1 downto 0);
        M_ArLock   : out std_logic;
        M_ArCache  : out std_logic_vector(3 downto 0);
        M_ArProt   : out std_logic_vector(2 downto 0);
        M_ArQos    : out std_logic_vector(3 downto 0);
        M_ArUser   : out std_logic_vector(UserWidth_g - 1 downto 0);
        M_ArRegion : out std_logic_vector(3 downto 0);
        -- read data channel
        M_RId      : in  std_logic_vector(IdWidth_g - 1 downto 0)       := (others => '0');
        M_RData    : in  std_logic_vector(DataWidth_g - 1 downto 0);
        M_RValid   : in  std_logic;
        M_RReady   : out std_logic;
        M_RResp    : in  std_logic_vector(1 downto 0);
        M_RLast    : in  std_logic                                      := '1';
        M_RUser    : in  std_logic_vector(UserWidth_g - 1 downto 0)     := (others => '0')
    );
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_axi_pl_stage is

    -- AXI constants
    constant LenWidth_c   : positive := 8;
    constant SizeWidth_c  : positive := 3;
    constant BurstWidth_c : positive := 2;
    constant CacheWidth_c : positive := 4;
    constant ProtWidth_c  : positive := 3;
    constant RespWidth_c  : positive := 2;

begin

    -- write address channel
    b_aw : block
        subtype AwProt_r is natural range S_AwProt'length-1 downto 0;
        subtype AwCache_r is natural range S_AwCache'length+AwProt_r'high downto AwProt_r'high+1;
        constant AwLock_r : natural := AwCache_r'high+1;
        subtype AwBurst_r is natural range S_AwBurst'length+AwLock_r downto AwLock_r+1;
        subtype AwSize_r is natural range S_AwSize'length+AwBurst_r'high downto AwBurst_r'high+1;
        subtype AwLen_r is natural range S_AwLen'length+AwSize_r'high downto AwSize_r'high+1;
        subtype AwAddr_r is natural range S_AwAddr'length+AwLen_r'high downto AwLen_r'high+1;
        subtype AwId_r is natural range S_AwId'length+AwAddr_r'high downto AwAddr_r'high+1;
        subtype AwQos_r is natural range S_AwQos'length+AwId_r'high downto AwId_r'high+1;
        subtype AwUser_r is natural range S_AwUser'length+AwQos_r'high downto AwQos_r'high+1;
        subtype AwRegion_r is natural range S_AwRegion'length+AwUser_r'high downto AwUser_r'high+1;

        signal AwDataIn, AwDataOut : std_logic_vector(AwRegion_r'high downto 0);

    begin
        -- map signals into one vector
        AwDataIn(AwProt_r) <= S_AwProt;
        AwDataIn(AwCache_r) <= S_AwCache;
        AwDataIn(AwLock_r) <= S_AwLock;
        AwDataIn(AwBurst_r) <= S_AwBurst;
        AwDataIn(AwSize_r) <= S_AwSize;
        AwDataIn(AwLen_r) <= S_AwLen;
        AwDataIn(AwAddr_r) <= S_AwAddr;
        AwDataIn(AwId_r) <= S_AwId;
        AwDataIn(AwQos_r) <= S_AwQos;
        AwDataIn(AwUser_r) <= S_AwUser;
        AwDataIn(AwRegion_r) <= S_AwRegion;

        -- Pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => AwDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map(
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => S_AwValid,
                In_Ready   => S_AwReady,
                In_Data    => AwDataIn,
                Out_Valid  => M_AwValid,
                Out_Ready  => M_AwReady,
                Out_Data   => AwDataOut
            );

        -- unmap signals from vector
        M_AwProt  <= AwDataOut(AwProt_r);
        M_AwCache <= AwDataOut(AwCache_r);
        M_AwLock  <= AwDataOut(AwLock_r);
        M_AwBurst <= AwDataOut(AwBurst_r);
        M_AwSize  <= AwDataOut(AwSize_r);
        M_AwLen   <= AwDataOut(AwLen_r);
        M_AwAddr  <= AwDataOut(AwAddr_r);
        M_AwId    <= AwDataOut(AwId_r);  
        M_AwQos   <= AwDataOut(AwQos_r);
        M_AwUser  <= AwDataOut(AwUser_r);
        M_AwRegion <= AwDataOut(AwRegion_r);
    end block;



    -- write data channel
    b_w : block
        subtype WData_r is natural range S_WData'length-1 downto 0;
        subtype WStrb_r is natural range S_WStrb'length+WData_r'high downto WData_r'high+1;
        constant WLast_r : natural := WStrb_r'high+1;
        subtype WUser_r is natural range S_WUser'length+WLast_r downto WLast_r+1;

        signal WDataIn, WDataOut : std_logic_vector(WUser_r'high downto 0);
    begin

        -- map signals into one vector
        WDataIn(WData_r) <= S_WData;
        WDataIn(WStrb_r) <= S_WStrb;
        WDataIn(WLast_r) <= S_WLast;
        WDataIn(WUser_r) <= S_WUser;
        
        -- pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => WDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map(
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => S_WValid,
                In_Ready   => S_WReady,
                In_Data    => WDataIn,
                Out_Valid  => M_WValid,
                Out_Ready  => M_WReady,
                Out_Data   => WDataOut
            );

        -- unmap signals from vector
        M_WLast <= WDataOut(WLast_r);
        M_WStrb <= WDataOut(WStrb_r);
        M_WData <= WDataOut(WData_r);
        M_WUser <= WDataOut(WUser_r);
    end block;

    -- write response channel
    b_b : block
        subtype BResp_r is natural range S_BResp'length-1 downto 0;
        subtype BId_r is natural range S_BId'length+BResp_r'high downto BResp_r'high+1;
        subtype BUser_r is natural range S_BUser'length+BId_r'high downto BId_r'high+1;

        signal BDataIn, BDataOut : std_logic_vector(BUser_r'high downto 0);
    begin
        -- map signals into one vector
        BDataIn(BId_r) <= M_BId;
        BDataIn(BResp_r) <= M_BResp;
        BDataIn(BUser_r) <= M_BUser;

        -- pipeline stage
        i_bch_pl : entity work.olo_base_pl_stage
            generic map(
                Width_g    => BDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map(
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => M_BValid,
                In_Ready   => M_BReady,
                In_Data    => BDataIn,
                Out_Valid  => S_BValid,
                Out_Ready  => S_BReady,
                Out_Data   => BDataOut
            );

        -- unmap signals from vector
        S_BId   <= BDataOut(BId_r);
        S_BResp <= BDataOut(BResp_r);
        S_BUser <= BDataOut(BUser_r);
    end block;

    -- read address channel
    b_ar : block
        subtype ArProt_r is natural range S_ArProt'length-1 downto 0;
        subtype ArCache_r is natural range S_ArCache'length+ArProt_r'high downto ArProt_r'high+1;
        constant ArLock_r : natural := ArCache_r'high+1;
        subtype ArBurst_r is natural range S_ArBurst'length+ArLock_r downto ArLock_r+1;
        subtype ArSize_r is natural range S_ArSize'length+ArBurst_r'high downto ArBurst_r'high+1;
        subtype ArLen_r is natural range S_ArLen'length+ArSize_r'high downto ArSize_r'high+1;
        subtype ArAddr_r is natural range S_ArAddr'length+ArLen_r'high downto ArLen_r'high+1;
        subtype ArId_r is natural range S_ArId'length+ArAddr_r'high downto ArAddr_r'high+1;
        subtype ArQos_r is natural range S_ArQos'length+ArId_r'high downto ArId_r'high+1;
        subtype ArUser_r is natural range S_ArUser'length+ArQos_r'high downto ArQos_r'high+1;
        subtype ArRegion_r is natural range S_ArRegion'length+ArUser_r'high downto ArUser_r'high+1;

        signal ArDataIn, ArDataOut : std_logic_vector(ArRegion_r'high downto 0);
    begin

        -- map signals into one vector
        ArDataIn(ArProt_r) <= S_ArProt;
        ArDataIn(ArCache_r) <= S_ArCache;
        ArDataIn(ArLock_r) <= S_ArLock;
        ArDataIn(ArBurst_r) <= S_ArBurst;
        ArDataIn(ArSize_r) <= S_ArSize;
        ArDataIn(ArLen_r) <= S_ArLen;
        ArDataIn(ArAddr_r) <= S_ArAddr;
        ArDataIn(ArId_r) <= S_ArId;
        ArDataIn(ArQos_r) <= S_ArQos;
        ArDataIn(ArUser_r) <= S_ArUser;
        ArDataIn(ArRegion_r) <= S_ArRegion;
        
        -- pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map(
                Width_g    => ArDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map(
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => S_ArValid,
                In_Ready   => S_ArReady,
                In_Data    => ArDataIn,
                Out_Valid  => M_ArValid,
                Out_Ready  => M_ArReady,
                Out_Data   => ArDataOut
            );

        -- unmap signals from vector
        M_ArProt  <= ArDataOut(ArProt_r);
        M_ArCache <= ArDataOut(ArCache_r);
        M_ArLock  <= ArDataOut(ArLock_r);
        M_ArBurst <= ArDataOut(ArBurst_r);
        M_ArSize  <= ArDataOut(ArSize_r);
        M_ArLen   <= ArDataOut(ArLen_r);
        M_ArAddr  <= ArDataOut(ArAddr_r);
        M_ArId    <= ArDataOut(ArId_r);
        M_ArQos   <= ArDataOut(ArQos_r);
        M_ArUser  <= ArDataOut(ArUser_r);
        M_ArRegion <= ArDataOut(ArRegion_r);
    end block;


    -- read data channel
    b_r : block
        subtype RData_r is natural range S_RData'length-1 downto 0;
        constant RLast_r : natural := RData_r'high+1;
        subtype RResp_r is natural range S_RResp'length+RLast_r downto RLast_r+1;
        subtype RId_r is natural range S_RId'length+RResp_r'high downto RResp_r'high+1;
        subtype RUser_r is natural range S_RUser'length+RId_r'high downto RId_r'high+1;

        signal RDataIn, RDataOut : std_logic_vector(RUser_r'high downto 0);
    begin
        -- map signals into one vector        
        RDataIn(RData_r) <= M_RData;
        RDataIn(RResp_r) <= M_RResp;
        RDataIn(RLast_r) <= M_RLast;
        RDataIn(RId_r) <= M_RId;
        RDataIn(RUser_r) <= M_RUser;

        -- pipeline stage
        i_rch_pl : entity work.olo_base_pl_stage
            generic map(
                Width_g    => RDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map(
                Clk        => Clk,
                Rst        => Rst,
                In_Valid   => M_RValid,
                In_Ready   => M_RReady,
                In_Data    => RDataIn,
                Out_Valid  => S_RValid,
                Out_Ready  => S_RReady,
                Out_Data   => RDataOut
            );

        -- unmap signals from vector
        S_RData <= RDataOut(RData_r);
        S_RResp <= RDataOut(RResp_r);
        S_RLast <= RDataOut(RLast_r);
        S_RId   <= RDataOut(RId_r);
        S_RUser <= RDataOut(RUser_r);
    end block;

end architecture;
