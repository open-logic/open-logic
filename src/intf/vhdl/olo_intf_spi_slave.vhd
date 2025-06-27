---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple SPI-slave
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_spi_slave.md
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
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_intf_spi_slave is
    generic (
        TransWidth_g                : positive             := 32;
        SpiCpol_g                   : natural range 0 to 1 := 0;
        SpiCpha_g                   : natural range 0 to 1 := 0;
        LsbFirst_g                  : boolean              := false;
        ConsecutiveTransactions_g   : boolean              := false;
        InternalTriState_g          : boolean              := true
    );
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- RX Data
        Rx_Valid        : out   std_logic;
        Rx_Data         : out   std_logic_vector(TransWidth_g - 1 downto 0);
        -- TX Data
        Tx_Valid        : in    std_logic                                   := '1';
        Tx_Ready        : out   std_logic;
        Tx_Data         : in    std_logic_vector(TransWidth_g - 1 downto 0) := (others => '0');
        -- Response Interface
        Resp_Valid      : out   std_logic;
        Resp_Sent       : out   std_logic;
        Resp_Aborted    : out   std_logic;
        Resp_CleanEnd   : out   std_logic;
        -- SPI
        Spi_Sclk        : in    std_logic;
        Spi_Mosi        : in    std_logic                                   := '0';
        Spi_Cs_n        : in    std_logic;
        -- Miso with internal Tristate
        Spi_Miso        : out   std_logic;
        -- Miso with external Tristate
        Spi_Miso_o      : out   std_logic;
        Spi_Miso_t      : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_intf_spi_slave is

    -- *** Types ***
    type State_t is (Idle_s, LatchTx_s, WaitSampleEdge_s, WaitInactiveEdge_s, WaitCsHigh_s);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        SpiCsnLast      : std_logic;
        SpiSclkLast     : std_logic;
        State           : State_t;
        Tx_Ready        : std_logic;
        SpiMisoData     : std_logic;
        SpiMisoTristate : std_logic;
        BitCnt          : integer range 0 to TransWidth_g;
        ShiftReg        : std_logic_vector(TransWidth_g - 1 downto 0);
        IsConsecutive   : boolean;
        Rx_Valid        : std_logic;
        Rx_Data         : std_logic_vector(TransWidth_g - 1 downto 0);
        Resp_Sent       : std_logic;
        Resp_Aborted    : std_logic;
        Resp_Valid      : std_logic;
        Resp_CleanEnd   : std_logic;
        RxOutput        : std_logic;
        DataLatched     : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal SpiMosi_i : std_logic;
    signal SpiSclk_i : std_logic;
    signal SpiCsn_i  : std_logic;

    -- *** Constants ***
    constant TxIdx_c : integer := choose(LsbFirst_g, 0, TransWidth_g - 1);

begin

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v                  : TwoProcess_r;
        variable CsnRe_v, CsnFe_v   : std_logic;
        variable SclkRe_v, SclkFe_v : std_logic;
        variable SampleEdge_v       : std_logic;
        variable TrasmitEdge_v      : std_logic;
        variable LeaveState_v       : boolean;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        CsnRe_v         := '0';
        CsnFe_v         := '0';
        SclkRe_v        := '0';
        SclkFe_v        := '0';
        LeaveState_v    := false;
        v.Rx_Valid      := '0';
        v.Resp_Sent     := '0';
        v.Resp_Aborted  := '0';
        v.Resp_Valid    := '0';
        v.RxOutput      := '0';
        v.Resp_CleanEnd := '0';

        -- *** Edge Detections ***
        if SpiCsn_i /= to01(r.SpiCsnLast) then
            CsnRe_v := SpiCsn_i;
            CsnFe_v := not SpiCsn_i;
        end if;
        v.SpiCsnLast := SpiCsn_i;
        if SpiSclk_i /= to01(r.SpiSclkLast) then
            SclkRe_v := SpiSclk_i;
            SclkFe_v := not SpiSclk_i;
        end if;
        v.SpiSclkLast := SpiSclk_i;
        -- Define Clock Edges
        if SpiCpol_g = SpiCpha_g then
            SampleEdge_v  := SclkRe_v;
            TrasmitEdge_v := SclkFe_v;
        else
            SampleEdge_v  := SclkFe_v;
            TrasmitEdge_v := SclkRe_v;
        end if;

        -- *** State Machine ***
        case r.State is
            when Idle_s =>
                -- In idle MISO is tristated
                v.SpiMisoTristate := '1';
                -- Acquire Tx data on falling edge of CS (transaction start)
                if CsnFe_v = '1' then
                    v.State       := LatchTx_s;
                    v.DataLatched := '0';
                    v.Tx_Ready    := '1';
                end if;
                -- First Transaction is not Consecutive
                v.IsConsecutive := false;

            when LatchTx_s =>
                v.BitCnt := 0;
                -- Latch data
                if Tx_Valid = '1' then
                    v.ShiftReg    := Tx_Data;
                    v.Tx_Ready    := '0';
                    v.DataLatched := '1';
                    -- Apply output data immediately after data was latched
                    v.SpiMisoData := Tx_Data(TxIdx_c);
                end if;
                -- For CPHA=0, data bust be valid on falling edge of CS immediately
                if SpiCpha_g = 0 and not r.IsConsecutive then
                    LeaveState_v := true;
                -- For CPHA=1, data must be valid latest on transmit edge of SCLK
                -- Same applies for Consecutive Transactions
                else
                    if TrasmitEdge_v = '1' then
                        LeaveState_v := true;
                    end if;
                end if;
                -- Leaving the state
                if LeaveState_v then
                    v.State := WaitSampleEdge_s;
                    -- Data was not present in time
                    if r.DataLatched = '0' and Tx_Valid = '0' then
                        v.ShiftReg := (others => '0');
                    end if;
                    v.Tx_Ready := '0';
                    -- Apply first data bit
                    v.SpiMisoData     := v.ShiftReg(TxIdx_c);
                    v.SpiMisoTristate := '0';
                end if;

            when WaitSampleEdge_s =>
                if SampleEdge_v = '1' then
                    if LsbFirst_g = false then
                        v.ShiftReg    := r.ShiftReg(r.ShiftReg'high - 1 downto 0) & SpiMosi_i;
                        v.SpiMisoData := r.ShiftReg(r.ShiftReg'high-1);
                    else
                        v.ShiftReg    := SpiMosi_i & r.ShiftReg(r.ShiftReg'high downto 1);
                        v.SpiMisoData := r.ShiftReg(1);
                    end if;
                    -- Last bit
                    if r.BitCnt = TransWidth_g - 1 then
                        -- Suppress needless MISO toggle at the end of a transaction
                        v.SpiMisoData := r.SpiMisoData;
                        -- Output Rx Data
                        v.RxOutput := '1'; -- Done in next cycle to await shift register update
                        -- Transaction completed successfully
                        v.Resp_Valid := '1';
                        v.Resp_Sent  := '1';
                        -- If consecutive transactions are enabled, latch next Tx data
                        if ConsecutiveTransactions_g then
                            v.State       := LatchTx_s;
                            v.DataLatched := '0';
                            v.Tx_Ready    := '1';
                        -- Otherwise, wait for CS to go high
                        else
                            v.State := WaitCsHigh_s;
                        end if;
                    -- Continue with next bit
                    else
                        v.State := WaitInactiveEdge_s;
                    end if;
                end if;
                -- After first bit, transactions are consecutive
                v.IsConsecutive := true;

            when WaitInactiveEdge_s =>
                -- Transmit on Transmit Edge
                if TrasmitEdge_v = '1' then
                    v.State  := WaitSampleEdge_s;
                    v.BitCnt := r.BitCnt + 1;
                end if;

            when WaitCsHigh_s => null;  -- Return to idle is handled after FSM

            -- coverage off
            when others => null; -- unreachable code
            -- coverage on
        end case;

        -- Output RX Data
        if r.RxOutput = '1' then
            v.Rx_Valid := '1';
            v.Rx_Data  := r.ShiftReg;
        end if;

        -- Return to idle if CS is high
        if SpiCsn_i = '1' then
            v.State           := Idle_s;
            v.SpiMisoTristate := '1';
            -- If Cs high is not expected, transaction was aborted
            if r.State /= WaitCsHigh_s and r.State /= Idle_s and r.DataLatched = '1' then
                v.Resp_Valid   := '1';
                v.Resp_Aborted := '1';
            -- Otherwise it is a clean-end
            elsif r.State /= Idle_s then
                v.Resp_Valid    := '1';
                v.Resp_CleanEnd := '1';
            end if;
        end if;

        -- *** assign signal ***
        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Rx_Valid      <= r.Rx_Valid;
    Rx_Data       <= r.Rx_Data;
    Tx_Ready      <= r.Tx_Ready;
    Resp_Valid    <= r.Resp_Valid;
    Resp_Sent     <= r.Resp_Sent;
    Resp_Aborted  <= r.Resp_Aborted;
    Resp_CleanEnd <= r.Resp_CleanEnd;

    -- Inernal Tri-State Buffers
    g_int_tristate : if InternalTriState_g generate
        Spi_Miso <= r.SpiMisoData when r.SpiMisoTristate = '0' else 'Z';
    end generate;

    -- External Tri-State Buffers
    g_ext_tristate : if not InternalTriState_g generate
        Spi_Miso_o <= r.SpiMisoData;
        Spi_Miso_t <= r.SpiMisoTristate;
    end generate;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.SpiCsnLast      <= '1';
                r.State           <= Idle_s;
                r.Tx_Ready        <= '0';
                r.SpiMisoTristate <= '1';
                r.RxOutput        <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Component Instantiation
    -----------------------------------------------------------------------------------------------
    -- SPI Input synchronization
    b_sync : block is
        signal SyncIn, SyncOut : std_logic_vector(2 downto 0);
    begin
        -- Input assembly
        SyncIn(0) <= Spi_Sclk;
        SyncIn(1) <= Spi_Mosi;
        SyncIn(2) <= Spi_Cs_n;

        -- Instance
        i_sync : entity work.olo_intf_sync
            generic map (
                Width_g     => 3,
                RstLevel_g  => '1'
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                DataAsync   => SyncIn,
                DataSync    => SyncOut
            );

        -- Output disassembly
        SpiSclk_i <= SyncOut(0);
        SpiMosi_i <= SyncOut(1);
        SpiCsn_i  <= SyncOut(2);
    end block;

end architecture;

