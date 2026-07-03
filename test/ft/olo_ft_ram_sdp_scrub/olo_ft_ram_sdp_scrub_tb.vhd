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
entity olo_ft_ram_sdp_scrub_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_ram_sdp_scrub_tb is

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
    signal Wr_Addr        : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Wr_Ena         : std_logic                                        := '0';
    signal Wr_Data        : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal Rd_Addr        : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Rd_Ena         : std_logic                                        := '0';
    signal Rd_Data        : std_logic_vector(Width_g - 1 downto 0);
    signal Rd_Valid       : std_logic;
    signal Rd_EccSec      : std_logic;
    signal Rd_EccDed      : std_logic;
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
    i_dut : entity olo.olo_ft_ram_sdp_scrub
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
            Wr_Addr         => Wr_Addr,
            Wr_Ena          => Wr_Ena,
            Wr_Data         => Wr_Data,
            Rd_Addr         => Rd_Addr,
            Rd_Ena          => Rd_Ena,
            Rd_Data         => Rd_Data,
            Rd_Valid        => Rd_Valid,
            Rd_EccSec       => Rd_EccSec,
            Rd_EccDed       => Rd_EccDed,
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

            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("Basic") then
                ft_write(1, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                ft_write(2, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                ft_write(3, 7, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                ft_check_ecc(1, 5, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Basic 1=5");
                ft_check_ecc(2, 6, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Basic 2=6");
                ft_check_ecc(3, 7, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Basic 3=7");
                ft_check_ecc(1, 5, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Basic re-read 1=5");

            -- Free-running scrubbing makes progress and never flags an overrun (the pacer is off).
            elsif run("ScrubPassDone") then
                ft_count_over_passes(3, Clk, Scrub_PassDone, Scrub_Overrun, RdValidCnt_v);
                check_equal(RdValidCnt_v, 0, "ScrubPassDone: no overrun when free-running");

            -- Each planted SEC must be observed by the scrubber exactly once (Scrub_EccSec pulses
            -- once): the first visit repairs the cell, so later passes
            -- read it clean.
            elsif run("ScrubFixesSec") then
                ft_write_flip(10, 16#AB#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                ft_write_flip(20, 16#CD#, singleBit(2),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                ft_count_over_passes(2, Clk, Scrub_PassDone, Scrub_EccSec, RdValidCnt_v);

                check_equal(RdValidCnt_v, 2,
                            "ScrubFixesSec: each planted SEC observed by the scrubber exactly once");

                ft_check_ecc(10, 16#AB#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ScrubFixesSec addr10 cleaned");
                ft_check_ecc(20, 16#CD#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ScrubFixesSec addr20 cleaned");

            -- The scrubber must observe the DED word on its own reads exactly once per pass
            -- (Scrub_EccDed pulses; the word is never repaired, so
            -- both passes of the window see it) and never write it back.
            elsif run("ScrubDoesNotWriteOnDed") then
                ft_write_flip(70, 16#EE#, doubleBit(0, 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                ft_count_over_passes(2, Clk, Scrub_PassDone, Scrub_EccDed, RdValidCnt_v);

                check_equal(RdValidCnt_v, 2,
                            "ScrubDoesNotWriteOnDed: DED word observed exactly once per pass (never repaired)");

                ft_check_ecc(70, 0, '0', '1', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "ScrubDoesNotWriteOnDed addr70 still Ded", check_data => false);

            -- Continuous user reads block the scrubber's read slot, so the scrubber cannot repair:
            -- a SEC planted at addr 128 must still be reported after hammering reads at addr 129
            -- for a long window. Once the user idles, the scrubber repairs it.
            elsif run("UserTrafficStarvesScrubRepair") then
                ft_write_flip(128, 16#AA#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    Rd_Addr <= toUslv(129, Rd_Addr'length);
                    Rd_Ena  <= '1';
                end loop;

                wait until rising_edge(Clk);
                Rd_Ena  <= '0';
                Rd_Addr <= (others => '0');

                -- The SEC is still reported: the scrubber never got a read slot to repair it.
                -- (The resumed scrubber needs far longer than this check to reach addr 128.)
                ft_check_ecc(128, 16#AA#, '1', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "UserTrafficStarvesScrubRepair: SEC persists under read hammering");

                -- With the user idle again the scrubber repairs the cell.
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(128, 16#AA#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "UserTrafficStarvesScrubRepair: repaired after the user idles");

            -- SDP arbitration: drive BOTH user ports every cycle (write to 150, read from 151) so
            -- there is never a free cycle on either port. The scrubber must be starved completely:
            -- no pass completes and a SEC planted before the storm is still reported afterwards
            -- (a scrubber writeback would have repaired it). This also exercises simultaneous
            -- dual-port user traffic, which only the SDP topology supports.
            elsif run("UserBusyNoCorruption") then
                ft_write_flip(100, 16#5A#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 200 loop
                    wait until rising_edge(Clk);
                    Wr_Addr <= toUslv(150, Wr_Addr'length);
                    Wr_Data <= toUslv(i, Width_g);
                    Wr_Ena  <= '1';
                    Rd_Addr <= toUslv(151, Rd_Addr'length);
                    Rd_Ena  <= '1';
                    -- Fully starved: the scrubber never gets a free read slot, so it can never
                    -- complete a pass.
                    check_equal(Scrub_PassDone, '0',
                                "UserBusyNoCorruption: scrubber fully starved while both ports are busy");
                end loop;

                wait until rising_edge(Clk);
                Wr_Ena  <= '0';
                Rd_Ena  <= '0';
                Wr_Addr <= (others => '0');
                Rd_Addr <= (others => '0');
                Wr_Data <= (others => '0');

                -- Let the storm's in-flight reads return (ft_check_ecc aligns to its own read, so
                -- this only keeps the window clean), then verify the planted SEC survived: the
                -- starved scrubber must not have written anything.
                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                end loop;

                ft_check_ecc(100, 16#5A#, '1', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "UserBusyNoCorruption: planted SEC persists (scrubber fully starved)");

                -- Once both ports idle, the scrubber repairs the cell.
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(100, 16#5A#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "UserBusyNoCorruption: repaired after the storm");

            -- Suspend/resume via Scrub_Enable, proven on the data: disable, plant a flip, wait
            -- longer than a full pass would take (the flip must survive: the scrubber is off),
            -- re-enable, wait, and check the flip is gone (repaired).
            elsif run("ScrubEnableSuspends") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                ft_write_flip(40, 16#99#, singleBit(1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 2 * PassCycles_c loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "ScrubEnableSuspends: no pass while Scrub_Enable='0'");
                end loop;

                ft_check_ecc(40, 16#99#, '1', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ScrubEnableSuspends: flip persists while suspended");

                Scrub_Enable <= '1';

                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(40, 16#99#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ScrubEnableSuspends: flip repaired after re-enable");

            elsif run("LatchedInjectionUnderPause") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                ft_preload_flip(singleBit(0), Clk, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 8 loop
                    wait until rising_edge(Clk);
                end loop;

                ft_write(110, 16#A5#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                ft_check_ecc(110, 16#A5#, '1', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "Latched injection landed on user write under Scrub_Enable='0'");

                Scrub_Enable <= '1';

            -- PassDone must pulse for exactly one cycle. Observe 3 consecutive pulses and check
            -- Scrub_PassDone is back to '0' on the cycle immediately following each rising edge.
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
            -- surface on the user-facing Rd_Valid (they are masked internally). Run two full passes
            -- (Scrub_PassDone x2) and assert Rd_Valid stays '0' throughout.
            elsif run("ScrubReadMaskedFromUser") then
                -- Align to a pass boundary, then count any user-facing Rd_Valid pulses over two full
                -- passes; the scrubber's own reads are masked, so the count must be zero.
                ft_wait_passes(1, Clk, Scrub_PassDone);
                ft_count_over_passes(2, Clk, Scrub_PassDone, Rd_Valid, RdValidCnt_v);

                check_equal(RdValidCnt_v, 0,
                            "User-facing Rd_Valid stays '0' while user is idle (scrubber reads masked)");

            -- Address-wrap boundary: SEC at addr 0 (first) and at addr Depth_c - 1 (last,
            -- where the address counter wraps in Decide_s and PassDone fires).
            elsif run("ScrubBoundaryAddresses") then
                ft_write_flip(0, 16#11#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                ft_write_flip(Depth_c - 1, 16#22#, singleBit(1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                ft_wait_passes(2, Clk, Scrub_PassDone);

                ft_check_ecc(0, 16#11#, '0', '0', Latency_c,
                             Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Boundary: SEC at addr 0 corrected");
                ft_check_ecc(Depth_c - 1, 16#22#, '0', '0', Latency_c,
                             Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                             "Boundary: SEC at addr Depth_c - 1 corrected");

            -- Reset while the scrubber has reads in flight must squash the scrub read-valid
            -- pipeline and the masked user Rd_Valid, leave no stale pulse after release, and
            -- preserve RAM contents. The pre-reset run time is swept so reset hits every
            -- alignment of the scrub operation (issue, each wait cycle, writeback decision)
            -- instead of one hard-coded phase that silently goes stale when the FSM changes.
            elsif run("ResetInFlight") then
                -- Plant a known clean value (a clean cell is never rewritten by the scrubber).
                ft_write(50, 16#3C#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

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
                        check_equal(Rd_Valid, '0',
                                    "ResetInFlight: user Rd_Valid squashed under Rst (k=" & integer'image(k) & ")");
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
                        check_equal(Rd_Valid, '0',
                                    "ResetInFlight: no stale user Rd_Valid after release (k=" & integer'image(k) & ")");
                    end loop;

                    -- Resume scrubbing for the next sweep iteration.
                    Scrub_Enable <= '1';
                    wait until rising_edge(Clk);
                end loop;

                -- Contents survived all resets; a fresh user read decodes correctly.
                ft_check_ecc(50, 16#3C#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ResetInFlight: contents survive + fresh read decodes");

                -- The scrubber resumes after reset.
                ft_wait_passes(1, Clk, Scrub_PassDone);

                check_true(true, "ResetInFlight: scrubber resumes (PassDone pulses)");

            -- Opportunistic scrubbing under partial traffic: user reads every other cycle leave
            -- free read slots, so the scrubber proceeds and repairs a SEC planted at addr 0 while
            -- the traffic keeps running (the write port is free for the writeback). Every issued
            -- user read must still return exactly once on the masked Rd_Valid, even with scrub
            -- reads and user returns interleaving in the shared decode path.
            elsif run("ScrubProceedsUnderPartialTraffic") then
                -- Plant a SEC at addr 0.
                ft_write_flip(0, 16#A5#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                -- Reset so the scrubber's address counter restarts at addr 0 (the SEC). Reset
                -- does not clear the RAM, so the planted SEC persists. The bridge read is already
                -- asserted during reset so the read port is busy from the instant of release and
                -- the scrubber cannot act before the counted window starts.
                wait until rising_edge(Clk);
                Rst     <= '1';
                Rd_Addr <= toUslv(100, Rd_Addr'length);
                Rd_Ena  <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst     <= '0';

                -- Bridge: keep the read port busy while the in-flight state settles. From here on,
                -- count issued user reads and returned Rd_Valid pulses: at the end both counts
                -- must match exactly, proving no user valid is swallowed and no scrubber valid
                -- leaks. (Reads sampled during reset are squashed by the RAM and counted neither
                -- as issued nor as returned.)
                IssuedCnt_v    := 0;
                UserValidCnt_v := 0;

                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                    if Rd_Ena = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if Rd_Valid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                    Rd_Addr <= toUslv(100, Rd_Addr'length);
                    Rd_Ena  <= '1';
                end loop;

                RdValidCnt_v := 0;

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if Rd_Ena = '1' then
                        IssuedCnt_v := IssuedCnt_v + 1;
                    end if;
                    if Rd_Valid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                    if (i mod 2) = 0 then
                        Rd_Addr <= toUslv(100, Rd_Addr'length);
                        Rd_Ena  <= '1';
                    else
                        Rd_Addr <= (others => '0');
                        Rd_Ena  <= '0';
                    end if;
                    -- The scrubber observes the SEC on its own read exactly once: the first free
                    -- read slot issues the read and the free write port takes the repair.
                    if Scrub_EccSec = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                end loop;

                wait until rising_edge(Clk);
                if Rd_Ena = '1' then
                    IssuedCnt_v := IssuedCnt_v + 1;
                end if;
                if Rd_Valid = '1' then
                    UserValidCnt_v := UserValidCnt_v + 1;
                end if;
                Rd_Ena  <= '0';
                Rd_Addr <= (others => '0');

                -- Drain: every issued read has returned after the full read latency.
                for i in 1 to Latency_c + 2 loop
                    wait until rising_edge(Clk);
                    if Rd_Valid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                end loop;

                check_equal(UserValidCnt_v, IssuedCnt_v,
                            "ScrubProceedsUnderPartialTraffic: Rd_Valid pulse count = issued user reads exactly");

                check_equal(RdValidCnt_v, 1,
                            "ScrubProceedsUnderPartialTraffic: SEC observed exactly once (repaired on first visit)");

                -- The repair happened DURING the traffic: addr 0 reads clean immediately.
                ft_check_ecc(0, 16#A5#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                             Rd_EccDed, "ScrubProceedsUnderPartialTraffic: SEC repaired under partial traffic");

            -- The scrubber RMW race: the user writes the address whose stale (corrected) data the
            -- scrubber holds in flight between its read and its writeback. The write must abort
            -- the writeback; otherwise the scrubber would overwrite the fresh user data with the
            -- stale corrected word. Sweep the write over every offset of the read-to-writeback
            -- window: plant a SEC at addr 0 under reset (so the scrubber restarts at addr 0 with
            -- the SEC guaranteed in place), fire a single-cycle clean user write k cycles after
            -- release, idle, then verify the user's value survived. The sweep discriminates at
            -- TotalReadLatency >= 2; at a total latency of 1 the user write owns the write port
            -- in the writeback cycle even without the inhibit.
            elsif run("UserWriteToInFlightScrubAddr") then

                for k in 0 to Latency_c + 2 loop
                    -- Park the scrubber and plant the SEC while Rst is asserted (reset affects
                    -- neither the RAM contents nor the write path), then restart at addr 0.
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    ft_write_flip(0, 16#A5#, singleBit(0),
                                  Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                    wait until rising_edge(Clk);
                    Rst <= '0';

                    -- Phase offset: the scrubber's read of addr 0 goes in flight right after
                    -- release; place the user write k cycles into the window.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    -- Single-cycle clean user write of a different value to the in-flight address.
                    ft_write(0, 16#77#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                    -- Let the scrubber retry/complete addr 0, then freeze it and check: the user
                    -- value must survive with clean ECC. A stale writeback would restore 16#A5#.
                    for i in 1 to 6 * (Latency_c + 1) loop
                        wait until rising_edge(Clk);
                    end loop;

                    Scrub_Enable <= '0';
                    wait until rising_edge(Clk);
                    ft_check_ecc(0, 16#77#, '0', '0', Latency_c, Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec,
                                 Rd_EccDed,
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
