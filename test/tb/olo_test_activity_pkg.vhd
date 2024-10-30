---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler, Benoit Stef
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

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_test_activity_pkg is

    -- Wait for a given time and check if the signal is idle
    procedure check_no_activity_stdl (
        signal sig : in std_logic;
        idle_time  : in time;
        msg        : in string := "");

    procedure check_no_activity_stdlv (
        signal sig : in std_logic_vector;
        idle_time  : in time;
        msg        : in string := "");

    -- Check when a signal had its last activity (without waiting)
    procedure check_last_activity (
        signal sig : in std_logic;
        idle_time  : in time;
        level      : in integer range -1 to 1 := -1; -- -1 = don't check, 0 = low, 1 = high
        msg        : in string                := "");

    -- pulse a signal
    procedure pulse_sig (
        signal sig   : out std_logic;
        signal clk   : in std_logic;
        active_level : in std_logic := '1');

    -- check if stdlv is arrived within a defined period of time
    procedure wait_for_value_stdlv (
        signal sig : in std_logic_vector; -- Signal to check
        exp_val    : in std_logic_vector; -- expected value
        timeout    : in time;             -- time to wait for
        msg        : in string);          -- bool out to stop Tb for ex.

    -- check if std is arrived within a defined period of time
    procedure wait_for_value_stdl (
        signal sig : in std_logic; -- Signal to check
        exp_val    : in std_logic; -- expected value
        timeout    : in time;      -- time to wait for
        msg        : in string);   -- bool out to stop Tb for ex.

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_test_activity_pkg is

    -- *** CheckNoActivity ***
    procedure check_no_activity_stdl (
        signal sig : in std_logic;
        idle_time  : in time;
        msg        : in string := "") is
    begin
        wait for idle_time;
        check(sig'last_event >= idle_time, "check_no_activity_stdl() failed: " & msg);
    end procedure;

    -- *** check_no_activity_stdlv ***
    procedure check_no_activity_stdlv (
        signal sig : in std_logic_vector;
        idle_time  : in time;
        msg        : in string := "") is
    begin
        wait for idle_time;
        check(sig'last_event >= idle_time, "check_no_activity_stdlv() failed: " & msg);
    end procedure;

    -- *** check_last_activity ***
    procedure check_last_activity (
        signal sig : in std_logic;
        idle_time  : in time;
        level      : in integer range -1 to 1 := -1; -- -1 = don't check, 0 = low, 1 = high
        msg        : in string                := "") is
    begin
        check(sig'last_event >= idle_time, "check_last_activity() - unexpected activity: " & msg);
        if level /= -1 then
            check_equal(sig, choose(level = 0, '0', '1'), "check_last_activity() - wrong level: " & msg);
        end if;
    end procedure;

    -- *** pulse_sig ***
    procedure pulse_sig (
        signal sig   : out std_logic;
        signal clk   : in std_logic;
        active_level : in std_logic := '1') is
    begin
        wait until rising_edge(clk);
        sig <= active_level;
        wait until rising_edge(clk);
        sig <= not active_level;
    end procedure;

    -- *** Wait for Standard logic vector to happen ***
    procedure wait_for_value_stdlv (
        signal sig : in std_logic_vector;
        exp_val    : in std_logic_vector;
        timeout    : in time;
        msg        : in string) is
    begin
        if sig /= exp_val then
            wait until exp_val = sig for timeout;
            if exp_val /= sig then
                error("wait_for_value_stdlv() failed: " & msg &
                        " Target state not reached" &
                        " [Expected " & to_string(exp_val) & "(0x" & to_hstring(exp_val) & ")" &
                        ", Received " & to_string(sig) & "(0x" & to_hstring(sig) & ")" & "]");
            end if;
        end if;
    end procedure;

    -- *** Wait for Standard logic to happen ***
    procedure wait_for_value_stdl (
        signal sig : in std_logic;
        exp_val    : in std_logic;
        timeout    : in time;
        msg        : in string) is
    begin
        if sig /= exp_val then
            wait until exp_val = sig for timeout;
            if exp_val /= sig then
                error("wait_for_value_stdl() failed: " & msg &
                        " Target state not reached" &
                        " [Expected " & to_string(exp_val) &
                        ", Received " & to_string(sig) & "]");
            end if;
        end if;
    end procedure;

end package body;
