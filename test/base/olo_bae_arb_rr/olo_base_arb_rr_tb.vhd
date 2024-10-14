---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

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
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_arb_rr_tb is
    generic (
        runner_cfg          : string
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_rr_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------

    constant Width_c : natural := 5;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------

    signal Clk       : std_logic                              := '0';
    signal Rst       : std_logic                              := '0';
    signal Out_Ready : std_logic                              := '0';
    signal Out_Valid : std_logic                              := '0';
    signal In_Req    : std_logic_vector(Width_c - 1 downto 0) := (others => '0');
    signal Out_Grant : std_logic_vector(Width_c - 1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_rr
        generic map (
            Width_g => Width_c
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Req      => In_Req,
            Out_Grant   => Out_Grant,
            Out_Ready   => Out_Ready,
            Out_Valid   => Out_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            Rst <= '1';
            wait for 1 us;
            Rst <= '0';

            if run("SingleBit") then
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00000#, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req    <= "01000";
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant 1 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant 2 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req    <= "00000";
                wait for 1 ns;
                check_equal(Out_Grant, 2#00000#, "Out_Grant not de-asserted");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
            end if;

            if run("MultiBit") then
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                In_Req    <= "10000";
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 3 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req    <= "10111";
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant 4 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 5 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 6 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 7 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant 8 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req    <= "00001";
                wait for 1 ns;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 9 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req    <= "11001";
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 10 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant 11 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                In_Req    <= "00000";
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
            end if;

            if run("ReadyLow") then

                -- Start test
                Out_Ready <= '0';
                In_Req    <= "10011";
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 12 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for 1 ns;
                Out_Ready <= '1';
                check_equal(Out_Grant, 2#10000#, "Out_Grant 12 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 13 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 13 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 14 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                In_Req    <= "10001";
                check_equal(Out_Grant, 2#00001#, "Out_Grant 14 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 15 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 15 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 16 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 16 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                Out_Ready <= '0';
                In_Req    <= "00000";
                wait for 1 us;
            end if;

            if run("ExampleFromDoc") then
                Out_Ready <= '0';
                wait until rising_edge(Clk);
                In_Req    <= "10110";
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 0");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 1");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 1");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 2");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 2");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 3");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 3");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00010#, "Out_Grant Wrong, Doc 4");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 4");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 5");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 5");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 6");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 6");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 7");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 7");
                wait until rising_edge(Clk);
                In_Req    <= "01100";
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 8");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 8");
                wait until rising_edge(Clk);
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 9");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 9");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for 1 ns;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 10");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 10");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for 1 ns;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 11");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 11");
                wait until rising_edge(Clk);
                In_Req    <= "00000";
                wait for 1 ns;
                check_equal(Out_Grant, 2#00000#, "Out_Grant Wrong, Doc 12");
                check_equal(Out_Valid, '0', "Valid Wrong, Doc 12");
                wait for 1 us;
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
