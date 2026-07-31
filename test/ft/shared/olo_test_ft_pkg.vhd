---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Shared test procedures for the fault-tolerant (ft) area test benches: user-port write helpers
-- and ECC read checks for the ECC RAM wrappers, plus scrub-pass synchronization helpers for the
-- scrubbed variants.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_math.all;

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

end package body;
