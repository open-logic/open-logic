---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library work;
    use work.olo_test_ft_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_fifo_packet_tb is
    generic (
        runner_cfg   : string;
        Width_g      : positive range 5 to 128 := 32;
        FeatureSet_g : string                  := "FULL"
    );
end entity;

architecture sim of olo_ft_fifo_packet_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant Depth_c         : natural  := 64;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -----------------------------------------------------------------------------------------------
    -- Verification components.
    --   Master drives the user-facing AXI-S input including TLAST (= In_Last).
    --   Slave samples (Out_Data, Out_Last, EccSec, EccDed); tuser = Sec & Ded.
    --   Stall configs on both sides keep back-pressure exercised on every case.
    -----------------------------------------------------------------------------------------------
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length  => Width_g,
        stall_config => new_stall_config(0.2, 0, 3)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length  => Width_g,
        user_length  => 2,
        stall_config => new_stall_config(0.2, 0, 3)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk               : std_logic                                      := '0';
    signal Rst               : std_logic                                      := '1';
    signal In_Valid          : std_logic;
    signal In_Ready          : std_logic;
    signal In_Data           : std_logic_vector(Width_g - 1 downto 0);
    signal In_Last           : std_logic;
    signal In_Drop           : std_logic                                      := '0';
    signal In_IsDropped      : std_logic;
    signal In_ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal In_ErrInj_Valid   : std_logic                                      := '0';
    signal Out_Valid         : std_logic;
    signal Out_Ready         : std_logic;
    signal Out_Data          : std_logic_vector(Width_g - 1 downto 0);
    signal Out_Size          : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);
    signal Out_Last          : std_logic;
    signal Out_Next          : std_logic;
    signal NextArm           : std_logic                                      := '0';
    signal Out_Repeat        : std_logic                                      := '0';
    signal Out_EccSec        : std_logic;
    signal Out_EccDed        : std_logic;
    signal Out_TUser         : std_logic_vector(1 downto 0);
    signal PacketLevel       : std_logic_vector(log2ceil(17 + 1) - 1 downto 0);
    signal FreeWords         : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
        variable Flip_v : std_logic_vector(CodewordWidth_c - 1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            In_ErrInj_BitFlip <= (others => '0');
            In_ErrInj_Valid   <= '0';
            In_Drop           <= '0';
            wait until rising_edge(Clk);
            Rst               <= '1';
            wait for 200 ns;
            wait until rising_edge(Clk);
            Rst               <= '0';
            wait until rising_edge(Clk);

            ---------------------------------------------------------------------------------------
            if run("Basic") then
                -- Three-word packet, no errors. TLAST asserted on the third beat.
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(10, Width_g), Flip_v, '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(20, Width_g), Flip_v, '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(30, Width_g), Flip_v, '1');
                ftExpectBeat(net, AxisSlave_c, toUslv(10, Width_g), Flip_v, "Basic[0]", '0');
                ftExpectBeat(net, AxisSlave_c, toUslv(20, Width_g), Flip_v, "Basic[1]", '0');
                ftExpectBeat(net, AxisSlave_c, toUslv(30, Width_g), Flip_v, "Basic[2] last", '1');

            ---------------------------------------------------------------------------------------
            elsif run("EccSec") then
                -- Two-word packet, single-bit flip on the first word.
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#AB#, Width_g),
                         setBits(0, CodewordWidth_c), '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#CD#, Width_g),
                         (Flip_v'range => '0'), '1');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#AB#, Width_g), setBits(0, CodewordWidth_c), "Sec[0]", '0');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#CD#, Width_g), (Flip_v'range => '0'), "Sec[1] last", '1');

            ---------------------------------------------------------------------------------------
            elsif run("EccDed") then
                -- Single-word packet with double-bit flip.
                Flip_v := setBits((0, 1), CodewordWidth_c);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#EF#, Width_g),
                         Flip_v, '1');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#EF#, Width_g), Flip_v, "Ded[0] last", '1');

            ---------------------------------------------------------------------------------------
            elsif run("SecAllBits") then

                -- Every codeword bit position, one-word packets.
                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    Flip_v := setBits(bitIdx, CodewordWidth_c);
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#A5#, Width_g),
                             Flip_v, '1');
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#A5#, Width_g), Flip_v, "SecAllBits flip " & integer'image(bitIdx), '1');
                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("DedSampledPairs") then

                for pair in 0 to 4 loop

                    case pair is
                        when 0 => Flip_v := setBits((0, 1),                              CodewordWidth_c);
                        when 1 => Flip_v := setBits((0, CodewordWidth_c - 1),            CodewordWidth_c);
                        when 2 => Flip_v := setBits((1, 2),                              CodewordWidth_c);
                        when 3 => Flip_v := setBits((2, 5),                              CodewordWidth_c);
                        when others => Flip_v := setBits((CodewordWidth_c / 2,
                                                          CodewordWidth_c / 2 + 1), CodewordWidth_c);
                    end case;

                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#5A#, Width_g),
                             Flip_v, '1');
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#5A#, Width_g), Flip_v, "DedPair " & integer'image(pair), '1');
                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("Drop") then
                -- In_Drop is passed through the wrapper (available in all supported feature
                -- sets). Hold it high for a whole packet (level, so no cycle alignment against
                -- the stalling master is needed): the packet must be dropped and only the
                -- following clean packet may reach the output.
                Flip_v := (others => '0');

                In_Drop <= '1';
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#D0#, Width_g), Flip_v, '0');
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait until rising_edge(Clk);
                check_equal(In_IsDropped, '1', "In_IsDropped must be asserted for the dropped packet");
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#D1#, Width_g), Flip_v, '1');
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait until rising_edge(Clk);
                In_Drop <= '0';

                -- Only the clean packet may come out
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#C0#, Width_g), Flip_v, '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#C1#, Width_g), Flip_v, '1');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#C0#, Width_g), Flip_v, "Drop survivor[0]", '0');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#C1#, Width_g), Flip_v, "Drop survivor[1] last", '1');

            ---------------------------------------------------------------------------------------
            elsif run("Repeat") then
                -- Out_Repeat is passed through the wrapper. Hold it high through the entire
                -- first read of a packet (level, so no cycle alignment is needed), then release
                -- it: the packet must be delivered twice, the following packet once.
                if FeatureSet_g = "FULL" then
                    Flip_v := (others => '0');

                    for i in 0 to 4 loop
                        ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                                 toUslv(16#A0# + i, Width_g), Flip_v, choose(i = 4, '1', '0'));
                    end loop;

                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#B0#, Width_g), Flip_v, '1');

                    Out_Repeat <= '1';

                    for i in 0 to 4 loop
                        ftExpectBeat(net, AxisSlave_c, toUslv(16#A0# + i, Width_g), Flip_v,
                            "Repeat first pass " & integer'image(i), choose(i = 4, '1', '0'));
                    end loop;

                    wait_until_idle(net, as_sync(AxisSlave_c));
                    wait until rising_edge(Clk);
                    Out_Repeat <= '0';

                    for i in 0 to 4 loop
                        ftExpectBeat(net, AxisSlave_c, toUslv(16#A0# + i, Width_g), Flip_v,
                            "Repeat second pass " & integer'image(i), choose(i = 4, '1', '0'));
                    end loop;

                    ftExpectBeat(net, AxisSlave_c, toUslv(16#B0#, Width_g), Flip_v, "Repeat follower", '1');
                else
                    -- DROP_SKIP_ONLY has no Out_Repeat: no test
                    null;
                end if;

            ---------------------------------------------------------------------------------------
            ---------------------------------------------------------------------------------------
            elsif run("ResetState") then
                -- Reset values of the complete output surface
                check_equal(In_Ready, '1', "In_Ready reset state");
                check_equal(Out_Valid, '0', "Out_Valid reset state");
                check_equal(In_IsDropped, '0', "In_IsDropped reset state");
                check_equal(PacketLevel, toUslv(0, PacketLevel'length), "PacketLevel reset state");
                check_equal(FreeWords, toUslv(Depth_c, FreeWords'length), "FreeWords reset state");

            ---------------------------------------------------------------------------------------
            elsif run("Size1Packets") then
                -- Single-beat packets: every beat is a packet boundary
                Flip_v := (others => '0');

                for i in 0 to 3 loop
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                               toUslv(16#30# + i, Width_g), Flip_v, '1');
                end loop;

                for i in 0 to 3 loop
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#30# + i, Width_g), Flip_v,
                                 "Size1 packet " & integer'image(i), '1');
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("NextPacket") then
                -- Out_Next skips the remainder of the packet being read. Armed before the first
                -- beat, so it fires on that beat and the rest of packet A is dropped.
                Flip_v := (others => '0');

                for i in 0 to 4 loop
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                               toUslv(16#C0# + i, Width_g), Flip_v, choose(i = 4, '1', '0'));
                end loop;

                for i in 0 to 2 loop
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                               toUslv(16#D0# + i, Width_g), Flip_v, choose(i = 2, '1', '0'));
                end loop;

                -- The skipped packet is terminated cleanly, so the delivered beat carries Last
                NextArm <= '1';
                ftExpectBeat(net, AxisSlave_c, toUslv(16#C0#, Width_g), Flip_v, "Next: first beat", '1');
                wait until rising_edge(Clk) and Out_Valid = '1' and Out_Ready = '1';
                NextArm <= '0';

                -- The remainder of packet A is skipped, packet B follows complete
                for i in 0 to 2 loop
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#D0# + i, Width_g), Flip_v,
                                 "Next: packet B beat " & integer'image(i), choose(i = 2, '1', '0'));
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("PacketLevelAndFreeWords") then
                -- Both status words are pass-throughs of the internal FIFO and must be exact
                Flip_v := (others => '0');

                for i in 0 to 3 loop
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                               toUslv(16#50# + i, Width_g), Flip_v, choose(i = 3, '1', '0'));
                end loop;

                for i in 0 to 1 loop
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                               toUslv(16#60# + i, Width_g), Flip_v, choose(i = 1, '1', '0'));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                for i in 0 to 5 loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(PacketLevel, toUslv(2, PacketLevel'length), "PacketLevel after two packets");
                check_equal(FreeWords, toUslv(Depth_c - 6, FreeWords'length), "FreeWords after six beats");

                for i in 0 to 3 loop
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#50# + i, Width_g), Flip_v,
                                 "Level drain A" & integer'image(i), choose(i = 3, '1', '0'));
                end loop;

                for i in 0 to 1 loop
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#60# + i, Width_g), Flip_v,
                                 "Level drain B" & integer'image(i), choose(i = 1, '1', '0'));
                end loop;

                wait_until_idle(net, as_sync(AxisSlave_c));

                for i in 0 to 5 loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(PacketLevel, toUslv(0, PacketLevel'length), "PacketLevel when drained");
                check_equal(FreeWords, toUslv(Depth_c, FreeWords'length), "FreeWords when drained");

            ---------------------------------------------------------------------------------------
            elsif run("Wraparound") then
                -- Push and drain more beats than the FIFO is deep, so the RAM address wraps
                Flip_v := (others => '0');

                for pkt in 0 to 4 loop

                    for i in 0 to 19 loop
                        ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid,
                                   toUslv(pkt * 20 + i, Width_g), Flip_v, choose(i = 19, '1', '0'));
                    end loop;

                    for i in 0 to 19 loop
                        ftExpectBeat(net, AxisSlave_c, toUslv(pkt * 20 + i, Width_g), Flip_v,
                                     "Wrap p" & integer'image(pkt) & " b" & integer'image(i),
                                     choose(i = 19, '1', '0'));
                    end loop;

                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

            elsif run("ResetInFlight") then
                -- Store a complete packet that is never drained (no read expectation queued, so
                -- the slave VC keeps Out_Ready low), then reset mid-operation. The FIFO must
                -- come back empty, with no stale beat, and accept new data cleanly afterwards.
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#40#, Width_g), Flip_v, '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#41#, Width_g), Flip_v, '1');
                wait_until_idle(net, as_sync(AxisMaster_c));

                -- Let the packet settle into the FIFO
                for i in 0 to 6 loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Out_Valid, '1', "Out_Valid must be high before the reset");

                -- Reset with the packet still stored
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst <= '0';

                -- Flush a few cycles: no stale valid may re-appear
                for i in 0 to 6 loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Out_Valid, '0', "Out_Valid must be squashed by the reset");
                check_equal(PacketLevel, toUslv(0, PacketLevel'length), "PacketLevel must be 0 after the reset");

                -- Clean recovery: a fresh packet passes through untouched
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#77#, Width_g), Flip_v, '1');
                ftExpectBeat(net, AxisSlave_c, toUslv(16#77#, Width_g), Flip_v, "Recovery packet", '1');

            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));
            wait for 1 us;

        end loop;

        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    Out_TUser <= Out_EccSec & Out_EccDed;
    Out_Next  <= NextArm and Out_Valid and Out_Ready;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_fifo_packet
        generic map (
            Width_g       => Width_g,
            Depth_g       => Depth_c,
            FeatureSet_g  => FeatureSet_g
        )
        port map (
            Clk               => Clk,
            Rst               => Rst,
            In_Valid          => In_Valid,
            In_Ready          => In_Ready,
            In_Data           => In_Data,
            In_Last           => In_Last,
            In_Drop           => In_Drop,
            In_IsDropped      => In_IsDropped,
            In_ErrInj_BitFlip => In_ErrInj_BitFlip,
            In_ErrInj_Valid   => In_ErrInj_Valid,
            Out_Valid         => Out_Valid,
            Out_Ready         => Out_Ready,
            Out_Data          => Out_Data,
            Out_Size          => Out_Size,
            Out_Last          => Out_Last,
            Out_Next          => Out_Next,
            Out_Repeat        => Out_Repeat,
            Out_EccSec        => Out_EccSec,
            Out_EccDed        => Out_EccDed,
            PacketLevel       => PacketLevel,
            FreeWords         => FreeWords
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data,
            TLast  => In_Last
        );

    vc_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data,
            TLast  => Out_Last,
            TUser  => Out_TUser
        );

end architecture;
