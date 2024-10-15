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
entity olo_base_cc_bits_tb is
    generic (
        runner_cfg     : string;
        ClockRatio_N_g : integer               := 3;
        ClockRatio_D_g : integer               := 2;
        SyncStages_g   : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_bits_tb is

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

    constant Time_Rst_Assert_c  : time := 2 * SlowerClock_Period_c;
    constant Time_Rst_Recover_c : time := 10 * SlowerClock_Period_c;
    constant Time_MaxDel_c      : time := (real(SyncStages_g + 1) + 0.01) * SlowerClock_Period_c; -- 1 cycle per stage + 1 for input register

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk   : std_logic                                  := '0';
    signal In_Rst   : std_logic                                  := '1';
    signal In_Data  : std_logic_vector(DataWidth_c - 1 downto 0) := x"00";
    signal Out_Clk  : std_logic                                  := '0';
    signal Out_Rst  : std_logic                                  := '1';
    signal Out_Data : std_logic_vector(DataWidth_c - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_bits
        generic map (
            Width_g      => DataWidth_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            -- Clock Domain A
            In_Clk    => In_Clk,
            In_Rst    => In_Rst,
            In_Data   => In_Data,
            -- Clock Domain B
            Out_Clk   => Out_Clk,
            Out_Rst   => Out_Rst,
            Out_Data  => Out_Data
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

            -- *** Reset ***
            In_Rst  <= '1';
            Out_Rst <= '1';
            wait for Time_Rst_Assert_c;
            In_Rst  <= '0';
            Out_Rst <= '0';
            wait for Time_Rst_Recover_c;

            if run("SimpleTransfer") then
                In_Data <= x"AB";
                wait_for_value_stdlv(Out_Data, x"AB", Time_MaxDel_c, "Data not transferred 1");
                In_Data <= x"CD";
                wait_for_value_stdlv(Out_Data, x"CD", Time_MaxDel_c, "Data not transferred 2");

            -- data transfer with A longer in reset
            elsif run("LongResetA") then
                wait until rising_edge(In_Clk);
                In_Rst  <= '1';
                Out_Rst <= '1';
                wait for Time_Rst_Assert_c;
                Out_Rst <= '0';
                wait for 100 * SlowerClock_Period_c;
                In_Rst  <= '0';
                wait for Time_Rst_Recover_c;
                In_Data <= x"12";
                wait_for_value_stdlv(Out_Data, x"12", Time_MaxDel_c, "Data not transferred 3");
                In_Data <= x"34";
                wait_for_value_stdlv(Out_Data, x"34", Time_MaxDel_c, "Data not transferred 4");

            -- data transfer with B longer in reset
            elsif run("LongResetB") then
                wait until rising_edge(In_Clk);
                In_Rst  <= '1';
                Out_Rst <= '1';
                wait for Time_Rst_Assert_c;
                In_Rst  <= '0';
                wait for 100 * SlowerClock_Period_c;
                Out_Rst <= '0';
                wait for Time_Rst_Recover_c;
                In_Data <= x"56";
                wait_for_value_stdlv(Out_Data, x"56", Time_MaxDel_c, "Data not transferred 5");
                In_Data <= x"78";
                wait_for_value_stdlv(Out_Data, x"78", Time_MaxDel_c, "Data not transferred 6");
            end if;
        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
