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

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_async_tb is
    generic (
        runner_cfg      : string;
        AlmFullOn_g     : boolean              := true;
        AlmEmptyOn_g    : boolean              := true;
        Depth_g         : natural              := 32;
        RamBehavior_g   : string               := "RBW";
        ReadyRstState_g : integer range 0 to 1 := 1;
        Optimization_g  : string               := "LATENCY";
        SyncStages_g    : integer range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_fifo_async_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c     : integer := 16;
    constant AlmFullLevel_c  : natural := Depth_g - 3;
    constant AlmEmptyLevel_c : natural := 5;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClockInFrequency_c  : real := 100.0e6;
    constant ClockInPeriod_c     : time := (1 sec) / ClockInFrequency_c;
    constant ClockOutFrequency_c : real := 83.333e6;
    constant ClockOutPeriod_c    : time := (1 sec) / ClockOutFrequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk       : std_logic                                        := '0';
    signal In_Rst       : std_logic                                        := '1';
    signal Out_Clk      : std_logic                                        := '0';
    signal Out_Rst      : std_logic                                        := '1';
    signal In_Data      : std_logic_vector(DataWidth_c-1 downto 0)         := (others => '0');
    signal In_Valid     : std_logic                                        := '0';
    signal In_Ready     : std_logic                                        := '0';
    signal Out_Data     : std_logic_vector(DataWidth_c-1 downto 0)         := (others => '0');
    signal Out_Valid    : std_logic                                        := '0';
    signal Out_Ready    : std_logic                                        := '0';
    signal In_Full      : std_logic                                        := '0';
    signal Out_Full     : std_logic                                        := '0';
    signal In_Empty     : std_logic                                        := '0';
    signal Out_Empty    : std_logic                                        := '0';
    signal In_AlmFull   : std_logic                                        := '0';
    signal Out_AlmFull  : std_logic                                        := '0';
    signal In_AlmEmpty  : std_logic                                        := '0';
    signal Out_AlmEmpty : std_logic                                        := '0';
    signal In_Level     : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0) := (others => '0');
    signal Out_Level    : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_fifo_async
        generic map (
            Width_g         => DataWidth_c,
            Depth_g         => Depth_g,
            AlmFullOn_g     => AlmFullOn_g,
            AlmFullLevel_g  => AlmFullLevel_c,
            AlmEmptyOn_g    => AlmEmptyOn_g,
            AlmEmptyLevel_g => AlmEmptyLevel_c,
            RamBehavior_g   => RamBehavior_g,
            ReadyRstState_g => toStdl(ReadyRstState_g),
            Optimization_g  => Optimization_g,
            SyncStages_g    => SyncStages_g
        )
        port map (
            -- Control Ports
            In_Clk          => In_Clk,
            In_Rst          => In_Rst,
            Out_Clk         => Out_Clk,
            Out_Rst         => Out_Rst,
            -- Input Data
            In_Data         => In_Data,
            In_Valid        => In_Valid,
            In_Ready        => In_Ready,
            -- Output Data
            Out_Data        => Out_Data,
            Out_Valid       => Out_Valid,
            Out_Ready       => Out_Ready,
            -- Input Status
            In_Full         => In_Full,
            In_Empty        => In_Empty,
            In_AlmFull      => In_AlmFull,
            In_AlmEmpty     => In_AlmEmpty,
            In_Level        => In_Level,
            -- Output Status
            Out_Full        => Out_Full,
            Out_Empty       => Out_Empty,
            Out_AlmFull     => Out_AlmFull,
            Out_AlmEmpty    => Out_AlmEmpty,
            Out_Level       => Out_Level
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    In_Clk  <= not In_Clk after 0.5 * ClockInPeriod_c;
    Out_Clk <= not Out_Clk after 0.5 * ClockOutPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- reset
            In_Rst  <= '1';
            Out_Rst <= '1';
            -- check if ready state during reset is correct
            wait for 20 ns;                     -- reset must be transferred to other clock domain
            wait until rising_edge(In_Clk);
            check_equal(In_Ready, toStdl(ReadyRstState_g), "In_Ready reset state not according to generic");
            wait for 1 us;

            -- Remove reset
            wait until rising_edge(In_Clk);
            In_Rst  <= '0';
            wait until rising_edge(Out_Clk);
            Out_Rst <= '0';
            wait for 100 ns;

            -- Check Reset State
            wait until rising_edge(In_Clk);
            check_equal(In_Ready, '1', "In_Ready after reset state not '1'");
            check_equal(In_Full, '0', "In_Full reset state not '0'");
            check_equal(In_Empty, '1', "In_Empty reset state not '1'");
            check_equal(In_Level, 0, "In_Level reset state not 0");
            if AlmFullOn_g then
                check_equal(In_AlmFull, '0', "In_AlmFull reset state not '0'");
            end if;
            if AlmEmptyOn_g then
                check_equal(In_AlmEmpty, '1', "In_AlmEmpty reset state not '1'");
            end if;

            wait until rising_edge(Out_Clk);
            check_equal(Out_Valid, '0', "Out_Valid reset state not '0'");
            check_equal(Out_Full, '0', "Out_Full reset state not '0'");
            check_equal(Out_Empty, '1', "Out_Empty reset state not '1'");
            check_equal(Out_Level, 0, "Out_Level reset state not 0");
            if AlmFullOn_g then
                check_equal(Out_AlmFull, '0', "Out_AlmFull reset state not '0'");
            end if;
            if AlmEmptyOn_g then
                check_equal(Out_AlmEmpty, '1', "Out_AlmEmpty reset state not '1'");
            end if;

            if run("TwoWordsWriteAndRead") then

                -- Write 1
                wait until falling_edge(In_Clk);
                In_Data  <= x"0001";
                In_Valid <= '1';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(In_Empty, '1', "In_Empty not high");
                check_equal(In_Level, 0, "In_Level not 0");

                -- Write 2
                wait until falling_edge(In_Clk);
                In_Data <= x"0002";
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(In_Empty, '0', "Empty not low");
                check_equal(In_Level, 1, "In_Level not 1");

                -- Pause 1
                wait until falling_edge(In_Clk);
                In_Data  <= x"0003";
                In_Valid <= '0';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(In_Empty, '0', "Empty not low");
                check_equal(In_Level, 2, "In_Level not 2");

                -- Pause 2
                for i in 0 to 5 loop
                    wait until falling_edge(In_Clk);
                    wait until falling_edge(Out_Clk);
                end loop;

                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0001#, "Illegal Out_Data 1");
                check_equal(In_Empty, '0', "In_Empty not low");
                check_equal(In_Full, '0', "In_Full not low");
                check_equal(Out_Empty, '0', "In_Empty not low");
                check_equal(Out_Full, '0', "In_Full not low");
                check_equal(In_Level, 2, "In_Level not 2");
                check_equal(Out_Level, 2, "Out_Level not 2");

                -- Read ack 1
                wait until falling_edge(Out_Clk);
                Out_Ready <= '1';
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0001#, "Illegal Out_Data 1");
                check_equal(Out_Empty, '0', "Empty not low");
                check_equal(Out_Level, 2, "Out_Level not 2");

                -- Read ack 2
                wait until falling_edge(Out_Clk);
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0002#, "Illegal Out_Data 2");
                check_equal(Out_Empty, '0', "Empty not low");
                check_equal(Out_Level, 1, "Out_Level not 1");

                -- empty 1
                wait until falling_edge(Out_Clk);
                Out_Ready <= '0';
                check_equal(Out_Valid, '0', "Out_Valid not high");
                check_equal(Out_Empty, '1', "Empty not high");
                check_equal(Out_Level, 0, "Out_Level not 0");

                -- empty 2
                for i in 0 to 4 loop
                    wait until falling_edge(Out_Clk);
                    wait until falling_edge(In_Clk);
                end loop;

                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '0', "Out_Valid not high");
                check_equal(In_Empty, '1', "In_Empty not high");
                check_equal(Out_Empty, '1', "Out_Empty not high");
                check_equal(In_Full, '0', "In_Full not low");
                check_equal(Out_Full, '0', "Out_Full not low");
                check_equal(In_Level, 0, "In_Level not 0");
                check_equal(Out_Level, 0, "Out_Level not 0");

            elsif run("WriteFullFifo") then
                wait until falling_edge(In_Clk);

                -- Fill FIFO
                for i in 0 to Depth_g - 1 loop
                    In_Valid <= '1';
                    In_Data  <= std_logic_vector(to_unsigned(i, In_Data'length));
                    wait until falling_edge(In_Clk);
                end loop;

                In_Valid <= '0';
                wait for 1 us;
                check_equal(In_Full, '1', "In_Full not asserted");
                check_equal(Out_Full, '1', "Out_Full not asserted");
                check_equal(In_Level, Depth_g, "In_Level not full");
                check_equal(Out_Level, Depth_g, "Out_Level not full");

                -- Add more data (not written because full)
                wait until falling_edge(In_Clk);
                In_Valid <= '1';
                In_Data  <= x"ABCD";
                wait until falling_edge(In_Clk);
                In_Data  <= x"8765";
                wait until falling_edge(In_Clk);
                In_Valid <= '0';
                wait for 1 us;
                check_equal(In_Full, '1', "In_Full not asserted");
                check_equal(Out_Full, '1', "Out_Full not asserted");
                check_equal(In_Level, Depth_g, "In_Level not full");
                check_equal(Out_Level, Depth_g, "Out_Level not full");

                -- Check read
                wait until falling_edge(Out_Clk);

                -- Read all data
                for i in 0 to Depth_g - 1 loop
                    Out_Ready <= '1';
                    check_equal(Out_Data, i, "Read wrong data in word " & integer'image(i));
                    wait until falling_edge(Out_Clk);
                end loop;

                Out_Ready <= '0';
                wait for 1 us;
                check_equal(In_Empty, '1', "In_Empty not asserted");
                check_equal(Out_Empty, '1', "Out_Empty not asserted");
                check_equal(In_Full, '0', "In_Full not de-asserted");
                check_equal(Out_Full, '0', "Out_Full not de-asserted");

            elsif run("ReadEmptyFifo") then

                wait until falling_edge(Out_Clk);
                check_equal(Out_Empty, '1', "Out_Empty not asserted");
                check_equal(In_Empty, '1', "In_Empty not asserted");

                -- read
                wait until falling_edge(Out_Clk);
                Out_Ready <= '1';
                wait until falling_edge(Out_Clk);
                Out_Ready <= '0';

                -- check correct functionality
                wait for 1 us;
                check_equal(Out_Empty, '1', "Out_Empty not asserted");
                check_equal(In_Empty, '1', "In_Empty not asserted");
                check_equal(In_Level, 0, "In_Level not empty");
                check_equal(Out_Level, 0, "Out_Level not empty");
                wait until falling_edge(In_Clk);
                In_Valid  <= '1';
                In_Data   <= x"8765";
                wait until falling_edge(In_Clk);
                In_Valid  <= '0';
                wait for 1 us;
                check_equal(Out_Empty, '0', "Out_Empty not de-asserted");
                check_equal(In_Empty, '0', "In_Empty not de-asserted");
                check_equal(In_Level, 1, "In_Level not empty");
                check_equal(Out_Level, 1, "Out_Level not empty");
                wait until falling_edge(Out_Clk);
                check_equal(Out_Data, 16#8765#, "Read wrong data");
                Out_Ready <= '1';
                wait until falling_edge(Out_Clk);
                Out_Ready <= '0';
                wait for 1 us;
                check_equal(Out_Empty, '1', "Out_Empty not asserted");
                check_equal(In_Empty, '1', "In_Empty not asserted");
                check_equal(In_Level, 0, "In_Level not empty");
                check_equal(Out_Level, 0, "Out_Level not empty");

            elsif run("AlmostFlags") then

                -- fill
                for i in 0 to Depth_g - 1 loop
                    wait until falling_edge(In_Clk);
                    In_Valid <= '1';
                    In_Data  <= std_logic_vector(to_unsigned(i, In_Data'length));
                    wait until falling_edge(In_Clk);
                    In_Valid <= '0';
                    wait for 1 us;
                    check_equal(In_Level, i + 1, "In_Level wrong");
                    check_equal(Out_Level, i + 1, "Out_Level wrong");
                    if AlmFullOn_g then
                        if i + 1 >= AlmFullLevel_c then
                            check_equal(In_AlmFull, '1', "InAlmost Full not set");
                            check_equal(Out_AlmFull, '1', "OutAlmost Full not set");
                        else
                            check_equal(In_AlmFull, '0', "InAlmost Full set");
                            check_equal(Out_AlmFull, '0', "OutAlmost Full set");
                        end if;
                    end if;
                    if AlmEmptyOn_g then
                        if i + 1 <= AlmEmptyLevel_c then
                            check_equal(In_AlmEmpty, '1', "InAlmost Empty not set");
                            check_equal(Out_AlmEmpty, '1', "OutAlmost Empty not set");
                        else
                            check_equal(In_AlmEmpty, '0', "InAlmost Empty set");
                            check_equal(Out_AlmEmpty, '0', "OutAlmost Empty set");
                        end if;
                    end if;
                end loop;

                -- flush
                for i in Depth_g - 1 downto 0 loop
                    wait until falling_edge(Out_Clk);
                    Out_Ready <= '1';
                    wait until falling_edge(Out_Clk);
                    Out_Ready <= '0';
                    wait for 1 us;
                    check_equal(In_Level, i, "In_Level wrong");
                    check_equal(Out_Level, i, "Out_Level wrong");
                    if AlmFullOn_g then
                        if i >= AlmFullLevel_c then
                            check_equal(In_AlmFull, '1', "InAlmost Full not set");
                            check_equal(Out_AlmFull, '1', "OutAlmost Full not set");
                        else
                            check_equal(In_AlmFull, '0', "InAlmost Full set");
                            check_equal(Out_AlmFull, '0', "OutAlmost Full set");
                        end if;
                    end if;
                    if AlmEmptyOn_g then
                        if i <= AlmEmptyLevel_c then
                            check_equal(In_AlmEmpty, '1', "InAlmost Empty not set");
                            check_equal(Out_AlmEmpty, '1', "OutAlmost Empty not set");
                        else
                            check_equal(In_AlmEmpty, '0', "InAlmost Empty set");
                            check_equal(Out_AlmEmpty, '0', "OutAlmost Empty set");
                        end if;
                    end if;
                end loop;

            elsif run("DiffDutyCycle") then

                -- Loop through all possible write duty-cycles
                for wrDel in 0 to 4 loop

                    -- Loop through all possible read duty-cycles
                    for rdDel in 0 to 4 loop
                        check_equal(In_Empty, '1', "In_Empty not asserted");

                        -- Write data
                        wait until falling_edge(In_Clk);

                        -- Write 5 words
                        for i in 0 to 4 loop
                            In_Valid <= '1';
                            In_Data  <= std_logic_vector(to_unsigned(i, In_Data'length));
                            wait until falling_edge(In_Clk);

                            -- Write delay
                            for k in 1 to wrDel loop
                                In_Valid <= '0';
                                In_Data  <= x"0000";
                                wait until falling_edge(In_Clk);
                            end loop;

                        end loop;

                        In_Valid <= '0';

                        -- Read data
                        wait until falling_edge(Out_Clk);

                        -- Read 5 words
                        for i in 0 to 4 loop
                            Out_Ready <= '1';
                            if Out_Valid = '0' then
                                wait until rising_edge(Out_Clk) and Out_Valid = '1';
                            end if;

                            check_equal(Out_Data, i, "Wrong data");
                            wait until falling_edge(Out_Clk);

                            -- Read delay
                            for k in 1 to rdDel loop
                                Out_Ready <= '0';
                                wait until falling_edge(Out_Clk);
                            end loop;

                        end loop;

                        Out_Ready <= '0';
                        check_equal(Out_Empty, '1', "Empty not asserted");
                        wait for 1 us;
                    end loop;

                end loop;

            elsif run("OutputReadyBeforeData") then
                Out_Ready <= '1';

                for i in 0 to 9 loop
                    wait until falling_edge(Out_Clk);
                    wait until falling_edge(In_Clk);
                end loop;

                In_Data  <= x"ABCD";
                In_Valid <= '1';
                wait until falling_edge(In_Clk);
                In_Data  <= x"4321";
                wait until falling_edge(In_Clk);
                In_Valid <= '0';
                wait until Out_Valid = '1' and rising_edge(Out_Clk);
                check_equal(Out_Empty, '0', "Empty asserted");
                check_equal(Out_Data, 16#ABCD#, "Wrong data 0");
                wait until Out_Valid = '1' and falling_edge(Out_Clk);
                check_equal(Out_Empty, '0', "Empty asserted");
                check_equal(Out_Data, 16#4321#, "Wrong data 1");
                wait until falling_edge(Out_Clk);
                check_equal(Out_Empty, '1', "Empty not asserted");
                check_equal(Out_Valid, '0', "Valid asserted");
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
