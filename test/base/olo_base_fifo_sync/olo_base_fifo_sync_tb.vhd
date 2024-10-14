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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_sync_tb is
    generic (
        runner_cfg      : string;
        AlmFullOn_g     : boolean              := true;
        AlmEmptyOn_g    : boolean              := true;
        Depth_g         : natural              := 32;
        RamBehavior_g   : string               := "RBW";
        ReadyRstState_g : integer range 0 to 1 := 1
    );
end entity;

architecture sim of olo_base_fifo_sync_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c     : integer := 16;
    constant AlmFullLevel_c  : natural := Depth_g - 3;
    constant AlmEmptyLevel_c : natural := 5;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClockFrequency_c : real := 100.0e6;
    constant ClockPeriod_c    : time := (1 sec) / ClockFrequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                            := '0';
    signal Rst       : std_logic                                            := '1';
    signal In_Data   : std_logic_vector(DataWidth_c - 1 downto 0)           := (others => '0');
    signal In_Valid  : std_logic                                            := '0';
    signal In_Ready  : std_logic                                            := '0';
    signal Out_Data  : std_logic_vector(DataWidth_c - 1 downto 0)           := (others => '0');
    signal Out_Valid : std_logic                                            := '0';
    signal Out_Ready : std_logic                                            := '0';
    signal Full      : std_logic                                            := '0';
    signal Empty     : std_logic                                            := '0';
    signal AlmFull   : std_logic                                            := '0';
    signal AlmEmpty  : std_logic                                            := '0';
    signal In_Level  : std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0) := (others => '0');
    signal Out_Level : std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_fifo_sync
        generic map (
            Width_g             => DataWidth_c,
            Depth_g             => Depth_g,
            AlmFullOn_g         => AlmFullOn_g,
            AlmFullLevel_g      => AlmFullLevel_c,
            AlmEmptyOn_g        => AlmEmptyOn_g,
            AlmEmptyLevel_g     => AlmEmptyLevel_c,
            RamBehavior_g       => RamBehavior_g,
            ReadyRstState_g     => toStdl(ReadyRstState_g)
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => In_Data,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready,
            Out_Data  => Out_Data,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready,
            Full      => Full,
            Empty     => Empty,
            AlmFull   => AlmFull,
            AlmEmpty  => AlmEmpty,
            In_Level  => In_Level,
            Out_Level => Out_Level
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClockPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- *** Reset ***
            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            -- check if ready state during reset is correct
            check_equal(toStdl(ReadyRstState_g), In_Ready, "In_Ready reset state not according to generic");
            wait for 1 us;

            -- Remove reset
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("Reset") then
                -- Check Reset State
                check_equal(In_Ready, '1', "In_Ready after reset state not '1'");
                check_equal(Out_Valid, '0', "Out_Valid reset state not '0'");
                check_equal(Full, '0', "Full reset state not '0'");
                check_equal(Empty, '1', "Empty reset state not '1'");
                check_equal(In_Level, 0, "In_Level reset state not 0");
                check_equal(Out_Level, 0, "In_Level reset state not 0");
                if AlmFullOn_g then
                    check_equal(AlmFull, '0', "AlmFull reset state not '0'");
                end if;
                if AlmEmptyOn_g then
                    check_equal(AlmEmpty, '1',  "AlmEmpty reset state not '1'");
                end if;

            elsif run("TwoWordsWriteAndRead") then

                -- Write 1
                wait until falling_edge(Clk);
                In_Data  <= x"0001";
                In_Valid <= '1';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '0', "Out_Valid wnt high unexpectedly");
                check_equal(Empty, '1', "Empty not high");
                check_equal(In_Level, 0, "In_Level not 0");
                check_equal(Out_Level, 0, "Out_Level not 0");

                -- Write 2
                wait until falling_edge(Clk);
                In_Data <= x"0002";
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '0', "Out_Valid wnt high unexpectedly");
                check_equal(Empty, '1', "Empty not high");
                check_equal(In_Level, 1, "In_Level not 0");
                check_equal(Out_Level, 0, "Out_Level not 0");

                -- Pause 1
                wait until falling_edge(Clk);
                In_Data  <= x"0003";
                In_Valid <= '0';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0001#, "Illegal Out_Data 1");
                check_equal(Empty, '0', "Empty not low");
                check_equal(In_Level, 2, "In_Level not 2");
                check_equal(Out_Level, 1, "Out_Level not 1");

                -- Pause 2
                wait until falling_edge(Clk);
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0001#, "Illegal Out_Data 1");
                check_equal(Empty, '0', "Empty not low");
                check_equal(In_Level, 2, "In_Level not 2");
                check_equal(Out_Level, 2, "Out_Level not 2");

                -- Read ack 1
                wait until falling_edge(Clk);
                Out_Ready <= '1';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0001#, "Illegal Out_Data 1");
                check_equal(Empty, '0', "Empty not low");
                check_equal(In_Level, 2, "In_Level not 2");
                check_equal(Out_Level, 2, "Out_Level not 2");

                -- Read ack 2
                wait until falling_edge(Clk);
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '1', "Out_Valid not high");
                check_equal(Out_Data, 16#0002#, "Illegal Out_Data 2");
                check_equal(Empty, '0', "Empty not low");
                check_equal(In_Level, 2, "In_Level not 2");
                check_equal(Out_Level, 1, "Out_Level not 1");

                -- empty 1
                wait until falling_edge(Clk);
                Out_Ready <= '0';
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '0', "Out_Valid not high");
                check_equal(Empty, '1', "Empty not high");
                check_equal(In_Level, 1, "In_Level not 1");
                check_equal(Out_Level, 0, "Out_Level not 0");

                -- empty 2
                wait until falling_edge(Clk);
                check_equal(In_Ready, '1', "In_Ready went low unexpectedly");
                check_equal(Out_Valid, '0', "Out_Valid not high");
                check_equal(Empty, '1', "Empty not high");
                check_equal(In_Level, 0, "In_Level not 0");
                check_equal(Out_Level, 0, "Out_Level not 0");

            elsif run("WriteFullFifo") then
                wait until falling_edge(Clk);

                -- Fill FIFO
                for i in 0 to Depth_g - 1 loop
                    In_Valid <= '1';
                    In_Data  <= toUslv(i, In_Data'length);
                    wait until falling_edge(Clk);
                end loop;

                In_Valid <= '0';
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Full, '1', "Full not asserted");
                check_equal(In_Level, Depth_g, "In_Level not Full");
                check_equal(Out_Level, Depth_g, "Out_Level not Full");

                -- Add more data (not written because full)
                In_Valid <= '1';
                In_Data  <= x"ABCD";
                wait until falling_edge(Clk);
                In_Data  <= x"8765";
                wait until falling_edge(Clk);
                In_Valid <= '0';
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Full, '1', "Full not asserted");
                check_equal(In_Level, Depth_g, "In_Level not Full");
                check_equal(Out_Level, Depth_g, "Out_Level not Full");

                -- Check read
                for i in 0 to Depth_g - 1 loop
                    Out_Ready <= '1';
                    check_equal(Out_Data, i, "Read wrong data in word " & integer'image(i));
                    wait until falling_edge(Clk);
                end loop;

                Out_Ready <= '0';
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Empty, '1', "Empty not asserted");
                check_equal(Full, '0', "Full not de-asserted");
                check_equal(In_Level, 0, "In_Level not Empty");
                check_equal(Out_Level, 0, "Out_Level not Empty");

            elsif run("ReadEmptyFifo") then
                wait until falling_edge(Clk);
                check_equal(Empty, '1', "Empty not asserted");

                -- read
                wait until falling_edge(Clk);
                Out_Ready <= '1';
                wait until falling_edge(Clk);
                Out_Ready <= '0';

                -- check correct output
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Empty, '1', "Empty not asserted");
                check_equal(In_Level, 0, "In_Level not Empty");
                check_equal(Out_Level, 0, "Out_Level not Empty");
                In_Valid  <= '1';
                In_Data   <= x"8765";
                wait until falling_edge(Clk);
                In_Valid  <= '0';
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Empty, '0', "Empty not de-asserted");
                check_equal(In_Level, 1, "In_Level not 1");
                check_equal(Out_Level, 1, "Out_Level not 1");
                check_equal(Out_Data, 16#8765#, "Read wrong data");
                Out_Ready <= '1';
                wait until falling_edge(Clk);
                Out_Ready <= '0';
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
                check_equal(Empty, '1', "Empty not asserted");
                check_equal(In_Level, 0, "In_Level not Empty");
                check_equal(Out_Level, 0, "Out_Level not Empty");

            elsif run("AlmostFlags") then
                wait until falling_edge(Clk);

                -- fill FIFO
                for i in 0 to Depth_g - 1 loop
                    In_Valid <= '1';
                    In_Data  <= std_logic_vector(to_unsigned(i, In_Data'length));
                    wait until falling_edge(Clk);
                    In_Valid <= '0';
                    wait until falling_edge(Clk);
                    wait until falling_edge(Clk);
                    check_equal(In_Level, i+1, "In_Level wrong fill");
                    check_equal(Out_Level, i+1, "Out_Level wrong fill");
                    if AlmFullOn_g then
                        if i + 1 >= AlmFullLevel_c then
                            check_equal(AlmFull, '1', "Full not set");
                        else
                            check_equal(AlmFull, '0', "Almost Full set");
                        end if;
                    end if;
                    if AlmEmptyOn_g then
                        if i + 1 <= AlmEmptyLevel_c then
                            check_equal(AlmEmpty, '1', "Almost Empty not set");
                        else
                            check_equal(AlmEmpty, '0', "Almost Empty set");
                        end if;
                    end if;
                end loop;

                -- flush
                for i in Depth_g - 1 downto 0 loop
                    Out_Ready <= '1';
                    wait until falling_edge(Clk);
                    Out_Ready <= '0';
                    wait until falling_edge(Clk);
                    wait until falling_edge(Clk);
                    check_equal(In_Level, i, "In_Level wrong flush");
                    check_equal(Out_Level, i, "Out_Level wrong flush");
                    if AlmFullOn_g then
                        if i >= AlmFullLevel_c then
                            check_equal(AlmFull, '1', "Almost Full not set");
                        else
                            check_equal(AlmFull, '0', "Almost Full set");
                        end if;
                    end if;
                    if AlmEmptyOn_g then
                        if i <= AlmEmptyLevel_c then
                            check_equal(AlmEmpty, '1', "Almost Empty not set");
                        else
                            check_equal(AlmEmpty, '0', "Almost Empty set");
                        end if;
                    end if;
                end loop;

            elsif run("DiffDutyCycle") then
                wait until falling_edge(Clk);

                -- Loop through write duty cycles
                for wrDel in 0 to 4 loop

                    -- Loop through read duty cycles
                    for rdDel in 0 to 4 loop
                        check_equal(Empty, '1', "Empty not asserted");

                        -- Write data
                        for i in 0 to 4 loop
                            In_Valid <= '1';
                            In_Data  <= toUslv(i, In_Data'length);
                            wait until falling_edge(Clk);

                            -- Wrie delay
                            for k in 1 to wrDel loop
                                In_Valid <= '0';
                                In_Data  <= x"0000";
                                wait until falling_edge(Clk);
                            end loop;

                        end loop;

                        In_Valid <= '0';

                        -- Read data
                        for i in 0 to 4 loop
                            Out_Ready <= '1';
                            check_equal(Out_Data, i, "Wrong data");
                            wait until falling_edge(Clk);

                            -- Read delay
                            for k in 1 to rdDel loop
                                Out_Ready <= '0';
                                wait until falling_edge(Clk);
                            end loop;

                        end loop;

                        Out_Ready <= '0';
                        check_equal(Empty, '1', "Empty not asserted");
                    end loop;

                end loop;

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
