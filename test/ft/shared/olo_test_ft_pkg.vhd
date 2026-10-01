---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Shared test procedures for the fault-tolerant (ft) area test benches: user-port write helpers
-- and ECC read checks for the ECC RAM wrappers, scrub-pass synchronization helpers for the
-- scrubbed variants, and AXI-Stream push/expect helpers for the ECC FIFO wrappers.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_test_ft_pkg is

    -- Single-cycle write through a user write port.
    procedure ftWrite (
        address       : in natural;
        data          : in natural;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal WrData : out std_logic_vector;
        signal WrEna  : out std_logic);

    -- Arm the error injection for the next write (latched by the DUT until a write consumes it).
    procedure ftPreloadFlip (
        flipBits        : in std_logic_vector;
        signal Clk      : in std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic);

    -- Single-cycle write with simultaneous error injection.
    procedure ftWriteFlip (
        address         : in natural;
        data            : in natural;
        flipBits        : in std_logic_vector;
        signal Clk      : in std_logic;
        signal Addr     : out std_logic_vector;
        signal WrData   : out std_logic_vector;
        signal WrEna    : out std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic);

    -- Issue a user read and check data and ECC flags after the given read latency.
    procedure ftCheckEcc (
        address        : in natural;
        data           : in natural;
        expEccSec      : in std_logic;
        expEccDed      : in std_logic;
        latency        : in natural;
        signal Clk     : in std_logic;
        signal Addr    : out std_logic_vector;
        signal RdEna   : out std_logic;
        signal RdData  : in std_logic_vector;
        signal RdValid : in std_logic;
        signal EccSec  : in std_logic;
        signal EccDed  : in std_logic;
        message        : in string;
        checkData      : in boolean := true);

    -- Wait for a given number of completed scrub passes (PassDone pulses).
    procedure ftWaitPasses (
        passes          : in positive;
        signal Clk      : in std_logic;
        signal PassDone : in std_logic);

    -- Like ftWaitPasses, but also tally how many cycles a watched signal was high over the window.
    procedure ftCountOverPasses (
        passes          : in positive;
        signal Clk      : in std_logic;
        signal PassDone : in std_logic;
        signal Watched  : in std_logic;
        watchedCount    : out natural);

    -- Push one beat through an AXI-Stream master VC. A non-zero flipBits pattern first arms the
    -- DUT's error-injection latch (drained handshake, one-cycle InjValid pulse) so the flip is
    -- applied to exactly this beat's codeword.
    procedure ftPushBeat (
        signal net      : inout network_t;
        master          : in axi_stream_master_t;
        signal Clk      : in std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic;
        data            : in std_logic_vector;
        flipBits        : in std_logic_vector;
        last            : in std_logic := '1');

    -- Queue the expected (data, tuser, tlast) outcome of a beat pushed with the given flip
    -- pattern: the decoder's deterministic output and the SEC/DED flags are computed from the
    -- flipped codeword, so the check succeeds even for DED beats.
    procedure ftExpectBeat (
        signal net : inout network_t;
        slave      : in axi_stream_slave_t;
        data       : in std_logic_vector;
        flipBits   : in std_logic_vector;
        message    : in string;
        last       : in std_logic := '1');

    -- Compute the decoder's deterministic outcome for a data word stored with the given flip
    -- pattern: the (possibly SEC-corrected) output data and the SEC/DED flags.
    procedure ftExpectedBeat (
        data      : in std_logic_vector;
        flipBits  : in std_logic_vector;
        expData   : out std_logic_vector;
        expEccSec : out std_logic;
        expEccDed : out std_logic);

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_test_ft_pkg is

    procedure ftWrite (
        address       : in natural;
        data          : in natural;
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

    procedure ftPreloadFlip (
        flipBits        : in std_logic_vector;
        signal Clk      : in std_logic;
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

    procedure ftWriteFlip (
        address         : in natural;
        data            : in natural;
        flipBits        : in std_logic_vector;
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

    procedure ftCheckEcc (
        address        : in natural;
        data           : in natural;
        expEccSec      : in std_logic;
        expEccDed      : in std_logic;
        latency        : in natural;
        signal Clk     : in std_logic;
        signal Addr    : out std_logic_vector;
        signal RdEna   : out std_logic;
        signal RdData  : in std_logic_vector;
        signal RdValid : in std_logic;
        signal EccSec  : in std_logic;
        signal EccDed  : in std_logic;
        message        : in string;
        checkData      : in boolean := true) is
    begin
        wait until rising_edge(Clk);
        Addr  <= toUslv(address, Addr'length);
        RdEna <= '1';
        wait until rising_edge(Clk);
        Addr  <= toUslv(0, Addr'length);
        RdEna <= '0';

        for i in 1 to latency loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdValid, '1',       message & " RdValid");
        check_equal(EccSec,  expEccSec, message & " EccSec");
        check_equal(EccDed,  expEccDed, message & " EccDed");
        if checkData then
            check_equal(RdData, toUslv(data, RdData'length), message & " data");
        end if;
    end procedure;

    procedure ftWaitPasses (
        passes          : in positive;
        signal Clk      : in std_logic;
        signal PassDone : in std_logic) is
        variable PassCnt_v : natural := 0;
    begin

        while PassCnt_v < passes loop
            wait until rising_edge(Clk);
            if PassDone = '1' then
                PassCnt_v := PassCnt_v + 1;
            end if;
        end loop;

    end procedure;

    procedure ftCountOverPasses (
        passes          : in positive;
        signal Clk      : in std_logic;
        signal PassDone : in std_logic;
        signal Watched  : in std_logic;
        watchedCount    : out natural) is
        variable PassCnt_v    : natural := 0;
        variable WatchedCnt_v : natural := 0;
    begin

        while PassCnt_v < passes loop
            wait until rising_edge(Clk);
            if Watched = '1' then
                WatchedCnt_v := WatchedCnt_v + 1;
            end if;
            if PassDone = '1' then
                PassCnt_v := PassCnt_v + 1;
            end if;
        end loop;

        watchedCount := WatchedCnt_v;
    end procedure;

    procedure ftPushBeat (
        signal net      : inout network_t;
        master          : in axi_stream_master_t;
        signal Clk      : in std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic;
        data            : in std_logic_vector;
        flipBits        : in std_logic_vector;
        last            : in std_logic := '1') is
        variable Inject_v : boolean := false;
    begin

        for i in flipBits'range loop
            if flipBits(i) = '1' then
                Inject_v := true;
            end if;
        end loop;

        if Inject_v then
            -- Drain so no in-flight handshake races the latch load
            wait_until_idle(net, as_sync(master));
            wait until rising_edge(Clk);

            -- One-cycle pulse: load the latch with flipBits
            InjFlip  <= flipBits;
            InjValid <= '1';
            wait until rising_edge(Clk);
            InjValid <= '0';

            push_axi_stream(net, master, data, tlast => last);

            -- Hold InjFlip stable until the push fires; the latch is cleared by the handshake
            wait_until_idle(net, as_sync(master));
            wait until rising_edge(Clk);
            InjFlip <= (InjFlip'range => '0');
        else
            push_axi_stream(net, master, data, tlast => last);
        end if;

    end procedure;

    procedure ftExpectBeat (
        signal net : inout network_t;
        slave      : in axi_stream_slave_t;
        data       : in std_logic_vector;
        flipBits   : in std_logic_vector;
        message    : in string;
        last       : in std_logic := '1') is
        variable ExpData_v  : std_logic_vector(data'length - 1 downto 0);
        variable ExpSec_v   : std_logic;
        variable ExpDed_v   : std_logic;
        variable ExpTuser_v : std_logic_vector(1 downto 0);
    begin
        ftExpectedBeat(data, flipBits, ExpData_v, ExpSec_v, ExpDed_v);
        ExpTuser_v := ExpSec_v & ExpDed_v;

        check_axi_stream(net, slave, ExpData_v, tlast => last, tuser => ExpTuser_v,
            msg                                       => message, blocking => false);
    end procedure;

    procedure ftExpectedBeat (
        data      : in std_logic_vector;
        flipBits  : in std_logic_vector;
        expData   : out std_logic_vector;
        expEccSec : out std_logic;
        expEccDed : out std_logic) is
        variable Codeword_v : std_logic_vector(flipBits'length - 1 downto 0);
        variable SynPar_v   : std_logic_vector(eccParityBits(data'length) downto 0);
    begin
        Codeword_v := eccEncode(data) xor flipBits;
        SynPar_v   := eccSyndromeAndParity(Codeword_v, data'length);
        expData    := eccCorrectData(Codeword_v, SynPar_v, data'length);
        expEccSec  := eccSecError(SynPar_v);
        expEccDed  := eccDedError(SynPar_v);
    end procedure;

end package body;
