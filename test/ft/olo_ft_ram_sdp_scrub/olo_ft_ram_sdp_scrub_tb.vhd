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
        signal Clk    : in std_logic;
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
        signal Clk      : in std_logic;
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
    signal Wr_Addr         : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Wr_Ena          : std_logic                                        := '0';
    signal Wr_Data         : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal Rd_Addr         : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Rd_Ena          : std_logic                                        := '0';
    signal Rd_Data         : std_logic_vector(Width_g - 1 downto 0);
    signal Rd_Valid        : std_logic;
    signal Rd_EccSec       : std_logic;
    signal Rd_EccDed       : std_logic;
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
        variable PassCnt_v      : natural;
        variable RdValidCnt_v   : natural;
        variable MaskFail_v     : boolean;
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
                write(1, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(2, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(3, 7, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic re-read 1=5");

            elsif run("ScrubPassDone") then
                PassCnt_v := 0;

                while PassCnt_v < 3 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "Scrub_PassDone pulsed >= 3 times");

            -- Each planted SEC must be observed by the scrubber exactly once (Scrub_Rd_Valid +
            -- Scrub_Rd_EccSec pulse together): the first visit repairs the cell, so later passes
            -- read it clean.
            elsif run("ScrubFixesSec") then
                writeWithFlip(10, 16#AB#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(20, 16#CD#, singleBit(2),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v    := 0;
                RdValidCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_Rd_Valid = '1' and Scrub_Rd_EccSec = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_equal(RdValidCnt_v, 2,
                            "ScrubFixesSec: each planted SEC observed by the scrubber exactly once");

                checkEcc(10, 16#AB#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubFixesSec addr10 cleaned");
                checkEcc(20, 16#CD#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubFixesSec addr20 cleaned");

            -- The scrubber must observe the DED word on its own reads (Scrub_Rd_Valid +
            -- Scrub_Rd_EccDed pulse together at least once per pass) and never write it back.
            elsif run("ScrubDoesNotWriteOnDed") then
                writeWithFlip(70, 16#EE#, doubleBit(0, 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v    := 0;
                RdValidCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_Rd_Valid = '1' and Scrub_Rd_EccDed = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(RdValidCnt_v >= 1,
                           "ScrubDoesNotWriteOnDed: scrubber observed the DED word (Scrub_Rd_EccDed pulsed)");

                checkEcc(70, 0, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubDoesNotWriteOnDed addr70 still Ded", CheckData => false);

            -- Plant SEC at addr 80, then drive user writes to addr 80 every other cycle for
            -- 400 cycles. User data is always authoritative: any user activity inhibits the
            -- scrubber for the duration, so the scrubber never gets a chance to write back.
            -- The user's writes (clean value 16#BB#, no injection) accumulate; addr 80 must
            -- read clean at the end.
            elsif run("UserWriteWinsDuringContention") then
                writeWithFlip(80, 16#AA#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Wr_Addr <= toUslv(80, Wr_Addr'length);
                        Wr_Data <= toUslv(16#BB#, Width_g);
                        Wr_Ena  <= '1';
                    else
                        Wr_Ena <= '0';
                    end if;
                end loop;

                wait until rising_edge(Clk);
                Wr_Ena  <= '0';
                Wr_Addr <= (others => '0');
                Wr_Data <= (others => '0');

                checkEcc(80, 16#BB#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "UserWriteWinsDuringContention: user write wins");

            -- SDP arbitration: drive BOTH user ports every cycle (write to 150, read from 151) so
            -- there is never an idle cycle. The cross-port inhibit must starve the scrubber
            -- completely: once the returns of any pre-saturation scrub reads have drained,
            -- Scrub_Rd_Valid staying '0' proves no scrub read is issued. A value written before
            -- the storm must stay intact (no scrub writeback sneaks onto the write port). This
            -- also exercises simultaneous dual-port user traffic, which only the SDP topology
            -- supports.
            elsif run("UserBusyNoCorruption") then
                writeWithFlip(100, 16#5A#, (CodewordWidth_c - 1 downto 0 => '0'),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 200 loop
                    wait until rising_edge(Clk);
                    Wr_Addr <= toUslv(150, Wr_Addr'length);
                    Wr_Data <= toUslv(i, Width_g);
                    Wr_Ena  <= '1';
                    Rd_Addr <= toUslv(151, Rd_Addr'length);
                    Rd_Ena  <= '1';
                    -- Pre-saturation scrub reads return within the read latency; afterwards no
                    -- scrub read may be issued at all.
                    if i > RamRdLatency_g + EccPipeline_g + 1 then
                        check_equal(Scrub_Rd_Valid, '0',
                                    "UserBusyNoCorruption: scrubber fully starved while both ports are busy");
                    end if;
                end loop;

                wait until rising_edge(Clk);
                Wr_Ena  <= '0';
                Rd_Ena  <= '0';
                Wr_Addr <= (others => '0');
                Rd_Addr <= (others => '0');
                Wr_Data <= (others => '0');

                -- Drain the in-flight user reads, then verify the pre-storm value is intact.
                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                    wait until rising_edge(Clk);
                end loop;

                checkEcc(100, 16#5A#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "UserBusyNoCorruption addr100 intact");

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

            elsif run("LatchedInjectionUnderPause") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                preloadFlip(singleBit(0), Clk, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 8 loop
                    wait until rising_edge(Clk);
                end loop;

                write(110, 16#A5#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                checkEcc(110, 16#A5#, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Latched injection landed on user write under Scrub_Enable='0'");

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

            -- With the user idle: Scrub_Rd_Valid pulse count = Depth_c per pass, user-facing
            -- Rd_Valid stays '0' (scrubber-owned reads masked). Scrub_Rd_EccSec /
            -- Scrub_Rd_EccDed are pass-throughs of the codec output and not gated, so they
            -- are meaningful only on cycles where Scrub_Rd_Valid='1' -- not checked here.
            elsif run("ScrubRdValidIntegrity") then

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
                    if Rd_Valid /= '0' then
                        MaskFail_v := true;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_equal(RdValidCnt_v, 2 * Depth_c,
                            "Scrub_Rd_Valid pulse count = 2 * Depth_c over 2 passes");
                check_true(not MaskFail_v,
                           "User-facing Rd_Valid stays '0' while user is idle (scrubber masking works)");

            -- Address-wrap boundary: SEC at addr 0 (first) and at addr Depth_c - 1 (last,
            -- where the address counter wraps in Decide_s and PassDone fires).
            elsif run("ScrubBoundaryAddresses") then
                writeWithFlip(0, 16#11#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(Depth_c - 1, 16#22#, singleBit(1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(0, 16#11#, '0', '0',
                         Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Boundary: SEC at addr 0 corrected");
                checkEcc(Depth_c - 1, 16#22#, '0', '0',
                         Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Boundary: SEC at addr Depth_c - 1 corrected");

            -- Reset asserted while the scrubber has reads in flight must squash the scrub
            -- read-valid pipeline and the masked user Rd_Valid, leave no stale pulse after
            -- release, and preserve RAM contents. Exercises the scrubber's reset of ValidPipe /
            -- Fsm / ScrubAddr / WaitCnt -- new state the wrapped RAM does not have.
            elsif run("ResetInFlight") then
                -- Plant a known clean value (a clean cell is never rewritten by the scrubber).
                write(50, 16#3C#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                -- Let the scrubber run (user idle) so reads are continuously in flight.
                for i in 1 to 4 * (RamRdLatency_g + EccPipeline_g + 1) loop
                    wait until rising_edge(Clk);
                end loop;

                -- Assert reset while the scrubber is active: ValidPipe is fed every cycle, so a
                -- missing reset would let Scrub_Rd_Valid pulse. Reset must hold it (and the masked
                -- user Rd_Valid) low.
                wait until rising_edge(Clk);
                Rst <= '1';

                -- Let the read-valid pipeline flush after asserting reset.
                for i in 1 to RamRdLatency_g + EccPipeline_g + 1 loop
                    wait until rising_edge(Clk);
                end loop;

                for i in 1 to 3 loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_Rd_Valid, '0', "ResetInFlight: Scrub_Rd_Valid squashed under Rst");
                    check_equal(Rd_Valid,       '0', "ResetInFlight: user Rd_Valid squashed under Rst");
                end loop;

                -- Pause the scrubber before release so no NEW scrub reads start; no stale valid
                -- from a pre-reset read may emerge after release.
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                Rst          <= '0';

                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_Rd_Valid, '0', "ResetInFlight: no stale Scrub_Rd_Valid after release");
                    check_equal(Rd_Valid,       '0', "ResetInFlight: no stale user Rd_Valid after release");
                end loop;

                -- Contents survived the reset; a fresh user read decodes correctly.
                Scrub_Enable <= '1';
                checkEcc(50, 16#3C#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
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
            -- NOT advance ScrubAddr, so the same address is retried. Plant a SEC at addr 0, drive
            -- intermittent user reads on a different address (addr 0 never written): the scrubber
            -- reads addr 0 every idle cycle but is inhibited before it can write back, so addr 0
            -- stays SEC throughout; it is repaired only once the user idles.
            elsif run("WritebackAbortsOnContention") then
                -- Plant a SEC at addr 0.
                writeWithFlip(0, 16#A5#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                -- Reset so the scrubber's address counter restarts at addr 0 (the SEC). Reset
                -- does not clear the RAM, so the planted SEC persists.
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst <= '0';

                -- Bridge: keep the user continuously busy so the scrubber (now parked on addr 0)
                -- cannot complete a repair before the alternating pattern starts. From here on,
                -- count issued user reads (Rd_Ena sampled at every edge) and returned Rd_Valid
                -- pulses: at the end both counts must match exactly, proving no user valid is
                -- swallowed and no scrubber valid leaks even with scrub issues and aborts
                -- interleaving the user returns.
                IssuedCnt_v    := 0;
                UserValidCnt_v := 0;

                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
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
                    -- Each scrub read of addr 0 returns its SEC flag on the codec-return cycle,
                    -- even though the FSM aborts; counting these proves the abort path runs.
                    if Scrub_Rd_Valid = '1' and Scrub_Rd_EccSec = '1' then
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

                -- Freeze the scrubber BEFORE the user-idle drain window; otherwise it would use
                -- the idle cycles to complete the repair that this test asserts was aborted.
                Scrub_Enable <= '0';

                -- Drain: every issued read has returned after the full read latency.
                for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                    wait until rising_edge(Clk);
                    if Rd_Valid = '1' then
                        UserValidCnt_v := UserValidCnt_v + 1;
                    end if;
                end loop;

                check_equal(UserValidCnt_v, IssuedCnt_v,
                            "WritebackAbortsOnContention: Rd_Valid pulse count = issued user reads exactly");

                check_true(RdValidCnt_v >= 10,
                           "WritebackAbortsOnContention: scrubber repeatedly read the SEC at addr 0 during contention");

                -- Freeze the scrubber; every writeback must have been aborted: addr 0 still SEC.
                -- A buggy engine that wrote back under inhibit, or advanced ScrubAddr past addr 0
                -- on abort, would read clean here.
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                checkEcc(0, 0, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
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

                checkEcc(0, 16#A5#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "WritebackAbortsOnContention: addr 0 repaired after contention (same-addr retry)");

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

                for k in 0 to RamRdLatency_g + EccPipeline_g + 2 loop
                    -- Park the scrubber and plant the SEC while Rst is asserted (reset affects
                    -- neither the RAM contents nor the write path), then restart at addr 0.
                    wait until rising_edge(Clk);
                    Rst <= '1';
                    writeWithFlip(0, 16#A5#, singleBit(0),
                                  Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                    wait until rising_edge(Clk);
                    Rst <= '0';

                    -- Phase offset: the scrubber's read of addr 0 goes in flight right after
                    -- release; place the user write k cycles into the window.
                    for i in 1 to k loop
                        wait until rising_edge(Clk);
                    end loop;

                    -- Single-cycle clean user write of a different value to the in-flight address.
                    write(0, 16#77#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                    -- Let the scrubber retry/complete addr 0, then freeze it and check: the user
                    -- value must survive with clean ECC. A stale writeback would restore 16#A5#.
                    for i in 1 to 6 * (RamRdLatency_g + EccPipeline_g + 1) loop
                        wait until rising_edge(Clk);
                    end loop;

                    Scrub_Enable <= '0';
                    wait until rising_edge(Clk);
                    checkEcc(0, 16#77#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
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
