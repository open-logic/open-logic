---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Milorad Petrovic
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_intf_inc_encoder_tb is
    generic (
        DefaultAngleResolution_g : positive;
        PositionWidth_g          : positive := 32;
        runner_cfg               : string);
end entity;

architecture rtl of olo_intf_inc_encoder_tb is
    
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c : time := (1 sec) / Clk_Frequency_c;
    

    signal Clk             : std_logic := '1';
    signal Rst             : std_logic := '1';
    signal Phase_A         : std_logic := '0';
    signal Phase_B         : std_logic := '0';
    signal Phase_Z         : std_logic := '0';
    signal Position        : std_logic_vector(PositionWidth_g - 1 downto 0);
    signal Clear_Position  : std_logic := '0';
    signal Angle           : std_logic_vector(PositionWidth_g - 1 downto 0);
    signal Clear_Angle     : std_logic := '0';
    signal AngleResolution : std_logic_vector(PositionWidth_g - 1 downto 0) := toUslv(DefaultAngleResolution_g, PositionWidth_g);
    signal Event_Up        : std_logic;
    signal Event_Down      : std_logic;
    signal Event_Index     : std_logic;

    procedure wait_clock_cycles(NumberOfCyclesToWait : positive) is
    begin
        for i in 1 to NumberOfCyclesToWait loop
            wait until rising_edge(Clk);
        end loop;
    end procedure wait_clock_cycles;
    
begin

    test_runner_watchdog(runner, 50 ms);

    proc_testcases : process is
    begin
        test_runner_setup(runner, runner_cfg);

        wait_clock_cycles(3);
        Rst <= '0';
        wait_clock_cycles(3);

        while test_suite loop
            if run("JustRun") then
                wait_clock_cycles(1000);
            end if;
        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process proc_testcases;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    inst_dut : entity olo.olo_intf_inc_encoder
        generic map (
            DefaultAngleResolution_g => DefaultAngleResolution_g,
            PositionWidth_g          => PositionWidth_g)
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Phase_A         => Phase_A,
            Phase_B         => Phase_B,
            Phase_Z         => Phase_Z,
            Position        => Position,
            Clear_Position  => Clear_Position,
            Angle           => Angle,
            Clear_Angle     => Clear_Angle,
            AngleResolution => AngleResolution,
            Event_Up        => Event_Up,
            Event_Down      => Event_Down,
            Event_Index     => Event_Index);

    -----------------------------------------------------------------------------------------------
    -- Encoder signal generator
    -----------------------------------------------------------------------------------------------
    proc_encoder_signal_generator : process is
    begin
        wait_clock_cycles(5);
        Phase_A <= '1';
        wait_clock_cycles(5);
        Phase_B <= '1';
        wait_clock_cycles(5);
        Phase_A <= '0';
        wait_clock_cycles(5);
        Phase_B <= '0';
    end process proc_encoder_signal_generator;

end architecture rtl;
