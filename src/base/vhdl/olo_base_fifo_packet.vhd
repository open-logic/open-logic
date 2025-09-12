---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
--- This is a synchronous packet FIFO. In contrast to a normal FIFO, it allows
--- dropping and repeating packets as well as detecting how many packets
--- there are in the FIFO.
--- The FIFO works in store-and-forward mode.
--- The FIFO assumes that all packets fit into the FIFO. Cut-through operation
--- as required to handle packets bigger than the FIFO is not iplemented.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_fifo_packet.md
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
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_fifo_packet is
    generic (
        Width_g             : positive;
        Depth_g             : positive;
        FeatureSet_g        : string                            := "FULL";
        RamStyle_g          : string                            := "auto";
        RamBehavior_g       : string                            := "RBW";
        SmallRamStyle_g     : string                            := "auto";
        SmallRamBehavior_g  : string                            := "same";
        MaxPackets_g        : positive range 2 to positive'high := 17
    );
    port (
        -- Control Ports
        Clk           : in    std_logic;
        Rst           : in    std_logic;
        -- Input Data
        In_Valid      : in    std_logic := '1';
        In_Ready      : out   std_logic;
        In_Data       : in    std_logic_vector(Width_g - 1 downto 0);
        In_Last       : in    std_logic := '1';
        In_Drop       : in    std_logic := '0';
        In_IsDropped  : out   std_logic;
        -- Output Data
        Out_Valid     : out   std_logic;
        Out_Ready     : in    std_logic := '1';
        Out_Data      : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Size      : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        Out_Last      : out   std_logic;
        Out_Next      : in    std_logic := '0';
        Out_Repeat    : in    std_logic := '0';
        -- Status
        PacketLevel   : out   std_logic_vector(log2ceil(MaxPackets_g + 1) - 1 downto 0);
        FreeWords     : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_fifo_packet is

    -- Constants
    constant SmallRamStyle_c    : string := choose(toLower(SmallRamStyle_g) = "same", RamStyle_g, SmallRamStyle_g);
    constant SmallRamBehavior_c : string := choose(toLower(SmallRamBehavior_g) = "same", RamBehavior_g, SmallRamBehavior_g);
    constant FeatureSet_c       : string := toLower(FeatureSet_g);

    -- Range definitions
    subtype Addr_c is integer range log2ceil(Depth_g) downto 0; -- one additional bit to differentiate between full/empty
    subtype AddrApp_c is integer range log2ceil(Depth_g) - 1 downto 0; -- one additional bit to differentiate between full/empty

    -- Types
    type RdFsm_t is (Fetch_s, Data_s, Last_s);

    type TwoProcess_r is record
        -- Write Side
        WrAddr         : unsigned(Addr_c); -- Shifted by Depth_g to Read pointer
        WrPacketStart  : unsigned(Addr_c); -- Shifted by Depth_g to Read pointer
        WrSize         : unsigned(Addr_c);
        WrPacketActive : std_logic;
        DropLatch      : std_logic;
        Full           : std_logic;
        -- Read Side
        RdAddr         : unsigned(Addr_c);
        RdPacketStart  : unsigned(Addr_c);
        RdPacketEnd    : unsigned(Addr_c);
        RdValid        : std_logic;
        RdFsm          : RdFsm_t;
        RdRepeat       : std_logic;
        RdSize         : unsigned(log2ceil(Depth_g + 1) - 1 downto 0);
        NextLatch      : std_logic;
        -- Status
        PacketLevel    : unsigned(log2ceil(MaxPackets_g + 1)-1 downto 0);
    end record;

    -- Write address have the MSB (unused for RAM adressing) inverted. This leads to ReadAddr = WriteAddr indicating
    -- .. the full condition (and not the empty condition).

    signal r, r_next : TwoProcess_r;

    -- Instntiation signals
    signal RamRdAddr        : std_logic_vector(Addr_c);
    signal FifoInReady      : std_logic;
    signal RdPacketEnd      : std_logic_vector(Addr_c);
    signal RdPacketEndValid : std_logic;
    signal RamWrEna         : std_logic;
    signal FifoInValid      : std_logic;
    signal FifoOutRdy       : std_logic;
    signal WrAddrStdlv      : std_logic_vector(Addr_c);
    signal OutLastDropOnly  : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert log2(Depth_g) = log2ceil(Depth_g)
        report "olo_base_fifo_packet: only power of two Depth_g is allowed"
        severity error;

    assert FeatureSet_c = "full" or FeatureSet_c = "drop_only"
        report "olo_base_fifo_packet: FeatureSet_g must be FULL or DROP_ONLY"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v           : TwoProcess_r;
        variable In_Ready_v  : std_logic;
        variable InDrop_v    : std_logic;
        variable OutLast_v   : std_logic;
        variable OutNext_v   : std_logic;
        variable OutRepeat_v : std_logic;
    begin
        -- hold variables stable
        v := r;

        -- *** Write side ***

        -- Default Values
        In_Ready_v  := ((not r.Full) and FifoInReady) or r.DropLatch;
        InDrop_v    := r.DropLatch;
        RamWrEna    <= '0';
        FifoInValid <= '0';

        -- Implement getting free aftter Full
        if r.WrAddr /= r.RdPacketStart then
            v.Full := '0';
        end if;

        -- Handle packet drop between samples
        if In_Drop = '1' and (r.WrPacketActive = '1' or In_Valid = '1') then
            v.DropLatch := '1';
        end if;

        if In_Valid = '1' and In_Ready_v = '1' then
            -- Packet Active
            v.WrPacketActive := '1';

            -- Handle FIFO becomes Full
            if r.WrAddr = r.RdPacketStart-1 then
                v.Full := '1';
            end if;

            -- Increment Address
            if r.WrAddr = Depth_g*2 - 1 then
                v.WrAddr := (others => '0');
            else
                v.WrAddr := r.WrAddr + 1;
            end if;

            -- Handle packet drop on sample
            if In_Drop = '1' then
                InDrop_v    := '1';
                v.DropLatch := '1';
            end if;

            -- Detect packets larger than allowed
            if r.WrSize = Depth_g then
                v.DropLatch := '1';
            else
                v.WrSize := r.WrSize + 1;
            end if;

            -- Handle end of packet
            if In_Last = '1' then
                -- Packet dropped
                if InDrop_v = '1' then
                    v.WrAddr := r.WrPacketStart;
                -- Packet stored
                else
                    v.WrPacketStart := r.WrAddr + 1;
                    FifoInValid     <= '1';
                end if;
                -- Reset signals for all packet ends
                v.DropLatch      := '0';
                v.WrSize         := to_unsigned(1, r.WrSize'length);
                v.WrPacketActive := '0';
            end if;

            -- Write to RAM
            RamWrEna <= '1';

        end if;

        -- Avoid blocking due to Full detection for oversized packets
        if r.DropLatch = '1' then
            v.WrAddr := r.WrPacketStart;
            v.Full   := '0';
        end if;

        -- Output
        In_IsDropped <= InDrop_v;
        In_Ready     <= In_Ready_v;

        -- *** Status ***

        -- *** Read side ***

        -- Default Values
        FifoOutRdy <= '0';
        OutLast_v  := '0';

        -- Suppress deactivated feature sets
        OutNext_v   := '0';
        OutRepeat_v := '0';
        if FeatureSet_c = "full" then
            OutNext_v   := Out_Next;
            OutRepeat_v := Out_Repeat;
        end if;

        -- FSM
        case r.RdFsm is
            when Fetch_s =>
                -- Set start address after completion of a packet
                v.RdPacketStart := r.RdAddr;

                -- Repeat packet
                if r.RdRepeat = '1' then
                    if r.RdPacketEnd = r.RdPacketStart then
                        v.RdFsm := Last_s;
                    else
                        v.RdFsm := Data_s;
                    end if;
                    v.RdRepeat := '0';
                    v.RdAddr   := r.RdPacketStart;
                    v.RdValid  := '1';
                    -- Revert signals for repeated packets
                    v.RdPacketStart := r.RdPacketStart;

                -- Read next packet info
                elsif RdPacketEndValid = '1' then
                    FifoOutRdy <= '1';
                    v.RdRepeat := '0';
                    if unsigned(RdPacketEnd) = r.RdAddr then
                        v.RdFsm := Last_s;
                    else
                        v.RdFsm := Data_s;
                    end if;
                    v.RdPacketEnd := unsigned(RdPacketEnd);
                    v.RdValid     := '1';
                    -- Packet size is only supported in FULL mode
                    if FeatureSet_c = "full" then
                        v.RdSize := unsigned(RdPacketEnd) - r.RdAddr + 1;
                    end if;

                end if;

            when Data_s =>
                -- Transaction
                if Out_Ready = '1' then
                    if v.RdAddr = Depth_g*2 - 1 then
                        v.RdAddr := (others => '0');
                    else
                        v.RdAddr := v.RdAddr + 1;
                    end if;

                    -- Handle normal end of packet
                    if r.RdAddr = r.RdPacketEnd - 1 then
                        v.RdFsm := Last_s;
                    end if;

                    -- Handle abortion of packet
                    if OutNext_v = '1' or r.NextLatch = '1' then
                        OutLast_v := '1';
                        v.RdValid := '0';
                        v.RdFsm   := Fetch_s;
                        v.RdAddr  := r.RdPacketEnd + 1;
                    end if;

                end if;

            when Last_s =>
                -- Assert last in this state (combinatorial)
                OutLast_v := '1';

                if Out_Ready = '1' then
                    -- Increment Address
                    if v.RdAddr = Depth_g*2 - 1 then
                        v.RdAddr := (others => '0');
                    else
                        v.RdAddr := v.RdAddr + 1;
                    end if;

                    -- Abort is not handled separately because it does not have any effect on the last word of a packet

                    -- To to idle cycle for fetch after packet completed
                    v.RdValid := '0';
                    v.RdFsm   := Fetch_s;
                end if;

            -- coverage off
            when others => null; -- unreacable code
            -- coverage on

        end case;

        RamRdAddr <= std_logic_vector(v.RdAddr);
        Out_Valid <= r.RdValid;
        if FeatureSet_c /= "full" then
            OutLast_v := OutLastDropOnly; -- Override default assignment further up in the process
            Out_Size  <= (others => 'X');
        else
            Out_Size <= std_logic_vector(r.RdSize);
        end if;
        Out_Last <= OutLast_v;

        -- Latch Next between samples
        if r.RdValid = '1' and Out_Ready = '1' and OutLast_v = '1' then
            v.NextLatch := '0';
        elsif r.RdValid = '1' and OutNext_v = '1' then
            v.NextLatch := '1';
        end if;

        -- Handle Packet Level
        if In_Valid = '1' and In_Ready_v = '1' and In_Last = '1' and InDrop_v = '0' then
            v.PacketLevel := r.PacketLevel + 1;
        end if;
        if r.RdValid = '1' and Out_Ready = '1' and OutLast_v = '1' and r.RdRepeat = '0' and OutRepeat_v = '0' then
            v.PacketLevel := v.PacketLevel - 1;
        end if;
        PacketLevel <= std_logic_vector(r.PacketLevel);

        -- Handle Free Space
        FreeWords <= std_logic_vector(r.RdPacketStart(FreeWords'range) - r.WrAddr(FreeWords'range));

        -- Latch Repeat between samples
        -- Clearing is done in FSM
        if OutRepeat_v = '1' and r.RdValid = '1' then
            v.RdRepeat := '1';
        end if;

        -- Assign signal
        r_next <= v;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.WrAddr         <= to_unsigned(Depth_g, r.WrAddr'length);
                r.WrPacketStart  <= to_unsigned(Depth_g, r.WrPacketStart'length);
                r.WrSize         <= to_unsigned(1, r.WrSize'length);
                r.WrPacketActive <= '0';
                r.DropLatch      <= '0';
                r.Full           <= '0';
                r.RdAddr         <= (others => '0');
                r.RdPacketStart  <= (others => '0');
                r.RdFsm          <= Fetch_s;
                r.RdRepeat       <= '0';
                r.RdValid        <= '0';
                r.NextLatch      <= '0';
                r.PacketLevel    <= (others => '0');
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------

    -- Fix the "shift by depth" between Write/Read address pointers for full/empty detection
    WrAddrStdlv(AddrApp_c)        <= std_logic_vector(r.WrAddr(AddrApp_c));
    WrAddrStdlv(WrAddrStdlv'high) <= not r.WrAddr(r.WrAddr'high);

    -- Main RAM
    b_ram : block is
        -- RAM stores last for drop_only feature set
        constant RamWidth_c : natural := choose(FeatureSet_c = "full", Width_g, Width_g+1);

        signal RamInData  : std_logic_vector(RamWidth_c-1 downto 0);
        signal RamOutData : std_logic_vector(RamWidth_c-1 downto 0);
    begin

        p_map : process (all) is
        begin
            if FeatureSet_c = "full" then
                -- Input
                RamInData <= In_Data;
                -- Output
                Out_Data <= RamOutData;
            else
                -- Input
                RamInData(RamInData'high) <= In_Last;
                RamInData(In_Data'range)  <= In_Data;
                -- Output
                OutLastDropOnly <= RamOutData(RamOutData'high); -- assigned in main comb process
                Out_Data        <= RamOutData(Out_Data'range);
            end if;
        end process;

        i_ram : entity work.olo_base_ram_sdp
            generic map (
                Depth_g         => Depth_g,
                Width_g         => RamWidth_c,
                RamStyle_g      => RamStyle_g,
                RamBehavior_g   => RamBehavior_g
            )
            port map (
                Clk     => Clk,
                Wr_Addr => WrAddrStdlv(AddrApp_c), -- Additional bit for full/empty differentiation is stripped
                Wr_Ena  => RamWrEna,
                Wr_Data => RamInData,
                Rd_Addr => RamRdAddr(AddrApp_c),   -- Additional bit for full/empty differentiation is stripped
                Rd_Data => RamOutData
            );

    end block;

    -- FIFO transfer packet ends for full feature set
    g_small_fifo : if FeatureSet_c = "full" generate

        i_pktend_fifo : entity work.olo_base_fifo_sync
            generic map (
                Width_g         => log2ceil(Depth_g)+1,
                Depth_g         => MaxPackets_g-1,     -- One packet is currently read out (not in the FIFO anymore)
                RamStyle_g      => SmallRamStyle_c,
                RamBehavior_g   => SmallRamBehavior_c,
                ReadyRstState_g => '0'
            )
            port map (
                Clk           => Clk,
                Rst           => Rst,
                In_Data       => WrAddrStdlv,
                In_Valid      => FifoInValid,
                In_Ready      => FifoInReady,
                Out_Data      => RdPacketEnd,
                Out_Valid     => RdPacketEndValid,
                Out_Ready     => FifoOutRdy
            );

    end generate;

    -- For drop_only feature set only the last end address must be latched
    g_no_small_fifo : if FeatureSet_c /= "full" generate

        FifoInReady <= '1';

        p_latch : process (Clk) is
        begin
            if rising_edge(Clk) then

                -- Read
                if FifoOutRdy = '1' then
                    RdPacketEndValid <= '0';
                end if;

                -- Write
                if FifoInValid = '1' then
                    RdPacketEndValid <= '1';
                    RdPacketEnd      <= WrAddrStdlv;
                end if;

                -- Reset
                if Rst = '1' then
                    RdPacketEndValid <= '0';
                end if;
            end if;
        end process;

    end generate;

end architecture;
