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
-- Unit test bench for the private scrubber engine with the pacer enabled; see
-- olo_ft_private_scrubber_tb for the free-running cases, the behavioral RAM model description and
-- the reasoning behind the split. Pacer timing is configured through integer generics because
-- GHDL cannot override real generics on the command line; the TB converts them to the real
-- ScrubClkHz_g / ScrubPeriod_g at the generic map. The defaults (10 kHz, 15 ms) keep a pacer
-- period at 150 clock cycles so the paced cases simulate quickly.
-- vunit: run_all_in_same_sim
entity olo_ft_private_scrubber_paced_tb is
    generic (
        runner_cfg         : string;
        Width_g            : positive range 2 to 32 := 8;
        Depth_g            : positive               := 16;
        TotalReadLatency_g : positive range 1 to 3  := 1;
        SinglePortRam_g    : boolean                := false;
        ScrubClkHz_g       : natural                := 10000;
        ScrubPeriodMs_g    : positive               := 15
    );
end entity;

architecture sim of olo_ft_private_scrubber_paced_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time     := 10 ns;
    constant AddrWidth_c : positive := log2ceil(Depth_g);

    -- One scrub operation takes issue (1) + read latency (TotalReadLatency_g) + decide (1) cycles
    -- when the user is idle; a full pass is Depth_g back-to-back operations.
    constant OpCycles_c : positive := TotalReadLatency_g + 2;

    -- Pacer timing in clock cycles (see olo_ft_private_scrubber: 1 kHz base tick divided down).
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

    -- Model-clear request: wipes memory, error state and the in-flight response pipeline. Used in
    -- the per-case preamble so the cases stay order-independent under run_all_in_same_sim.
    signal ClearStrobe : std_logic := '0';

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

            -- Apply a clear request last (wins over any concurrent write or plant): wipe memory,
            -- error state and the in-flight response pipeline.
            if ClearStrobe = '1' then
                Mem      <= (others => (others => '0'));
                ErrState <= (others => ErrNone_c);

                DataPipe_v  := (others => (others => '0'));
                SecPipe_v   := (others => '0');
                DedPipe_v   := (others => '0');
                ValidPipe_v := (others => '0');

                Ram_Rd_Data   <= (others => '0');
                Ram_Rd_EccSec <= '0';
                Ram_Rd_EccDed <= '0';
                Ram_Rd_Valid  <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
        variable Gap1_v        : natural;
        variable Gap2_v        : natural;
        variable EventCnt_v    : natural;
        variable OverrunSeen_v : boolean;
        variable PassSeen_v    : boolean;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Per-case preamble: reset the DUT and wipe the behavioral model so every case starts
            -- from a pristine, order-independent state (all cases share one simulation). The reset
            -- also restarts the pacer, so period strobes are aligned to the case start.
            wait until rising_edge(Clk);
            Scrub_Enable <= '1';
            User_Wr_Ena  <= '0';
            User_Rd_Ena  <= '0';
            User_Wr_Addr <= (others => '0');
            User_Rd_Addr <= (others => '0');
            User_Wr_Data <= (others => '0');
            Rst          <= '1';
            ClearStrobe  <= '1';
            wait until rising_edge(Clk);
            ClearStrobe  <= '0';
            wait until rising_edge(Clk);
            Rst          <= '0';
            wait until rising_edge(Clk);

            -- Pacer: with the user idle, exactly one pass per period; the completion-to-completion
            -- gap equals the period and no overrun is flagged.
            if run("PacedOnePassPerPeriod") then
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
