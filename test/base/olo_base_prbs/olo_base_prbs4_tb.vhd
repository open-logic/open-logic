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
    use olo.olo_base_pkg_array.all;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_prbs4_tb is
    generic (
        runner_cfg      : string;
        BitsPerSymbol_g : positive := 2
    );
end entity;

architecture sim of olo_base_prbs4_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant PrbsSequence_c    : std_logic_vector(14 downto 0)                        := "010110010001111";
    constant PrbsSequenceRep_c : std_logic_vector(4*PrbsSequence_c'length-1 downto 0) := PrbsSequence_c & PrbsSequence_c & PrbsSequence_c & PrbsSequence_c;
    constant States_c          : StlvArray4_t (0 to PrbsSequence_c'high)              := (
        "1111", "1110", "1100", "1000",
        "0001", "0010", "0100", "1001",
        "0011", "0110", "1101", "1010",
        "0101", "1011", "0111"
    );

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => BitsPerSymbol_g,
        stall_config => new_stall_config(0.5, 0, 10)
    );

    constant StateSlave_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => 4,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk           : std_logic                                     := '0';
    signal Rst           : std_logic                                     := '0';
    signal Out_Data      : std_logic_vector(BitsPerSymbol_g- 1 downto 0) := (others => '0');
    signal Out_Ready     : std_logic                                     := '0';
    signal Out_Valid     : std_logic                                     := '0';
    signal State_Current : std_logic_vector(3 downto 0)                  := (others => '0');
    signal State_New     : std_logic_vector(3 downto 0)                  := (others => '0');
    signal State_Set     : std_logic                                     := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable StartBit_v : integer;
        variable StateIdx_v : integer;
        variable Symbol_v   : std_logic_vector(BitsPerSymbol_g-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            InDelay_v := 0 ns;

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("CheckSequence") then
                StartBit_v := 0;

                while StartBit_v < 15 loop
                    Symbol_v := PrbsSequenceRep_c(StartBit_v+BitsPerSymbol_g-1 downto StartBit_v);
                    check_axi_stream(net, AxisSlave_c, Symbol_v, blocking => false, msg => "Wrong Data");
                    -- State is updated already before outputting first symbol
                    if BitsPerSymbol_g > 4 then
                        StateIdx_v := (StartBit_v + BitsPerSymbol_g - 4) mod States_c'length;
                    else
                        StateIdx_v := StartBit_v;
                    end if;
                    check_axi_stream(net, StateSlave_c, States_c(StateIdx_v), blocking => false, msg => "Wrong State");
                    StartBit_v := StartBit_v + BitsPerSymbol_g;
                end loop;

            end if;

            -- Set State
            if run("SetState") then
                -- Set state
                wait until rising_edge(Clk);
                State_New <= States_c(6);
                State_Set <= '1';
                wait until rising_edge(Clk);
                State_New <= (others => '0');
                State_Set <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                -- Chekc Sequency
                StartBit_v := 6;

                while StartBit_v < 15 loop
                    Symbol_v := PrbsSequenceRep_c(StartBit_v+BitsPerSymbol_g-1 downto StartBit_v);
                    check_axi_stream(net, AxisSlave_c, Symbol_v, blocking => false, msg => "Wrong Data");
                    -- State is updated already before outputting first symbol
                    if BitsPerSymbol_g > 4 then
                        StateIdx_v := (StartBit_v + BitsPerSymbol_g - 4) mod States_c'length;
                    else
                        StateIdx_v := StartBit_v;
                    end if;
                    check_axi_stream(net, StateSlave_c, States_c(StateIdx_v), blocking => false, msg => "Wrong State");
                    StartBit_v := StartBit_v + BitsPerSymbol_g;
                end loop;

            end if;

            wait_until_idle(net, as_sync(AxisSlave_c));
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
    i_dut : entity olo.olo_base_prbs
        generic map (
            Polynomial_g    => Polynomial_Prbs4_c,
            Seed_g          => "1111",
            BitsPerSymbol_g => BitsPerSymbol_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Out_Data        => Out_Data,
            Out_Ready       => Out_Ready,
            Out_Valid       => Out_Valid,
            State_Current   => State_Current,
            State_New       => State_New,
            State_Set       => State_Set
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_data : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data
        );

    vc_state : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => StateSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Ready,
            TData  => State_Current
        );

end architecture;
