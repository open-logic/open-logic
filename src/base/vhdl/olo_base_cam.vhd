---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler
----------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This components implements a content addressable memory.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cam.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_cam is
    generic (
        -- Basic Configuration
        Addresses_g          : positive;
        ContentWidth_g       : positive;
        RamStyle_g           : string   := "auto";
        RamBehavior_g        : string   := "RBW";
        RamBlockDepth_g      : positive := 512;
        ClearAfterReset_g    : boolean  := true;
        -- Read/Write interleaving
        ReadPriority_g       : boolean  := true;
        StrictOrdering_g     : boolean  := false;
        -- Pipelineing
        UseAddrOut_g         : boolean  := true;
        RegisterInput_g      : boolean  := true;
        RegisterMatch_g      : boolean  := true;
        FirstBitDecLatency_g : natural  := 1
    );
    port (
        -- Control Signals
        Clk                     : in    std_logic;
        Rst                     : in    std_logic;

        -- CAM read request
        Rd_Valid                : in    std_logic;
        Rd_Ready                : out   std_logic;
        Rd_Content              : in    std_logic_vector(ContentWidth_g-1 downto 0);

        -- Cam write
        Wr_Valid                : in    std_logic;
        Wr_Ready                : out   std_logic;
        Wr_Content              : in    std_logic_vector(ContentWidth_g-1 downto 0);
        Wr_Addr                 : in    std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Wr_Write                : in    std_logic;
        Wr_Clear                : in    std_logic := '0';
        Wr_ClearAll             : in    std_logic := '0';

        -- CAM one hot read response
        Match_Valid             : out   std_logic;
        Match_Match             : out   std_logic_vector(Addresses_g-1 downto 0);

        -- CAM binary read response
        Addr_Valid              : out   std_logic;
        Addr_Found              : out   std_logic;
        Addr_Addr               : out   std_logic_vector(log2ceil(Addresses_g)-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_cam is

    -- *** Constants ***
    constant BlockAddrBits_c  : positive := log2ceil(RamBlockDepth_g);
    constant BlocksParallel_c : positive := integer(ceil(real(ContentWidth_g) / real(BlockAddrBits_c)));
    constant TotalAddrBits_c  : positive := BlocksParallel_c * BlockAddrBits_c;

    -- *** Two Process Method ***
    type TwoProcess_r is record
        -- Stage 0
        Content_0         : std_logic_vector(ContentWidth_g - 1 downto 0);
        Addr_0            : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Write_0           : std_logic;
        Clear_0           : std_logic;
        ClearAll_0        : std_logic;
        Read_0            : std_logic;
        -- Stage 1
        ContentExtended_1 : std_logic_vector(TotalAddrBits_c - 1 downto 0);
        Addr_1            : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
        Write_1           : std_logic;
        Clear_1           : std_logic;
        ClearAll_1        : std_logic;
        Read_1            : std_logic;
        -- Stage 2
        Match_2           : std_logic_vector(Addresses_g-1 downto 0);
        Read_2            : std_logic;
        -- Clear after reset
        RstClearDone      : std_logic;
        RstClearCounter   : unsigned(BlockAddrBits_c-1 downto 0);
        RstClearWr        : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signal Types ***
    type RamData_t is array (natural range <>) of std_logic_vector(Addresses_g-1 downto 0);

    -- *** Instantiation Signals ***
    signal ReadContent_0 : std_logic_vector(ContentWidth_g-1 downto 0);
    signal RamRead_1     : RamData_t(0 to BlocksParallel_c-1);
    signal RamWrite_1    : RamData_t(0 to BlocksParallel_c-1);
    signal WrMem_1       : std_logic;
    signal MatchInt      : std_logic_vector(Addresses_g-1 downto 0);
    signal MatchValid    : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert isPower2(RamBlockDepth_g)
        report "olo_base_cam - RamBlockDepth_g must be a power of 2"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_cob : process (all) is
        variable v                        : TwoProcess_r;
        variable ClearMask_v, SetMask_v   : std_logic_vector(Addresses_g-1 downto 0);
        variable InRdReady_v, InWrReady_v : std_logic;
    begin
        -- *** Hold variables stable ***
        v := r;

        -- *** Input Ready Handling ***
        if ReadPriority_g then
            InRdReady_v := '1';
            InWrReady_v := not Rd_Valid;
        else
            InWrReady_v := '1';
            InRdReady_v := not Wr_Valid;
        end if;
        -- For Write and Rad with strict ordering, wait until write is done
        if r.Write_0 = '1' or r.Clear_0 = '1' or r.ClearAll_0 = '1' then
            InWrReady_v := '0';
            if StrictOrdering_g and RamBehavior_g = "RBW" then
                -- If the ordering is not strict or the ram writes befor read, we camm continue reading immediately
                InRdReady_v := '0';
            else
                -- If ordering is not strict, we can always take a read after a write (because WrReady is low)
                InRdReady_v := '1';
            end if;
        end if;
        -- Handle Reset
        if Rst = '1' or (ClearAfterReset_g and r.RstClearDone = '0') then
            InRdReady_v := '0';
            InWrReady_v := '0';
        end if;
        Rd_Ready <= InRdReady_v;
        Wr_Ready <= InWrReady_v;

        -- *** Stage 0 ***
        v.Addr_0     := Wr_Addr;
        v.Write_0    := '0';
        v.Clear_0    := '0';
        v.Read_0     := '0';
        v.ClearAll_0 := '0';
        if InWrReady_v = '1' and Wr_Valid = '1' then
            v.Content_0  := Wr_Content;
            v.Write_0    := Wr_Write;
            v.Clear_0    := Wr_Clear;
            v.ClearAll_0 := Wr_ClearAll;
        elsif InRdReady_v = '1' and Rd_Valid = '1' then
            v.Content_0 := Rd_Content;
            v.Read_0    := '1';
        end if;
        if RegisterInput_g then
            ReadContent_0 <= r.Content_0;
        else
            ReadContent_0 <= v.Content_0;
        end if;

        -- *** Stage 1 ***
        if RegisterInput_g then
            -- Wait for RAM to respond
            v.ContentExtended_1                            := (others => '0');
            v.ContentExtended_1(ContentWidth_g-1 downto 0) := r.Content_0;
            v.Addr_1                                       := r.Addr_0;
            v.Write_1                                      := r.Write_0;
            v.Clear_1                                      := r.Clear_0;
            v.Read_1                                       := r.Read_0;
            v.ClearAll_1                                   := r.ClearAll_0;
        else
            -- Skip one register state
            v.ContentExtended_1                            := (others => '0');
            v.ContentExtended_1(ContentWidth_g-1 downto 0) := v.Content_0;
            v.Addr_1                                       := v.Addr_0;
            v.Write_1                                      := v.Write_0;
            v.Clear_1                                      := v.Clear_0;
            v.Read_1                                       := v.Read_0;
            v.ClearAll_1                                   := v.ClearAll_0;
        end if;

        -- *** Stage 2 ***
        v.Read_2 := r.Read_1;
        -- Find one hot matching address
        v.Match_2 := RamRead_1(0);

        -- Loop over all parallel blocks
        for i in 1 to BlocksParallel_c-1 loop
            v.Match_2 := v.Match_2 and RamRead_1(i);
        end loop;

        -- Modify CAM content if required
        ClearMask_v := (others => '1');
        SetMask_v   := (others => '0');
        if r.Write_1 = '1' then
            -- Write new CAM entry
            SetMask_v(fromUslv(to01(r.Addr_1))) := '1';
        end if;
        if r.Clear_1 = '1' then
            -- Clear single CAM entry
            ClearMask_v(fromUslv(to01(r.Addr_1))) := '0';
        end if;
        if r.ClearAll_1 = '1' then
            -- Clear all CAM entries - this overrides the single clear mask
            -- Note: ClearAll is somewhat timing suboptimal and shall only be used if this is tolerable
            ClearMask_v := not v.Match_2;
        end if;

        -- loop over all blocks
        for i in 0 to BlocksParallel_c-1 loop
            RamWrite_1(i) <= (RamRead_1(i) and ClearMask_v) or SetMask_v;
        end loop;

        WrMem_1 <= r.Write_1 or r.Clear_1 or r.ClearAll_1 or r.RstClearWr;
        -- One hot output
        if RegisterMatch_g then
            MatchValid <= r.Read_2;
            MatchInt   <= r.Match_2;
        else
            MatchValid <= v.Read_2;
            MatchInt   <= v.Match_2;
        end if;

        -- *** Clear after reset ***
        v.RstClearWr := '0';
        if ClearAfterReset_g then
            -- Increment Counter
            if r.RstClearDone = '0' then
                if r.RstClearCounter = 2**BlockAddrBits_c-1 then
                    v.RstClearDone := '1';
                else
                    v.RstClearCounter := r.RstClearCounter + 1;
                end if;
            else
                v.RstClearDone := '1';
            end if;
            -- Control clearing signal
            if r.RstClearDone = '0' then
                -- Deasserting ready signals is done further up where the ready signals are assigned
                -- Clear CAM
                v.RstClearWr := '1'; -- Assignment to memory write done further up in code

                -- loop over all blocks
                for i in 0 to BlocksParallel_c-1 loop
                    v.ContentExtended_1((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c) := std_logic_vector(r.RstClearCounter);
                end loop;

            end if;
            if r.RstClearWr = '1' then
                RamWrite_1 <= (others => (others => '0'));
            end if;
        end if;

        -- *** Assign to signal ***
        r_next <= v;
    end process;

    -- Output signals
    Match_Valid <= MatchValid;
    Match_Match <= MatchInt;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Write_0         <= '0';
                r.Clear_0         <= '0';
                r.ClearAll_0      <= '0';
                r.Read_0          <= '0';
                r.Write_1         <= '0';
                r.Clear_1         <= '0';
                r.ClearAll_1      <= '0';
                r.Read_1          <= '0';
                r.Read_2          <= '0';
                r.RstClearDone    <= '0';
                r.RstClearCounter <= (others => '0');
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Instantiations
    -----------------------------------------------------------------------------------------------
    -- CAM memory array
    g_addr : for i in 0 to BlocksParallel_c-1 generate
        signal ContentExtended_0 : std_logic_vector(TotalAddrBits_c-1 downto 0) := (others => '0');
        signal RdAddr_0          : std_logic_vector(BlockAddrBits_c-1 downto 0);
        signal WrAddr_1          : std_logic_vector(BlockAddrBits_c-1 downto 0);
    begin
        -- Input assembly
        ContentExtended_0(ContentWidth_g-1 downto 0) <= ReadContent_0;

        RdAddr_0 <= to01(ContentExtended_0((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));
        WrAddr_1 <= to01(r.ContentExtended_1((i+1)*BlockAddrBits_c-1 downto i*BlockAddrBits_c));

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
                Wr_Data     => RamWrite_1(i),
                Rd_Addr     => RdAddr_0,
                Rd_Data     => RamRead_1(i)
            );

    end generate;

    -- First bit decoder
    g_addrout : if UseAddrOut_g generate

        i_addrout : entity work.olo_base_decode_firstbit
            generic map (
                InWidth_g       => Addresses_g,
                InReg_g         => false,   -- Regiser is in r
                OutReg_g        => choose(FirstBitDecLatency_g = 0, false, true),
                PlRegs_g        => choose(FirstBitDecLatency_g = 0, 0, FirstBitDecLatency_g-1)
            )
            port map (
                Clk          => Clk,
                Rst          => Rst,
                In_Data      => MatchInt,
                In_Valid     => MatchValid,
                Out_FirstBit => Addr_Addr,
                Out_Found    => Addr_Found,
                Out_Valid    => Addr_Valid
            );

    end generate;

    g_naddrout : if not UseAddrOut_g generate

        -- Dummy signals
        Addr_Valid <= '0';
        Addr_Found <= '0';
        Addr_Addr  <= (others => '0');

    end generate;

end architecture;

