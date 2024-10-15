---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
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

library work;
    use work.olo_test_activity_pkg.all;

library olo;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cc_status_tb is
    generic (
        runner_cfg     : string;
        ClockRatio_N_g : integer               := 3;
        ClockRatio_D_g : integer               := 2;
        SyncStages_g   : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_status_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClockRatio_c : real    := real(ClockRatio_N_g) / real(ClockRatio_D_g);
    constant DataWidth_c  : integer := 8;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkIn_Frequency_c    : real := 100.0e6;
    constant ClkIn_Period_c       : time := (1 sec) / ClkIn_Frequency_c;
    constant ClkOut_Frequency_c   : real := ClkIn_Frequency_c * ClockRatio_c;
    constant ClkOut_Period_c      : time := (1 sec) / ClkOut_Frequency_c;
    constant SlowerClock_Period_c : time := (1 sec) / minimum(ClkIn_Frequency_c, ClkOut_Frequency_c);
    constant Time_Rst_Assert_c    : time := 2 * SlowerClock_Period_c;
    constant Time_Rst_Recover_c   : time := 10 * SlowerClock_Period_c;
    constant Time_MaxDel_c        : time := 15 * SlowerClock_Period_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk     : std_logic                                  := '0';
    signal In_RstIn   : std_logic                                  := '1';
    signal In_RstOut  : std_logic;
    signal In_Data    : std_logic_vector(DataWidth_c - 1 downto 0) := x"00";
    signal Out_Clk    : std_logic                                  := '0';
    signal Out_RstIn  : std_logic                                  := '1';
    signal Out_RstOut : std_logic;
    signal Out_Data   : std_logic_vector(DataWidth_c - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_status
        generic map (
            Width_g      => DataWidth_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            -- Clock Domain A
            In_Clk     => In_Clk,
            In_RstIn   => In_RstIn,
            In_RstOut  => In_RstOut,
            In_Data    => In_Data,
            -- Clock Domain B
            Out_Clk    => Out_Clk,
            Out_RstIn  => Out_RstIn,
            Out_RstOut => Out_RstOut,
            Out_Data   => Out_Data
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    In_Clk  <= not In_Clk after 0.5 * ClkIn_Period_c;
    Out_Clk <= not Out_Clk after 0.5 * ClkOut_Period_c;

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
            In_RstIn  <= '1';
            Out_RstIn <= '1';
            wait for 1 us;

            -- Check if both sides are in reset
            check(In_RstOut = '1', "In_RstOut not asserted");
            check(Out_RstOut = '1', "Out_RstOut not asserted");

            -- Remove reset
            wait until rising_edge(In_Clk);
            In_RstIn  <= '0';
            wait until rising_edge(Out_Clk);
            Out_RstIn <= '0';
            wait for 1 us;

            -- Check if both sides exited reset
            check(In_RstOut = '0', "In_RstOut not de-asserted");
            check(Out_RstOut = '0', "Out_RstOut not de-asserted");

            -- *** Reset Tests ***
            if run("Reset") then

                -- Check if RstA is propagated to both sides
                wait until rising_edge(In_Clk);
                In_RstIn <= '1';
                wait until rising_edge(In_Clk);
                In_RstIn <= '0';
                wait for 1 us;
                check(In_RstOut = '0', "In_RstOut not de-asserted after In_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after In_RstIn");
                check(In_RstOut'last_event < 1 us, "In_RstOut not asserted after In_RstIn");
                check(Out_RstOut'last_event < 1 us, "Out_RstOut not asserted after In_RstIn");

                -- Check if RstB is propagated to both sides
                wait until rising_edge(Out_Clk);
                Out_RstIn <= '1';
                wait until rising_edge(Out_Clk);
                Out_RstIn <= '0';
                wait for 1 us;
                check(In_RstOut = '0', "In_RstOut not de-asserted after Out_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after Out_RstIn");
                check(In_RstOut'last_event < 1 us, "In_RstOut not asserted after Out_RstIn");
                check(Out_RstOut'last_event < 1 us, "Out_RstOut not asserted after Out_RstIn");

            -- *** Data Tests ***
            elsif run("Data") then
                -- data transfer after resetting both
                In_RstIn  <= '1';
                Out_RstIn <= '1';
                wait for Time_Rst_Assert_c;
                In_RstIn  <= '0';
                Out_RstIn <= '0';
                wait for Time_Rst_Recover_c;
                In_Data   <= x"AB";
                wait_for_value_stdlv(Out_Data, x"AB", Time_MaxDel_c, "Data not transferred 1");
                In_Data   <= x"CD";
                wait_for_value_stdlv(Out_Data, x"CD", Time_MaxDel_c, "Data not transferred 2");

                -- data transfer with A longer in reset
                In_RstIn  <= '1';
                Out_RstIn <= '1';
                wait for Time_Rst_Assert_c;
                Out_RstIn <= '0';
                wait for 100 * SlowerClock_Period_c;
                In_RstIn  <= '0';
                wait for Time_Rst_Recover_c;
                In_Data   <= x"12";
                wait_for_value_stdlv(Out_Data, x"12", Time_MaxDel_c, "Data not transferred 3");
                In_Data   <= x"34";
                wait_for_value_stdlv(Out_Data, x"34", Time_MaxDel_c, "Data not transferred 4");

                -- data transfer with B longer in reset
                In_RstIn  <= '1';
                Out_RstIn <= '1';
                wait for Time_Rst_Assert_c;
                In_RstIn  <= '0';
                wait for 100 * SlowerClock_Period_c;
                Out_RstIn <= '0';
                wait for Time_Rst_Recover_c;
                In_Data   <= x"56";
                wait_for_value_stdlv(Out_Data, x"56", Time_MaxDel_c, "Data not transferred 5");
                In_Data   <= x"78";
                wait_for_value_stdlv(Out_Data, x"78", Time_MaxDel_c, "Data not transferred 6");
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
