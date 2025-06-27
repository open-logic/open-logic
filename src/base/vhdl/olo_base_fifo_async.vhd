---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic asynchronous FIFO. The clocks can be fully asynchronous
-- (unrelated). It  has optional level- and almost-full/empty ports.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_fifo_async.md
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
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_fifo_async is
    generic (
        Width_g         : positive;
        Depth_g         : positive; -- must be power of two
        AlmFullOn_g     : boolean               := false;
        AlmFullLevel_g  : natural               := 0;
        AlmEmptyOn_g    : boolean               := false;
        AlmEmptyLevel_g : natural               := 0;
        RamStyle_g      : string                := "auto";
        RamBehavior_g   : string                := "RBW";
        ReadyRstState_g : std_logic             := '1';
        Optimization_g  : string                := "SPEED"; -- SPEED or LATENCY
        SyncStages_g    : positive range 2 to 4 := 2
    );
    port (
        -- Input interface
        In_Clk          : in    std_logic;
        In_Rst          : in    std_logic;
        In_RstOut       : out   std_logic;
        In_Data         : in    std_logic_vector(Width_g-1 downto 0);
        In_Valid        : in    std_logic := '1';
        In_Ready        : out   std_logic;
        -- Input Status
        In_Full         : out   std_logic;
        In_Empty        : out   std_logic;
        In_AlmFull      : out   std_logic;
        In_AlmEmpty     : out   std_logic;
        In_Level        : out   std_logic_vector(log2ceil(Depth_g+1)-1 downto 0);
        -- Output Interface
        Out_Clk         : in    std_logic;
        Out_Rst         : in    std_logic;
        Out_RstOut      : out   std_logic;
        Out_Data        : out   std_logic_vector(Width_g-1 downto 0);
        Out_Valid       : out   std_logic;
        Out_Ready       : in    std_logic := '1';
        -- Output Status
        Out_Full        : out   std_logic;
        Out_Empty       : out   std_logic;
        Out_AlmFull     : out   std_logic;
        Out_AlmEmpty    : out   std_logic;
        Out_Level       : out   std_logic_vector(log2ceil(Depth_g+1)-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_fifo_async is

    constant AddrWidth_c    : positive := log2ceil(Depth_g)+1;
    constant RamAddrWidth_c : positive := log2ceil(Depth_g);

    type TwoProcessIn_r is record
        WrAddr     : unsigned(AddrWidth_c-1 downto 0); -- One additional bit for full/empty detection
        WrAddrGray : std_logic_vector(AddrWidth_c-1 downto 0);
        RdAddr     : unsigned(AddrWidth_c-1 downto 0);
        WrAddrReg  : unsigned(AddrWidth_c-1 downto 0);
        RamWr      : std_logic;
        DataReg    : std_logic_vector(Width_g-1 downto 0);
    end record;

    type TwoProcessOut_r is record
        RdAddr     : unsigned(AddrWidth_c-1 downto 0); -- One additional bit for full/empty detection
        RdAddrGray : std_logic_vector(AddrWidth_c-1 downto 0);
        WrAddr     : unsigned(AddrWidth_c-1 downto 0);
        OutLevel   : unsigned(AddrWidth_c-1 downto 0);
    end record;

    signal ri, ri_next : TwoProcessIn_r := (WrAddr          => (others => '0'),
                                             WrAddrGray     => (others => '0'),
                                             RdAddr         => (others => '0'),
                                             WrAddrReg      => (others => '0'),
                                             RamWr          => '0',
                                            DataReg         => (others => '0'));

    signal ro, ro_next : TwoProcessOut_r := (RdAddr          => (others => '0'),
                                              RdAddrGray     => (others => '0'),
                                              WrAddr         => (others => '0'),
                                              OutLevel       => (others => '0'));

    signal RstInInt     : std_logic;
    signal RstOutInt    : std_logic;
    signal RamRdAddr    : std_logic_vector(RamAddrWidth_c-1 downto 0);
    signal RamWrAddr    : std_logic_vector(RamAddrWidth_c-1 downto 0);
    signal RamWr        : std_logic;
    signal RamWrData    : std_logic_vector(Width_g-1 downto 0);
    signal WrAddrGray   : std_logic_vector(AddrWidth_c-1 downto 0);
    signal RdAddrGray   : std_logic_vector(AddrWidth_c-1 downto 0);
    signal WrAddrGrayIn : std_logic_vector(AddrWidth_c-1 downto 0);
    signal RdAddrGrayIn : std_logic_vector(AddrWidth_c-1 downto 0);

begin

    assert log2(Depth_g) = log2ceil(Depth_g)
        report "###ERROR###: olo_base_fifo_async: only power of two Depth_g is allowed"
        severity error;

    p_comb : process (all) is
        variable vi        : TwoProcessIn_r;
        variable vo        : TwoProcessOut_r;
        variable InLevel_v : unsigned(log2ceil(Depth_g) downto 0);
    begin
        -- *** hold variables stable ***
        vi := ri;
        vo := ro;

        -- *** Write Side ***
        -- Defaults
        In_Ready    <= '0';
        In_Full     <= '0';
        In_Empty    <= '0';
        In_AlmFull  <= '0';
        In_AlmEmpty <= '0';
        vi.RamWr    := '0';

        -- Level Detection
        InLevel_v := ri.WrAddr - ri.RdAddr;
        In_Level  <= std_logic_vector(InLevel_v);

        -- Full
        -- if InLevel_v = Depth_g then --> Below if-condition implements this in a more timing optimal way
        -- .. by avoiding relying on the carry chain for InLevel_v. Equivalence is given becasue FIFO
        -- .. depth is power of two.
        if (ri.WrAddr(ri.WrAddr'left) /= ri.RdAddr(ri.RdAddr'left)) and
           (ri.WrAddr(ri.WrAddr'left-1 downto 0) = ri.RdAddr(ri.RdAddr'left-1 downto 0)) then
            In_Full <= '1';
        else
            In_Ready <= '1';
            -- Execute Write
            if In_Valid = '1' then
                vi.WrAddr := ri.WrAddr + 1;
                vi.RamWr  := '1';
            end if;
        end if;
        -- Artificially keep InRdy low during reset if required
        if (ReadyRstState_g = '0') and (RstInInt = '1') then
            In_Ready <= '0';
        end if;

        -- Status Detection
        if InLevel_v = 0 then
            In_Empty <= '1';
        end if;
        if InLevel_v >= AlmFullLevel_g and AlmFullOn_g then
            In_AlmFull <= '1';
        end if;
        if InLevel_v <= AlmEmptyLevel_g and AlmEmptyOn_g then
            In_AlmEmpty <= '1';
        end if;

        -- Pipeline registers for speed optimization
        vi.WrAddrReg := ri.WrAddr;
        vi.DataReg   := In_Data;

        -- *** Read Side ***
        -- Defaults
        Out_Valid    <= '0';
        Out_Full     <= '0';
        Out_Empty    <= '0';
        Out_AlmFull  <= '0';
        Out_AlmEmpty <= '0';

        -- Level Detection
        if ro.WrAddr = ro.RdAddr then
            vo.OutLevel := (others => '0');
        else
            vo.OutLevel := ro.WrAddr - ro.RdAddr;
            if (Out_Ready = '1') and (ro.OutLevel /= 0) then
                vo.OutLevel := vo.OutLevel - 1;
            end if;
        end if;
        Out_Level <= std_logic_vector(ro.OutLevel);

        -- Empty
        if ro.OutLevel = 0 then
            Out_Empty <= '1';
        else
            Out_Valid <= '1';
            -- Execute read
            if Out_Ready = '1' then
                vo.RdAddr := ro.RdAddr + 1;
            end if;
        end if;
        RamRdAddr <= std_logic_vector(vo.RdAddr(log2ceil(Depth_g) - 1 downto 0));

        -- Status Detection
        if ro.OutLevel = Depth_g then
            Out_Full <= '1';
        end if;
        if ro.OutLevel >= AlmFullLevel_g and AlmFullOn_g then
            Out_AlmFull <= '1';
        end if;
        if ro.OutLevel <= AlmEmptyLevel_g and AlmEmptyOn_g then
            Out_AlmEmpty <= '1';
        end if;

        -- *** Address Clock domain crossings ***
        -- Bin->Gray is simple, can be done without additional FF
        vi.WrAddrGray := binaryToGray(std_logic_vector(vi.WrAddr));
        vo.RdAddrGray := binaryToGray(std_logic_vector(vo.RdAddr));

        -- Gray->Bin involves some logic, needs additional FF
        vi.RdAddr := unsigned(grayToBinary(RdAddrGray));
        vo.WrAddr := unsigned(grayToBinary(WrAddrGray));

        -- *** Assign signal ***
        ri_next <= vi;
        ro_next <= vo;

    end process;

    p_seq_in : process (In_Clk) is
    begin
        if rising_edge(In_Clk) then
            ri <= ri_next;
            if RstInInt = '1' then
                ri.WrAddr     <= (others => '0');
                ri.WrAddrGray <= (others => '0');
                ri.RdAddr     <= (others => '0');
                ri.RamWr      <= '0';
            end if;
        end if;
    end process;

    p_seq_out : process (Out_Clk) is
    begin
        if rising_edge(Out_Clk) then
            ro <= ro_next;
            if RstOutInt = '1' then
                ro.RdAddr     <= (others => '0');
                ro.RdAddrGray <= (others => '0');
                ro.WrAddr     <= (others => '0');
                ro.OutLevel   <= (others => '0');
            end if;
        end if;
    end process;

    -- Optional pipeline stage for speed optimization
    RamWrAddr <= std_logic_vector(ri.WrAddr(log2ceil(Depth_g) - 1 downto 0)) when Optimization_g = "LATENCY" else
                 std_logic_vector(ri.WrAddrReg(log2ceil(Depth_g) - 1 downto 0));
    RamWr     <= ri_next.RamWr when Optimization_g = "LATENCY" else ri.RamWr;
    RamWrData <= In_Data when Optimization_g = "LATENCY" else ri.DataReg;

    i_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g         => Depth_g,
            Width_g         => Width_g,
            RamStyle_g      => RamStyle_g,
            IsAsync_g       => true,
            RamBehavior_g   => RamBehavior_g
        )
        port map (
            Clk         => In_Clk,
            Wr_Addr     => RamWrAddr,
            Wr_Ena      => RamWr,
            Wr_Data     => RamWrData,
            Rd_Clk      => Out_Clk,
            Rd_Addr     => RamRdAddr,
            Rd_Data     => Out_Data
        );

    -- Wr -> Rd Sync
    WrAddrGrayIn <= ri_next.WrAddrGray when Optimization_g = "LATENCY" else ri.WrAddrGray; -- optional register stage

    i_cc_wr_rd : entity work.olo_base_cc_bits
        generic map (
            Width_g      => AddrWidth_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            In_Clk   => In_Clk,
            In_Rst   => RstInInt,
            In_Data  => WrAddrGrayIn,
            Out_Clk  => Out_Clk,
            Out_Rst  => RstOutInt,
            Out_Data => WrAddrGray
        );

    -- Rd -> Wr Sync
    RdAddrGrayIn <= ro_next.RdAddrGray when Optimization_g = "LATENCY" else ro.RdAddrGray; -- optional register stage

    i_cc_rd_wr : entity work.olo_base_cc_bits
        generic map (
            Width_g      => AddrWidth_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            In_Clk   => Out_Clk,
            In_Rst   => RstOutInt,
            In_Data  => RdAddrGrayIn, -- use unregistered signal because CC contains register
            Out_Clk  => In_Clk,
            Out_Rst  => RstInInt,
            Out_Data => RdAddrGray
        );

    -- Reset CC
    i_rst_cc : entity work.olo_base_cc_reset
        port map (
            A_Clk       => In_Clk,
            A_RstIn     => In_Rst,
            A_RstOut    => RstInInt,
            B_Clk       => Out_Clk,
            B_RstIn     => Out_Rst,
            B_RstOut    => RstOutInt
        );

    Out_RstOut <= RstOutInt;
    In_RstOut  <= RstInInt;

end architecture;
