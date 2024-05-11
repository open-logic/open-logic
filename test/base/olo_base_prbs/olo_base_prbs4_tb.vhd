------------------------------------------------------------------------------
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
    use ieee.math_real.all;

library vunit_lib;
	context vunit_lib.vunit_context;
    context vunit_lib.com_context;
	context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_array.all;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_prbs4_tb is
    generic (
        runner_cfg      : string;
        BitsPerSymbol_g : positive := 2
    );
end entity olo_base_prbs4_tb;

architecture sim of olo_base_prbs4_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant PrbsSequence_c     : std_logic_vector(14 downto 0) := "010110010001111";
    constant PrbsSequenceRep_c  : std_logic_vector(2*PrbsSequence_c'length-1 downto 0) := PrbsSequence_c & PrbsSequence_c;
    constant States_c : t_aslv4 (0 to PrbsSequence_c'high) := ( "1111", "1110", "1100", "1000", 
                                                                "0001", "0010", "0100", "1001",
                                                                "0011", "0110", "1101", "1010",
                                                                "0101", "1011", "0111");

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;
    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    shared variable InDelay     : time := 0 ns;


    -- *** Verification Compnents ***
	constant axisSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => BitsPerSymbol_g,
		stall_config => new_stall_config(0.5, 0, 10)
	);

    constant stateSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => 4,
		stall_config => new_stall_config(0.0, 0, 0)
	);
    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk              : std_logic                                      := '0';                              
    signal Rst              : std_logic                                      := '0';                                                 
    signal Out_Data         : std_logic_vector(BitsPerSymbol_g- 1 downto 0)  := (others => '0'); 
    signal Out_Ready        : std_logic                                      := '0';
    signal Out_Valid        : std_logic                                      := '0';
    signal State_Current    : std_logic_vector(3 downto 0)                   := (others => '0');
    signal State_New        : std_logic_vector(3 downto 0)                   := (others => '0');
    signal State_Set        : std_logic                                      := '0';

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        variable StartBit_v : integer;
        variable Symbol_v   : std_logic_vector(BitsPerSymbol_g-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            InDelay := 0 ns;

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
                    check_axi_stream(net, axisSlave, Symbol_v, blocking => false, msg => "Wrong Data");
                    check_axi_stream(net, stateSlave, States_c(StartBit_v), blocking => false, msg => "Wrong State");
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
                    check_axi_stream(net, axisSlave, Symbol_v, blocking => false, msg => "Wrong Data");
                    check_axi_stream(net, stateSlave, States_c(StartBit_v), blocking => false, msg => "Wrong State");
                    StartBit_v := StartBit_v + BitsPerSymbol_g;
                end loop;
            end if;
            
            wait_until_idle(net, as_sync(axisSlave));
            wait for 1 us;

        end loop;
        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;


    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_prbs
        generic map (
            LfsrWidth_g     => 4,
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

	------------------------------------------------------------
	-- Verification Components
	------------------------------------------------------------
	vc_data : entity vunit_lib.axi_stream_slave
	generic map (
	    slave => axisSlave
	)
	port map (
	    aclk   => Clk,
	    tvalid => Out_Valid,
        tready => Out_Ready,
	    tdata  => Out_Data
	);

	vc_state : entity vunit_lib.axi_stream_slave
	generic map (
	    slave => stateSlave
	)
	port map (
	    aclk   => Clk,
	    tvalid => Out_Ready,
	    tdata  => State_Current
	);

end sim;
