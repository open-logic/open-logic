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
entity olo_base_strobe_div_tb is
    generic (
        runner_cfg      : string;
        Latency_g       : natural := 1
    );
end entity;

architecture sim of olo_base_strobe_div_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant MaxRatio_c  : integer := 100;
    constant FreqClkHz_c : real    := 100.0e6;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Period_c : time := (1 sec) / FreqClkHz_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                           := '0';
    signal Rst       : std_logic                                           := '0';
    signal In_Ratio  : std_logic_vector(log2ceil(MaxRatio_c-1)-1 downto 0) := (others => '0');
    signal In_Valid  : std_logic                                           := '0';
    signal Out_Valid : std_logic                                           := '0';
    signal Out_Ready : std_logic                                           := '1';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Time1_v : time;
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
                In_Ratio  <= toUslv(4-1, In_Ratio'length);
                Out_Ready <= '1';

                for i in 0 to 5 loop
                    Time1_v := now;

                    -- Not forwarded
                    for j in 0 to 2 loop
                        In_Valid <= '1';
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        wait until rising_edge(Clk);
                    end loop;

                    -- Forwarded
                    In_Valid <= '1';
                    if Latency_g = 0 then
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        check_equal(Out_Valid, '0', "Unexpected strobe");
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '1', "Strobe not asserted");
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Strobe not de-asserted");
                    else
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '1', "Strobe not asserted");
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '0', "Strobe not de-asserted");
                    end if;
                end loop;

            end if;

            -- ReadyLow
            if run("ReadyLow") then
                In_Ratio  <= toUslv(5-1, In_Ratio'length);
                Out_Ready <= '0';

                for i in 0 to 5 loop
                    Time1_v := now;

                    -- Not forwarded
                    for j in 0 to 3 loop
                        In_Valid <= '1';
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        wait until rising_edge(Clk);
                    end loop;

                    -- Forwarded
                    In_Valid <= '1';
                    if Latency_g = 0 then
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        check_equal(Out_Valid, '0', "Unexpected strobe");
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '1', "Strobe not asserted");
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                    else
                        wait until rising_edge(Clk);
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        In_Valid <= '0';
                    end if;
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '1', "Strobe not kept 1");
                    Out_Ready <= '1';
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '1', "Strobe not kept 2");
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '0', "Strobe not de-asserted");
                    Out_Ready <= '0';
                end loop;

            end if;

            -- Immediate Assert on Decrease
            if run("DecreaseHandling") then
                Out_Ready <= '1';

                for i in 3 to 5 loop
                    In_Ratio <= toUslv(10-1, In_Ratio'length);
                    Time1_v  := now;

                    -- Not forwarded
                    for j in 0 to 3 loop
                        In_Valid <= '1';
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        wait until rising_edge(Clk);
                    end loop;

                    -- Forwarded
                    In_Valid <= '1';
                    In_Ratio <= toUslv(i-1, In_Ratio'length);
                    if Latency_g = 0 then
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        check_equal(Out_Valid, '0', "Unexpected strobe");
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '1', "Strobe not asserted");
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Strobe not de-asserted");
                    else
                        wait until rising_edge(Clk);
                        In_Valid <= '0';
                        check_relation(Out_Valid'last_event > (now-Time1_v), "Unexpected strobe");
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '1', "Strobe not asserted");
                        wait until rising_edge(Clk);
                        check_equal(Out_Valid, '0', "Strobe not de-asserted");
                    end if;
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
    i_dut : entity olo.olo_base_strobe_div
        generic map (
            MaxRatio_g      => MaxRatio_c,
            Latency_g       => Latency_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Ratio    => In_Ratio,
            In_Valid    => In_Valid,
            Out_Valid   => Out_Valid,
            Out_Ready   => Out_Ready
        );

end architecture;
