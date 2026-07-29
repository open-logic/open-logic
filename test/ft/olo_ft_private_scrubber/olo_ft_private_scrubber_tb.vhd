---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_math.all;

library work;
    use work.olo_test_ft_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- Unit test bench for the private scrubber engine, driving its user/RAM channels directly against
-- a behavioral RAM model (payload memory plus a per-address error state and a read pipeline of
-- TotalReadLatency_g cycles). Direct control of every port and of the planted error state makes
-- the FSM branches (aborts, waits, pacer arming) far easier to hit than through the full RAM
-- wrappers; the wrappers' own test benches verify the integration.
--
-- This test bench deliberately does NOT use run_all_in_same_sim: the test cases carry per-test
-- VUnit configurations (free-running cases sweep TotalReadLatency_g x SinglePortRam_g; paced cases
-- enable the pacer through the integer ScrubPeriodMs_g generic, converted to the real ScrubPeriod_g
-- at the DUT generic map because GHDL cannot override real generics on the command line).
entity olo_ft_private_scrubber_tb is
    generic (
        runner_cfg         : string;
        Width_g            : positive range 2 to 32 := 8;
        Depth_g            : positive               := 16;
        TotalReadLatency_g : positive range 1 to 3  := 1;
        SinglePortRam_g    : boolean                := false;
        -- Pacer configuration as integers: ScrubPeriodMs_g = 0 keeps the pacer off (free-running).
        ScrubClkHz_g       : natural                := 100000000;
        ScrubPeriodMs_g    : natural                := 0
    );
end entity;

architecture sim of olo_ft_private_scrubber_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time     := 10 ns;
    constant AddrWidth_c : positive := log2ceil(Depth_g);

    -- One scrub operation takes issue (1) + read latency (TotalReadLatency_g) + decide (1) cycles
    -- when the user is idle; a full pass is Depth_g back-to-back operations.
    constant OpCycles_c   : positive := TotalReadLatency_g + 2;
    constant PassCycles_c : positive := Depth_g * OpCycles_c;

    -- Pacer timing in clock cycles (see olo_ft_private_scrubber: 1 kHz base tick divided down).
    constant Paced_c        : boolean := ScrubPeriodMs_g > 0;
    constant PeriodCycles_c : natural := (ScrubClkHz_g / 1000) * ScrubPeriodMs_g;

    -- Behavioral error state per address.
    constant ErrNone_c : natural := 0;
    constant ErrSec_c  : natural := 1;
    constant ErrDed_c  : natural := 2;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                  := '0';
    signal Rst            : std_logic                                  := '0';
    signal Scrub_Enable   : std_logic                                  := '1';
    signal User_Wr_Addr   : std_logic_vector(AddrWidth_c - 1 downto 0) := (others => '0');
    signal User_Wr_Ena    : std_logic                                  := '0';
    signal User_Wr_Data   : std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
    signal User_Rd_Addr   : std_logic_vector(AddrWidth_c - 1 downto 0) := (others => '0');
    signal User_Rd_Ena    : std_logic                                  := '0';
    signal Ram_Wr_Addr    : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Wr_Ena     : std_logic;
    signal Ram_Wr_Data    : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_Rd_Addr    : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Rd_Ena     : std_logic;
    signal Ram_Addr       : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Rd_Data    : std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
    signal Ram_Rd_EccSec  : std_logic                                  := '0';
    signal Ram_Rd_EccDed  : std_logic                                  := '0';
    signal Ram_Rd_Valid   : std_logic                                  := '0';
    signal User_Rd_Valid  : std_logic;
    signal Scrub_EccSec   : std_logic;
    signal Scrub_EccDed   : std_logic;
    signal Scrub_PassDone : std_logic;
    signal Scrub_Overrun  : std_logic;

    -- Effective RAM addresses seen by the behavioral model (collapsed port for single-port mode).
    signal Ram_RdAddrEff : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_WrAddrEff : std_logic_vector(AddrWidth_c - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- Behavioral RAM Model State
    -----------------------------------------------------------------------------------------------
    type Mem_t is array (0 to Depth_g - 1) of std_logic_vector(Width_g - 1 downto 0);
    type Err_t is array (0 to Depth_g - 1) of natural range 0 to 2;

    signal Mem      : Mem_t := (others => (others => '0'));
    signal ErrState : Err_t := (others => ErrNone_c);

    -- Error-plant request from the control process to the model (single driver on ErrState).
    -- Plain natural (not range-constrained): the bounds must match the plant procedure's signal
    -- formals exactly (vcom-1030 under Questa).
    signal PlantAddr   : natural   := 0;
    signal PlantState  : natural   := 0;
    signal PlantStrobe : std_logic := '0';

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    -- Plant an error state directly into the behavioral model (as a radiation upset would).
    procedure plant (
        address            : natural;
        state              : natural;
        signal Clk         : in  std_logic;
        signal PlantAddrS  : out natural;
        signal PlantStateS : out natural;
        signal PlantStrbS  : out std_logic) is
    begin
        wait until rising_edge(Clk);
        PlantAddrS  <= address;
        PlantStateS <= state;
        PlantStrbS  <= '1';
        wait until rising_edge(Clk);
        PlantStrbS  <= '0';
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_private_scrubber
        generic map (
            Depth_g            => Depth_g,
            Width_g            => Width_g,
            TotalReadLatency_g => TotalReadLatency_g,
            SinglePortRam_g    => SinglePortRam_g,
            ScrubClkHz_g       => real(ScrubClkHz_g),
            ScrubPeriod_g      => real(ScrubPeriodMs_g) / 1000.0
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            Scrub_Enable   => Scrub_Enable,
            User_Wr_Addr   => User_Wr_Addr,
            User_Wr_Ena    => User_Wr_Ena,
            User_Wr_Data   => User_Wr_Data,
            User_Rd_Addr   => User_Rd_Addr,
            User_Rd_Ena    => User_Rd_Ena,
            Ram_Wr_Addr    => Ram_Wr_Addr,
            Ram_Wr_Ena     => Ram_Wr_Ena,
            Ram_Wr_Data    => Ram_Wr_Data,
            Ram_Rd_Addr    => Ram_Rd_Addr,
            Ram_Rd_Ena     => Ram_Rd_Ena,
            Ram_Addr       => Ram_Addr,
            Ram_Rd_Data    => Ram_Rd_Data,
            Ram_Rd_EccSec  => Ram_Rd_EccSec,
            Ram_Rd_EccDed  => Ram_Rd_EccDed,
            Ram_Rd_Valid   => Ram_Rd_Valid,
            User_Rd_Valid  => User_Rd_Valid,
            Scrub_EccSec   => Scrub_EccSec,
            Scrub_EccDed   => Scrub_EccDed,
            Scrub_PassDone => Scrub_PassDone,
            Scrub_Overrun  => Scrub_Overrun
        );

    -- Single-port mode collapses read and write onto the shared Ram_Addr.
    Ram_RdAddrEff <= Ram_Addr when SinglePortRam_g else Ram_Rd_Addr;
    Ram_WrAddrEff <= Ram_Addr when SinglePortRam_g else Ram_Wr_Addr;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- Behavioral RAM Model
    -----------------------------------------------------------------------------------------------
    -- Read-before-write memory with a TotalReadLatency_g deep response pipeline and a per-address
    -- error state (none/SEC/DED). Any write stores a clean word (clearing the error state), which
    -- also makes an unwanted scrub writeback observable: a stale writeback corrupts Mem and a
    -- writeback on a DED word clears its error state.
    p_model : process (Clk) is
        type DataPipe_t is array (1 to TotalReadLatency_g) of std_logic_vector(Width_g - 1 downto 0);

        variable DataPipe_v  : DataPipe_t                                := (others => (others => '0'));
        variable SecPipe_v   : std_logic_vector(1 to TotalReadLatency_g) := (others => '0');
        variable DedPipe_v   : std_logic_vector(1 to TotalReadLatency_g) := (others => '0');
        variable ValidPipe_v : std_logic_vector(1 to TotalReadLatency_g) := (others => '0');
        variable RdAddr_v    : natural range 0 to Depth_g - 1;
        variable WrAddr_v    : natural range 0 to Depth_g - 1;
    begin
        if rising_edge(Clk) then

            -- Shift the response pipeline (stage 1 is next out).
            for i in 1 to TotalReadLatency_g - 1 loop
                DataPipe_v(i)  := DataPipe_v(i + 1);
                SecPipe_v(i)   := SecPipe_v(i + 1);
                DedPipe_v(i)   := DedPipe_v(i + 1);
                ValidPipe_v(i) := ValidPipe_v(i + 1);
            end loop;

            -- Accept the read issued in the elapsed cycle (read-before-write: response uses the
            -- memory and error state from before this edge's write).
            if Ram_Rd_Ena = '1' then
                RdAddr_v := to_integer(unsigned(Ram_RdAddrEff));

                DataPipe_v(TotalReadLatency_g)  := Mem(RdAddr_v);
                ValidPipe_v(TotalReadLatency_g) := '1';
                if ErrState(RdAddr_v) = ErrSec_c then
                    SecPipe_v(TotalReadLatency_g) := '1';
                else
                    SecPipe_v(TotalReadLatency_g) := '0';
                end if;
                if ErrState(RdAddr_v) = ErrDed_c then
                    DedPipe_v(TotalReadLatency_g) := '1';
                else
                    DedPipe_v(TotalReadLatency_g) := '0';
                end if;
            else
                DataPipe_v(TotalReadLatency_g)  := (others => '0');
                SecPipe_v(TotalReadLatency_g)   := '0';
                DedPipe_v(TotalReadLatency_g)   := '0';
                ValidPipe_v(TotalReadLatency_g) := '0';
            end if;

            -- Present the response due this cycle.
            Ram_Rd_Data   <= DataPipe_v(1);
            Ram_Rd_EccSec <= SecPipe_v(1);
            Ram_Rd_EccDed <= DedPipe_v(1);
            Ram_Rd_Valid  <= ValidPipe_v(1);

            -- Apply the write issued in the elapsed cycle (stores a clean word).
            if Ram_Wr_Ena = '1' then
                WrAddr_v := to_integer(unsigned(Ram_WrAddrEff));

                Mem(WrAddr_v)      <= Ram_Wr_Data;
                ErrState(WrAddr_v) <= ErrNone_c;
            end if;

            -- Apply a plant request (never used concurrently with a write to the same address).
            if PlantStrobe = '1' then
                ErrState(PlantAddr) <= PlantState;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
        variable PassCnt_v     : natural;
        variable Gap1_v        : natural;
        variable Gap2_v        : natural;
        variable IssuedCnt_v   : natural;
        variable ReturnCnt_v   : natural;
        variable EventCnt_v    : natural;
        variable OverrunSeen_v : boolean;
        variable PassSeen_v    : boolean;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset pulse; the behavioral model state deliberately survives (like a real RAM).
            wait until rising_edge(Clk);
            Scrub_Enable <= '1';
            Rst          <= '1';
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            Rst          <= '0';
            wait until rising_edge(Clk);

            -- With the user idle, back-to-back scrub operations make a pass take exactly
            -- Depth_g * (TotalReadLatency_g + 2) cycles; measure the gap between two completions.
            -- Free-running operation must never flag an overrun.
            if run("FreeRunPassCadence") then
                OverrunSeen_v := false;

                ftWaitPasses(1, Clk, Scrub_PassDone);

                Gap1_v := 0;

                loop
                    wait until rising_edge(Clk);
                    Gap1_v := Gap1_v + 1;
                    if Scrub_Overrun = '1' then
                        OverrunSeen_v := true;
                    end if;
                    exit when Scrub_PassDone = '1';
                end loop;

                check_equal(Gap1_v, PassCycles_c, "FreeRunPassCadence: pass gap is exactly one back-to-back pass");

                -- PassDone is a single-cycle pulse.
                wait until rising_edge(Clk);
                check_equal(Scrub_PassDone, '0', "FreeRunPassCadence: PassDone pulse width = 1");
                check_false(OverrunSeen_v, "FreeRunPassCadence: no overrun when free-running");

            -- Each planted SEC is observed by the scrubber exactly once (the first visit repairs
            -- the word), and the payload survives the writeback unchanged.
            elsif run("ScrubRepairsSec") then
                -- Park the scrubber at address 0 so the observation window is deterministic.
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(3, 16#A5#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                ftWrite(Depth_g - 1, 16#3C#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(3, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                plant(Depth_g - 1, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                ftCountOverPasses(2, Clk, Scrub_PassDone, Scrub_EccSec, EventCnt_v);

                check_equal(EventCnt_v, 2, "ScrubRepairsSec: each planted SEC observed exactly once");
                check_equal(ErrState(3), ErrNone_c, "ScrubRepairsSec: addr 3 repaired");
                check_equal(ErrState(Depth_g - 1), ErrNone_c, "ScrubRepairsSec: last addr repaired");
                check_equal(Mem(3), toUslv(16#A5#, Width_g), "ScrubRepairsSec: addr 3 payload intact");
                check_equal(Mem(Depth_g - 1), toUslv(16#3C#, Width_g), "ScrubRepairsSec: last addr payload intact");

            -- A DED word is observed on every pass (never repaired) and never written back.
            elsif run("ScrubDoesNotWriteDed") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(4, 16#77#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(4, ErrDed_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                ftCountOverPasses(2, Clk, Scrub_PassDone, Scrub_EccDed, EventCnt_v);

                check_equal(EventCnt_v, 2, "ScrubDoesNotWriteDed: DED observed once per pass");
                check_equal(ErrState(4), ErrDed_c, "ScrubDoesNotWriteDed: DED word never written back");
                check_equal(Mem(4), toUslv(16#77#, Width_g), "ScrubDoesNotWriteDed: payload untouched");

            -- The headline opportunistic property: a user read every second cycle must NOT starve
            -- the scrubber. Passes complete, a planted SEC is repaired, and every user read still
            -- returns exactly once on the masked User_Rd_Valid.
            elsif run("PartialTrafficCompletesPass") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                plant(2, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                PassCnt_v   := 0;
                IssuedCnt_v := 0;
                ReturnCnt_v := 0;

                for i in 1 to 8 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    if User_Rd_Ena = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if User_Rd_Valid = '1' then
                        ReturnCnt_v := ReturnCnt_v + 1;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                    if (i mod 2) = 0 then
                        User_Rd_Addr <= toUslv(1, AddrWidth_c);
                        User_Rd_Ena  <= '1';
                    else
                        User_Rd_Ena <= '0';
                    end if;
                end loop;

                wait until rising_edge(Clk);
                if User_Rd_Ena = '1' then
                    IssuedCnt_v := IssuedCnt_v + 1;
                end if;
                if User_Rd_Valid = '1' then
                    ReturnCnt_v := ReturnCnt_v + 1;
                end if;
                User_Rd_Ena <= '0';

                -- Drain the in-flight user reads.
                for i in 1 to TotalReadLatency_g + 2 loop
                    wait until rising_edge(Clk);
                    if User_Rd_Valid = '1' then
                        ReturnCnt_v := ReturnCnt_v + 1;
                    end if;
                end loop;

                check_true(PassCnt_v >= 2, "PartialTrafficCompletesPass: passes complete under 50% user reads");
                check_equal(ErrState(2), ErrNone_c, "PartialTrafficCompletesPass: SEC repaired under partial traffic");
                check_equal(ReturnCnt_v, IssuedCnt_v, "PartialTrafficCompletesPass: every user read returns exactly once");

            -- A user read EVERY cycle leaves no free read slot: the scrubber must be fully starved
            -- (no pass, planted SEC untouched) and no user read may be swallowed.
            elsif run("ReadSaturationStarves") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                plant(2, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                IssuedCnt_v := 0;
                ReturnCnt_v := 0;

                for i in 1 to 3 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    if User_Rd_Ena = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if User_Rd_Valid = '1' then
                        ReturnCnt_v := ReturnCnt_v + 1;
                    end if;
                    check_equal(Scrub_PassDone, '0', "ReadSaturationStarves: no pass completes under saturation");
                    User_Rd_Addr <= toUslv(1, AddrWidth_c);
                    User_Rd_Ena  <= '1';
                end loop;

                wait until rising_edge(Clk);
                if User_Rd_Ena = '1' then
                    IssuedCnt_v := IssuedCnt_v + 1;
                end if;
                if User_Rd_Valid = '1' then
                    ReturnCnt_v := ReturnCnt_v + 1;
                end if;
                User_Rd_Ena <= '0';

                for i in 1 to TotalReadLatency_g + 2 loop
                    wait until rising_edge(Clk);
                    if User_Rd_Valid = '1' then
                        ReturnCnt_v := ReturnCnt_v + 1;
                    end if;
                end loop;

                check_equal(ErrState(2), ErrSec_c, "ReadSaturationStarves: planted SEC persists (scrubber starved)");
                check_equal(ReturnCnt_v, IssuedCnt_v, "ReadSaturationStarves: every user read returns exactly once");

            -- Write traffic on every cycle blocks only the WRITEBACK: on a dual-port RAM the
            -- scrubber still reads (observes the SEC exactly once, then waits for a free write
            -- slot); on a single-port RAM the port is occupied, so it cannot even read. Either
            -- way the SEC is not repaired until the traffic stops, then repair completes.
            elsif run("WriteTrafficBlocksWriteback") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(0, 16#A5#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(0, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';

                -- Start the write storm while the scrubber is still disabled, then enable it
                -- under traffic so it never sees a free cycle before the storm.
                User_Wr_Addr <= toUslv(7, AddrWidth_c);
                User_Wr_Data <= toUslv(16#11#, Width_g);
                User_Wr_Ena  <= '1';
                wait until rising_edge(Clk);
                Scrub_Enable <= '1';

                EventCnt_v := 0;

                for i in 1 to 3 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    if Scrub_EccSec = '1' then
                        EventCnt_v := EventCnt_v + 1;
                    end if;
                    check_equal(Scrub_PassDone, '0', "WriteTrafficBlocksWriteback: pass blocked at the SEC word");
                    User_Wr_Addr <= toUslv(7, AddrWidth_c);
                    User_Wr_Data <= toUslv(i mod 256, Width_g);
                    User_Wr_Ena  <= '1';
                end loop;

                wait until rising_edge(Clk);
                User_Wr_Ena  <= '0';
                User_Wr_Addr <= (others => '0');
                User_Wr_Data <= (others => '0');

                if SinglePortRam_g then
                    check_equal(EventCnt_v, 0, "WriteTrafficBlocksWriteback: single port occupied, no scrub read");
                else
                    check_equal(EventCnt_v, 1, "WriteTrafficBlocksWriteback: SEC observed exactly once while waiting");
                end if;
                check_equal(ErrState(0), ErrSec_c, "WriteTrafficBlocksWriteback: SEC not repaired during traffic");

                -- Once the traffic stops the pending repair completes.
                for i in 1 to 4 * OpCycles_c loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(ErrState(0), ErrNone_c, "WriteTrafficBlocksWriteback: repair completes after traffic stops");
                check_equal(Mem(0), toUslv(16#A5#, Width_g), "WriteTrafficBlocksWriteback: payload intact");

            -- The RMW race, swept over every alignment: a clean user write to the address whose
            -- stale data the scrubber holds in flight must win; the stale writeback is aborted.
            elsif run("UserWriteToInFlightAddrSweep") then

                for k in 0 to OpCycles_c + 1 loop
                    -- Park at address 0 with the SEC in place.
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    ftWrite(0, 16#A5#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                    plant(0, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                    wait until rising_edge(Clk);
                    Rst <= '0';

                    -- Fresh user write k cycles after release.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    ftWrite(0, 16#77#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);

                    for i in 1 to 3 * OpCycles_c loop
                        wait until rising_edge(Clk);
                    end loop;

                    check_equal(Mem(0), toUslv(16#77#, Width_g),
                                "UserWriteToInFlightAddrSweep: fresh user data survives (k=" & integer'image(k) & ")");
                    check_equal(ErrState(0), ErrNone_c,
                                "UserWriteToInFlightAddrSweep: word clean (k=" & integer'image(k) & ")");
                end loop;

            -- An aborted operation must not advance the scrub address: after a user write hits the
            -- in-flight address, the next scrub read retries the SAME address.
            elsif run("AbortPreservesAddr") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(0, 16#A5#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(0, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                -- Wait for the scrubber's first read (user idle, so any RAM read is scrub-owned).
                loop
                    wait until rising_edge(Clk);
                    exit when Ram_Rd_Ena = '1';
                end loop;

                check_equal(Ram_RdAddrEff, toUslv(0, AddrWidth_c), "AbortPreservesAddr: first scrub read at addr 0");

                -- Single-cycle user write to the in-flight address (one cycle after issue).
                User_Wr_Addr <= toUslv(0, AddrWidth_c);
                User_Wr_Data <= toUslv(16#77#, Width_g);
                User_Wr_Ena  <= '1';
                wait until rising_edge(Clk);
                User_Wr_Ena  <= '0';
                User_Wr_Addr <= (others => '0');
                User_Wr_Data <= (others => '0');

                -- The aborted operation retries the same address.
                loop
                    wait until rising_edge(Clk);
                    exit when Ram_Rd_Ena = '1';
                end loop;

                check_equal(Ram_RdAddrEff, toUslv(0, AddrWidth_c), "AbortPreservesAddr: retry reads addr 0 again");

                for i in 1 to 2 * OpCycles_c loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Mem(0), toUslv(16#77#, Width_g), "AbortPreservesAddr: user data survived");
                check_equal(ErrState(0), ErrNone_c, "AbortPreservesAddr: word clean after user write");

            -- While the scrubber waits for a free write slot, user read RESPONSES keep flowing
            -- through the shared decode path. The held writeback payload must stay the scrubber's
            -- own read response; a naive implementation that keeps capturing the decoder output
            -- every cycle would write another address's data into the scrubbed word.
            elsif run("WritebackDataStableDuringWait") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(0, 16#A5#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                ftWrite(8, 16#EE#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(0, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';
                Scrub_Enable <= '1';

                -- Wait for the scrub read of addr 0 to be issued (user idle until here).
                loop
                    wait until rising_edge(Clk);
                    exit when Ram_Rd_Ena = '1';
                end loop;

                -- Now block the writeback with continuous writes to addr 7 while reading addr 8
                -- every cycle, flooding the response path with foreign data.
                for i in 1 to 4 * OpCycles_c loop
                    User_Wr_Addr <= toUslv(7, AddrWidth_c);
                    User_Wr_Data <= toUslv(16#11#, Width_g);
                    User_Wr_Ena  <= '1';
                    User_Rd_Addr <= toUslv(8, AddrWidth_c);
                    User_Rd_Ena  <= '1';
                    wait until rising_edge(Clk);
                end loop;

                User_Wr_Ena  <= '0';
                User_Rd_Ena  <= '0';
                User_Wr_Addr <= (others => '0');
                User_Rd_Addr <= (others => '0');
                User_Wr_Data <= (others => '0');

                -- The pending writeback (or, single-port, the whole retried operation) completes.
                for i in 1 to 4 * OpCycles_c loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Mem(0), toUslv(16#A5#, Width_g),
                            "WritebackDataStableDuringWait: writeback used the scrubber's own read data");
                check_equal(ErrState(0), ErrNone_c, "WritebackDataStableDuringWait: SEC repaired");

            -- Scrub_Enable = '0' suspends scrubbing entirely: no scrub read is issued and a planted
            -- SEC survives for longer than a full pass would take; after re-enabling it is repaired.
            elsif run("EnableSuspendsScrubbing") then
                Rst          <= '1';
                Scrub_Enable <= '0';
                ftWrite(5, 16#B4#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(5, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                wait until rising_edge(Clk);
                Rst          <= '0';

                for i in 1 to 2 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    check_equal(Ram_Rd_Ena, '0', "EnableSuspendsScrubbing: no scrub read while disabled");
                    check_equal(Scrub_PassDone, '0', "EnableSuspendsScrubbing: no pass while disabled");
                end loop;

                check_equal(ErrState(5), ErrSec_c, "EnableSuspendsScrubbing: SEC persists while disabled");

                Scrub_Enable <= '1';

                ftWaitPasses(1, Clk, Scrub_PassDone);

                check_equal(ErrState(5), ErrNone_c, "EnableSuspendsScrubbing: SEC repaired after re-enable");
                check_equal(Mem(5), toUslv(16#B4#, Width_g), "EnableSuspendsScrubbing: payload intact");

            -- Reset at every alignment of a scrub operation: the read-valid pipeline is squashed
            -- (no stale status pulse during reset), the address restarts, and scrubbing recovers.
            elsif run("ResetMidPassSweep") then

                for k in 0 to 2 * OpCycles_c + 1 loop
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    plant(0, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);
                    wait until rising_edge(Clk);
                    Rst <= '0';

                    -- Let the scrubber run to the swept alignment, then reset mid-operation.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    Rst <= '1';
                    wait until rising_edge(Clk);

                    -- While in reset (and one cycle beyond), no stale scrub status may pulse.
                    for i in 1 to 2 loop
                        wait until rising_edge(Clk);
                        check_equal(Scrub_EccSec, '0', "ResetMidPassSweep: no stale SEC pulse under reset (k=" & integer'image(k) & ")");
                        check_equal(Scrub_EccDed, '0', "ResetMidPassSweep: no stale DED pulse under reset (k=" & integer'image(k) & ")");
                        check_equal(Scrub_PassDone, '0', "ResetMidPassSweep: no stale PassDone under reset (k=" & integer'image(k) & ")");
                    end loop;

                    Rst <= '0';
                    wait until rising_edge(Clk);
                end loop;

                -- After the last reset the scrubber recovers and repairs the planted SEC.
                ftWaitPasses(1, Clk, Scrub_PassDone);

                check_equal(ErrState(0), ErrNone_c, "ResetMidPassSweep: scrubbing recovers after reset");

            -- Pacer: with the user idle, exactly one pass per period; the completion-to-completion
            -- gap equals the period and no overrun is flagged.
            elsif run("PacedOnePassPerPeriod") then
                OverrunSeen_v := false;

                ftWaitPasses(1, Clk, Scrub_PassDone);

                Gap1_v := 0;

                loop
                    wait until rising_edge(Clk);
                    Gap1_v := Gap1_v + 1;
                    if Scrub_Overrun = '1' then
                        OverrunSeen_v := true;
                    end if;
                    exit when Scrub_PassDone = '1';
                end loop;

                Gap2_v := 0;

                loop
                    wait until rising_edge(Clk);
                    Gap2_v := Gap2_v + 1;
                    if Scrub_Overrun = '1' then
                        OverrunSeen_v := true;
                    end if;
                    exit when Scrub_PassDone = '1';
                end loop;

                check_true(abs(integer(Gap1_v) - integer(PeriodCycles_c)) <= 2,
                           "PacedOnePassPerPeriod: first gap is one period");
                check_true(abs(integer(Gap2_v) - integer(PeriodCycles_c)) <= 2,
                           "PacedOnePassPerPeriod: second gap is one period");
                check_false(OverrunSeen_v, "PacedOnePassPerPeriod: no overrun while passes fit the period");

            -- Pacer: total read-port saturation prevents the armed pass from finishing, so the
            -- next period strobes flag an overrun; once the port is idle again the overruns stop.
            elsif run("PacedOverrunWhenStarved") then
                EventCnt_v := 0;

                for i in 1 to 3 * PeriodCycles_c loop
                    wait until rising_edge(Clk);
                    if Scrub_Overrun = '1' then
                        EventCnt_v := EventCnt_v + 1;
                    end if;
                    User_Rd_Addr <= toUslv(1, AddrWidth_c);
                    User_Rd_Ena  <= '1';
                end loop;

                wait until rising_edge(Clk);
                User_Rd_Ena <= '0';

                check_true(EventCnt_v >= 1, "PacedOverrunWhenStarved: overrun flagged while starved");

                -- Recovery: skip one period (the pending pass completes), then a full period must
                -- pass without any further overrun.
                for i in 1 to PeriodCycles_c loop
                    wait until rising_edge(Clk);
                end loop;

                EventCnt_v := 0;

                for i in 1 to PeriodCycles_c loop
                    wait until rising_edge(Clk);
                    if Scrub_Overrun = '1' then
                        EventCnt_v := EventCnt_v + 1;
                    end if;
                end loop;

                check_equal(EventCnt_v, 0, "PacedOverrunWhenStarved: no overrun after the port is idle again");

            -- Suspending via Scrub_Enable in the middle of a paced pass must NOT flag an overrun:
            -- suspension also disarms the period watchdog. Scrubbing resumes after re-enabling.
            elsif run("PacedEnableDropNoOverrun") then
                ftWaitPasses(1, Clk, Scrub_PassDone);

                -- Wait for the next pass to start (first scrub read; user idle) and get mid-pass.
                loop
                    wait until rising_edge(Clk);
                    exit when Ram_Rd_Ena = '1';
                end loop;

                for i in 1 to 3 * OpCycles_c loop
                    wait until rising_edge(Clk);
                end loop;

                Scrub_Enable <= '0';

                OverrunSeen_v := false;
                PassSeen_v    := false;

                for i in 1 to 3 * PeriodCycles_c loop
                    wait until rising_edge(Clk);
                    if Scrub_Overrun = '1' then
                        OverrunSeen_v := true;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassSeen_v := true;
                    end if;
                end loop;

                check_false(OverrunSeen_v, "PacedEnableDropNoOverrun: no overrun while suspended mid-pass");
                check_false(PassSeen_v, "PacedEnableDropNoOverrun: no pass completes while suspended");

                Scrub_Enable <= '1';

                -- Scrubbing resumes with the next period strobe and completes without an overrun.
                Gap1_v        := 0;
                OverrunSeen_v := false;

                loop
                    wait until rising_edge(Clk);
                    Gap1_v := Gap1_v + 1;
                    if Scrub_Overrun = '1' then
                        OverrunSeen_v := true;
                    end if;
                    exit when Scrub_PassDone = '1' or Gap1_v >= 3 * PeriodCycles_c;
                end loop;

                check_true(Gap1_v < 3 * PeriodCycles_c, "PacedEnableDropNoOverrun: scrubbing resumes after re-enable");
                check_false(OverrunSeen_v, "PacedEnableDropNoOverrun: no overrun on resume");

            -- Pacer: a paced scrubber still repairs, just on the paced schedule.
            elsif run("PacedRepairsSec") then
                ftWrite(3, 16#5C#, Clk, User_Wr_Addr, User_Wr_Data, User_Wr_Ena);
                plant(3, ErrSec_c, Clk, PlantAddr, PlantState, PlantStrobe);

                ftWaitPasses(2, Clk, Scrub_PassDone);

                check_equal(ErrState(3), ErrNone_c, "PacedRepairsSec: SEC repaired by the paced scrubber");
                check_equal(Mem(3), toUslv(16#5C#, Width_g), "PacedRepairsSec: payload intact");

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
