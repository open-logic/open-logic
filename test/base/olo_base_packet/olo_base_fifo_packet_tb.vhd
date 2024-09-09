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
entity olo_base_fifo_packet_tb is
    generic (
        runner_cfg      : string
    );
end entity olo_base_fifo_packet_tb;

architecture sim of olo_base_fifo_packet_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------
    constant Width_c  : integer := 16;
    constant Depth_c  : integer := 32;
    constant MaxPackets_c : integer := 4;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant ClockFrequency_c : real    := 100.0e6;
    constant ClockPeriod_c    : time    := (1 sec) / ClockFrequency_c;

    shared variable InDelay : time := 0 ns;
    shared variable OutDelay : time := 0 ns;

    -- *** Verification Compnents ***
	constant axisMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => Width_c,
		stall_config => new_stall_config(0.0, 0, 0)
	);
	constant axisSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => Width_c,
		stall_config => new_stall_config(0.0, 0, 0)
	);

    procedure PushPacket(   signal  net         : inout network_t;
                                    size        : integer;
                                    startVal    : integer := 1)
    is
        variable tlast : std_logic := '0';
    begin
        for i in 0 to size-1 loop
            if i = size-1 then
                tlast := '1';
            end if;
            wait for InDelay;
            push_axi_stream(net, axisMaster, toUslv(startVal + i, Width_c), tlast => tlast);      
        end loop;
    end procedure;

    procedure CheckPacket(  signal  net         : inout network_t;
                                    size        : integer;
                                    startVal    : integer := 1)
    is
        variable tlast : std_logic := '0';
    begin
        for i in 0 to size-1 loop
            if i = size-1 then
                tlast := '1';
            end if;
            wait for OutDelay;
            check_axi_stream(net, axisSlave, toUslv(startVal + i, Width_c), tlast => tlast, blocking => false);
        end loop;
    end procedure;

    procedure TestPacket(   signal  net         : inout network_t;
                                    size        : integer;
                                    startVal    : integer := 1)
    is
    begin
        CheckPacket(net, size, startVal);
        PushPacket(net, size, startVal);
    end procedure;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk           : std_logic                                    := '0';
    signal Rst           : std_logic;
    signal In_Valid      : std_logic                                    := '0';
    signal In_Ready      : std_logic;
    signal In_Data       : std_logic_vector(Width_c - 1 downto 0);
    signal In_Last       : std_logic                                    := '0';
    signal In_Drop       : std_logic                                    := '0';
    signal In_IsDropped  : std_logic;
    signal Out_Valid     : std_logic;
    signal Out_Ready     : std_logic                                    := '0';
    signal Out_Data      : std_logic_vector(Width_c - 1 downto 0);
    signal Out_Last      : std_logic;
    signal Out_Next      : std_logic                                    := '0'; 
    signal Out_Repeat    : std_logic                                    := '0';

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 10 ms);
    p_control : process
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

            -- Default Values
            InDelay := 0 ns;
            OutDelay := 0 ns;

            -- Reset state
            if run("ResetState") then
                check_equal(In_Ready, '1', "In_Ready");
                check_equal(In_IsDropped, '0', "In_IsDropped");
                check_equal(Out_Valid, '0', "Out_Valid");
                check_equal(Out_Last, '0', "Out_Last");
            end if;

            -- *** Simple Cases ***

            if run("SinglePacket") then
                TestPacket(net, 3, 1);
            end if;

            if run("TwoPackets") then
                TestPacket(net, 3, 1);
                TestPacket(net, 4, 4);
            end if;

            if run("LimitedInputRate") then
                InDelay := 10*ClockPeriod_c;
                CheckPacket(net, 3, 1);
                CheckPacket(net, 4, 4);
                PushPacket(net, 3, 1);
                PushPacket(net, 4, 4);              
            end if;

            if run("LimitedOutputRate") then
                OutDelay := 10*ClockPeriod_c;
                PushPacket(net, 3, 1);
                PushPacket(net, 4, 4);
                CheckPacket(net, 3, 1);
                CheckPacket(net, 4, 4);         
            end if;

            if run("WraparoundInPacket") then
                TestPacket(net, Depth_c-5, 1);
                TestPacket(net, 10, 16#100#);
            end if;

            if run("WraparoundBetweenPackets") then
                TestPacket(net, Depth_c, 1);
                TestPacket(net, 10, 16#100#);
            end if;


            -- *** Size=1 Packets ***

            if run("Size1First") then
                TestPacket(net, 1, 1);
                TestPacket(net, 3, 4);
            end if;

            if run("Size1Middle") then
                TestPacket(net, 3, 1);
                TestPacket(net, 1, 4);
                TestPacket(net, 3, 5);
            end if;

            if run("Size1Last") then
                TestPacket(net, 3, 1);
                TestPacket(net, 1, 4);
            end if;

            if run("WraparoundAfterSize1") then
                TestPacket(net, Depth_c-1, 1);
                TestPacket(net, 1, 16#100#);
                TestPacket(net, 10, 16#200#);
            end if;

            if run("WraparoundBeforeSize1") then
                TestPacket(net, Depth_c, 1);
                TestPacket(net, 1, 16#100#);
                TestPacket(net, 10, 16#200#);
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
    Clk <= not Clk after 0.5*ClockPeriod_c;

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_fifo_packet
        generic map ( 
            Width_g             => Width_c,                
            Depth_g             => Depth_c,                                
            RamStyle_g          => "auto",      
            RamBehavior_g       => "RBW",
            SmallRamStyle_g     => "same",
            SmallRamBehavior_g  => "same",
            MaxPackets_g        => MaxPackets_c
        )
        port map (    
            Clk           => Clk,
            Rst           => Rst,
            In_Valid      => In_Valid,
            In_Ready      => In_Ready,
            In_Data       => In_Data,
            In_Last       => In_Last,
            In_Drop       => In_Drop,
            In_IsDropped  => In_IsDropped,
            Out_Valid     => Out_Valid,
            Out_Ready     => Out_Ready,
            Out_Data      => Out_Data,
            Out_Last      => Out_Last,
            Out_Next      => Out_Next,
            Out_Repeat    => Out_Repeat
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
        tlast  => Out_Last 
	);

end sim;
