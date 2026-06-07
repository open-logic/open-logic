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
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    procedure write (
        address       : natural;
        data          : natural;
        signal Clk    : in  std_logic;
        signal Addr   : out std_logic_vector;
        signal WrData : out std_logic_vector;
        signal WrEna  : out std_logic) is
    begin
        wait until rising_edge(Clk);
        Addr   <= toUslv(address, Addr'length);
        WrData <= toUslv(data, WrData'length);
        WrEna  <= '1';
        wait until rising_edge(Clk);
        WrEna  <= '0';
        Addr   <= toUslv(0, Addr'length);
        WrData <= toUslv(0, WrData'length);
    end procedure;

    -- Preload an injection pattern without writing. Pattern is held in the encoder's latch and
    -- applied to the next write that reaches the encoder.
    procedure preloadFlip (
        flipBits        : std_logic_vector;
        signal Clk      : in  std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic) is
    begin
        wait until rising_edge(Clk);
        InjFlip  <= flipBits;
        InjValid <= '1';
        wait until rising_edge(Clk);
        InjFlip  <= (InjFlip'range => '0');
        InjValid <= '0';
    end procedure;

    procedure writeWithFlip (
        address         : natural;
        data            : natural;
        flipBits        : std_logic_vector;
        signal Clk      : in  std_logic;
        signal Addr     : out std_logic_vector;
        signal WrData   : out std_logic_vector;
        signal WrEna    : out std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic) is
    begin
        wait until rising_edge(Clk);
        Addr     <= toUslv(address, Addr'length);
        WrData   <= toUslv(data, WrData'length);
        WrEna    <= '1';
        InjFlip  <= flipBits;
        InjValid <= '1';
        wait until rising_edge(Clk);
        WrEna    <= '0';
        InjFlip  <= (InjFlip'range => '0');
        InjValid <= '0';
        Addr     <= toUslv(0, Addr'length);
        WrData   <= toUslv(0, WrData'length);
    end procedure;

    -- Issue a read on the shared port. With a scrubber present, RdValid may not pulse on the
    -- TotalReadLatency_c+1 cycle if the scrubber owned the read cycle (User_PortBusy gating
    -- prevents this for the cycle we drive RdEna='1', but the data still arrives after the
    -- pipeline). To stay deterministic, the procedure simply waits for the expected latency
    -- and checks RdValid is high.
    procedure checkEcc (
        address        : natural;
        data           : natural;
        expEccSec      : std_logic;
        expEccDed      : std_logic;
        signal Clk     : in  std_logic;
        signal Addr    : out std_logic_vector;
        signal RdEna   : out std_logic;
        signal RdData  : in  std_logic_vector;
        signal RdValid : in  std_logic;
        signal EccSec  : in  std_logic;
        signal EccDed  : in  std_logic;
        message        : string;
        CheckData      : boolean := true) is
    begin
        wait until rising_edge(Clk);
        Addr  <= toUslv(address, Addr'length);
        RdEna <= '1';
        wait until rising_edge(Clk);
        Addr  <= toUslv(0, Addr'length);
        RdEna <= '0';

        for i in 1 to RamRdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdValid, '1',       message & " RdValid");
        check_equal(EccSec,  expEccSec, message & " EccSec");
        check_equal(EccDed,  expEccDed, message & " EccDed");
        if CheckData then
            check_equal(RdData, toUslv(data, RdData'length), message & " data");
        end if;
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk             : std_logic                                        := '0';
    signal Rst             : std_logic                                        := '0';
    signal Addr            : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal WrEna           : std_logic                                        := '0';
    signal WrData          : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal RdEna           : std_logic                                        := '0';
    signal RdData          : std_logic_vector(Width_g - 1 downto 0);
    signal RdValid         : std_logic;
    signal RdEccSec        : std_logic;
    signal RdEccDed        : std_logic;
    signal ErrInj_BitFlip  : std_logic_vector(CodewordWidth_c - 1 downto 0)   := (others => '0');
    signal ErrInj_Valid    : std_logic                                        := '0';
    signal Scrub_Enable    : std_logic                                        := '1';
    signal Scrub_Rd_Valid  : std_logic;
    signal Scrub_Rd_EccSec : std_logic;
    signal Scrub_Rd_EccDed : std_logic;
    signal Scrub_PassDone  : std_logic;

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
            Scrub_Rd_Valid  => Scrub_Rd_Valid,
            Scrub_Rd_EccSec => Scrub_Rd_EccSec,
            Scrub_Rd_EccDed => Scrub_Rd_EccDed,
            Scrub_PassDone  => Scrub_PassDone
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
        variable PassCnt_v    : natural;
        variable RdValidCnt_v : natural;
        variable MaskFail_v   : boolean;
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
                write(1, 5, Clk, Addr, WrData, WrEna);
                write(2, 6, Clk, Addr, WrData, WrEna);
                write(3, 7, Clk, Addr, WrData, WrEna);
                checkEcc(1, 5, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed, "Basic re-read 1=5");

            -- With user idle, the scrubber walks the address space and pulses Scrub_PassDone on
            -- rollover from Depth_g - 1 to 0. Confirm at least three pulses within the watchdog
            -- window so we know the scrubber is making progress under the SP arbitration rules.
            elsif run("ScrubPassDone") then
                PassCnt_v := 0;

                while PassCnt_v < 3 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "Scrub_PassDone pulsed >= 3 times");

            -- Plant SEC errors at two distinct addresses; idle the user; wait for two full scrubber
            -- passes; verify the cells now read clean.
            elsif run("ScrubFixesSec") then
                writeWithFlip(10, 16#AB#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(20, 16#CD#, singleBit(2),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(10, 16#AB#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "ScrubFixesSec addr10 cleaned");
                checkEcc(20, 16#CD#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "ScrubFixesSec addr20 cleaned");

            -- DED reads are reported but the writeback is suppressed (corrected data is unreliable).
            -- After idle scrub time, the DED flag must still be set.
            elsif run("ScrubDoesNotWriteOnDed") then
                writeWithFlip(70, 16#EE#, doubleBit(0, 1),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(70, 0, '0', '1', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "ScrubDoesNotWriteOnDed addr70 still Ded", CheckData => false);

            -- Plant SEC at addr 80, then drive user writes to addr 80 every other cycle for
            -- 400 cycles. User data is always authoritative: any user activity inhibits the
            -- scrubber for the duration, so the scrubber never gets a chance to write back.
            -- The user's writes (clean value 16#BB#, no injection) accumulate; addr 80 must
            -- read clean at the end.
            elsif run("UserWriteWinsDuringContention") then
                writeWithFlip(80, 16#AA#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Addr   <= toUslv(80, Addr'length);
                        WrData <= toUslv(16#BB#, Width_g);
                        WrEna  <= '1';
                    else
                        WrEna <= '0';
                    end if;
                end loop;

                wait until rising_edge(Clk);
                WrEna  <= '0';
                Addr   <= (others => '0');
                WrData <= (others => '0');

                checkEcc(80, 16#BB#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "UserWriteWinsDuringContention: user write wins");

            -- SP arbitration: while the user holds the port busy with continuous activity, the
            -- scrubber must never issue a request that lands on the RAM. We do not have a direct
            -- "scrubber-owned cycle" probe, but Scrub_Active = '1' must not coincide with a user
            -- read or write that gets corrupted. The functional contract is captured here as: a
            -- user value written under continuous user activity reads back intact.
            elsif run("UserBusyNoCorruption") then
                writeWithFlip(100, 16#5A#, (CodewordWidth_c - 1 downto 0 => '0'),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                -- 200 cycles of continuous user activity (alternating read / write on adjacent
                -- addresses) that does not touch addr=100. The scrubber is free to act on any
                -- non-busy cycles -- but with continuous activity, none should exist.

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
                end loop;

                wait until rising_edge(Clk);
                WrEna  <= '0';
                RdEna  <= '0';
                Addr   <= (others => '0');
                WrData <= (others => '0');

                checkEcc(100, 16#5A#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "UserBusyNoCorruption addr100 intact");

            -- Scrub_Enable='0' must hold the scrubber FSM in Idle on the same cycle, so no
            -- Scrub_PassDone pulses fire over a long observation window. Re-enabling must
            -- resume scrubbing (PassDone pulses again).
            elsif run("ScrubEnableSuspends") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                for i in 1 to 2 * Depth_c loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "Scrub_PassDone='0' while Scrub_Enable='0' at cycle " & integer'image(i));
                end loop;

                Scrub_Enable <= '1';

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "Scrub_PassDone resumes pulsing after Scrub_Enable='1'");

            -- The injection latch is the use case Scrub_Enable was designed for: preload a flip
            -- pattern, wait some idle cycles, then issue the user write. With the scrubber paused,
            -- the latch is guaranteed to land on the user's write (and not on a scrubber writeback
            -- that would otherwise have consumed it first).
            elsif run("LatchedInjectionUnderPause") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                preloadFlip(singleBit(0), Clk, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 8 loop
                    wait until rising_edge(Clk);
                end loop;

                write(110, 16#A5#, Clk, Addr, WrData, WrEna);

                checkEcc(110, 16#A5#, '1', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
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

            -- With the user idle: (a) Scrub_Rd_Valid must pulse exactly Depth_c times per
            -- pass (one per address), (b) the user-facing RdValid must stay '0' (scrubber's
            -- own reads must not pulse it via the wrapper's masking). Scrub_Rd_EccSec /
            -- Scrub_Rd_EccDed are pass-throughs of the codec output and are not gated, so
            -- they are not checked here -- they are meaningful only on cycles where
            -- Scrub_Rd_Valid='1'.
            elsif run("ScrubRdValidIntegrity") then
                -- Align: wait for the first PassDone so the count starts at addr 0 of a pass.

                loop
                    wait until rising_edge(Clk);
                    exit when Scrub_PassDone = '1';
                end loop;

                PassCnt_v    := 0;
                RdValidCnt_v := 0;
                MaskFail_v   := false;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_Rd_Valid = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                    if RdValid /= '0' then
                        MaskFail_v := true;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_equal(RdValidCnt_v, 2 * Depth_c,
                            "Scrub_Rd_Valid pulse count = 2 * Depth_c over 2 passes");
                check_true(not MaskFail_v,
                           "User-facing RdValid stays '0' while user is idle (scrubber masking works)");

            -- Address-wrap boundary: SEC at addr 0 (first address of every pass) and at
            -- addr Depth_c - 1 (last address, where Incr_s wraps and PassDone fires on the
            -- same event). Catches any off-by-one in the wrap arithmetic or in the
            -- first-address path of a fresh pass.
            elsif run("ScrubBoundaryAddresses") then
                writeWithFlip(0, 16#11#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(Depth_c - 1, 16#22#, singleBit(1),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(0, 16#11#, '0', '0',
                         Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "Boundary: SEC at addr 0 corrected");
                checkEcc(Depth_c - 1, 16#22#, '0', '0',
                         Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "Boundary: SEC at addr Depth_c - 1 corrected");

            -- Reset asserted while the scrubber has reads in flight must squash the scrub
            -- read-valid pipeline and the masked user RdValid, leave no stale pulse after
            -- release, and preserve RAM contents. Exercises the scrubber's reset of ValidPipe /
            -- Fsm / ScrubAddr / WaitCnt -- new state the wrapped RAM does not have.
            elsif run("ResetInFlight") then
                -- Plant a known clean value (a clean cell is never rewritten by the scrubber).
                write(50, 16#3C#, Clk, Addr, WrData, WrEna);

                -- Let the scrubber run (user idle) so reads are continuously in flight.
                for i in 1 to 4 * (RamRdLatency_g + EccPipeline_g + 1) loop
                    wait until rising_edge(Clk);
                end loop;

                -- Assert reset while the scrubber is active: ValidPipe is fed every cycle, so a
                -- missing reset would let Scrub_Rd_Valid pulse. Reset must hold it (and the masked
                -- user RdValid) low.
                wait until rising_edge(Clk);
                Rst <= '1';

                -- Let the read-valid pipeline flush after asserting reset.
                for i in 1 to RamRdLatency_g + EccPipeline_g + 1 loop
                    wait until rising_edge(Clk);
                end loop;

                -- Reset must now hold the scrub read-valid (and the masked user RdValid) low,
                -- even though the scrubber is still enabled and would otherwise keep issuing reads.
                for i in 1 to 3 loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_Rd_Valid, '0', "ResetInFlight: Scrub_Rd_Valid squashed under Rst");
                    check_equal(RdValid,        '0', "ResetInFlight: user RdValid squashed under Rst");
                end loop;

                -- Pause the scrubber before release so no NEW scrub reads start; no stale valid
                -- from a pre-reset read may emerge after release.
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                Rst          <= '0';

                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_Rd_Valid, '0', "ResetInFlight: no stale Scrub_Rd_Valid after release");
                    check_equal(RdValid,        '0', "ResetInFlight: no stale user RdValid after release");
                end loop;

                -- Contents survived the reset; a fresh user read decodes correctly.
                Scrub_Enable <= '1';
                checkEcc(50, 16#3C#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "ResetInFlight: contents survive + fresh read decodes");

                -- The scrubber resumes after reset.
                PassCnt_v := 0;

                while PassCnt_v < 1 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "ResetInFlight: scrubber resumes (PassDone pulses)");

            -- A user access during the scrubber's read-decode window must abort the writeback and
            -- NOT advance ScrubAddr, so the same address is retried. Plant a SEC at addr 0 (the
            -- pass start), drive intermittent user reads on a different address (addr 0 never
            -- written): the scrubber reads addr 0 every idle cycle but is inhibited before it can
            -- write back, so addr 0 stays SEC throughout; it is repaired only once the user idles.
            elsif run("WritebackAbortsOnContention") then
                -- Plant a SEC at addr 0.
                writeWithFlip(0, 16#A5#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                -- Reset so the scrubber's address counter restarts at addr 0 (the SEC). Reset
                -- does not clear the RAM, so the planted SEC persists.
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst <= '0';

                -- Bridge: keep the user continuously busy so the scrubber (now parked on addr 0)
                -- cannot complete a repair before the alternating pattern starts.
                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                    wait until rising_edge(Clk);
                    Addr  <= toUslv(100, Addr'length);
                    RdEna <= '1';
                end loop;

                RdValidCnt_v := 0;

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Addr  <= toUslv(100, Addr'length);
                        RdEna <= '1';
                    else
                        Addr  <= (others => '0');
                        RdEna <= '0';
                    end if;
                    -- Each scrub read of addr 0 returns its SEC flag on the codec-return cycle,
                    -- even though the FSM aborts; counting these proves the abort path runs.
                    if Scrub_Rd_Valid = '1' and Scrub_Rd_EccSec = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                end loop;

                wait until rising_edge(Clk);
                RdEna <= '0';
                Addr  <= (others => '0');

                check_true(RdValidCnt_v >= 10,
                           "WritebackAbortsOnContention: scrubber repeatedly read the SEC at addr 0 during contention");

                -- Freeze the scrubber; every writeback must have been aborted: addr 0 still SEC.
                -- A buggy engine that wrote back under inhibit, or advanced ScrubAddr past addr 0
                -- on abort, would read clean here.
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                checkEcc(0, 0, '1', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "WritebackAbortsOnContention: SEC at addr 0 NOT repaired during contention",
                         CheckData => false);

                -- Re-enable and idle: the same-address retry now completes and repairs addr 0.
                Scrub_Enable <= '1';
                PassCnt_v    := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(0, 16#A5#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "WritebackAbortsOnContention: addr 0 repaired after contention (same-addr retry)");

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
                -- RamRdLatency_g+EccPipeline_g+1 cycles; user idle, so no aborts).
                for i in 1 to (Depth_c - 8) * (RamRdLatency_g + EccPipeline_g + 1) loop
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
                    exit when RdValidCnt_v >= Depth_c * (RamRdLatency_g + EccPipeline_g + 1);
                end loop;

                check_true(RdValidCnt_v < (Depth_c / 2) * (RamRdLatency_g + EccPipeline_g + 1),
                           "ScrubEnablePreservesAddr: PassDone arrived quickly after resume (ScrubAddr preserved)");

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
