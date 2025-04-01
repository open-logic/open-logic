---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Enclustra GmbH, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Eduardo del Castillo, Oliver Bründler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements multiple pipeline stages for an axi4 interface.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/axi/olo_axi_pl_stage.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_axi_pl_stage is
    generic (
        AddrWidth_g : positive := 32;
        DataWidth_g : positive := 32;
        IdWidth_g   : natural  := 0;
        UserWidth_g : natural  := 0;
        Stages_g    : positive := 1
    );
    port (
        -- Control Signals
        Clk        : in    std_logic;
        Rst        : in    std_logic;

        -- Slave Interface
        -- write address channel
        S_AwId     : in    std_logic_vector(IdWidth_g - 1 downto 0)   := (others => '0');
        S_AwAddr   : in    std_logic_vector(AddrWidth_g - 1 downto 0);
        S_AwValid  : in    std_logic;
        S_AwReady  : out   std_logic;
        S_AwLen    : in    std_logic_vector(7 downto 0)               := (others => '0');
        S_AwSize   : in    std_logic_vector(2 downto 0)               := (others => '0');
        S_AwBurst  : in    std_logic_vector(1 downto 0)               := (others => '0');
        S_AwLock   : in    std_logic                                  := '0';
        S_AwCache  : in    std_logic_vector(3 downto 0)               := (others => '0');
        S_AwProt   : in    std_logic_vector(2 downto 0)               := (others => '0');
        S_AwQos    : in    std_logic_vector(3 downto 0)               := (others => '0');
        S_AwUser   : in    std_logic_vector(UserWidth_g - 1 downto 0) := (others => '0');
        S_AwRegion : in    std_logic_vector(3 downto 0)               := (others => '0');
        -- write data channel
        S_WData    : in    std_logic_vector(DataWidth_g - 1 downto 0);
        S_WStrb    : in    std_logic_vector(DataWidth_g / 8 - 1 downto 0);
        S_WValid   : in    std_logic;
        S_WReady   : out   std_logic;
        S_WLast    : in    std_logic                                  := '1';
        S_WUser    : in    std_logic_vector(UserWidth_g - 1 downto 0) := (others => '0');
        -- write response channel
        S_BId      : out   std_logic_vector(IdWidth_g - 1 downto 0);
        S_BResp    : out   std_logic_vector(1 downto 0);
        S_BValid   : out   std_logic;
        S_BReady   : in    std_logic;
        S_BUser    : out   std_logic_vector(UserWidth_g - 1 downto 0);
        -- read address channel
        S_ArId     : in    std_logic_vector(IdWidth_g - 1 downto 0)   := (others => '0');
        S_ArAddr   : in    std_logic_vector(AddrWidth_g - 1 downto 0);
        S_ArValid  : in    std_logic;
        S_ArReady  : out   std_logic;
        S_ArLen    : in    std_logic_vector(7 downto 0)               := (others => '0');
        S_ArSize   : in    std_logic_vector(2 downto 0)               := (others => '0');
        S_ArBurst  : in    std_logic_vector(1 downto 0)               := (others => '0');
        S_ArLock   : in    std_logic;
        S_ArCache  : in    std_logic_vector(3 downto 0)               := (others => '0');
        S_ArProt   : in    std_logic_vector(2 downto 0)               := (others => '0');
        S_ArQos    : in    std_logic_vector(3 downto 0)               := (others => '0');
        S_ArUser   : in    std_logic_vector(UserWidth_g - 1 downto 0) := (others => '0');
        S_ArRegion : in    std_logic_vector(3 downto 0)               := (others => '0');
        -- read data channel
        S_RId      : out   std_logic_vector(IdWidth_g - 1 downto 0);
        S_RData    : out   std_logic_vector(DataWidth_g - 1 downto 0);
        S_RValid   : out   std_logic;
        S_RReady   : in    std_logic;
        S_RResp    : out   std_logic_vector(1 downto 0);
        S_RLast    : out   std_logic;
        S_RUser    : out   std_logic_vector(UserWidth_g - 1 downto 0);

        -- output interface
        -- write address channel
        M_AwId     : out   std_logic_vector(IdWidth_g - 1 downto 0);
        M_AwAddr   : out   std_logic_vector(AddrWidth_g - 1 downto 0);
        M_AwValid  : out   std_logic;
        M_AwReady  : in    std_logic;
        M_AwLen    : out   std_logic_vector(7 downto 0);
        M_AwSize   : out   std_logic_vector(2 downto 0);
        M_AwBurst  : out   std_logic_vector(1 downto 0);
        M_AwLock   : out   std_logic;
        M_AwCache  : out   std_logic_vector(3 downto 0);
        M_AwProt   : out   std_logic_vector(2 downto 0);
        M_AwQos    : out   std_logic_vector(3 downto 0);
        M_AwUser   : out   std_logic_vector(UserWidth_g - 1 downto 0);
        M_AwRegion : out   std_logic_vector(3 downto 0);
        -- write data channel
        M_WData    : out   std_logic_vector(DataWidth_g - 1 downto 0);
        M_WStrb    : out   std_logic_vector(DataWidth_g / 8 - 1 downto 0);
        M_WValid   : out   std_logic;
        M_WReady   : in    std_logic;
        M_WLast    : out   std_logic;
        M_WUser    : out   std_logic_vector(UserWidth_g - 1 downto 0);
        -- write response channel
        M_BId      : in    std_logic_vector(IdWidth_g - 1 downto 0)   := (others => '0');
        M_BResp    : in    std_logic_vector(1 downto 0);
        M_BValid   : in    std_logic;
        M_BReady   : out   std_logic;
        M_BUser    : in    std_logic_vector(UserWidth_g - 1 downto 0) := (others => '0');
        -- read address channel
        M_ArId     : out   std_logic_vector(IdWidth_g - 1 downto 0);
        M_ArAddr   : out   std_logic_vector(AddrWidth_g - 1 downto 0);
        M_ArValid  : out   std_logic;
        M_ArReady  : in    std_logic;
        M_ArLen    : out   std_logic_vector(7 downto 0);
        M_ArSize   : out   std_logic_vector(2 downto 0);
        M_ArBurst  : out   std_logic_vector(1 downto 0);
        M_ArLock   : out   std_logic;
        M_ArCache  : out   std_logic_vector(3 downto 0);
        M_ArProt   : out   std_logic_vector(2 downto 0);
        M_ArQos    : out   std_logic_vector(3 downto 0);
        M_ArUser   : out   std_logic_vector(UserWidth_g - 1 downto 0);
        M_ArRegion : out   std_logic_vector(3 downto 0);
        -- read data channel
        M_RId      : in    std_logic_vector(IdWidth_g - 1 downto 0)   := (others => '0');
        M_RData    : in    std_logic_vector(DataWidth_g - 1 downto 0);
        M_RValid   : in    std_logic;
        M_RReady   : out   std_logic;
        M_RResp    : in    std_logic_vector(1 downto 0);
        M_RLast    : in    std_logic                                  := '1';
        M_RUser    : in    std_logic_vector(UserWidth_g - 1 downto 0) := (others => '0')
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_axi_pl_stage is

begin

    -- write address channel
    b_aw : block is
        subtype  AwProtRng_c   is natural range S_AwProt'length-1                   downto 0;
        subtype  AwCacheRng_c  is natural range S_AwCache'length+AwProtRng_c'high   downto AwProtRng_c'high+1;
        constant AwLockIdx_C : natural := AwCacheRng_c'high+1;
        subtype  AwBurstRng_c  is natural range S_AwBurst'length+AwLockIdx_C          downto AwLockIdx_C+1;
        subtype  AwSizeRng_c   is natural range S_AwSize'length+AwBurstRng_c'high   downto AwBurstRng_c'high+1;
        subtype  AwLenRng_c    is natural range S_AwLen'length+AwSizeRng_c'high     downto AwSizeRng_c'high+1;
        subtype  AwAddrRng_c   is natural range S_AwAddr'length+AwLenRng_c'high     downto AwLenRng_c'high+1;
        subtype  AwIdRng_c     is natural range S_AwId'length+AwAddrRng_c'high      downto AwAddrRng_c'high+1;
        subtype  AwQosRng_c    is natural range S_AwQos'length+AwIdRng_c'high       downto AwIdRng_c'high+1;
        subtype  AwUserRng_c   is natural range S_AwUser'length+AwQosRng_c'high     downto AwQosRng_c'high+1;
        subtype  AwRegionRng_c is natural range S_AwRegion'length+AwUserRng_c'high  downto AwUserRng_c'high+1;

        signal AwDataIn, AwDataOut : std_logic_vector(AwRegionRng_c'high downto 0);
    begin
        -- map signals into one vector
        AwDataIn(AwProtRng_c)   <= S_AwProt;
        AwDataIn(AwCacheRng_c)  <= S_AwCache;
        AwDataIn(AwLockIdx_C)   <= S_AwLock;
        AwDataIn(AwBurstRng_c)  <= S_AwBurst;
        AwDataIn(AwSizeRng_c)   <= S_AwSize;
        AwDataIn(AwLenRng_c)    <= S_AwLen;
        AwDataIn(AwAddrRng_c)   <= S_AwAddr;
        AwDataIn(AwIdRng_c)     <= S_AwId;
        AwDataIn(AwQosRng_c)    <= S_AwQos;
        AwDataIn(AwUserRng_c)   <= S_AwUser;
        AwDataIn(AwRegionRng_c) <= S_AwRegion;

        -- Pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => AwDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map (
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
        M_AwProt   <= AwDataOut(AwProtRng_c);
        M_AwCache  <= AwDataOut(AwCacheRng_c);
        M_AwLock   <= AwDataOut(AwLockIdx_C);
        M_AwBurst  <= AwDataOut(AwBurstRng_c);
        M_AwSize   <= AwDataOut(AwSizeRng_c);
        M_AwLen    <= AwDataOut(AwLenRng_c);
        M_AwAddr   <= AwDataOut(AwAddrRng_c);
        M_AwId     <= AwDataOut(AwIdRng_c);
        M_AwQos    <= AwDataOut(AwQosRng_c);
        M_AwUser   <= AwDataOut(AwUserRng_c);
        M_AwRegion <= AwDataOut(AwRegionRng_c);
    end block;

    -- write data channel
    b_w : block is
        subtype  WDataRng_c is natural range S_WData'length-1              downto 0;
        subtype  WStrbRng_c is natural range S_WStrb'length+WDataRng_c'high  downto WDataRng_c'high+1;
        constant WLastIdx_c : natural := WStrbRng_c'high+1;
        subtype  WUserRng_c is natural range S_WUser'length+WLastIdx_c       downto WLastIdx_c+1;

        signal WDataIn, WDataOut : std_logic_vector(WUserRng_c'high downto 0);
    begin

        -- map signals into one vector
        WDataIn(WDataRng_c) <= S_WData;
        WDataIn(WStrbRng_c) <= S_WStrb;
        WDataIn(WLastIdx_c) <= S_WLast;
        WDataIn(WUserRng_c) <= S_WUser;

        -- pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => WDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map (
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
        M_WLast <= WDataOut(WLastIdx_c);
        M_WStrb <= WDataOut(WStrbRng_c);
        M_WData <= WDataOut(WDataRng_c);
        M_WUser <= WDataOut(WUserRng_c);
    end block;

    -- write response channel
    b_b : block is
        subtype BRespRng_c is natural range S_BResp'length-1           downto 0;
        subtype BIdRng_c   is natural range S_BId'length+BRespRng_c'high downto BRespRng_c'high+1;
        subtype BuserRng_c is natural range S_BUser'length+BIdRng_c'high downto BIdRng_c'high+1;

        signal BDataIn, BDataOut : std_logic_vector(BuserRng_c'high downto 0);
    begin
        -- map signals into one vector
        BDataIn(BIdRng_c)   <= M_BId;
        BDataIn(BRespRng_c) <= M_BResp;
        BDataIn(BuserRng_c) <= M_BUser;

        -- pipeline stage
        i_bch_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => BDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map (
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
        S_BId   <= BDataOut(BIdRng_c);
        S_BResp <= BDataOut(BRespRng_c);
        S_BUser <= BDataOut(BuserRng_c);
    end block;

    -- read address channel
    b_ar : block is
        subtype  ArProtRng_c   is natural range S_ArProt'length-1                 downto 0;
        subtype  ArCacheRng_c  is natural range S_ArCache'length+ArProtRng_c'high   downto ArProtRng_c'high+1;
        constant ArLockIdx_c : natural := ArCacheRng_c'high+1;
        subtype  ArBurstRng_c  is natural range S_ArBurst'length+ArLockIdx_c        downto ArLockIdx_c+1;
        subtype  ArSizeRng_c   is natural range S_ArSize'length+ArBurstRng_c'high   downto ArBurstRng_c'high+1;
        subtype  ArLenRng_c    is natural range S_ArLen'length+ArSizeRng_c'high     downto ArSizeRng_c'high+1;
        subtype  ArAddrRng_c   is natural range S_ArAddr'length+ArLenRng_c'high     downto ArLenRng_c'high+1;
        subtype  ArIdRng_c     is natural range S_ArId'length+ArAddrRng_c'high      downto ArAddrRng_c'high+1;
        subtype  ArQosRng_c    is natural range S_ArQos'length+ArIdRng_c'high       downto ArIdRng_c'high+1;
        subtype  ArUserRng_c   is natural range S_ArUser'length+ArQosRng_c'high     downto ArQosRng_c'high+1;
        subtype  ArRegionRng_c is natural range S_ArRegion'length+ArUserRng_c'high  downto ArUserRng_c'high+1;

        signal ArDataIn, ArDataOut : std_logic_vector(ArRegionRng_c'high downto 0);
    begin

        -- map signals into one vector
        ArDataIn(ArProtRng_c)   <= S_ArProt;
        ArDataIn(ArCacheRng_c)  <= S_ArCache;
        ArDataIn(ArLockIdx_c)   <= S_ArLock;
        ArDataIn(ArBurstRng_c)  <= S_ArBurst;
        ArDataIn(ArSizeRng_c)   <= S_ArSize;
        ArDataIn(ArLenRng_c)    <= S_ArLen;
        ArDataIn(ArAddrRng_c)   <= S_ArAddr;
        ArDataIn(ArIdRng_c)     <= S_ArId;
        ArDataIn(ArQosRng_c)    <= S_ArQos;
        ArDataIn(ArUserRng_c)   <= S_ArUser;
        ArDataIn(ArRegionRng_c) <= S_ArRegion;

        -- pipeline stage
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => ArDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map (
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
        M_ArProt   <= ArDataOut(ArProtRng_c);
        M_ArCache  <= ArDataOut(ArCacheRng_c);
        M_ArLock   <= ArDataOut(ArLockIdx_c);
        M_ArBurst  <= ArDataOut(ArBurstRng_c);
        M_ArSize   <= ArDataOut(ArSizeRng_c);
        M_ArLen    <= ArDataOut(ArLenRng_c);
        M_ArAddr   <= ArDataOut(ArAddrRng_c);
        M_ArId     <= ArDataOut(ArIdRng_c);
        M_ArQos    <= ArDataOut(ArQosRng_c);
        M_ArUser   <= ArDataOut(ArUserRng_c);
        M_ArRegion <= ArDataOut(ArRegionRng_c);
    end block;

    -- read data channel
    b_r : block is
        subtype  RDataRng_c is natural range S_RData'length-1             downto 0;
        constant RLastIdx_c : natural := RDataRng_c'high+1;
        subtype  RRespRng_c is natural range S_RResp'length+RLastIdx_c    downto RLastIdx_c+1;
        subtype  RIdRng_c   is natural range S_RId'length+RRespRng_c'high downto RRespRng_c'high+1;
        subtype  RUserRng_c is natural range S_RUser'length+RIdRng_c'high downto RIdRng_c'high+1;

        signal RDataIn, RDataOut : std_logic_vector(RUserRng_c'high downto 0);
    begin
        -- map signals into one vector
        RDataIn(RDataRng_c) <= M_RData;
        RDataIn(RRespRng_c) <= M_RResp;
        RDataIn(RLastIdx_c) <= M_RLast;
        RDataIn(RIdRng_c)   <= M_RId;
        RDataIn(RUserRng_c) <= M_RUser;

        -- pipeline stage
        i_rch_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g    => RDataIn'length,
                UseReady_g => true,
                Stages_g   => Stages_g
            )
            port map (
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
        S_RData <= RDataOut(RDataRng_c);
        S_RResp <= RDataOut(RRespRng_c);
        S_RLast <= RDataOut(RLastIdx_c);
        S_RId   <= RDataOut(RIdRng_c);
        S_RUser <= RDataOut(RUserRng_c);
    end block;

end architecture;
