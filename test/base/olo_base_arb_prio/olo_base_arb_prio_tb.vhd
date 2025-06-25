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
-- vunit: run_all_in_same_sim
entity olo_base_arb_prio_tb is
    generic (
        runner_cfg          : string;
        Latency_g           : natural := 1
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_prio_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c : natural := 5;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                              := '0';
    signal Rst       : std_logic                              := '0';
    signal In_Req    : std_logic_vector(Width_c - 1 downto 0) := (others => '0');
    signal Out_Grant : std_logic_vector(Width_c - 1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real    := 100.0e6;
    constant Clk_Period_c    : time    := (1 sec) / Clk_Frequency_c;
    signal ExpectedGrant     : integer := 0;
    signal ExpectedGrantDel  : integer := 0;
    signal CheckGrant        : boolean := false;
    signal CheckGrantDel     : boolean := false;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_prio
        generic map (
            Width_g   => Width_c,
            Latency_g => Latency_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Req      => In_Req,
            Out_Grant   => Out_Grant
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
                CheckGrant    <= true;
                ExpectedGrant <= 2#00000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#00000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                In_Req        <= "01000";
                ExpectedGrant <= 2#01000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#01000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                In_Req        <= "00000";
                ExpectedGrant <= 2#00000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                CheckGrant    <= false;
            end if;

            if run("MultiBit") then
                wait until rising_edge(Clk);
                wait for 1 ns;
                CheckGrant    <= true;
                In_Req        <= "10111";
                ExpectedGrant <= 2#10000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#10000#;
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#00100#;
                In_Req        <= "00111";
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#00010#;
                In_Req        <= "00011";
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#10000#;
                In_Req        <= "10001";
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#00001#;
                In_Req        <= "00001";
                wait until rising_edge(Clk);
                wait for 1 ns;
                ExpectedGrant <= 2#00000#;
                In_Req        <= "00000";
                wait until rising_edge(Clk);
                wait for 1 ns;
                CheckGrant    <= false;
            end if;

            wait for 1 us; -- Wait for all checks to complete before stopping

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Custom Processes
    -----------------------------------------------------------------------------------------------
    -- Check Grant after the expected latency
    CheckGrantDel    <= transport CheckGrant after Latency_g*Clk_Period_c;
    ExpectedGrantDel <= transport ExpectedGrant after Latency_g*Clk_Period_c;

    p_checkout : process (Clk) is
    begin
        if rising_edge(Clk) then
            if CheckGrantDel then
                check_equal(Out_Grant, ExpectedGrantDel, "Wrong Grant");
            end if;
        end if;
    end process;

end architecture;
