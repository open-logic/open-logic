---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple AXI master. Simple means: It does not
-- support any unaligned reads/writes and it does not do any width conversions.
-- It just executes the transfers requested and splits them into multiple AXI
-- transactions in order to not burst over 4k boundaries and respect the maximum
-- transaction size.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/axi/olo_axi_master_simple.md
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
    use work.olo_axi_pkg_protocol.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_axi_master_simple is
    generic (
        -- AXI Configuration
        AxiAddrWidth_g              : positive range 12 to 64  := 32;
        AxiDataWidth_g              : positive range 8 to 1024 := 32;
        AxiMaxBeats_g               : positive range 1 to 256  := 256;
        AxiMaxOpenTransactions_g    : positive range 1 to 8    := 8;
        -- User Configuration
        UserTransactionSizeBits_g   : positive                 := 24;
        DataFifoDepth_g             : positive                 := 1024;
        ImplRead_g                  : boolean                  := true;
        ImplWrite_g                 : boolean                  := true;
        RamBehavior_g               : string                   := "RBW"
    );
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- User Command Interface
        CmdWr_Addr      : in    std_logic_vector(AxiAddrWidth_g - 1 downto 0)            := (others => '0');
        CmdWr_Size      : in    std_logic_vector(UserTransactionSizeBits_g - 1 downto 0) := (others => '0');
        CmdWr_LowLat    : in    std_logic                                                := '0';
        CmdWr_Valid     : in    std_logic                                                := '0';
        CmdWr_Ready     : out   std_logic;
        -- User Command Interface
        CmdRd_Addr      : in    std_logic_vector(AxiAddrWidth_g - 1 downto 0)            := (others => '0');
        CmdRd_Size      : in    std_logic_vector(UserTransactionSizeBits_g - 1 downto 0) := (others => '0');
        CmdRd_LowLat    : in    std_logic                                                := '0';
        CmdRd_Valid     : in    std_logic                                                := '0';
        CmdRd_Ready     : out   std_logic;
        -- Write Data
        Wr_Data         : in    std_logic_vector(AxiDataWidth_g - 1 downto 0)            := (others => '0');
        Wr_Be           : in    std_logic_vector(AxiDataWidth_g / 8 - 1 downto 0)        := (others => '0');
        Wr_Valid        : in    std_logic                                                := '0';
        Wr_Ready        : out   std_logic;
        -- Read Data
        Rd_Data         : out   std_logic_vector(AxiDataWidth_g - 1 downto 0);
        Rd_Last         : out   std_logic;
        Rd_Valid        : out   std_logic;
        Rd_Ready        : in    std_logic                                                := '1';
        -- Response
        Wr_Done         : out   std_logic;
        Wr_Error        : out   std_logic;
        Rd_Done         : out   std_logic;
        Rd_Error        : out   std_logic;
        -- AXI Address Write Channel
        M_Axi_AwAddr    : out   std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        M_Axi_AwLen     : out   std_logic_vector(7 downto 0);
        M_Axi_AwSize    : out   std_logic_vector(2 downto 0);
        M_Axi_AwBurst   : out   std_logic_vector(1 downto 0);
        M_Axi_AwLock    : out   std_logic;
        M_Axi_AwCache   : out   std_logic_vector(3 downto 0);
        M_Axi_AwProt    : out   std_logic_vector(2 downto 0);
        M_Axi_AwValid   : out   std_logic;
        M_Axi_AwReady   : in    std_logic                                                := '0';
        -- AXI Write Data Channel
        M_Axi_WData     : out   std_logic_vector(AxiDataWidth_g - 1 downto 0);
        M_Axi_WStrb     : out   std_logic_vector(AxiDataWidth_g / 8 - 1 downto 0);
        M_Axi_WLast     : out   std_logic;
        M_Axi_WValid    : out   std_logic;
        M_Axi_WReady    : in    std_logic                                                := '0';
        -- AXI Write Response Channel
        M_Axi_BResp     : in    std_logic_vector(1 downto 0)                             := (others => '0');
        M_Axi_BValid    : in    std_logic                                                := '0';
        M_Axi_BReady    : out   std_logic;
        -- AXI Read Address Channel
        M_Axi_ArAddr    : out   std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        M_Axi_ArLen     : out   std_logic_vector(7 downto 0);
        M_Axi_ArSize    : out   std_logic_vector(2 downto 0);
        M_Axi_ArBurst   : out   std_logic_vector(1 downto 0);
        M_Axi_ArLock    : out   std_logic;
        M_Axi_ArCache   : out   std_logic_vector(3 downto 0);
        M_Axi_ArProt    : out   std_logic_vector(2 downto 0);
        M_Axi_ArValid   : out   std_logic;
        M_Axi_ArReady   : in    std_logic                                                := '0';
        -- AXI Read Data Channel
        M_Axi_RData     : in    std_logic_vector(AxiDataWidth_g - 1 downto 0)            := (others => '0');
        M_Axi_RResp     : in    std_logic_vector(1 downto 0)                             := (others => '0');
        M_Axi_RLast     : in    std_logic                                                := '0';
        M_Axi_RValid    : in    std_logic                                                := '0';
        M_Axi_RReady    : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_axi_master_simple is

    -- *** Constants ***
    constant UnusedAddrBits_c : natural := log2(AxiDataWidth_g / 8);

    constant BeatsBits_c     : natural := log2ceil(AxiMaxBeats_g + 1);
    constant MaxBeatsNoCmd_c : natural := max(AxiMaxBeats_g * AxiMaxOpenTransactions_g, DataFifoDepth_g);

    -- *** Type Definitions ***
    type WriteTfGen_t is (Idle_s, MaxCalc_s, GenTf_s, WriteTf_s);
    type ReadTfGen_t is (Idle_s, MaxCalc_s, GenTf_s, WriteTf_s);
    type AwFsm_t is (Idle_s, Wait_s);
    type ArFsm_t is (Idle_s, Wait_s);
    type WrFsm_t is (Idle_s, NonLast_s, Last_s);

    -- *** Functions ***
    function addrMasked (Addr : in std_logic_vector) return std_logic_vector is
        variable Masked_v : std_logic_vector(Addr'range);
    begin
        Masked_v                                := Addr;
        Masked_v(UnusedAddrBits_c - 1 downto 0) := (others => '0');
        return Masked_v;
    end function;

    -- *** Two Process Record ***
    type TwoProcess_r is record
        -- *** Write Related Registers ***
        -- Command Interface
        CmdWr_Ready     : std_logic;
        Wr_Error        : std_logic;
        Wr_Done         : std_logic;
        -- Generate Write Transactions
        WriteTfGenState : WriteTfGen_t;
        WrAddr          : unsigned(CmdWr_Addr'range);
        WrBeats         : unsigned(CmdWr_Size'range);
        WrLowLat        : std_logic;
        WrMaxBeats      : unsigned(BeatsBits_c - 1 downto 0);
        WrTfBeats       : unsigned(BeatsBits_c - 1 downto 0);
        WrTfVld         : std_logic;
        WrTfIsLast      : std_logic;
        -- Execute Aw Commands
        AwFsm           : AwFsm_t;
        AwFsmRdy        : std_logic;
        AwCmdSent       : std_logic;
        AwCmdSize       : unsigned(BeatsBits_c - 1 downto 0);
        AwCmdSizeMin1   : unsigned(BeatsBits_c - 1 downto 0); -- AwCmdSize-1 for timing optimization reasons
        WDataFifoWrite  : std_logic;
        -- Execute W Data
        WFsm            : WrFsm_t;
        WDataFifoRd     : std_logic;
        WDataEna        : std_logic;
        WDataBeats      : unsigned(BeatsBits_c - 1 downto 0);
        -- Write Response
        WrRespError     : std_logic;
        -- Write General
        WrOpenTrans     : integer range -1 to AxiMaxOpenTransactions_g;
        WrBeatsNoCmd    : signed(log2ceil(MaxBeatsNoCmd_c + 1) downto 0);
        -- AXI Signals
        M_Axi_AwAddr    : std_logic_vector(M_Axi_AwAddr'range);
        M_Axi_AwLen     : std_logic_vector(M_Axi_AwLen'range);
        M_Axi_AwValid   : std_logic;
        M_Axi_WLast     : std_logic;

        -- *** Read Related Registers ***
        -- Command Interface
        CmdRd_Ready     : std_logic;
        Rd_Error        : std_logic;
        Rd_Done         : std_logic;
        -- Generate Read Transactions
        ReadTfGenState  : ReadTfGen_t;
        RdAddr          : unsigned(CmdRd_Addr'range);
        RdBeats         : unsigned(CmdRd_Size'range);
        RdLowLat        : std_logic;
        RdMaxBeats      : unsigned(BeatsBits_c - 1 downto 0);
        RdTfBeats       : unsigned(BeatsBits_c - 1 downto 0);
        RdTfVld         : std_logic;
        RdTfIsLast      : std_logic;
        -- Execute Ar Commands
        ArFsm           : ArFsm_t;
        ArFsmRdy        : std_logic;
        ArCmdSent       : std_logic;
        ArCmdSize       : unsigned(BeatsBits_c - 1 downto 0);
        ArCmdSizeMin1   : unsigned(BeatsBits_c - 1 downto 0); -- ArCmdSize-1 for timing optimization reasons
        RDataFifoRead   : std_logic;
        -- Write Response
        RdRespError     : std_logic;
        -- Read General
        RdOpenTrans     : unsigned(log2ceil(AxiMaxOpenTransactions_g + 1) - 1 downto 0);
        RdFifoSpaceFree : signed(log2ceil(MaxBeatsNoCmd_c + 1) downto 0);
        -- AXI Signals
        M_Axi_ArAddr    : std_logic_vector(M_Axi_ArAddr'range);
        M_Axi_ArLen     : std_logic_vector(M_Axi_ArLen'range);
        M_Axi_ArValid   : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal WrDataFifoORdy    : std_logic;
    signal WrDataFifoOVld    : std_logic;
    signal WrTransFifoInVld  : std_logic;
    signal WrTransFifoBeats  : std_logic_vector(BeatsBits_c - 1 downto 0);
    signal WrTransFifoOutVld : std_logic;
    signal WrRespIsLast      : std_logic;
    signal WrRespFifoVld     : std_logic;
    signal WrData_Rdy_I      : std_logic;
    signal RdTransFifoInVld  : std_logic;
    signal RdRespIsLast      : std_logic;
    signal RdRespFifoVld     : std_logic;
    signal RdDat_Vld_I       : std_logic;
    signal RdRespLast        : std_logic;
    signal M_Axi_RReady_I    : std_logic;

begin

    -- *** Static Assertions ***
    assert AxiDataWidth_g mod 8 = 0
        report "###ERROR###: olo_axi_master_simple AxiDataWidth_g must be a multiple of 8"
        severity failure;
    assert isPower2(AxiDataWidth_g/8)
        report "###ERROR###: olo_axi_master_simple AxiDataWidth_g must be 2^X bytes"
        severity failure;
    assert UserTransactionSizeBits_g < AxiAddrWidth_g-log2(AxiDataWidth_g/8)
        report "###ERROR###: olo_axi_master_simple UserTransactionSizeBits_g must be smaller than AxiAddrWidth_g-log2(AxiDataWidth_g/8), see documentation"
        severity failure;

    -- *** Runtime Assertions ***
    p_assert : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Unexpected read response
            if ImplRead_g and RdRespLast = '1' then
                assert RdRespFifoVld = '1'
                    report "###ERROR###: olo_axi_master_simple: Unexpected Read Response (RdRespFifo Empty)"
                    severity error;
            end if;
            -- Unexpected write response
            if ImplWrite_g and M_Axi_BValid = '1' then
                assert WrRespFifoVld = '1'
                    report "###ERROR###: olo_axi_master_simple: Unexpected Write Response (WrRespFifo Empty)"
                    severity error;
            end if;
        end if;
    end process;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v               : TwoProcess_r;
        variable WrMax4kBeats_v  : unsigned(13 - UnusedAddrBits_c downto 0);
        variable RdMax4kBeats_v  : unsigned(13 - UnusedAddrBits_c downto 0);
        variable Stdlv9Bit_v     : std_logic_vector(8 downto 0);
        variable WDataTransfer_v : boolean;
        variable StartWBurst_v   : boolean := true;
    begin
        -- *** Keep two process variables stable ***
        v := r;

        -- *** Write Related Code ***
        if ImplWrite_g then

            -- Default Value
            WrMax4kBeats_v := (others => '0');

            -- Write Transfer Generation FSM
            case r.WriteTfGenState is
                when Idle_s =>
                    v.CmdWr_Ready := '1';
                    if (r.CmdWr_Ready = '1') and (CmdWr_Valid = '1') then
                        v.CmdWr_Ready     := '0';
                        v.WrAddr          := unsigned(addrMasked(CmdWr_Addr));
                        v.WrBeats         := unsigned(CmdWr_Size);
                        v.WrLowLat        := CmdWr_LowLat;
                        v.WriteTfGenState := MaxCalc_s;
                    end if;

                when MaxCalc_s =>
                    WrMax4kBeats_v := resize(unsigned('0' & not r.WrAddr(11 downto UnusedAddrBits_c)) + 1, WrMax4kBeats_v'length);
                    if WrMax4kBeats_v > AxiMaxBeats_g then
                        v.WrMaxBeats := to_unsigned(AxiMaxBeats_g, BeatsBits_c);
                    else
                        v.WrMaxBeats := WrMax4kBeats_v(BeatsBits_c - 1 downto 0);
                    end if;
                    v.WriteTfGenState := GenTf_s;

                when GenTf_s =>
                    if (r.WrMaxBeats < r.WrBeats) then
                        v.WrTfBeats  := r.WrMaxBeats;
                        v.WrTfIsLast := '0';
                    else
                        v.WrTfBeats  := r.WrBeats(BeatsBits_c - 1 downto 0);
                        v.WrTfIsLast := '1';
                    end if;
                    v.WrTfVld         := '1';
                    v.WriteTfGenState := WriteTf_s;

                when WriteTf_s =>
                    if (r.WrTfVld = '1') and (r.AwFsmRdy = '1') then
                        v.WrTfVld := '0';
                        v.WrBeats := r.WrBeats - r.WrTfBeats;
                        v.WrAddr  := r.WrAddr + resize(2**UnusedAddrBits_c * r.WrTfBeats, v.WrAddr'length);
                        if r.WrTfIsLast = '1' then
                            v.WriteTfGenState := Idle_s;
                        else
                            v.WriteTfGenState := MaxCalc_s;
                        end if;
                    end if;

                -- coverage off
                when others => null; -- unreachable code
                -- coverage on

            end case;

            -- ADefault Value
            v.AwCmdSent := '0';

            -- AW generation FSM
            case r.AwFsm is
                when Idle_s =>
                    if ((r.WrLowLat = '1') or (r.WrBeatsNoCmd >= signed('0' & r.WrTfBeats))) and
                       (r.WrOpenTrans < AxiMaxOpenTransactions_g) and (r.WrTfVld = '1') then
                        v.AwFsmRdy := '1';
                    end if;
                    if (r.AwFsmRdy = '1') and (r.WrTfVld = '1') then
                        v.AwFsmRdy      := '0';
                        v.M_Axi_AwAddr  := std_logic_vector(r.WrAddr);
                        Stdlv9Bit_v     := std_logic_vector(resize(r.WrTfBeats - 1, 9));
                        v.M_Axi_AwLen   := Stdlv9Bit_v(7 downto 0);
                        v.M_Axi_AwValid := '1';
                        v.AwFsm         := Wait_s;
                        v.AwCmdSent     := '1';
                        v.AwCmdSize     := r.WrTfBeats;
                        v.AwCmdSizeMin1 := r.WrTfBeats - 1;
                    end if;

                when Wait_s =>
                    if M_Axi_AwReady = '1' then
                        v.WrOpenTrans   := r.WrOpenTrans + 1;
                        v.M_Axi_AwValid := '0';
                        v.AwFsm         := Idle_s;
                    end if;

                -- coverage off
                when others => null; -- unreachable code
                -- coverage on

            end case;

            -- Update counter for FIFO entries that were not yet announced in a command
            -- .. Implementation is a bit weird for timing optimization reasons.
            -- Use registered WDataFifoWrite: This helps with timing and it does not introduce any risk since
            -- .. the decrement is still done immediately, the increment is delayed by one clock cycle. So worst
            -- .. case a High-Latency transfer is delayed by one cycle which is acceptable.
            v.WDataFifoWrite := WrData_Rdy_I and Wr_Valid;
            if r.AwCmdSent = '1' then
                if r.WDataFifoWrite = '1' then
                    v.WrBeatsNoCmd := r.WrBeatsNoCmd - signed('0' & r.AwCmdSizeMin1); -- Decrement by size and increment by one (timing opt)
                else
                    v.WrBeatsNoCmd := r.WrBeatsNoCmd - signed('0' & r.AwCmdSize);
                end if;
            elsif r.WDataFifoWrite = '1' then
                v.WrBeatsNoCmd := r.WrBeatsNoCmd + 1;
            end if;

            -- Default Values
            WDataTransfer_v := (r.WDataEna = '1') and (WrDataFifoOVld = '1') and (WrDataFifoORdy = '1');
            v.WDataFifoRd   := '0';
            StartWBurst_v   := false;

            -- W generation FSM
            case r.WFsm is
                when Idle_s =>
                    if WrTransFifoOutVld = '1' then
                        StartWBurst_v := true;      -- shared code
                    end if;

                when NonLast_s =>
                    if WDataTransfer_v then
                        if r.WDataBeats = 2 then
                            v.M_Axi_WLast := '1';
                            v.WFsm        := Last_s;
                        end if;
                        v.WDataBeats := r.WDataBeats - 1;
                    end if;

                when Last_s =>
                    if WDataTransfer_v then
                        -- Immediately start next transfer
                        -- .. WDataFifoRd is checked to leave time for the FIFO to complete the read in case of single cycle transfers
                        if (WrTransFifoOutVld = '1') and (r.WDataFifoRd = '0') then
                            StartWBurst_v := true;    -- shared code
                        -- End of transfer without a next one back-to-back
                        else
                            v.WDataEna    := '0';
                            v.WFsm        := Idle_s;
                            v.M_Axi_WLast := '0';
                        end if;
                    end if;

                -- coverage off
                when others => null; -- unreachable code
                -- coverage on

            end case;

            -- implementation of shared code
            if StartWBurst_v then
                v.WDataFifoRd := '1';
                v.WDataEna    := '1';
                v.WDataBeats  := unsigned(WrTransFifoBeats);
                if unsigned(WrTransFifoBeats) = 1 then
                    v.M_Axi_WLast := '1';
                    v.WFsm        := Last_s;
                else
                    v.M_Axi_WLast := '0';
                    v.WFsm        := NonLast_s;
                end if;
            end if;

            -- Default values
            v.Wr_Done  := '0';
            v.Wr_Error := '0';

            -- W response FSM
            if M_Axi_BValid = '1' then
                v.WrOpenTrans := v.WrOpenTrans - 1; -- Use v. because it may have been modified above and this modification has not to be overriden
                if WrRespIsLast = '1' then
                    if (M_Axi_BResp /= AxiResp_Okay_c) then
                        v.Wr_Error := '1';
                    else
                        v.Wr_Error    := r.WrRespError;
                        v.Wr_Done     := not r.WrRespError;
                        v.WrRespError := '0';
                    end if;
                elsif M_Axi_BResp /= AxiResp_Okay_c then
                    v.WrRespError := '1';
                end if;
            end if;

        end if;

        -- *** Read Related Code ***
        if ImplRead_g then

            -- Default Values
            RdMax4kBeats_v := (others => '0');

            -- Read generation FSM
            case r.ReadTfGenState is
                when Idle_s =>
                    v.CmdRd_Ready := '1';
                    if (r.CmdRd_Ready = '1') and (CmdRd_Valid = '1') then
                        v.CmdRd_Ready    := '0';
                        v.RdAddr         := unsigned(addrMasked(CmdRd_Addr));
                        v.RdBeats        := unsigned(CmdRd_Size);
                        v.RdLowLat       := CmdRd_LowLat;
                        v.ReadTfGenState := MaxCalc_s;
                    end if;

                when MaxCalc_s =>
                    RdMax4kBeats_v := resize(unsigned('0' & not r.RdAddr(11 downto UnusedAddrBits_c)) + 1, RdMax4kBeats_v'length);
                    if RdMax4kBeats_v > AxiMaxBeats_g then
                        v.RdMaxBeats := to_unsigned(AxiMaxBeats_g, BeatsBits_c);
                    else
                        v.RdMaxBeats := RdMax4kBeats_v(BeatsBits_c - 1 downto 0);
                    end if;
                    v.ReadTfGenState := GenTf_s;

                when GenTf_s =>
                    if (r.RdMaxBeats < r.RdBeats) then
                        v.RdTfBeats  := r.RdMaxBeats;
                        v.RdTfIsLast := '0';
                    else
                        v.RdTfBeats  := r.RdBeats(BeatsBits_c - 1 downto 0);
                        v.RdTfIsLast := '1';
                    end if;
                    v.RdTfVld        := '1';
                    v.ReadTfGenState := WriteTf_s;

                when WriteTf_s =>
                    if (r.RdTfVld = '1') and (r.ArFsmRdy = '1') then
                        v.RdTfVld := '0';
                        v.RdBeats := r.RdBeats - r.RdTfBeats;
                        v.RdAddr  := r.RdAddr + resize(2**UnusedAddrBits_c * r.RdTfBeats, v.RdAddr'length);
                        if r.RdTfIsLast = '1' then
                            v.ReadTfGenState := Idle_s;
                        else
                            v.ReadTfGenState := MaxCalc_s;
                        end if;
                    end if;

                -- coverage off
                when others => null; -- unreachable code
                -- coverage on

            end case;

            -- Default Values
            v.ArCmdSent := '0';

            -- AR Generation FSM
            case r.ArFsm is
                when Idle_s =>
                    if ((r.RdLowLat = '1') or (r.RdFifoSpaceFree >= signed('0' & r.RdTfBeats))) and
                       (r.RdOpenTrans < AxiMaxOpenTransactions_g) and (r.RdTfVld = '1') then
                        v.ArFsmRdy := '1';
                    end if;
                    if (r.ArFsmRdy = '1') and (r.RdTfVld = '1') then
                        v.ArFsmRdy      := '0';
                        v.M_Axi_ArAddr  := std_logic_vector(r.RdAddr);
                        Stdlv9Bit_v     := std_logic_vector(resize(r.RdTfBeats - 1, 9));
                        v.M_Axi_ArLen   := Stdlv9Bit_v(7 downto 0);
                        v.M_Axi_ArValid := '1';
                        v.ArFsm         := Wait_s;
                        v.ArCmdSent     := '1';
                        v.ArCmdSize     := r.RdTfBeats;
                        v.ArCmdSizeMin1 := r.RdTfBeats - 1;
                    end if;

                when Wait_s =>
                    if M_Axi_ArReady = '1' then
                        v.RdOpenTrans   := r.RdOpenTrans + 1;
                        v.M_Axi_ArValid := '0';
                        v.ArFsm         := Idle_s;
                    end if;

                -- coverage off
                when others => null; -- unreachable code
                -- coverage on

            end case;

            -- Update counter for FIFO entries that were not yet announced in a command
            -- .. Implementation is a bit weird for timing optimization reasons.
            -- Use registered RDataFifoRead: This helps with timing and it does not introduce any risk since
            -- .. the decrement is still done immediately, the increment is delayed by one clock cycle. So worst
            -- .. case a High-Latency transfer is delayed by one cycle which is acceptable.
            v.RDataFifoRead := Rd_Ready and RdDat_Vld_I;
            if r.ArCmdSent = '1' then
                if r.RDataFifoRead = '1' then
                    v.RdFifoSpaceFree := r.RdFifoSpaceFree - signed('0' & r.ArCmdSizeMin1); -- Decrement by size and increment by one (timing opt)
                else
                    v.RdFifoSpaceFree := r.RdFifoSpaceFree - signed('0' & r.ArCmdSize);
                end if;
            elsif r.RDataFifoRead = '1' then
                v.RdFifoSpaceFree := r.RdFifoSpaceFree + 1;
            end if;

            -- *** R Response Generation ***
            -- Default Values
            v.Rd_Done  := '0';
            v.Rd_Error := '0';

            -- FSM
            if RdRespLast = '1' then
                v.RdOpenTrans := v.RdOpenTrans - 1; -- Use v. because it may have been modified above and this modification has not to be overriden
                if RdRespIsLast = '1' then
                    if (M_Axi_RResp /= AxiResp_Okay_c) then
                        v.Rd_Error := '1';
                    else
                        v.Rd_Error    := r.RdRespError;
                        v.Rd_Done     := not r.RdRespError;
                        v.RdRespError := '0';
                    end if;
                elsif M_Axi_RResp /= AxiResp_Okay_c then
                    v.RdRespError := '1';
                end if;
            end if;

        end if;

        -- *** Update Signal ***
        r_next <= v;
    end process;

    -- *** Registered Process ***
    p_reg : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                -- Write Related Registers
                if ImplWrite_g then
                    r.CmdWr_Ready     <= '0';
                    r.WriteTfGenState <= Idle_s;
                    r.WrTfVld         <= '0';
                    r.AwFsm           <= Idle_s;
                    r.AwFsmRdy        <= '0';
                    r.AwCmdSent       <= '0';
                    r.M_Axi_AwValid   <= '0';
                    r.WDataFifoRd     <= '0';
                    r.WDataEna        <= '0';
                    r.WrOpenTrans     <= 0;
                    r.WrRespError     <= '0';
                    r.Wr_Done         <= '0';
                    r.Wr_Error        <= '0';
                    r.WrBeatsNoCmd    <= (others => '0');
                    r.WFsm            <= Idle_s;
                    r.WDataFifoWrite  <= '0';
                end if;
                -- Read Related Registers
                if ImplRead_g then
                    r.CmdRd_Ready     <= '0';
                    r.ReadTfGenState  <= Idle_s;
                    r.RdTfVld         <= '0';
                    r.ArFsmRdy        <= '0';
                    r.ArCmdSent       <= '0';
                    r.M_Axi_ArValid   <= '0';
                    r.ArFsm           <= Idle_s;
                    r.RdOpenTrans     <= (others => '0');
                    r.RdRespError     <= '0';
                    r.Rd_Done         <= '0';
                    r.Rd_Error        <= '0';
                    r.RdFifoSpaceFree <= to_signed(DataFifoDepth_g, r.RdFifoSpaceFree'length);
                    r.RDataFifoRead   <= '0';
                end if;
            end if;
        end if;
    end process;

    -- *** Outputs ***
    CmdWr_Ready   <= r.CmdWr_Ready;
    M_Axi_AwAddr  <= r.M_Axi_AwAddr;
    M_Axi_AwLen   <= r.M_Axi_AwLen;
    M_Axi_AwValid <= r.M_Axi_AwValid;
    M_Axi_WLast   <= r.M_Axi_WLast;
    Wr_Done       <= r.Wr_Done;
    Wr_Error      <= r.Wr_Error;
    CmdRd_Ready   <= r.CmdRd_Ready;
    M_Axi_ArAddr  <= r.M_Axi_ArAddr;
    M_Axi_ArLen   <= r.M_Axi_ArLen;
    M_Axi_ArValid <= r.M_Axi_ArValid;
    Rd_Done       <= r.Rd_Done;
    Rd_Error      <= r.Rd_Error;

    -- *** Constant Outputs ***
    M_Axi_AwSize  <= std_logic_vector(to_unsigned(log2(AxiDataWidth_g / 8), 3));
    M_Axi_ArSize  <= std_logic_vector(to_unsigned(log2(AxiDataWidth_g / 8), 3));
    M_Axi_AwBurst <= AxiBurst_Incr_c;
    M_Axi_ArBurst <= AxiBurst_Incr_c;
    M_Axi_AwCache <= "0011";              -- According AXI reference guide
    M_Axi_ArCache <= "0011";              -- According AXI reference guide
    M_Axi_AwProt  <= "000";               -- According AXI reference guide
    M_Axi_ArProt  <= "000";               -- According AXI reference guide
    M_Axi_AwLock  <= '0';                 -- Exclusive access support not implemented
    M_Axi_ArLock  <= '0';                 -- Exclusive access support not implemented
    M_Axi_BReady  <= '1' when ImplWrite_g else '0';

    -----------------------------------------------------------------------------------------------
    -- Instantiations
    -----------------------------------------------------------------------------------------------

    -- *** Write FIFOs ***
    g_write : if ImplWrite_g generate

        -- *** FIFO for data transfer FSM ***
        -- Generate Valid
        WrTransFifoInVld <= r.AwFsmRdy and r.WrTfVld;

        -- Instance
        i_fifo_wr_trans : entity work.olo_base_fifo_sync
            generic map (
                Width_g        => BeatsBits_c,
                Depth_g        => AxiMaxOpenTransactions_g,
                RamBehavior_g  => RamBehavior_g
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Data     => std_logic_vector(r.WrTfBeats),
                In_Valid    => WrTransFifoInVld,
                In_Ready    => open,                  -- Not required since maximum of open transactions is limitted
                Out_Data    => WrTransFifoBeats,
                Out_Valid   => WrTransFifoOutVld,
                Out_Ready   => r.WDataFifoRd
            );

        -- *** Write Data FIFO ***
        b_fifo_wr_data : block is
            signal InData  : std_logic_vector(Wr_Data'length + Wr_Be'length - 1 downto 0);
            signal OutData : std_logic_vector(InData'range);
        begin
            -- Assemble input
            InData(Wr_Data'high downto Wr_Data'low)                     <= Wr_Data;
            InData(Wr_Data'high + Wr_Be'length downto Wr_Data'high + 1) <= Wr_Be;

            -- Instance
            i_fifo_wr_data : entity work.olo_base_fifo_sync
                generic map (
                    Width_g         => Wr_Data'length + Wr_Be'length,
                    Depth_g         => DataFifoDepth_g,
                    RamBehavior_g   => RamBehavior_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Data     => InData,
                    In_Valid    => Wr_Valid,
                    In_Ready    => WrData_Rdy_I,
                    Out_Data    => OutData,
                    Out_Valid   => WrDataFifoOVld,
                    Out_Ready   => WrDataFifoORdy
                );

            -- Disassemble output
            M_Axi_WData    <= OutData(Wr_Data'high downto Wr_Data'low);
            M_Axi_WStrb    <= OutData(Wr_Data'high + Wr_Be'length downto Wr_Data'high + 1);
            M_Axi_WValid   <= WrDataFifoOVld and r.WDataEna;
            WrDataFifoORdy <= M_Axi_WReady and r.WDataEna;
            Wr_Ready       <= WrData_Rdy_I;
        end block;

        -- FIFO for write response FSM
        i_fifo_wr_resp : entity work.olo_base_fifo_sync
            generic map (
                Width_g        => 1,
                Depth_g        => AxiMaxOpenTransactions_g,
                RamBehavior_g  => RamBehavior_g
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Data(0)  => r.WrTfIsLast,
                In_Valid    => WrTransFifoInVld,
                In_Ready    => open,               -- Not required since maximum of open transactions is limitted
                Out_Data(0) => WrRespIsLast,
                Out_Valid   => WrRespFifoVld,
                Out_Ready   => M_Axi_BValid
            );

    end generate;

    -- Tie signals to ground if read not implemented
    g_nwrite : if not ImplWrite_g generate
        M_Axi_WStrb  <= (others => '0');
        M_Axi_WData  <= (others => '0');
        M_Axi_WValid <= '0';
        Wr_Ready     <= '0';
    end generate;

    -- *** Read FIFOs ***
    g_read : if ImplRead_g generate

        -- Read Data FIFO
        b_fifo_rd_data : block is
            signal InData, OutData : std_logic_vector(Rd_Data'length downto 0);
        begin
            -- Assemble Input data
            InData(M_Axi_RData'high downto 0) <= M_Axi_RData;
            -- Only forward last flag for the last burst of a user transfer (RdRespIsLast)
            InData(M_Axi_RData'high + 1) <= M_Axi_RLast and RdRespIsLast;

            -- FIFO
            i_fifo_rd_data : entity work.olo_base_fifo_sync
                generic map (
                    Width_g        => Rd_Data'length+1,
                    Depth_g        => DataFifoDepth_g,
                    RamBehavior_g  => RamBehavior_g
                )
                port map (
                    Clk         => Clk,
                    Rst         => Rst,
                    In_Data     => InData,
                    In_Valid    => M_Axi_RValid,
                    In_Ready    => M_Axi_RReady_I,
                    Out_Data    => OutData,
                    Out_Valid   => RdDat_Vld_I,
                    Out_Ready   => Rd_Ready
                );

            -- Disassemble Output data
            Rd_Data      <= OutData(Rd_Data'high downto 0);
            Rd_Last      <= OutData(Rd_Data'high+1);
            Rd_Valid     <= RdDat_Vld_I;
            M_Axi_RReady <= M_Axi_RReady_I;
        end block;

        -- Assemble FIFO input
        RdTransFifoInVld <= r.ArFsmRdy and r.RdTfVld;
        RdRespLast       <= M_Axi_RValid and M_Axi_RReady_I and M_Axi_RLast;

        -- FIFO instance
        i_fifo_rd_resp : entity work.olo_base_fifo_sync
            generic map (
                Width_g        => 1,
                Depth_g        => AxiMaxOpenTransactions_g,
                RamBehavior_g  => RamBehavior_g
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Data(0)  => r.RdTfIsLast,
                In_Valid    => RdTransFifoInVld,
                In_Ready    => open,               -- Not required since maximum of open transactions is limitted
                Out_Data(0) => RdRespIsLast,
                Out_Valid   => RdRespFifoVld,
                Out_Ready   => RdRespLast
            );

    end generate;

    -- Tie signals to ground if read not implemented
    g_nread : if not ImplRead_g generate
        M_Axi_RReady <= '0';
        Rd_Data      <= (others => '0');
        Rd_Valid     <= '0';
    end generate;

end architecture;
