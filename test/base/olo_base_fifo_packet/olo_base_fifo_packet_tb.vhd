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

library osvvm;
    use osvvm.RandomPkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_packet_tb is
    generic (
        RandomStall_g   : boolean := false;
        RandomPackets_g : integer := 100;
        runner_cfg      : string
    );
end entity;

architecture sim of olo_base_fifo_packet_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c      : integer := 16;
    constant Depth_c      : integer := 32;
    constant MaxPackets_c : integer := 4;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClockFrequency_c : real := 100.0e6;
    constant ClockPeriod_c    : time := (1 sec) / ClockFrequency_c;
    constant CaseDelay_c      : time := ClockPeriod_c*20;
    shared variable Random_v  : RandomPType;

    shared variable InDelay_v  : time := 0 ns;
    shared variable OutDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c           : axi_stream_master_t := new_axi_stream_master (
        data_length => Width_c,
        user_length => 1,
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 10)
    );
    constant AxisSlave_c            : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => Width_c,
        user_length => log2ceil(Depth_c+1),
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 10)
    );
    constant AxisNextRepeatMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => 2,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisIsDropedSlave_c    : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => 1,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure pushPacket (
        signal  net : inout network_t;
        size        : integer;
        startVal    : integer := 1;
        dropAt      : integer := integer'high;
        isDroppedAt : integer := integer'high;
        blocking    : boolean := false) is
        variable Tlast_v     : std_logic := '0';
        variable Drop_v      : std_logic := '0';
        variable IsDropped_v : std_logic_vector(0 downto 0);
        variable Tuser_v     : std_logic_vector(0 downto 0);
    begin

        -- Loop over data-beats
        for i in 0 to size-1 loop
            -- Expect isdropped
            if isDroppedAt <= i or dropAt <= i then
                IsDropped_v := "1";
            else
                IsDropped_v := "0";
            end if;
            check_axi_stream(net, AxisIsDropedSlave_c, IsDropped_v, blocking => false, msg => "IsDropped_v");

            -- Push Data
            if i = size-1 then
                Tlast_v := '1';
            end if;
            if dropAt = i then
                Drop_v := '1';
            else
                Drop_v := '0';
            end if;
            Tuser_v(0) := Drop_v;
            if InDelay_v > 0 ns then
                wait for InDelay_v;
            end if;
            push_axi_stream(net, AxisMaster_c, toUslv(startVal + i, Width_c), tlast => Tlast_v, tuser => Tuser_v);
        end loop;

        if blocking then
            wait_until_idle(net, as_sync(AxisMaster_c));
        end if;
    end procedure;

    procedure checkPacket (
        signal  net : inout network_t;
        size        : integer;
        startVal    : integer := 1;
        nextAt      : integer := -1;
        repeatAt    : integer := -1;
        pktSize     : integer := -1; -- if not specified "size" is used
        blocking    : boolean := false) is
        variable Tlast_v          : std_logic := '0';
        variable Next_v, Repeat_v : std_logic := '0';
        variable Size_v           : std_logic_vector(log2ceil(Depth_c+1) - 1 downto 0);
    begin

        -- Loop over data-beats
        for i in 0 to size-1 loop
            -- Next/Repeat
            Next_v   := '0';
            Repeat_v := '0';
            if nextAt = i then
                Next_v := '1';
            end if;
            if repeatAt = i then
                Repeat_v := '1';
            end if;
            push_axi_stream(net, AxisNextRepeatMaster_c, Repeat_v & Next_v);
            -- Data
            if i = size-1 then
                Tlast_v := '1';
            end if;
            if OutDelay_v > 0 ns then
                wait for OutDelay_v;
            end if;
            if pktsize = -1 then
                Size_v := toUslv(size, Size_v'length);
            else
                Size_v := toUslv(pktSize, Size_v'length);
            end if;
            check_axi_stream(net, AxisSlave_c, toUslv(startVal + i, Width_c), tlast => Tlast_v, tuser => Size_v, blocking => false);
        end loop;

        if blocking then
            wait_until_idle(net, as_sync(AxisSlave_c));
        end if;
    end procedure;

    procedure testPacket (
        signal  net : inout network_t;
        size        : integer;
        startVal    : integer := 1) is
    begin
        checkPacket(net, size, startVal);
        pushPacket(net, size, startVal);
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic;
    signal In_Valid     : std_logic := '0';
    signal In_Ready     : std_logic;
    signal In_Data      : std_logic_vector(Width_c - 1 downto 0);
    signal In_Last      : std_logic := '0';
    signal In_Drop      : std_logic := '0';
    signal In_IsDropped : std_logic;
    signal PacketLevel  : std_logic_vector(log2ceil(MaxPackets_c + 1) - 1 downto 0);
    signal FreeWords    : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);
    signal Out_Valid    : std_logic;
    signal Out_Ready    : std_logic := '0';
    signal Out_Data     : std_logic_vector(Width_c - 1 downto 0);
    signal Out_Size     : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);
    signal Out_Last     : std_logic;
    signal Out_Next     : std_logic := '0';
    signal Out_Repeat   : std_logic := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 20 ms);

    p_control : process is
        variable PacketSize_v  : integer;
        variable DropAt_v      : integer;
        variable IsDroppedAt_v : integer;
        variable NextAt_v      : integer;
        variable RepeatAt_v    : integer;
        variable PktDropped_v  : boolean;
        variable Repetitions_v : integer;
        variable ReadSize_v    : integer;
        variable Level_v       : integer;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for ClockPeriod_c*3;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Default Values
            InDelay_v  := 0 ns;
            OutDelay_v := 0 ns;

            -- Reset state
            if run("ResetState") then
                check_equal(In_Ready, '1', "In_Ready");
                check_equal(In_IsDropped, '0', "In_IsDropped");
                check_equal(Out_Valid, '0', "Out_Valid");
                check_equal(Out_Last, '0', "Out_Last");
            end if;

            -- *** Simple Cases ***

            if run("SinglePacket") then
                testPacket(net, 3, 1);
            end if;

            if run("TwoPackets") then
                testPacket(net, 3, 1);
                testPacket(net, 4, 4);
            end if;

            if run("LimitedInputRate") then
                InDelay_v := 10*ClockPeriod_c;
                checkPacket(net, 3, 1);
                checkPacket(net, 4, 4);
                pushPacket(net, 3, 1);
                pushPacket(net, 4, 4);
            end if;

            if run("LimitedOutputRate") then
                OutDelay_v := 10*ClockPeriod_c;
                pushPacket(net, 3, 1);
                pushPacket(net, 4, 4);
                checkPacket(net, 3, 1);
                checkPacket(net, 4, 4);
            end if;

            if run("WraparoundInPacket") then
                testPacket(net, Depth_c-5, 1);
                testPacket(net, 10, 16#100#);
            end if;

            if run("WraparoundBetweenPackets") then
                testPacket(net, Depth_c-5, 1);
                testPacket(net, 5, 16#100#);
                testPacket(net, 10, 16#200#);
            end if;

            -- Required to accomplish full coverage
            if run("RdAddrWraparoundInLast") then
                testPacket(net, Depth_c-5, 1);
                testPacket(net, Depth_c-5, 16#100#);
                testPacket(net, 10, 16#200#);
                testPacket(net, 10, 16#300#);
            end if;

            -- Required to accomplish full coverage
            if run("RdAddrWraparoundInData") then
                testPacket(net, Depth_c-5, 1);
                testPacket(net, Depth_c-5, 16#100#);
                testPacket(net, 20, 16#200#);
                testPacket(net, 3, 16#300#);
            end if;

            -- *** Size=1 Packets ***

            if run("Size1First") then
                testPacket(net, 1, 1);
                testPacket(net, 3, 4);
            end if;

            if run("Size1Middle") then
                testPacket(net, 3, 1);
                testPacket(net, 1, 4);
                testPacket(net, 3, 5);
            end if;

            if run("Size1Last") then
                testPacket(net, 3, 1);
                testPacket(net, 1, 4);
            end if;

            if run("WraparoundAfterSize1") then
                testPacket(net, Depth_c-1, 1);
                testPacket(net, 1, 16#100#);
                testPacket(net, 10, 16#200#);
            end if;

            if run("WraparoundBeforeSize1") then
                testPacket(net, Depth_c-10, 1);
                testPacket(net, 10, 16#100#);
                testPacket(net, 1, 16#200#);
                testPacket(net, 10, 16#300#);
            end if;

            -- *** Drop Packet Test (Input Side) ***

            if run("DropPacketMiddle") then

                -- Loop over different drop positions
                for dropWord in 0 to 2 loop
                    testPacket(net, 3, 1);
                    pushPacket(net, 3, 16, dropAt => dropWord);
                    testPacket(net, 3, 32);
                    wait for CaseDelay_c;
                end loop;

            end if;

            if run("DropPacketFirstPacket") then
                pushPacket(net, 3, 1, dropAt => 0);
                testPacket(net, 3, 16);
            end if;

            if run("DropPacketMiddleSize1") then
                testPacket(net, 3, 1);
                pushPacket(net, 1, 16, dropAt => 0);
                testPacket(net, 3, 32);
            end if;

            if run("DropPacketFirstSize1") then
                pushPacket(net, 1, 1, dropAt => 0);
                testPacket(net, 3, 16);
            end if;

            if run("DropPacket-ContainingWraparound-SplBeforeWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#, dropAt => 1);
                testPacket(net, 12, 16#200#);
            end if;

            if run("DropPacket-ContainingWraparound-SplAfterWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#, dropAt => 8);
                testPacket(net, 12, 16#200#);
            end if;

            if run("DropPacket-AfterWraparound") then
                testPacket(net, Depth_c-10, 2);
                testPacket(net, 10, 16#100#);
                pushPacket(net, 2, 16#200#, dropAt => 1);
                testPacket(net, 10, 16#300#);
            end if;

            if run("DropPacketMiddle-PushAllFirst") then

                -- Loop over different drop positions
                for dropWord in 0 to 2 loop
                    -- Push
                    pushPacket(net, 3, 1);
                    pushPacket(net, 3, 16);
                    pushPacket(net, 3, 32, dropAt => dropWord);
                    pushPacket(net, 3, 48);
                    -- Wait before read
                    wait for 1 us;
                    -- Check
                    checkPacket(net, 3, 1);
                    checkPacket(net, 3, 16);
                    checkPacket(net, 3, 48);
                    wait for CaseDelay_c;
                end loop;

            end if;

            -- *** Repeat Packet Test (Output Side) ***

            if run("RepeatPacketMiddle") then

                -- Loop over different repeat positions
                for repeatWord in 0 to 2 loop
                    testPacket(net, 3, 1);
                    pushPacket(net, 3, 16);
                    checkPacket(net, 3, 16, repeatAt => repeatWord);
                    checkPacket(net, 3, 16);
                    testPacket(net, 3, 32);
                    wait for CaseDelay_c;
                end loop;

            end if;

            if run("RepeatPacketFirstPacket") then
                pushPacket(net, 3, 1);
                checkPacket(net, 3, 1, repeatAt => 0);
                checkPacket(net, 3, 1);
            end if;

            if run("RepeatPacketMiddleSize1") then
                testPacket(net, 3, 1);
                pushPacket(net, 1, 16);
                checkPacket(net, 1, 16, repeatAt => 0);
                checkPacket(net, 1, 16);
                testPacket(net, 3, 32);
            end if;

            if run("RepeatPacketFirstSize1") then
                pushPacket(net, 1, 1);
                checkPacket(net, 1, 1, repeatAt => 0);
                checkPacket(net, 1, 1);
            end if;

            if run("RepeatPacketMuti") then
                testPacket(net, 3, 1);
                pushPacket(net, 3, 16);

                -- Loop over different repeat positions
                for repeatWord in 0 to 2 loop
                    checkPacket(net, 3, 16, repeatAt => repeatWord);
                end loop;

                checkPacket(net, 3, 16);
                testPacket(net, 3, 32);
            end if;

            if run("RepeatPacketMultiFirstSize1") then
                pushPacket(net, 1, 1);
                checkPacket(net, 1, 1, repeatAt => 0);
                checkPacket(net, 1, 1, repeatAt => 0);
                checkPacket(net, 1, 1, repeatAt => 0);
                checkPacket(net, 1, 1);
                testPacket(net, 3, 16);
            end if;

            if run("RepeatPacket-ContainingWraparound-SplBeforeWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#);
                checkPacket(net, 10, 16#100#, repeatAt => 2);
                checkPacket(net, 10, 16#100#);
                testPacket(net, 3, 16#200#);
            end if;

            if run("RepeatPacket-ContainingWraparound-SplAfterWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#);
                checkPacket(net, 10, 16#100#, repeatAt => 8);
                checkPacket(net, 10, 16#100#);
                testPacket(net, 3, 16#200#);
            end if;

            -- *** Next Packet Test (Output Side) ***

            if run("NextPacketMiddle") then

                -- Loop over different skip positions
                for nextWord in 0 to 2 loop
                    testPacket(net, 3, 1);
                    pushPacket(net, 3, 16);
                    checkPacket(net, nextWord+1, 16, nextAt => nextWord, pktSize => 3);
                    testPacket(net, 3, 32);
                    wait for CaseDelay_c;
                end loop;

            end if;

            if run("NextPacketFirstPacket") then
                pushPacket(net, 3, 1);
                checkPacket(net, 1, 1, nextAt => 0, pktSize => 3);
                testPacket(net, 3, 32);
            end if;

            if run("NextPacketMiddleSize1") then
                testPacket(net, 3, 1);
                pushPacket(net, 1, 16);
                checkPacket(net, 1, 16, nextAt => 0);
                testPacket(net, 3, 32);
            end if;

            if run("NextPacketMulti") then
                testPacket(net, 3, 1);
                pushPacket(net, 3, 16);
                checkPacket(net, 1, 16, nextAt => 0, pktSize => 3);
                pushPacket(net, 3, 32);
                checkPacket(net, 2, 32, nextAt => 1, pktSize => 3);
                testPacket(net, 3, 32);
            end if;

            if run("NextPacket-ContainingWraparound-SplBeforeWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#);
                checkPacket(net, 3, 16#100#, nextAt => 2, pktSize => 10);
                testPacket(net, 3, 16#200#);
            end if;

            if run("NextPacket-ContainingWraparound-SplAfterWrap") then
                testPacket(net, Depth_c-5, 1);
                pushPacket(net, 10, 16#100#);
                checkPacket(net, 8, 16#100#, nextAt => 7, pktSize => 10);
                testPacket(net, 3, 16#200#);
            end if;

            if run("NextPacket-ContainingWraparound-Multi") then
                testPacket(net, Depth_c-15, 1);

                -- Three packets
                for pkt in 1 to 3 loop
                    pushPacket(net, 10, 16#100#*pkt);
                    checkPacket(net, 1, 16#100#*pkt, nextAt => 0, pktSize => 10);
                end loop;

                testPacket(net, 3, 16#800#);
            end if;

            -- *** Next/Repeat Packet Test (Output Side) ***
            if run("NextRepeatPacketMiddle-SameWord") then

                -- Loop over different skip positions
                for nextWord in 0 to 2 loop
                    testPacket(net, 3, 1);
                    pushPacket(net, 3, 16);
                    checkPacket(net, nextWord+1, 16, nextAt => nextWord, repeatAt => nextWord, pktSize => 3);
                    checkPacket(net, 3, 16);
                    testPacket(net, 3, 32);
                    wait for CaseDelay_c;
                end loop;

            end if;

            if run("NextRepeatPacketMiddle-RepeatBefore") then

                -- Loop over different skip positions
                for nextWord in 1 to 2 loop
                    testPacket(net, 3, 1);
                    pushPacket(net, 3, 16);
                    checkPacket(net, nextWord+1, 16, nextAt => nextWord, repeatAt => 0, pktSize => 3);
                    checkPacket(net, 3, 16);
                    testPacket(net, 3, 32);
                    wait for CaseDelay_c;
                end loop;

            end if;

            if run("NextRepeatPacketFirstPacket") then
                pushPacket(net, 3, 1);
                checkPacket(net, 1, 1, nextAt => 0, repeatAt => 0, pktSize => 3);
                checkPacket(net, 3, 1);
                testPacket(net, 3, 32);
            end if;

            if run("NextRepeatPacketMiddleSize1") then
                testPacket(net, 3, 1);
                pushPacket(net, 1, 16);
                checkPacket(net, 1, 16, nextAt => 0, repeatAt => 0);
                checkPacket(net, 1, 16);
                testPacket(net, 3, 32);
            end if;

            if run("NextRepeatPacketMulti") then
                testPacket(net, 3, 1);
                pushPacket(net, 3, 16);
                checkPacket(net, 1, 16, nextAt => 0, repeatAt => 0, pktSize => 3);
                checkPacket(net, 2, 16, nextAt => 1, repeatAt => 1, pktSize => 3);
                checkPacket(net, 3, 16);
                testPacket(net, 3, 32);
            end if;

            if run("NextRepeatPacket-ContainingWraparound") then
                testPacket(net, Depth_c-15, 1);
                pushPacket(net, 10, 16#100#);

                -- Three packets
                for pkt in 1 to 3 loop
                    checkPacket(net, pkt+1, 16#100#, nextAt => pkt, repeatAt => 1, pktSize => 10);
                end loop;

                checkPacket(net, 4, 16#100#, nextAt => 3, pktSize => 10);
                testPacket(net, 3, 16#800#);
            end if;

            -- *** Corner Cases ***
            if run("MaxPacketsAndPacketLevel") then
                check_equal(PacketLevel, 0, "PacketLevel empty");

                -- Fill FIFO
                for pkt in 0 to MaxPackets_c-1 loop
                    pushPacket(net, 3, 16*pkt, blocking => true);
                    wait until rising_edge(Clk);
                    check_equal(PacketLevel, pkt+1, "PacketLevel 0");
                end loop;

                -- These packets are added on the go when readout starts
                for pkt in 0 to 3 loop
                    pushPacket(net, 3, 16*(pkt+MaxPackets_c));
                end loop;

                check_equal(PacketLevel, MaxPackets_c, "PacketLevel 1");

                -- Readout all packets
                for pkt in 0 to MaxPackets_c+3 loop
                    checkPacket(net, 3, 16*pkt, blocking => true);
                    Level_v := minimum(MaxPackets_c+3 - pkt, MaxPackets_c-1);  ---1 packet is readout
                    -- Only works with non-random input timing
                    if not RandomStall_g then
                        wait until rising_edge(Clk);
                        check_equal(PacketLevel, Level_v, "PacketLevel 2");
                    end if;
                end loop;

            end if;

            if run("OversizedPacket-Middle") then
                testPacket(net, 3, 1);
                pushPacket(net, Depth_c+1, 16, isDroppedAt => Depth_c); -- Ignored because oversized
                testPacket(net, 3, 32);
            end if;

            if run("OversizedPacket-First") then
                pushPacket(net, Depth_c+1, 1, isDroppedAt => Depth_c); -- Ignored because oversized
                testPacket(net, 3, 16);
            end if;

            if run("MaxSizedPacket-Middle") then
                testPacket(net, 3, 1);
                testPacket(net, Depth_c, 16);
                testPacket(net, 3, 32);
            end if;

            if run("OversizedPacket-Multi") then
                testPacket(net, 3, 1);
                pushPacket(net, Depth_c+1, 16, isDroppedAt => Depth_c); -- Ignored because oversized
                pushPacket(net, Depth_c+10, 32, isDroppedAt => Depth_c); -- Ignored because oversized
                testPacket(net, 3, 48);
            end if;

            -- *** Constrained Random Test ***
            if run("Random") then

                -- Generate random packets
                for pkt in 0 to RandomPackets_g-1 loop
                    -- Input Side
                    PacketSize_v := Random_v.RandInt(1, Depth_c+5);

                    -- Drop 10% of packets at input
                    if Random_v.RandInt(0, 99) < 10 then
                        DropAt_v := Random_v.RandInt(0, PacketSize_v-1);
                    else
                        DropAt_v := PacketSize_v+1; -- Don't drop
                    end if;
                    IsDroppedAt_v := choose(PacketSize_v > Depth_c, Depth_c, PacketSize_v+1);
                    PktDropped_v  := (IsDroppedAt_v <= PacketSize_v) or (DropAt_v <= PacketSize_v);
                    pushPacket(net, PacketSize_v, 16#100#*pkt, dropAt => DropAt_v, isDroppedAt => IsDroppedAt_v);

                    -- Output Side
                    if not PktDropped_v then
                        -- Repeat 10% of the packets
                        if Random_v.RandInt(0, 99) < 10 then
                            -- Repeat between 2 and 5 times
                            Repetitions_v := Random_v.RandInt(2, 5);
                        else
                            Repetitions_v := 1;
                        end if;

                        -- Repeated readouts
                        for i in 1 to Repetitions_v loop
                            -- Skip 10% of the packets prematurely
                            ReadSize_v := PacketSize_v;
                            if Random_v.RandInt(0, 99) < 10 then
                                NextAt_v   := Random_v.RandInt(0, PacketSize_v-1);
                                ReadSize_v := NextAt_v+1;
                            else
                                NextAt_v := PacketSize_v+1; -- Don't skip
                            end if;
                            -- Random Repetition position
                            if i < Repetitions_v then
                                RepeatAt_v := Random_v.RandInt(0, minimum(ReadSize_v-1, NextAt_v));
                            else
                                RepeatAt_v := PacketSize_v+1; -- Don't repeat
                            end if;
                            checkPacket(net, ReadSize_v, 16#100#*pkt, repeatAt => RepeatAt_v, nextAt => NextAt_v, pktSize => PacketSize_v);

                        end loop;

                    end if;

                end loop;

            end if;

            -- End case condition
            wait for CaseDelay_c;
            -- Due to a VUNit bug wait_until_idle does not work correctly here
            if In_Valid = '1' then
                wait until In_Valid = '0';
            end if;
            wait_until_idle(net, as_sync(AxisSlave_c));
            wait_until_idle(net, as_sync(AxisNextRepeatMaster_c));
            wait_until_idle(net, as_sync(AxisIsDropedSlave_c));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*ClockPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
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
            Out_Size      => Out_Size,
            Out_Last      => Out_Last,
            Out_Next      => Out_Next,
            Out_Repeat    => Out_Repeat,
            PacketLevel   => PacketLevel,
            FreeWords     => FreeWords
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            Aclk     => Clk,
            TValid   => In_Valid,
            TReady   => In_Ready,
            TData    => In_Data,
            TLast    => In_Last,
            TUser(0) => In_Drop
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            Aclk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data,
            TLast  => Out_Last,
            TUser  => Out_Size
        );

    b_nr : block is
        signal Ready       : std_logic;
        signal NextLocal   : std_logic;
        signal RepeatLocal : std_logic;
    begin
        Ready <= Out_Ready and Out_Valid;

        vc_next_repeat : entity vunit_lib.axi_stream_master
            generic map (
                Master => AxisNextRepeatMaster_c
            )
            port map (
                Aclk        => Clk,
                TValid      => open,
                TReady      => Ready,
                TData(0)    => NextLocal,
                TData(1)    => RepeatLocal
            );

        -- Supporess Next/Repeat before full handshaking (tested in olo_base_fifo_packet_tb)
        Out_Next   <= NextLocal and Out_Ready and Out_Valid;
        Out_Repeat <= RepeatLocal and Out_Ready and Out_Valid;
    end block;

    b_id : block is
        signal Valid : std_logic;
    begin
        Valid <= In_Valid and In_Ready;

        vc_isdropped : entity vunit_lib.axi_stream_slave
            generic map (
                Slave => AxisIsDropedSlave_c
            )
            port map (
                Aclk      => Clk,
                TValid    => Valid,
                TData(0)  => In_IsDropped
            );

    end block;

end architecture;
