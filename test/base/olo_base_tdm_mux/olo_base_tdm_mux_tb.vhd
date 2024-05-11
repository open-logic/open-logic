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
entity olo_base_tdm_mux_tb is
    generic (
        runner_cfg      : string
    );
end entity olo_base_tdm_mux_tb;

architecture sim of olo_base_tdm_mux_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant Width_c        : natural   := 16;    
    constant Channels_c     : natural   := 5;
    constant ClkPeriod_c    : time      := 10 ns;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------

    -- *** Verification Compnents ***
	constant axisMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => Width_c,
        user_length => 3,
		stall_config => new_stall_config(0.0, 0, 0)
	);
	constant axisSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => Width_c,
		stall_config => new_stall_config(0.0, 0, 0)
	);

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk         : std_logic                                                  := '0';                                                       
    signal Rst         : std_logic                                                  := '1';                                                       
    signal In_Valid    : std_logic                                                  := '0';                                                       
    signal In_Data     : std_logic_vector(Width_c - 1 downto 0)                     := (others => '0');    
    signal In_ChSel    : std_logic_vector(2 downto 0)                               := (others => '0');
    signal In_Last     : std_logic                                                  := '0';  
    signal Out_Valid   : std_logic                                                  := '0';                                                     
    signal Out_Data    : std_logic_vector(Width_c - 1 downto 0)                     := (others => '0'); 
    signal Out_Last    : std_logic                                                  := '0';
begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process
        variable ChSel_v : integer;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Test each channel
            if run("EachChannel") then
                for ch in 0 to Channels_c-1 loop
                    for s in 0 to Channels_c-1 loop
                        push_axi_stream(net, axisMaster, toUslv(ch*256+s, Width_c), tuser => toUslv(ch, In_ChSel'length), tlast => '0');
                    end loop;
                    check_axi_stream(net, axisSlave, toUslv(ch*256+ch, Width_c), tlast => '0', blocking => false, msg => "data " & integer'image(ch));
                    wait_until_idle(net, as_sync(axisMaster));
                    wait for 1 us;
                end loop;
            end if;

            -- Test select sampling on first sample
            if run("SampleOnFirst") then
                for ch in 0 to Channels_c-1 loop
                    for s in 0 to Channels_c-1 loop
                        if s = 0 then
                            ChSel_v := ch;
                        else
                            ChSel_v := 0;
                        end if;
                        push_axi_stream(net, axisMaster, toUslv(ch*256+s, Width_c), tuser => toUslv(ChSel_v, In_ChSel'length), tlast => '0');
                    end loop;
                    check_axi_stream(net, axisSlave, toUslv(ch*256+ch, Width_c), tlast => '0', blocking => false, msg => "data " & integer'image(ch));
                    wait for 1 us;
                end loop;
            end if;

            if run("ResyncOnTlast") then
                -- Two samples off
                push_axi_stream(net, axisMaster, toUslv(10, Width_c), tuser => toUslv(4, In_ChSel'length), tlast => '0');
                push_axi_stream(net, axisMaster, toUslv(11, Width_c), tuser => toUslv(4, In_ChSel'length), tlast => '1');
                -- Resynchronize (with t-last set)
                for spl in 0 to 3 loop
                    for ch in 0 to Channels_c-1 loop
                        push_axi_stream(net, axisMaster, toUslv(spl*32+ch, Width_c), tuser => toUslv(3, In_ChSel'length), tlast => choose(ch=Channels_c-1, '1', '0'));
                    end loop;
                    check_axi_stream(net, axisSlave, toUslv(spl*32+3, Width_c), tlast => '1', blocking => false, msg => "data " & integer'image(spl));
                end loop;
                -- Test if t-last stays cleared if unused
                for spl in 0 to 3 loop
                    for ch in 0 to Channels_c-1 loop
                        push_axi_stream(net, axisMaster, toUslv(spl*32+ch, Width_c), tuser => toUslv(3, In_ChSel'length), tlast => '0');
                    end loop;
                    check_axi_stream(net, axisSlave, toUslv(spl*32+3, Width_c), tlast => '0', blocking => false, msg => "data " & integer'image(spl));
                end loop;
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
    i_dut : entity olo.olo_base_tdm_mux
        generic map (
            Channels_g   => Channels_c,
            Width_g      => Width_c
        )
        port map (   
            Clk         => Clk,       
            Rst         => Rst,    
            In_ChSel    => In_ChSel,   
            In_Valid    => In_Valid,  
            In_Data     => In_Data,   
            In_Last     => In_Last,   
            Out_Valid   => Out_Valid, 
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
	    tdata  => In_Data,
        tlast  => In_Last,
        tuser  => In_ChSel
	);
  
	vc_response : entity vunit_lib.axi_stream_slave
	generic map (
	    slave => axisSlave
	)
	port map (
	    aclk   => Clk,
	    tvalid => Out_Valid,
	    tdata  => Out_Data,
        tlast  => Out_Last
	);

end sim;
