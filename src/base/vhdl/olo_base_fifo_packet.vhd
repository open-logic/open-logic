------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a synchronous packet FIFO.ff
-- Doc: Inefficient for 1 word packets (1 idle cycle after each packet)
-- Add status (known free space, packets level, empty, full-data, full-packets)
-- Doc Depth must be power of two


-- New "Manual Signals" TB (not using AXI-Stream VCs)
-- Assert Repeat between handshaking
-- Assert Next between handshakingss
-- Allow "drop" between handshaking (only after first HS?)
-- Allow "next" between handshaking (only after first HS?)
-- Allow "repeat" between handshaking (also after last but before next HS)



------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_fifo_packet is
    generic ( 
        Width_g             : positive;                   
        Depth_g             : positive;                                 
        RamStyle_g          : string    := "auto";       
        RamBehavior_g       : string    := "RBW";
        SmallRamStyle_g     : string    := "auto";
        SmallRamBehavior_g  : string    := "same";
        MaxPackets_g        : positive range 2 to positive'high  := 16
    );
    port (    
        -- Control Ports
          Clk           : in  std_logic;
          Rst           : in  std_logic;
          -- Input Data
          In_Valid      : in  std_logic                                             := '1';
          In_Ready      : out std_logic;
          In_Data       : in  std_logic_vector(Width_g - 1 downto 0);
          In_Last       : in  std_logic                                             := '1';
          In_Drop       : in  std_logic                                             := '0';
          In_IsDropped  : out std_logic;
          -- Output Data
          Out_Valid     : out std_logic;
          Out_Ready     : in  std_logic                                             := '1';
          Out_Data      : out std_logic_vector(Width_g - 1 downto 0);
          Out_Last      : out std_logic;
          Out_Next      : in  std_logic                                             := '0'; 
          Out_Repeat    : in  std_logic                                             := '0'   
          
    );
end entity;


------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_fifo_packet is

    constant SmallRamStyle_c    : string := choose(SmallRamStyle_g = "same", RamStyle_g, SmallRamStyle_g);
    constant SmallRamBehavior_c : string := choose(SmallRamBehavior_g = "same", RamBehavior_g, SmallRamBehavior_g);

    subtype Addr_r is integer range log2ceil(Depth_g) downto 0; -- one additional bit to differentiate between full/empty 
    subtype AddrApp_r is integer range log2ceil(Depth_g) - 1 downto 0; -- one additional bit to differentiate between full/empty


    type RdFsm_t is (Fetch_s, Data_s, Last_s);

    type two_process_r is record
        -- Write Side
        WrAddr          : unsigned(Addr_r); -- Shifted by Depth_g to Read pointer
        WrPacketStart   : unsigned(Addr_r); -- Shifted by Depth_g to Read pointer
        WrSize          : unsigned(Addr_r);
        DropLatch       : std_logic;
        Full            : std_logic;
        -- Read Side
        RdAddr          : unsigned(Addr_r);
        RdPacketStart   : unsigned(Addr_r);
        RdPacketEnd     : unsigned(Addr_r);
        RdValid         : std_logic;
        RdFsm           : RdFsm_t;
        RdRepeat        : std_logic;
    end record;
    -- Write address have the MSB (unused for RAM adressing) inverted. This leads to ReadAddr = WriteAddr indicating
    -- .. the full condition (and not the empty condition).

    signal r, r_next : two_process_r;

    signal RamRdAddr : std_logic_vector(Addr_r);
    signal FifoInReady : std_logic;
    signal RdPacketEnd : std_logic_vector(Addr_r);
    signal RdPacketEndValid : std_logic;
    signal RamWrEna : std_logic;
    signal FifoInValid : std_logic;
    signal FifoOutRdy : std_logic;
    signal WrAddrStdlv : std_logic_vector(Addr_r);

begin

    assert log2(Depth_g) = log2ceil(Depth_g) report "olo_base_fifo_packet: only power of two Depth_g is allowed" severity error;


    p_comb : process(In_Valid, In_Data, In_Last, In_Drop, Out_Ready, Out_Next, Out_Repeat, Rst, r,
                     FifoInReady, RdPacketEnd, RdPacketEndValid)
        variable v : two_process_r;
        variable In_Ready_v : std_logic;
        variable InDrop_v : std_logic;
    begin
        -- hold variables stable
        v := r;

        -- *** Write side ***

        -- Default Values
        In_Ready_v := ((not r.Full) and FifoInReady) or r.DropLatch;
        InDrop_v := r.DropLatch;
        RamWrEna <= '0';
        FifoInValid <= '0';

        -- Implement getting free aftter Full
        if r.WrAddr /= r.RdPacketStart then
            v.Full := '0';
        end if;

        if In_Valid = '1' and In_Ready_v = '1' then
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

            -- Handle packet drop
            if In_Drop = '1' then
                InDrop_v := '1';
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
                    FifoInValid <= '1';
                end if;
                -- Reset signals for all packet ends
                v.DropLatch := '0';
                v.WrSize := to_unsigned(1, r.WrSize'length);
            end if;

            -- Write to RAM
            RamWrEna <= '1';

        end if;

        -- Avoid blocking due to Full detection for oversized packets
        if r.DropLatch = '1' then
            v.WrAddr := r.WrPacketStart;  
            v.Full := '0';
        end if;

        -- Output
        In_IsDropped <= InDrop_v;
        In_Ready <= In_Ready_v;

        -- *** Status ***

        -- *** Read side ***
    
        -- Default Values
        FifoOutRdy <= '0';
        Out_Last <= '0';


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
                    v.RdAddr := r.RdPacketStart;
                    v.RdPacketStart := r.RdPacketStart; -- Revert start address
                    v.RdValid := '1';

                -- Read next packet info
                elsif RdPacketEndValid = '1' then
                    FifoOutRdy <= '1';
                    if unsigned(RdPacketEnd) = r.RdAddr then
                        v.RdFsm := Last_s;
                    else
                        v.RdFsm := Data_s;
                    end if; 
                    v.RdPacketEnd := unsigned(RdPacketEnd);
                    v.RdValid := '1';
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
                    if Out_Next = '1' then
                        Out_Last <= '1';
                        v.RdValid := '0';
                        v.RdFsm := Fetch_s;       
                        v.RdAddr := r.RdPacketEnd + 1;           
                    end if;

                    -- Detect Repetition
                    if Out_Repeat = '1' then
                        v.RdRepeat := '1';
                    end if;

                end if;

            when Last_s =>
                -- Assert last in this state (combinatorial)
                Out_Last <= '1';

                if Out_Ready = '1' then
                    -- Increment Address
                    if v.RdAddr = Depth_g*2 - 1 then
                        v.RdAddr := (others => '0');
                    else
                        v.RdAddr := v.RdAddr + 1;
                    end if;

                    -- Abort is not handled separately because it does not have any effect on the last word of a packet

                    -- Detect Repetition
                    if Out_Repeat = '1' then
                        v.RdRepeat := '1';
                    end if;

                    -- To to idle cycle for fetch after packet completed
                    v.RdValid := '0';
                    v.RdFsm := Fetch_s;
                end if;

            when others => null;

        end case;
        RamRdAddr <= std_logic_vector(v.RdAddr);
        Out_Valid <= r.RdValid;

        -- Assign signal
        r_next <= v;

    end process;

    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.WrAddr        <= to_unsigned(Depth_g, r.WrAddr'length);
                r.WrPacketStart <= to_unsigned(Depth_g, r.WrPacketStart'length);
                r.WrSize        <= to_unsigned(1, r.WrSize'length);
                r.DropLatch     <= '0';
                r.Full          <= '0';
                r.RdAddr        <= (others => '0');
                r.RdPacketStart <= (others => '0');
                r.RdFsm         <= Fetch_s; 
                r.RdRepeat      <= '0';
                r.RdValid       <= '0';
            end if;
        end if;
    end process;

    -- Fix the "shift by depth" between Write/Read address pointers for full/empty detection
    WrAddrStdlv(AddrApp_r) <= std_logic_vector(r.WrAddr(Addrapp_r));
    WrAddrStdlv(WrAddrStdlv'high) <= not r.WrAddr(r.WrAddr'high);

    -- Main RAM
    i_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g         => Depth_g,
            Width_g         => Width_g,
            RamStyle_g      => RamStyle_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map(
            Clk         => Clk,
            Wr_Addr     => WrAddrStdlv(AddrApp_r),  -- Additional bit for full/empty differentiation is stripped
            Wr_Ena      => RamWrEna,
            Wr_Data     => In_Data,
            Rd_Addr     => RamRdAddr(AddrApp_r), -- Additional bit for full/empty differentiation is stripped
            Rd_Data     => Out_Data
        );


    -- FIFO transfer packet ends
    i_pktend_fifo : entity work.olo_base_fifo_sync
        generic map ( 
            Width_g         => log2ceil(Depth_g)+1,                
            Depth_g         => MaxPackets_g,                   
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


end architecture;
