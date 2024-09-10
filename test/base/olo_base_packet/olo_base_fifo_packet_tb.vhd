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
        user_length => 1,
		stall_config => new_stall_config(0.0, 0, 0)
	);
	constant axisSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => Width_c,
		stall_config => new_stall_config(0.0, 0, 0)
	);
    constant axisNextRepeatMaster : axi_stream_master_t := new_axi_stream_master (
        data_length => 2,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure PushPacket(   signal  net         : inout network_t;
                                    size        : integer;
                                    startVal    : integer := 1;
                                    dropAt      : integer := -1)
    is
        variable tlast : std_logic := '0';
        variable drop  : std_logic := '0';
        variable tuser : std_logic_vector(0 downto 0);
    begin
        check(dropAt < size, "PushPacket: dropAt must be smaller than size");
        for i in 0 to size-1 loop
            if i = size-1 then
                tlast := '1';
            end if;
            if dropAt = i then
                drop := '1';
            else
                drop := '0';
            end if;
            tuser(0) := drop;
            wait for InDelay;
            push_axi_stream(net, axisMaster, toUslv(startVal + i, Width_c), tlast => tlast, tuser => tuser);      
        end loop;
    end procedure;

    procedure CheckPacket(  signal  net         : inout network_t;
                                    size        : integer;
                                    startVal    : integer := 1;
                                    nextAt      : integer := -1;
                                    repeatAt    : integer := -1)
    is
        variable tlast : std_logic := '0';
        variable next_v, repeat_v : std_logic := '0';
    begin
        for i in 0 to size-1 loop
            -- Next/Repeat
            next_v := '0';
            repeat_v := '0';
            if nextAt = i then
                next_v := '1';
            end if;
            if repeatAt = i then
                repeat_v := '1';
            end if;
            push_axi_stream(net, axisNextRepeatMaster, repeat_v & next_v);
            -- Data
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

            -- *** Drop Packet Test (Input Side) ***
            
            if run("DropPacketMiddle") then
                for dropWord in 0 to 2 loop
                    TestPacket(net, 3, 1);
                    PushPacket(net, 3, 16, dropAt => dropWord);
                    TestPacket(net, 3, 32);
                    wait for 1 us;
                end loop;
            end if;

            if run("DropPacketFirstPacket") then
                PushPacket(net, 3, 1, dropAt => 0);
                TestPacket(net, 3, 16);
            end if;

            if run("DropPacketMiddleSize1") then
                TestPacket(net, 3, 1);
                PushPacket(net, 1, 16, dropAt => 0);
                TestPacket(net, 3, 32);
            end if;

            if run("DropPacketFirstSize1") then
                PushPacket(net, 1, 1, dropAt => 0);
                TestPacket(net, 3, 16);
            end if;

            if run("DropPacket-ContainingWraparound-SplBeforeWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#, dropAt => 1);
                TestPacket(net, 12, 16#200#);
            end if;

            if run("DropPacket-ContainingWraparound-SplAfterWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#, dropAt => 8);
                TestPacket(net, 12, 16#200#);
            end if;

            if run("DropPacket-AfterWraparound") then
                TestPacket(net, Depth_c, 2);
                PushPacket(net, 2, 16#100#, dropAt => 1);
                TestPacket(net, 10, 16#200#);
            end if;

            if run("DropPacketMiddle-PushAllFirst") then
                for dropWord in 0 to 2 loop
                    -- Push
                    PushPacket(net, 3, 1);
                    PushPacket(net, 3, 16);
                    PushPacket(net, 3, 32, dropAt => dropWord);
                    PushPacket(net, 3, 48);
                    -- Wait before read
                    wait for 1 us;
                    -- Check
                    CheckPacket(net, 3, 1);
                    CheckPacket(net, 3, 16);
                    CheckPacket(net, 3, 48);
                    wait for 1 us;
                end loop;
            end if;

            -- *** Repeat Packet Test (Output Side) ***

            if run("RepeatPacketMiddle") then
                for repeatWord in 0 to 2 loop
                    TestPacket(net, 3, 1);
                    PushPacket(net, 3, 16);
                    CheckPacket(net, 3, 16, repeatAt => repeatWord);
                    CheckPacket(net, 3, 16);
                    TestPacket(net, 3, 32);
                    wait for 1 us;
                end loop;
            end if;

            if run("RepeatPacketFirstPacket") then
                PushPacket(net, 3, 1);
                CheckPacket(net, 3, 1, repeatAt => 0);
                CheckPacket(net, 3, 1);
            end if;

            if run("RepeatPacketMiddleSize1") then
                TestPacket(net, 3, 1);
                PushPacket(net, 1, 16);
                CheckPacket(net, 1, 16, repeatAt => 0);
                CheckPacket(net, 1, 16);
                TestPacket(net, 3, 32);
            end if;

            if run("RepeatPacketFirstSize1") then
                PushPacket(net, 1, 1);
                CheckPacket(net, 1, 1, repeatAt => 0);
                CheckPacket(net, 1, 1);
            end if;

            if run("RepeatPacketMuti") then
                TestPacket(net, 3, 1);
                PushPacket(net, 3, 16);
                for repeatWord in 0 to 2 loop
                    CheckPacket(net, 3, 16, repeatAt => repeatWord);
                end loop;
                CheckPacket(net, 3, 16);
                TestPacket(net, 3, 32);                
            end if;

            if run("RepeatPacketMultiFirstSize1") then
                PushPacket(net, 1, 1);
                CheckPacket(net, 1, 1, repeatAt => 0);
                CheckPacket(net, 1, 1, repeatAt => 0);
                CheckPacket(net, 1, 1, repeatAt => 0);
                CheckPacket(net, 1, 1);
                TestPacket(net, 3, 16);
            end if;

            if run("RepeatPacket-ContainingWraparound-SplBeforeWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#);
                CheckPacket(net, 10, 16#100#, repeatAt => 2);
                CheckPacket(net, 10, 16#100#);
                TestPacket(net, 3, 16#200#);
            end if;

            if run("RepeatPacket-ContainingWraparound-SplAfterWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#);
                CheckPacket(net, 10, 16#100#, repeatAt => 8);
                CheckPacket(net, 10, 16#100#);
                TestPacket(net, 3, 16#200#);
            end if;

            -- *** Next Packet Test (Output Side) ***


            if run("NextPacketMiddle") then
                for nextWord in 0 to 2 loop
                    TestPacket(net, 3, 1);
                    PushPacket(net, 3, 16);
                    CheckPacket(net, nextWord+1, 16, nextAt => nextWord);
                    TestPacket(net, 3, 32);
                    wait for 1 us;
                end loop;
            end if;

            if run("NextPacketFirstPacket") then
                PushPacket(net, 3, 1);
                CheckPacket(net, 1, 1, nextAt => 0);
                TestPacket(net, 3, 32);
            end if;

            if run("NextPacketMiddleSize1") then
                TestPacket(net, 3, 1);
                PushPacket(net, 1, 16);
                CheckPacket(net, 1, 16, nextAt => 0);
                TestPacket(net, 3, 32);
            end if;

            if run("NextPacketMulti") then
                TestPacket(net, 3, 1);
                PushPacket(net, 3, 16);
                CheckPacket(net, 1, 16, nextAt => 0);
                PushPacket(net, 3, 32);
                CheckPacket(net, 2, 32, nextAt => 1);
                TestPacket(net, 3, 32);
            end if;

            if run("NextPacket-ContainingWraparound-SplBeforeWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#);
                CheckPacket(net, 3, 16#100#, nextAt => 2);
                TestPacket(net, 3, 16#200#);
            end if;

            if run("NextPacket-ContainingWraparound-SplAfterWrap") then
                TestPacket(net, Depth_c-5, 1);
                PushPacket(net, 10, 16#100#);
                CheckPacket(net, 8, 16#100#, nextAt => 7);
                TestPacket(net, 3, 16#200#);
            end if;

            if run("NextPacket-ContainingWraparound-Multi") then
                TestPacket(net, Depth_c-15, 1);
                for pkt in 1 to 3 loop
                    PushPacket(net, 10, 16#100#*pkt);
                    CheckPacket(net, 1, 16#100#*pkt, nextAt => 0);
                end loop;
                TestPacket(net, 3, 16#800#);
            end if;
            
            -- *** Next/Repeat Packet Test (Output Side) ***
            if run("NextRepeatPacketMiddle-SameWord") then
                for nextWord in 0 to 2 loop
                    TestPacket(net, 3, 1);
                    PushPacket(net, 3, 16);
                    CheckPacket(net, nextWord+1, 16, nextAt => nextWord, repeatAt => nextWord);
                    CheckPacket(net, 3, 16);
                    TestPacket(net, 3, 32);
                    wait for 1 us;
                end loop;
            end if;

            if run("NextRepeatPacketMiddle-RepeatBefore") then
                for nextWord in 1 to 2 loop
                    TestPacket(net, 3, 1);
                    PushPacket(net, 3, 16);
                    CheckPacket(net, nextWord+1, 16, nextAt => nextWord, repeatAt => 0);
                    CheckPacket(net, 3, 16);
                    TestPacket(net, 3, 32);
                    wait for 1 us;
                end loop;
            end if;

            if run("NextRepeatPacketFirstPacket") then
                PushPacket(net, 3, 1);
                CheckPacket(net, 1, 1, nextAt => 0, repeatAt => 0);
                CheckPacket(net, 3, 1);
                TestPacket(net, 3, 32);
            end if;

            if run("NextRepeatPacketMiddleSize1") then
                TestPacket(net, 3, 1);
                PushPacket(net, 1, 16);
                CheckPacket(net, 1, 16, nextAt => 0, repeatAt => 0);
                CheckPacket(net, 1, 16);
                TestPacket(net, 3, 32);
            end if;

            if run("NextRepeatPacketMulti") then
                TestPacket(net, 3, 1);
                PushPacket(net, 3, 16);
                CheckPacket(net, 1, 16, nextAt => 0, repeatAt => 0);
                CheckPacket(net, 2, 16, nextAt => 1, repeatAt => 1);
                CheckPacket(net, 3, 16);
                TestPacket(net, 3, 32);
            end if;


            if run("NextRepeatPacket-ContainingWraparound") then
                TestPacket(net, Depth_c-15, 1);
                PushPacket(net, 10, 16#100#);
                for pkt in 1 to 3 loop                    
                    CheckPacket(net, pkt+1, 16#100#, nextAt => pkt, repeatAt => 1);
                end loop;
                CheckPacket(net, 4, 16#100#, nextAt => 3); 
                TestPacket(net, 3, 16#800#);
            end if;

            -- *** Corner Cases ***
            if run("MaxPackets") then
                for pkt in 0 to MaxPackets_c+4 loop
                    PushPacket(net, 3, 16*pkt);
                end loop;
                OutDelay := 100*ClockPeriod_c;
                for pkt in 0 to MaxPackets_c+4 loop
                    CheckPacket(net, 3, 16*pkt);
                    -- Remove delay after second packet
                    if pkt = 1 then
                        OutDelay := 0 ns;
                    end if;
                end loop;
            end if;
       
--
            --if run("RepeatPacket-ContainingWraparound-SplAfterWrap") then
            --    TestPacket(net, Depth_c-5, 1);
            --    PushPacket(net, 10, 16#100#);
            --    CheckPacket(net, 10, 16#100#, repeatAt => 8);
            --    CheckPacket(net, 10, 16#100#);
            --    TestPacket(net, 3, 16#200#);
            --end if; 

            -- Multi with Wrap




            wait for 1 us;
            wait_until_idle(net, as_sync(axisMaster));
            wait_until_idle(net, as_sync(axisSlave));
            wait_until_idle(net, as_sync(axisNextRepeatMaster));

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
	    aclk        => Clk,
	    tvalid      => In_Valid,
        tready      => In_Ready,
	    tdata       => In_Data,
        tlast       => In_Last,
        tuser(0)    => In_Drop
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

    b_nr : block
        signal Ready : std_logic;
    begin
        Ready <= Out_Ready and Out_Valid;
        vc_next_repeat : entity vunit_lib.axi_stream_master
        generic map (
            master => axisNextRepeatMaster
        )
        port map (
            aclk        => Clk,
            tvalid      => open,
            tready      => Ready,
            tdata(0)    => Out_Next,
            tdata(1)    => Out_Repeat
        );
    end block;
  

end sim;
