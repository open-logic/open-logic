------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
	context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_async_tb is
    generic (
        runner_cfg      : string;
        AlmFullOn_g     : boolean              := true;
        AlmEmptyOn_g    : boolean              := true;
        Depth_g         : natural              := 32;
        RamBehavior_g   : string               := "RBW";
        ReadyRstState_g : integer range 0 to 1 := 1
    );
end entity olo_base_fifo_async_tb;

architecture sim of olo_base_fifo_async_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------
    constant DataWidth_c     : integer := 16;
    constant AlmFullLevel_c  : natural := Depth_g - 3;
    constant AlmEmptyLevel_c : natural := 5;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant ClockInFrequency_c  : real    := 100.0e6;
    constant ClockInPeriod_c     : time    := (1 sec) / ClockInFrequency_c;
    constant ClockOutFrequency_c : real    := 83.333e6;
    constant ClockOutPeriod_c    : time    := (1 sec) / ClockOutFrequency_c;
    signal TbRunning             : boolean := True;

    shared variable CheckNow : boolean := False;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal In_Clk       : std_logic                                            := '0';
    signal In_Rst       : std_logic                                            := '1';
    signal Out_Clk      : std_logic                                            := '0';
    signal Out_Rst      : std_logic                                            := '1';
    signal In_Data      : std_logic_vector(DataWidth_c-1 downto 0)             := (others => '0');
    signal In_Valid     : std_logic                                            := '0';
    signal In_Ready     : std_logic                                            := '0';
    signal Out_Data     : std_logic_vector(DataWidth_c-1 downto 0)             := (others => '0');
    signal Out_Valid    : std_logic                                            := '0';
    signal Out_Ready    : std_logic                                            := '0';
    signal In_Full      : std_logic                                            := '0';
    signal Out_Full     : std_logic                                            := '0';
    signal In_Empty     : std_logic                                            := '0';
    signal Out_Empty    : std_logic                                            := '0';
    signal In_AlmFull   : std_logic                                            := '0';
    signal Out_AlmFull  : std_logic                                            := '0';
    signal In_AlmEmpty  : std_logic                                            := '0';
    signal Out_AlmEmpty : std_logic                                            := '0';
    signal In_Level     : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0)  := (others => '0');
    signal Out_Level    : std_logic_vector(log2ceil(Depth_g+1)-1 downto 0)  := (others => '0');

begin

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_fifo_async
        generic map (
            Width_g         => DataWidth_c,
            Depth_g         => Depth_g,
            AlmFullOn_g     => AlmFullOn_g,
            AlmFullLevel_g  => AlmFullLevel_c,
            AlmEmptyOn_g    => AlmEmptyOn_g,
            AlmEmptyLevel_g => AlmEmptyLevel_c,
            RamBehavior_g   => RamBehavior_g,
            ReadyRstState_g => int_to_std_logic(ReadyRstState_g)
      )
      port map(
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

  -------------------------------------------------------------------------
  -- Clock
  -------------------------------------------------------------------------
  p_clk_in : process
  begin
    In_Clk <= '0';
    while TbRunning loop
      wait for 0.5 * ClockInPeriod_c;
      In_Clk <= '1';
      wait for 0.5 * ClockInPeriod_c;
      In_Clk <= '0';
    end loop;
    wait;
  end process;

  p_clk_out : process
  begin
    Out_Clk <= '0';
    while TbRunning loop
      wait for 0.5 * ClockOutPeriod_c;
      Out_Clk <= '1';
      wait for 0.5 * ClockOutPeriod_c;
      Out_Clk <= '0';
    end loop;
    wait;
  end process;

  -------------------------------------------------------------------------
  -- TB Control
  -------------------------------------------------------------------------
  p_control : process
  begin
    -- *** Reset Tests ***
    print(">> Reset");
    -- Reset
    In_Rst  <= '1';
    Out_Rst <= '1';
    -- check if ready state during reset is correct
    wait for 20 ns;                     -- reset must be transferred to other clock domain
    wait until rising_edge(In_Clk);
    assert In_Ready = int_to_std_logic(ReadyRstState_g) report "###ERROR###: In_Ready reset state not according to generic" severity error;
    wait for 1 us;

    -- Remove reset
    wait until rising_edge(In_Clk);
    In_Rst  <= '0';
    wait until rising_edge(Out_Clk);
    Out_Rst <= '0';
    wait for 100 ns;

    -- Check Reset State
    wait until rising_edge(In_Clk);
    assert In_Ready = '1' report "###ERROR###: In_Ready after reset state not '1'" severity error;
    assert In_Full = '0' report "###ERROR###: In_Full reset state not '0'" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty reset state not '1'" severity error;
    assert unsigned(In_Level) = 0 report "###ERROR###: In_Level reset state not 0" severity error;
    if AlmFullOn_g then
      assert In_AlmFull = '0' report "###ERROR###: In_AlmFull reset state not '0'" severity error;
    end if;
    if AlmEmptyOn_g then
      assert In_AlmEmpty = '1' report "###ERROR###: In_AlmEmpty reset state not '1'" severity error;
    end if;

    wait until rising_edge(Out_Clk);
    assert Out_Valid = '0' report "###ERROR###: Out_Valid reset state not '0'" severity error;
    assert Out_Full = '0' report "###ERROR###: Out_Full reset state not '0'" severity error;
    assert Out_Empty = '1' report "###ERROR###: Out_Empty reset state not '1'" severity error;
    assert unsigned(Out_Level) = 0 report "###ERROR###: Out_Level reset state not 0" severity error;
    if AlmFullOn_g then
      assert Out_AlmFull = '0' report "###ERROR###: Out_AlmFull reset state not '0'" severity error;
    end if;
    if AlmEmptyOn_g then
      assert Out_AlmEmpty = '1' report "###ERROR###: Out_AlmEmpty reset state not '1'" severity error;
    end if;

    -- *** Two words write then read ***
    print(">> Two words write then read");
    -- Write 1
    wait until falling_edge(In_Clk);
    In_Data  <= X"0001";
    In_Valid  <= '1';
    assert In_Ready = '1' report "###ERROR###: In_Ready went low unexpectedly" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty not high" severity error;
    assert unsigned(In_Level) = 0 report "###ERROR###: In_Level not 0" severity error;
    -- Write 2
    wait until falling_edge(In_Clk);
    In_Data  <= X"0002";
    assert In_Ready = '1' report "###ERROR###: In_Ready went low unexpectedly" severity error;
    assert In_Empty = '0' report "###ERROR###: Empty not low" severity error;
    assert unsigned(In_Level) = 1 report "###ERROR###: In_Level not 1" severity error;
    -- Pause 1
    wait until falling_edge(In_Clk);
    In_Data  <= X"0003";
    In_Valid  <= '0';
    assert In_Ready = '1' report "###ERROR###: In_Ready went low unexpectedly" severity error;
    assert In_Empty = '0' report "###ERROR###: Empty not low" severity error;
    assert unsigned(In_Level) = 2 report "###ERROR###: In_Level not 2" severity error;
    -- Pause 2
    for i in 0 to 4 loop
      wait until falling_edge(In_Clk);
      wait until falling_edge(Out_Clk);
    end loop;
    assert In_Ready = '1' report "###ERROR###: In_Ready went low unexpectedly" severity error;
    assert Out_Valid = '1' report "###ERROR###: Out_Valid not high" severity error;
    assert Out_Data = X"0001" report "###ERROR###: Illegal Out_Data 1" severity error;
    assert In_Empty = '0' report "###ERROR###: In_Empty not low" severity error;
    assert In_Full = '0' report "###ERROR###: In_Full not low" severity error;
    assert Out_Empty = '0' report "###ERROR###: In_Empty not low" severity error;
    assert Out_Full = '0' report "###ERROR###: In_Full not low" severity error;
    assert unsigned(In_Level) = 2 report "###ERROR###: In_Level not 2" severity error;
    assert unsigned(Out_Level) = 2 report "###ERROR###: Out_Level not 2" severity error;
    -- Read ack 1
    wait until falling_edge(Out_Clk);
    Out_Ready <= '1';
    assert Out_Valid = '1' report "###ERROR###: Out_Valid not high" severity error;
    assert Out_Data = X"0001" report "###ERROR###: Illegal Out_Data 1" severity error;
    assert Out_Empty = '0' report "###ERROR###: Empty not low" severity error;
    assert unsigned(Out_Level) = 2 report "###ERROR###: Out_Level not 2" severity error;
    -- Read ack 2
    wait until falling_edge(Out_Clk);
    assert Out_Valid = '1' report "###ERROR###: Out_Valid not high" severity error;
    assert Out_Data = X"0002" report "###ERROR###: Illegal Out_Data 2" severity error;
    assert Out_Empty = '0' report "###ERROR###: Empty not low" severity error;
    assert unsigned(Out_Level) = 1 report "###ERROR###: Out_Level not 1" severity error;
    -- empty 1
    wait until falling_edge(Out_Clk);
    Out_Ready <= '0';
    assert Out_Valid = '0' report "###ERROR###: Out_Valid not high" severity error;
    assert Out_Empty = '1' report "###ERROR###: Empty not high" severity error;
    assert unsigned(Out_Level) = 0 report "###ERROR###: Out_Level not 0" severity error;
    -- empty 2
    for i in 0 to 4 loop
      wait until falling_edge(Out_Clk);
      wait until falling_edge(In_Clk);
    end loop;
    assert In_Ready = '1' report "###ERROR###: In_Ready went low unexpectedly" severity error;
    assert Out_Valid = '0' report "###ERROR###: Out_Valid not high" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty not high" severity error;
    assert Out_Empty = '1' report "###ERROR###: Out_Empty not high" severity error;
    assert In_Full = '0' report "###ERROR###: In_Full not low" severity error;
    assert Out_Full = '0' report "###ERROR###: Out_Full not low" severity error;
    assert unsigned(In_Level) = 0 report "###ERROR###: In_Level not 0" severity error;
    assert unsigned(Out_Level) = 0 report "###ERROR###: Out_Level not 0" severity error;

    -- *** Write into Full FIFO ***
    wait until falling_edge(In_Clk);
    print(">> Write into Full FIFO");
    -- Fill FIFO
    for i in 0 to Depth_g - 1 loop
      In_Valid <= '1';
      In_Data <= std_logic_vector(to_unsigned(i, In_Data'length));
      wait until falling_edge(In_Clk);
    end loop;
    In_Valid  <= '0';
    wait for 1 us;
    assert In_Full = '1' report "###ERROR###: In_Full not asserted" severity error;
    assert Out_Full = '1' report "###ERROR###: Out_Full not asserted" severity error;
    assert unsigned(In_Level) = Depth_g report "###ERROR###: In_Level not full" severity error;
    assert unsigned(Out_Level) = Depth_g report "###ERROR###: Out_Level not full" severity error;
    -- Add more data (not written because full)
    wait until falling_edge(In_Clk);
    In_Valid  <= '1';
    In_Data  <= X"ABCD";
    wait until falling_edge(In_Clk);
    In_Data  <= X"8765";
    wait until falling_edge(In_Clk);
    In_Valid  <= '0';
    wait for 1 us;
    assert In_Full = '1' report "###ERROR###: In_Full not asserted" severity error;
    assert Out_Full = '1' report "###ERROR###: Out_Full not asserted" severity error;
    assert unsigned(In_Level) = Depth_g report "###ERROR###: In_Level not full" severity error;
    assert unsigned(Out_Level) = Depth_g report "###ERROR###: Out_Level not full" severity error;
    -- Check read
    wait until falling_edge(Out_Clk);
    for i in 0 to Depth_g - 1 loop
      Out_Ready <= '1';
      assert unsigned(Out_Data) = i report "###ERROR: Read wrong data in word " & integer'image(i) severity error;
      wait until falling_edge(Out_Clk);
    end loop;
    Out_Ready <= '0';
    wait for 1 us;
    assert In_Empty = '1' report "###ERROR###: In_Empty not asserted" severity error;
    assert Out_Empty = '1' report "###ERROR###: Out_Empty not asserted" severity error;
    assert In_Full = '0' report "###ERROR###: In_Full not de-asserted" severity error;
    assert Out_Full = '0' report "###ERROR###: Out_Full not de-asserted" severity error;

    -- *** Read from Empty Fifo ***
    wait until falling_edge(Out_Clk);
    print(">> Read from Empty FIFO");
    assert Out_Empty = '1' report "###ERROR###: Out_Empty not asserted" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty not asserted" severity error;
    -- read
    wait until falling_edge(Out_Clk);
    Out_Ready <= '1';
    wait until falling_edge(Out_Clk);
    Out_Ready <= '0';
    -- check correct functionality
    wait for 1 us;
    assert Out_Empty = '1' report "###ERROR###: Out_Empty not asserted" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty not asserted" severity error;
    assert unsigned(In_Level) = 0 report "###ERROR###: In_Level not empty" severity error;
    assert unsigned(Out_Level) = 0 report "###ERROR###: Out_Level not empty" severity error;
    wait until falling_edge(In_Clk);
    In_Valid  <= '1';
    In_Data  <= X"8765";
    wait until falling_edge(In_Clk);
    In_Valid  <= '0';
    wait for 1 us;
    assert Out_Empty = '0' report "###ERROR###: Out_Empty not de-asserted" severity error;
    assert In_Empty = '0' report "###ERROR###: In_Empty not de-asserted" severity error;
    assert unsigned(In_Level) = 1 report "###ERROR###: In_Level not empty" severity error;
    assert unsigned(Out_Level) = 1 report "###ERROR###: Out_Level not empty" severity error;
    wait until falling_edge(Out_Clk);
    assert Out_Data = X"8765" report "###ERROR: Read wrong data" severity error;
    Out_Ready <= '1';
    wait until falling_edge(Out_Clk);
    Out_Ready <= '0';
    wait for 1 us;
    assert Out_Empty = '1' report "###ERROR###: Out_Empty not asserted" severity error;
    assert In_Empty = '1' report "###ERROR###: In_Empty not asserted" severity error;
    assert unsigned(In_Level) = 0 report "###ERROR###: In_Level not empty" severity error;
    assert unsigned(Out_Level) = 0 report "###ERROR###: Out_Level not empty" severity error;

    -- *** Almost full/almost empty
    print(">> Almost full/almost empty");
    -- fill
    for i in 0 to Depth_g - 1 loop
      wait until falling_edge(In_Clk);
      In_Valid <= '1';
      In_Data <= std_logic_vector(to_unsigned(i, In_Data'length));
      wait until falling_edge(In_Clk);
      In_Valid <= '0';
      wait for 1 us;
      assert unsigned(In_Level) = i + 1 report "###ERROR###: In_Level wrong" severity error;
      assert unsigned(Out_Level) = i + 1 report "###ERROR###: Out_Level wrong" severity error;
      if AlmFullOn_g then
        if i + 1 >= AlmFullLevel_c then
          assert In_AlmFull = '1' report "###ERROR###: InAlmost Full not set" severity error;
          assert Out_AlmFull = '1' report "###ERROR###: OutAlmost Full not set" severity error;
        else
          assert In_AlmFull = '0' report "###ERROR###: InAlmost Full set" severity error;
          assert Out_AlmFull = '0' report "###ERROR###: OutAlmost Full set" severity error;
        end if;
      end if;
      if AlmEmptyOn_g then
        if i + 1 <= AlmEmptyLevel_c then
          assert In_AlmEmpty = '1' report "###ERROR###: InAlmost Empty not set" severity error;
          assert Out_AlmEmpty = '1' report "###ERROR###: OutAlmost Empty not set" severity error;
        else
          assert In_AlmEmpty = '0' report "###ERROR###: InAlmost Empty set" severity error;
          assert Out_AlmEmpty = '0' report "###ERROR###: OutAlmost Empty set" severity error;
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
      assert unsigned(In_Level) = i report "###ERROR###: In_Level wrong" severity error;
      assert unsigned(Out_Level) = i report "###ERROR###: Out_Level wrong" severity error;
      if AlmFullOn_g then
        if i >= AlmFullLevel_c then
          assert In_AlmFull = '1' report "###ERROR###: InAlmost Full not set" severity error;
          assert Out_AlmFull = '1' report "###ERROR###: OutAlmost Full not set" severity error;
        else
          assert In_AlmFull = '0' report "###ERROR###: InAlmost Full set" severity error;
          assert Out_AlmFull = '0' report "###ERROR###: OutAlmost Full set" severity error;
        end if;
      end if;
      if AlmEmptyOn_g then
        if i <= AlmEmptyLevel_c then
          assert In_AlmEmpty = '1' report "###ERROR###: InAlmost Empty not set" severity error;
          assert Out_AlmEmpty = '1' report "###ERROR###: OutAlmost Empty not set" severity error;
        else
          assert In_AlmEmpty = '0' report "###ERROR###: InAlmost Empty set" severity error;
          assert Out_AlmEmpty = '0' report "###ERROR###: OutAlmost Empty set" severity error;
        end if;
      end if;
    end loop;

    -- Different duty cycles
    print(">> Different Duty Cycles");
    for wrDel in 0 to 4 loop
      for rdDel in 0 to 4 loop
        assert In_Empty = '1' report "###ERROR###: In_Empty not asserted" severity error;
        -- Write data
        wait until falling_edge(In_Clk);
        for i in 0 to 4 loop
          In_Valid <= '1';
          In_Data <= std_logic_vector(to_unsigned(i, In_Data'length));
          wait until falling_edge(In_Clk);
          for k in 1 to wrDel loop
            In_Valid <= '0';
            In_Data <= X"0000";
            wait until falling_edge(In_Clk);
          end loop;
        end loop;
        In_Valid  <= '0';
        -- Read data
        wait until falling_edge(Out_Clk);
        for i in 0 to 4 loop
          Out_Ready <= '1';
          assert unsigned(Out_Data) = i report "###ERROR###: Wrong data" severity error;
          wait until falling_edge(Out_Clk);
          for k in 1 to rdDel loop
            Out_Ready <= '0';
            wait until falling_edge(Out_Clk);
          end loop;
        end loop;
        Out_Ready <= '0';
        assert Out_Empty = '1' report "###ERROR###: Empty not asserted" severity error;
        wait for 1 us;
      end loop;
    end loop;

    -- Output Ready before data available
    print(">> Output Ready before data available");
    Out_Ready <= '1';
    for i in 0 to 9 loop
      wait until falling_edge(Out_Clk);
      wait until falling_edge(In_Clk);
    end loop;
    In_Data  <= X"ABCD";
    In_Valid  <= '1';
    wait until falling_edge(In_Clk);
    In_Data  <= X"4321";
    wait until falling_edge(In_Clk);
    In_Valid  <= '0';
    wait until Out_Valid = '1' and rising_edge(Out_Clk);
    assert Out_Empty = '0' report "###ERROR###: Empty asserted" severity error;
    assert Out_Data = X"ABCD" report "###ERROR###: Wrong data 0" severity error;
    wait until Out_Valid = '1' and falling_edge(Out_Clk);
    assert Out_Empty = '0' report "###ERROR###: Empty asserted" severity error;
    assert Out_Data = X"4321" report "###ERROR###: Wrong data 1" severity error;
    wait until falling_edge(Out_Clk);
    assert Out_Empty = '1' report "###ERROR###: Empty not asserted" severity error;
    assert Out_Valid = '0' report "###ERROR###: Valid asserted" severity error;

    -- TB done
    TbRunning <= false;
    wait;
  end process;

end sim;
