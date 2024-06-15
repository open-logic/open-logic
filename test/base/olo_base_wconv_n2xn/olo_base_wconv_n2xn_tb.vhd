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
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_wconv_n2xn_tb is
    generic (
        runner_cfg      : string;
        WidthRatio_g    : positive range 1 to 3 := 2
    );
end entity olo_base_wconv_n2xn_tb;

architecture sim of olo_base_wconv_n2xn_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant InWidth_c      : natural   := 4;    
    constant OutWidth_c     : natural   := InWidth_c*WidthRatio_g;
    constant ClkPeriod_c    : time      := 10 ns;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    shared variable WordDelay : time := 0 ns;

    -- *** Verification Compnents ***
	constant axisMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => InWidth_c,
		stall_config => new_stall_config(0.0, 0, 0)
	);
	constant axisSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => OutWidth_c,
        user_length => WidthRatio_g,
		stall_config => new_stall_config(0.0, 0, 0)
	);

    function CounterValue(start : integer) return std_logic_vector is
        variable x : std_logic_vector(OutWidth_c-1 downto 0);
    begin
        for i in 0 to WidthRatio_g-1 loop
            x(4*i+3 downto 4*i) := toUslv(start+i, 4);
        end loop;
        return x;
    end function;

    procedure PushCounterValue( signal  net     : inout network_t; 
                                        start   : integer; 
                                        count   : integer;
                                        last    : std_logic) is
        variable lastCheck : std_logic := '0';
    begin
        for i in 0 to count-1 loop
            if i = count-1 then
                lastCheck := last;
            end if;
            if WordDelay > 0 ns then
                wait for WordDelay;
            end if;
            push_axi_stream(net, axisMaster, toUslv(start+i, 4), tlast => lastCheck);
        end loop;
    end procedure;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk         : std_logic                                                  := '0';                                                       
    signal Rst         : std_logic                                                  := '1';                                                       
    signal In_Valid    : std_logic                                                  := '0';                                                       
    signal In_Ready    : std_logic                                                  := '0';                                                       
    signal In_Data     : std_logic_vector(InWidth_c - 1 downto 0)                   := (others => '0');                       
    signal In_Last     : std_logic                                                  := '0';  
    signal Out_WordEna : std_logic_vector(WidthRatio_g - 1 downto 0)                := (others => '0');  
    signal Out_Valid   : std_logic                                                  := '0';                                                     
    signal Out_Ready   : std_logic                                                  := '0'; 
    signal Out_Data    : std_logic_vector(OutWidth_c - 1 downto 0)                  := (others => '0'); 
    signal Out_Last    : std_logic                                                  := '0';

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        variable data       : std_logic_vector(Out_Data'range);
        variable last       : std_logic;
        variable wordEna    : std_logic_vector(Out_WordEna'range);
        variable tkeep, tstrb : std_logic_vector(OutWidth_c/8-1 downto 0);
        variable tdest, tid : std_logic_vector(-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            WordDelay := 0 ns;

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Single Word
            if run("Basic") then
                -- Without last      
                PushCounterValue(net, start => 1, count => WidthRatio_g, last => '0');
                check_axi_stream(net, axisSlave, CounterValue(1), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                -- With last
                PushCounterValue(net, start => 3, count => WidthRatio_g, last => '1');
                check_axi_stream(net, axisSlave, CounterValue(3), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
            end if;

            if run("FullThrottle") then
                PushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                PushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                PushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
                check_axi_stream(net, axisSlave, CounterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                check_axi_stream(net, axisSlave, CounterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                check_axi_stream(net, axisSlave, CounterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
            end if;

            if run("OutLimited") then
                PushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                PushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                PushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
                wait for 200 ns;
                check_axi_stream(net, axisSlave, CounterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                wait for 200 ns;
                check_axi_stream(net, axisSlave, CounterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                wait for 200 ns;
                check_axi_stream(net, axisSlave, CounterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
            end if;

            if run("InLimited") then
                WordDelay := 200 ns;
                check_axi_stream(net, axisSlave, CounterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                check_axi_stream(net, axisSlave, CounterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                check_axi_stream(net, axisSlave, CounterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
                PushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                PushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                PushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
            end if;

            if run("PartialWord") then
                PushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                check_axi_stream(net, axisSlave, CounterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "full Word");
                push_axi_stream(net, axisMaster, toUslv(7, 4), tlast => '1');
                pop_axi_stream(net, axisSlave, tdata => data, tlast => last, tkeep => tkeep, tstrb => tstrb, tid => tid, tdest => tdest, tuser => wordEna);
                check_equal(data(3 downto 0), 7, "lastWord data");
                check_equal(last, '1', "lastWord Last");
                check_equal(wordEna, 1, "lastWort WordEna");
            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(axisMaster));
            wait_until_idle(net, as_sync(axisSlave));

        end loop;
        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk  <= not Clk after 0.5 * ClkPeriod_c;

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_wconv_n2xn
        generic map (
            InWidth_g    => InWidth_c,
            OutWidth_g   => OutWidth_c
        )
        port map (   
            Clk         => Clk,       
            Rst         => Rst,       
            In_Valid    => In_Valid,  
            In_Ready    => In_Ready,  
            In_Data     => In_Data,   
            In_Last     => In_Last,   
            Out_WordEna => Out_WordEna,
            Out_Valid   => Out_Valid, 
            Out_Ready   => Out_Ready, 
            Out_Data    => Out_Data,  
            Out_Last    => Out_Last  
        ); 

	------------------------------------------------------------
	-- Verification Components
	------------------------------------------------------------
	vc_stimuli : entity vunit_lib.axi_stream_master
	generic map (
	    master => axisMaster
	)
	port map (
	    aclk   => Clk,
	    tvalid => In_Valid,
        tready => In_Ready,
	    tdata  => In_Data,
        tlast  => In_Last
	);
  
	vc_response : entity vunit_lib.axi_stream_slave
	generic map (
	    slave => axisSlave
	)
	port map (
	    aclk   => Clk,
	    tvalid => Out_Valid,
        tready => Out_Ready,
	    tdata  => Out_Data,
        tlast  => Out_Last,
        tuser  => Out_WordEna
    
	);

end sim;
