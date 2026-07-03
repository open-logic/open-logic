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
    use olo.olo_ft_pkg_ecc.all;

library work;
    use work.olo_test_ft_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_ram_sp_scrub_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_ram_sp_scrub_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);
    constant Depth_c         : positive := 200;

    -- User-visible read latency and the length of one full scrub pass with the user idle (one
    -- scrub operation per Latency_c + 2 cycles).
    constant Latency_c    : natural  := RamRdLatency_g + EccPipeline_g;
    constant PassCycles_c : positive := Depth_c * (Latency_c + 2);

    -----------------------------------------------------------------------------------------------
    -- Bit-flip pattern helpers
    -----------------------------------------------------------------------------------------------
    function singleBit (idx : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    begin
        Result_v(idx) := '1';
        return Result_v;
    end function;

    function doubleBit (idxA : natural; idxB : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    begin
        Result_v(idxA) := '1';
        Result_v(idxB) := '1';
        return Result_v;
    end function;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                        := '0';
    signal Rst            : std_logic                                        := '0';
    signal Addr           : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal WrEna          : std_logic                                        := '0';
    signal WrData         : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal RdEna          : std_logic                                        := '0';
    signal RdData         : std_logic_vector(Width_g - 1 downto 0);
    signal RdValid        : std_logic;
    signal RdEccSec       : std_logic;
    signal RdEccDed       : std_logic;
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0)   := (others => '0');
    signal ErrInj_Valid   : std_logic                                        := '0';
    signal Scrub_Enable   : std_logic                                        := '1';
    signal Scrub_EccSec   : std_logic;
    signal Scrub_EccDed   : std_logic;
    signal Scrub_PassDone : std_logic;
    signal Scrub_Overrun  : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sp_scrub
        generic map (
            Depth_g        => Depth_c,
            Width_g        => Width_g,
            RamBehavior_g  => RamBehavior_g,
            RamRdLatency_g => RamRdLatency_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Addr            => Addr,
            WrEna           => WrEna,
            WrData          => WrData,
            RdEna           => RdEna,
            RdData          => RdData,
            RdValid         => RdValid,
            RdEccSec        => RdEccSec,
            RdEccDed        => RdEccDed,
            ErrInj_BitFlip  => ErrInj_BitFlip,
            ErrInj_Valid    => ErrInj_Valid,
            Scrub_Enable    => Scrub_Enable,
            Scrub_EccSec    => Scrub_EccSec,
            Scrub_EccDed    => Scrub_EccDed,
            Scrub_PassDone  => Scrub_PassDone,
            Scrub_Overrun   => Scrub_Overrun
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
        variable RdValidCnt_v   : natural;
        variable IssuedCnt_v    : natural;
        variable UserValidCnt_v : natural;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset pulse: brings the scrubber FSM to a known Idle state for every case.
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Basic write / read still works with the scrubber present. The scrubber may rewrite
            -- any clean cell with its corrected codeword between user writes; on a clean cell the
            -- corrected codeword equals the original so the user reads the value they wrote.
            if run("Basic") then
                ft_write(1, 5, Clk, Addr, WrData, WrEna);
                ft_write(2, 6, Clk, Addr, WrData, WrEna);
                ft_write(3, 7, Clk, Addr, WrData, WrEna);
                ft_check_ecc(1, 5, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Basic 1=5");
                ft_check_ecc(2, 6, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Basic 2=6");
                ft_check_ecc(3, 7, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Basic 3=7");
                ft_check_ecc(1, 5, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Basic re-read 1=5");

            -- Simultaneous write + read on the shared port: the wrapper's port-collapse mux
            -- claims the combined op behaves like plain olo_ft_ram_sp (one Addr, RamBehavior_g
            -- decides the read data). Pre-write a known value, then write a new value with
            -- WrEna = RdEna = '1' in one cycle. RBW returns the old word, WBR the new one; both
            -- decode clean. A subsequent plain read returns the new value.
            elsif run("WriteReadSameCycle") then
                ft_write(60, 16#0F#, Clk, Addr, WrData, WrEna);

                wait until rising_edge(Clk);
                Addr   <= toUslv(60, Addr'length);
                WrData <= toUslv(16#F0#, WrData'length);
                WrEna  <= '1';
                RdEna  <= '1';
                wait until rising_edge(Clk);
                WrEna  <= '0';
                RdEna  <= '0';
                Addr   <= toUslv(0, Addr'length);
                WrData <= toUslv(0, WrData'length);

                for i in 1 to Latency_c loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(RdValid,  '1', "WriteReadSameCycle: RdValid pulses for the combined op");
                check_equal(RdEccSec, '0', "WriteReadSameCycle EccSec");
                check_equal(RdEccDed, '0', "WriteReadSameCycle EccDed");

                if RamBehavior_g = "RBW" then
                    check_equal(RdData, toUslv(16#0F#, RdData'length), "WriteReadSameCycle: RBW returns the old word");
                else
                    check_equal(RdData, toUslv(16#F0#, RdData'length), "WriteReadSameCycle: WBR returns the new word");
                end if;

                ft_check_ecc(60, 16#F0#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "WriteReadSameCycle: new value persisted");

            -- With user idle, the scrubber walks the address space and pulses Scrub_PassDone on
            -- rollover from Depth_g - 1 to 0. Confirm at least three pulses within the watchdog
            -- window; free-running scrubbing must never flag an overrun (the pacer is off).
            elsif run("ScrubPassDone") then
                ft_count_over_passes(3, Clk, Scrub_PassDone, Scrub_Overrun, RdValidCnt_v);
                check_equal(RdValidCnt_v, 0, "ScrubPassDone: no overrun when free-running");

            -- Plant SEC errors at two distinct addresses; idle the user; wait for two full scrubber
            -- passes; verify the cells now read clean. Each planted SEC must be observed by the
            -- scrubber exactly once (Scrub_EccSec pulses once): the first
            -- visit repairs the cell, so later passes read it clean.
            elsif run("ScrubFixesSec") then
                ft_write_flip(10, 16#AB#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                ft_write_flip(20, 16#CD#, singleBit(2),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                ft_count_over_passes(2, Clk, Scrub_PassDone, Scrub_EccSec, RdValidCnt_v);

                check_equal(RdValidCnt_v, 2,
                            "ScrubFixesSec: each planted SEC observed by the scrubber exactly once");

                ft_check_ecc(10, 16#AB#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubFixesSec addr10 cleaned");
                ft_check_ecc(20, 16#CD#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubFixesSec addr20 cleaned");

            -- DED reads are reported but the writeback is suppressed (corrected data is unreliable).
            -- The scrubber must observe the DED word on its own reads exactly once per pass
            -- (Scrub_EccDed pulses; the word is never repaired, so
            -- both passes of the window see it) and, after idle scrub time, the DED flag must
            -- still be set on a user read.
            elsif run("ScrubDoesNotWriteOnDed") then
                ft_write_flip(70, 16#EE#, doubleBit(0, 1),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                ft_count_over_passes(2, Clk, Scrub_PassDone, Scrub_EccDed, RdValidCnt_v);

                check_equal(RdValidCnt_v, 2,
                            "ScrubDoesNotWriteOnDed: DED word observed exactly once per pass (never repaired)");

                ft_check_ecc(70, 0, '0', '1', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubDoesNotWriteOnDed addr70 still Ded", check_data => false);

            -- Continuous user reads occupy the single shared port, so the scrubber cannot repair:
            -- a SEC planted at addr 128 must still be reported after hammering reads at addr 129
            -- for a long window. Once the user idles, the scrubber repairs it.
            elsif run("UserTrafficStarvesScrubRepair") then
                ft_write_flip(128, 16#AA#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    Addr  <= toUslv(129, Addr'length);
                    RdEna <= '1';
                end loop;

                wait until rising_edge(Clk);
                RdEna <= '0';
                Addr  <= (others => '0');

                -- The SEC is still reported: the scrubber never got a port slot to repair it.
                -- (The resumed scrubber needs far longer than this check to reach addr 128.)
                ft_check_ecc(128, 16#AA#, '1', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "UserTrafficStarvesScrubRepair: SEC persists under read hammering");

                -- With the user idle again the scrubber repairs the cell.
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(128, 16#AA#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "UserTrafficStarvesScrubRepair: repaired after the user idles");

            -- SP arbitration: continuous alternating user activity (write / read on adjacent
            -- addresses) occupies the single port every cycle, so the scrubber is starved
            -- completely: no pass completes and a SEC planted before the storm is still reported
            -- afterwards (a scrubber writeback would have repaired it).
            elsif run("UserBusyNoCorruption") then
                ft_write_flip(100, 16#5A#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 200 loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Addr   <= toUslv(150, Addr'length);
                        WrData <= toUslv(i, Width_g);
                        WrEna  <= '1';
                        RdEna  <= '0';
                    else
                        Addr  <= toUslv(151, Addr'length);
                        WrEna <= '0';
                        RdEna <= '1';
                    end if;
                    -- Fully starved: the scrubber never gets an idle port cycle, so it can never
                    -- complete a pass.
                    check_equal(Scrub_PassDone, '0',
                                "UserBusyNoCorruption: scrubber fully starved while the user saturates the port");
                end loop;

                wait until rising_edge(Clk);
                WrEna  <= '0';
                RdEna  <= '0';
                Addr   <= (others => '0');
                WrData <= (others => '0');

                -- Let the storm's in-flight reads return (ft_check_ecc aligns to its own read, so
                -- this only keeps the window clean), then verify the planted SEC survived: the
                -- starved scrubber must not have written anything.
                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                end loop;

                ft_check_ecc(100, 16#5A#, '1', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "UserBusyNoCorruption: planted SEC persists (scrubber fully starved)");

                -- Once the port idles, the scrubber repairs the cell.
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(100, 16#5A#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "UserBusyNoCorruption: repaired after the storm");

            -- Suspend/resume via Scrub_Enable, proven on the data: disable, plant a flip, wait
            -- longer than a full pass would take (the flip must survive: the scrubber is off),
            -- re-enable, wait, and check the flip is gone (repaired).
            elsif run("ScrubEnableSuspends") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                ft_write_flip(40, 16#99#, singleBit(1),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 2 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "ScrubEnableSuspends: no pass while Scrub_Enable='0'");
                end loop;

                ft_check_ecc(40, 16#99#, '1', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubEnableSuspends: flip persists while suspended");

                Scrub_Enable <= '1';

                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(40, 16#99#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubEnableSuspends: flip repaired after re-enable");

            -- The injection latch is the use case Scrub_Enable was designed for: preload a flip
            -- pattern, wait some idle cycles, then issue the user write. With the scrubber paused,
            -- the latch is guaranteed to land on the user's write (and not on a scrubber writeback
            -- that would otherwise have consumed it first).
            elsif run("LatchedInjectionUnderPause") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                ft_preload_flip(singleBit(0), Clk, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 8 loop
                    wait until rising_edge(Clk);
                end loop;

                ft_write(110, 16#A5#, Clk, Addr, WrData, WrEna);

                ft_check_ecc(110, 16#A5#, '1', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Latched injection landed on user write under Scrub_Enable='0'");

                Scrub_Enable <= '1';

            -- PassDone must pulse for exactly one cycle. Observe 3 consecutive pulses and check
            -- Scrub_PassDone is back to '0' on the cycle immediately following each rising edge.
            -- Catches a class of bugs that leave PassDone stuck high or pulse it for multiple
            -- cycles -- the existing ScrubPassDone test counts pulses but would silently mask
            -- such bugs by counting them as "faster than expected".
            elsif run("ScrubPassDonePulseWidth") then

                for k in 1 to 3 loop

                    loop
                        wait until rising_edge(Clk);
                        exit when Scrub_PassDone = '1';
                    end loop;

                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "PassDone pulse width = 1 (pulse " & integer'image(k) & ")");
                end loop;

            -- With the user idle, the scrubber scans the whole RAM but its own reads must never
            -- surface on the user-facing RdValid (they are masked internally). Run two full passes
            -- (Scrub_PassDone x2) and assert RdValid stays '0' throughout.
            elsif run("ScrubReadMaskedFromUser") then
                -- Align to a pass boundary, then count any user-facing RdValid pulses over two full
                -- passes; the scrubber's own reads are masked, so the count must be zero.
                ft_wait_passes(1, Clk, Scrub_PassDone);
                ft_count_over_passes(2, Clk, Scrub_PassDone, RdValid, RdValidCnt_v);

                check_equal(RdValidCnt_v, 0,
                            "User-facing RdValid stays '0' while user is idle (scrubber reads masked)");

            -- Address-wrap boundary: SEC at addr 0 (first address of every pass) and at
            -- addr Depth_c - 1 (last address, where the address counter wraps in Decide_s and
            -- PassDone fires on the same event). Catches any off-by-one in the wrap arithmetic
            -- or in the first-address path of a fresh pass.
            elsif run("ScrubBoundaryAddresses") then
                ft_write_flip(0, 16#11#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                ft_write_flip(Depth_c - 1, 16#22#, singleBit(1),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(0, 16#11#, '0', '0', Latency_c,
                             Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Boundary: SEC at addr 0 corrected");
                ft_check_ecc(Depth_c - 1, 16#22#, '0', '0', Latency_c,
                             Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "Boundary: SEC at addr Depth_c - 1 corrected");

            -- Reset while the scrubber has reads in flight must squash the scrub read-valid
            -- pipeline and the masked user RdValid, leave no stale pulse after release, and
            -- preserve RAM contents. The pre-reset run time is swept so reset hits every
            -- alignment of the scrub operation (issue, each wait cycle, writeback decision)
            -- instead of one hard-coded phase that silently goes stale when the FSM changes.
            elsif run("ResetInFlight") then
                -- Plant a known clean value (a clean cell is never rewritten by the scrubber).
                ft_write(50, 16#3C#, Clk, Addr, WrData, WrEna);

                for k in 1 to 2 * (Latency_c + 2) loop

                    -- Let the scrubber run (user idle) for k cycles, then reset mid-operation.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    wait until rising_edge(Clk);
                    Rst <= '1';

                    -- Let the read-valid pipeline flush after asserting reset.
                    for i in 1 to Latency_c + 1 loop
                        wait until rising_edge(Clk);
                    end loop;

                    for i in 1 to 3 loop
                        wait until rising_edge(Clk);
                        check_equal(Scrub_EccSec, '0',
                                    "ResetInFlight: no scrub status pulse under Rst (k=" & integer'image(k) & ")");
                        check_equal(Scrub_EccDed, '0',
                                    "ResetInFlight: no scrub status pulse under Rst (k=" & integer'image(k) & ")");
                        check_equal(RdValid, '0',
                                    "ResetInFlight: user RdValid squashed under Rst (k=" & integer'image(k) & ")");
                    end loop;

                    -- Pause the scrubber before release so no NEW scrub reads start; no stale
                    -- valid from a pre-reset read may emerge after release.
                    Scrub_Enable <= '0';
                    wait until rising_edge(Clk);
                    Rst          <= '0';

                    for i in 1 to Latency_c + 2 loop
                        wait until rising_edge(Clk);
                        check_equal(Scrub_EccSec, '0',
                                    "ResetInFlight: no stale scrub status after release (k=" & integer'image(k) & ")");
                        check_equal(Scrub_EccDed, '0',
                                    "ResetInFlight: no stale scrub status after release (k=" & integer'image(k) & ")");
                        check_equal(RdValid, '0',
                                    "ResetInFlight: no stale user RdValid after release (k=" & integer'image(k) & ")");
                    end loop;

                    -- Resume scrubbing for the next sweep iteration.
                    Scrub_Enable <= '1';
                    wait until rising_edge(Clk);
                end loop;

                -- Contents survived all resets; a fresh user read decodes correctly.
                ft_check_ecc(50, 16#3C#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ResetInFlight: contents survive + fresh read decodes");

                -- The scrubber resumes after reset.
                ft_wait_passes(1, Clk, Scrub_PassDone);

                check_true(true, "ResetInFlight: scrubber resumes (PassDone pulses)");

            -- Opportunistic scrubbing under partial traffic: user reads every other cycle leave
            -- idle port cycles, so the scrubber proceeds and repairs a SEC planted at addr 0 while
            -- the traffic keeps running. Every issued user read must still return exactly once on
            -- the masked RdValid, even with scrub reads and user returns interleaving in the
            -- shared decode path.
            elsif run("ScrubProceedsUnderPartialTraffic") then
                -- Plant a SEC at addr 0.
                ft_write_flip(0, 16#A5#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                -- Reset so the scrubber's address counter restarts at addr 0 (the SEC). Reset
                -- does not clear the RAM, so the planted SEC persists. The bridge read is already
                -- asserted during reset so the port is busy from the instant of release and the
                -- scrubber cannot act before the counted window starts.
                wait until rising_edge(Clk);
                Rst   <= '1';
                Addr  <= toUslv(100, Addr'length);
                RdEna <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst   <= '0';

                -- Bridge: keep the port busy while the in-flight state settles. From here on,
                -- count issued user reads and returned RdValid pulses: at the end both counts
                -- must match exactly, proving no user valid is swallowed and no scrubber valid
                -- leaks. (Reads sampled during reset are squashed by the RAM and counted neither
                -- as issued nor as returned.)
                IssuedCnt_v    := 0;
                UserValidCnt_v := 0;

                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                    if RdEna = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if RdValid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                    Addr  <= toUslv(100, Addr'length);
                    RdEna <= '1';
                end loop;

                RdValidCnt_v := 0;

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if RdEna = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if RdValid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                    if (i mod 2) = 0 then
                        Addr  <= toUslv(100, Addr'length);
                        RdEna <= '1';
                    else
                        Addr  <= (others => '0');
                        RdEna <= '0';
                    end if;
                    -- The scrubber observes the SEC on its own read exactly once: the first idle
                    -- port cycle issues the read and a later idle cycle takes the repair.
                    if Scrub_EccSec = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                end loop;

                wait until rising_edge(Clk);
                if RdEna = '1' then
                    IssuedCnt_v := IssuedCnt_v + 1;
                end if;
                if RdValid = '1' then
                    UserValidCnt_v := UserValidCnt_v + 1;
                end if;
                RdEna <= '0';
                Addr  <= (others => '0');

                -- Drain: every issued read has returned after the full read latency.
                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                    if RdValid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                end loop;

                check_equal(UserValidCnt_v, IssuedCnt_v,
                            "ScrubProceedsUnderPartialTraffic: RdValid pulse count = issued user reads exactly");

                check_equal(RdValidCnt_v, 1,
                            "ScrubProceedsUnderPartialTraffic: SEC observed exactly once (repaired on first visit)");

                -- The repair happened DURING the traffic: addr 0 reads clean immediately.
                ft_check_ecc(0, 16#A5#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                             "ScrubProceedsUnderPartialTraffic: SEC repaired under partial traffic");

            -- The scrubber RMW race: the user writes the address whose stale (corrected) data the
            -- scrubber holds in flight between its read and its writeback. The write must abort
            -- the writeback; otherwise the scrubber would overwrite the fresh user data with the
            -- stale corrected word. Sweep the write over every offset of the read-to-writeback
            -- window: plant a SEC at addr 0 under reset (so the scrubber restarts at addr 0 with
            -- the SEC guaranteed in place), fire a single-cycle clean user write k cycles after
            -- release, idle, then verify the user's value survived. The sweep discriminates at
            -- TotalReadLatency >= 2; at a total latency of 1 the user write owns the RAM port
            -- mux in the same cycle even without the inhibit.
            elsif run("UserWriteToInFlightScrubAddr") then

                for k in 0 to Latency_c + 2 loop
                    -- Park the scrubber and plant the SEC while Rst is asserted (reset affects
                    -- neither the RAM contents nor the write path), then restart at addr 0.
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    ft_write_flip(0, 16#A5#, singleBit(0),
                                  Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                    wait until rising_edge(Clk);
                    Rst <= '0';

                    -- Phase offset: the scrubber's read of addr 0 goes in flight right after
                    -- release; place the user write k cycles into the window.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    -- Single-cycle clean user write of a different value to the in-flight address.
                    ft_write(0, 16#77#, Clk, Addr, WrData, WrEna);

                    -- Let the scrubber retry/complete addr 0, then freeze it and check: the user
                    -- value must survive with clean ECC. A stale writeback would restore 16#A5#.
                    for i in 1 to 6 * (Latency_c + 1) loop
                        wait until rising_edge(Clk);
                    end loop;

                    Scrub_Enable <= '0';
                    wait until rising_edge(Clk);
                    ft_check_ecc(0, 16#77#, '0', '0', Latency_c, Clk, Addr, RdEna, RdData, RdValid, RdEccSec,
                                 RdEccDed,
                                 "UserWriteToInFlightScrubAddr: fresh user data survives (k=" & integer'image(k) & ")");
                    Scrub_Enable <= '1';
                end loop;

            -- Scrub_Enable='0' must PRESERVE ScrubAddr (resume from the same address), not reset
            -- it to 0. Advance the scrubber to near the end of a pass, suspend, resume, and time
            -- the next PassDone: only a preserved address makes it arrive quickly.
            elsif run("ScrubEnablePreservesAddr") then
                -- Align to a pass boundary so ScrubAddr is 0.

                loop
                    wait until rising_edge(Clk);
                    exit when Scrub_PassDone = '1';
                end loop;

                -- Advance to near the end of the pass (one scrub op per
                -- RamRdLatency_g+EccPipeline_g+2 cycles; user idle, so no aborts).
                for i in 1 to (Depth_c - 8) * (Latency_c + 2) loop
                    wait until rising_edge(Clk);
                end loop;

                -- Suspend then resume; a correct engine keeps ScrubAddr near the end.
                Scrub_Enable <= '0';

                for i in 1 to 50 loop
                    wait until rising_edge(Clk);
                end loop;

                Scrub_Enable <= '1';

                -- Time the next PassDone. Preserved => only ~8 addresses remain (short).
                -- Reset-to-0 => a near-full pass (long). Assert it is short.
                RdValidCnt_v := 0;

                loop
                    wait until rising_edge(Clk);
                    RdValidCnt_v := RdValidCnt_v + 1;
                    exit when Scrub_PassDone = '1';
                    exit when RdValidCnt_v >= PassCycles_c;
                end loop;

                check_true(RdValidCnt_v < (Depth_c / 2) * (Latency_c + 2),
                           "ScrubEnablePreservesAddr: PassDone arrived quickly after resume (ScrubAddr preserved)");

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
