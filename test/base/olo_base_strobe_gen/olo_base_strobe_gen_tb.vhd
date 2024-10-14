---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler
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
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_strobe_gen_tb is
    generic (
        runner_cfg       : string;
        FreqStrobeHz_g   : string  := "10.0e6";
        FractionalMode_g : boolean := true
    );
end entity;

architecture sim of olo_base_strobe_gen_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant FreqClkHz_c    : real := 100.0e6;
    constant FreqStrobeHz_c : real := fromString(FreqStrobeHz_g);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Period_c    : time := (1 sec) / FreqClkHz_c;
    constant Strobe_Period_c : time := (1 sec) / FreqStrobeHz_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic := '0';
    signal Rst       : std_logic := '0';
    signal In_Sync   : std_logic := '0';
    signal Out_Valid : std_logic := '0';
    signal Out_Ready : std_logic := '1';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable FirstSTrobe_v  : time;
        variable LastStrobe_v   : time;
        variable StrobePeriod_v : time;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Generate Strobe
            if run("Basic") then
                -- Generate strobe with Ready always high
                Out_Ready <= '1';

                for i in 0 to 50 loop
                    -- Strobe
                    wait until rising_edge(Clk) and Out_Valid = '1';
                    if i > 0 then
                        StrobePeriod_v := now - LastStrobe_v;
                        -- For non-fractional mode, check every period
                        if not FractionalMode_g then
                            check(abs(StrobePeriod_v-Strobe_Period_c) < 0.5 * Clk_Period_c, "period");
                        end if;
                    else
                        FirstSTrobe_v := now;
                    end if;
                    LastStrobe_v := now;
                    -- Check De-assertion
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '0', "deassertion");
                end loop;

                -- for fractional mode, check average
                if FractionalMode_g then
                    StrobePeriod_v := LastStrobe_v - FirstSTrobe_v;
                    check(abs(StrobePeriod_v-Strobe_Period_c*50)/50 < 0.02 * Clk_Period_c,
                        "period - got: " & time'image(StrobePeriod_v) & " expected: " & time'image(Strobe_Period_c*50));
                end if;

            end if;

            -- Synchronization
            if run("Synchronization") then
                -- Generate strobe with Ready always high
                Out_Ready <= '1';

                -- Synchronize in the middle of a period
                wait until rising_edge(Clk) and Out_Valid = '1';
                wait for Strobe_Period_c / 2;
                wait until rising_edge(Clk);
                In_Sync        <= '1';
                wait until rising_edge(Clk);
                In_Sync        <= '0';
                wait until rising_edge(Clk);
                check_equal(Out_Valid, '1', "assertion");
                LastStrobe_v   := now;
                wait until rising_edge(Clk);
                check_equal(Out_Valid, '0', "deassertion");
                wait until rising_edge(Clk) and Out_Valid = '1';
                StrobePeriod_v := now - LastStrobe_v;
                check(abs(StrobePeriod_v-Strobe_Period_c) < 0.5 * Clk_Period_c, "period");
            end if;

            -- ReadyLow
            if run("ReadyLow") then
                -- Generate strobe with Ready always high
                Out_Ready <= '0';

                for i in 0 to 5 loop
                    -- Strobe
                    wait until rising_edge(Clk) and Out_Valid = '1';
                    if i > 0 then
                        StrobePeriod_v := now - LastStrobe_v;
                        check(abs(StrobePeriod_v-Strobe_Period_c) < 1.0 * Clk_Period_c, "period"); -- 1 period to stay compatible with fractional mode
                    end if;
                    LastStrobe_v := now;

                    for i in 0 to 3 loop
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '1', "stay asserted");
                    end loop;

                    Out_Ready <= '1';
                    wait until rising_edge(Clk);
                    Out_Ready <= '0';
                    -- Check De-assertion
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '0', "deassertion");
                end loop;

            end if;

            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_strobe_gen
        generic map (
            FreqClkHz_g      => FreqClkHz_c,
            FreqStrobeHz_g   => FreqStrobeHz_c,
            FractionalMode_g => FractionalMode_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Sync     => In_Sync,
            Out_Valid   => Out_Valid,
            Out_Ready   => Out_Ready
        );

end architecture;
