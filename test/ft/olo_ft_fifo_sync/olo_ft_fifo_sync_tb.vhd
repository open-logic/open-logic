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
entity olo_ft_fifo_sync_tb is
    generic (
        runner_cfg      : string;
        Width_g         : positive range 5 to 128 := 32;
        Depth_g         : positive                := 32;
        AlmFullOn_g     : boolean                 := true;
        AlmEmptyOn_g    : boolean                 := true;
        RamBehavior_g   : string                  := "RBW";
        ReadyRstState_g : integer range 0 to 1    := 1;
        EccPipeline_g   : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_fifo_sync_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time    := 10 ns;
    constant Depth_c         : natural := Depth_g;
    constant AlmFullLevel_c  : natural := Depth_c - 4;
    constant AlmEmptyLevel_c : natural := 4;
    -- Beats the ECC decoder can buffer (two per pipeline stage)
    constant DecCapacity_c   : natural  := 2 * EccPipeline_g;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -----------------------------------------------------------------------------------------------
    -- Verification components.
    --   Master pushes In_Data through the user-facing AXI-S input.
    --   Slave samples (Out_Data, EccSec, EccDed) on the output side; tuser = Sec & Ded.
    --   Both VCs carry a non-zero stall probability so back-pressure is exercised on every
    --   test case (the FIFO's flow control through the codec must remain correct under stalls).
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
    signal In_Data           : std_logic_vector(Width_g - 1 downto 0);
    signal In_Valid          : std_logic;
    signal In_Ready          : std_logic;
    signal In_Level          : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);
    signal In_ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal In_ErrInj_Valid   : std_logic                                      := '0';
    signal Out_Data          : std_logic_vector(Width_g - 1 downto 0);
    signal Out_Valid         : std_logic;
    signal Out_Ready         : std_logic;
    signal Slave_Ready       : std_logic;
    signal Out_ReadyForce    : std_logic                                      := '0';
    signal Out_Level         : std_logic_vector(log2ceil(Depth_c + DecCapacity_c + 1) - 1 downto 0);
    signal Out_EccSec        : std_logic;
    signal Out_EccDed        : std_logic;
    signal Out_TUser         : std_logic_vector(1 downto 0);
    signal Full              : std_logic;
    signal AlmFull           : std_logic;
    signal Empty             : std_logic;
    signal AlmEmpty          : std_logic;

    -- AlmFull/AlmEmpty are tied low when the corresponding generic disables them
    procedure checkAlmFull (expected : in std_logic; msg : in string) is
        variable Exp_v : std_logic := expected;
    begin
        if not AlmFullOn_g then
            Exp_v := '0';
        end if;
        check_equal(AlmFull, Exp_v, "AlmFull " & msg);
    end procedure;

    procedure checkAlmEmpty (expected : in std_logic; msg : in string) is
        variable Exp_v : std_logic := expected;
    begin
        if not AlmEmptyOn_g then
            Exp_v := '0';
        end if;
        check_equal(AlmEmpty, Exp_v, "AlmEmpty " & msg);
    end procedure;

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
            wait until rising_edge(Clk);
            Rst               <= '1';
            wait for 200 ns;
            wait until rising_edge(Clk);
            Rst               <= '0';
            wait until rising_edge(Clk);

            ---------------------------------------------------------------------------------------
            if run("Basic") then
                -- Three clean beats. Both master and slave stall at ~20% so back-pressure
                -- happens organically on every test.
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(10, Width_g), Flip_v);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(20, Width_g), Flip_v);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(30, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(10, Width_g), Flip_v, "Basic[0]");
                ftExpectBeat(net, AxisSlave_c, toUslv(20, Width_g), Flip_v, "Basic[1]");
                ftExpectBeat(net, AxisSlave_c, toUslv(30, Width_g), Flip_v, "Basic[2]");

            ---------------------------------------------------------------------------------------
            elsif run("EccSec") then
                Flip_v := setBits(0, CodewordWidth_c);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#AB#, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(16#AB#, Width_g), Flip_v, "EccSec corrected");

            ---------------------------------------------------------------------------------------
            elsif run("EccDed") then
                Flip_v := setBits((0, 1), CodewordWidth_c);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#EF#, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(16#EF#, Width_g), Flip_v, "EccDed detected");

            ---------------------------------------------------------------------------------------
            elsif run("Mixed") then
                -- Clean / SEC / clean: adjacent beats keep their flags independent through the
                -- FIFO + pipeline.
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#01#, Width_g), Flip_v);
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#02#, Width_g), setBits(0, CodewordWidth_c));
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#03#, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(16#01#, Width_g), (Flip_v'range => '0'),         "Mixed[0] clean");
                ftExpectBeat(net, AxisSlave_c, toUslv(16#02#, Width_g), setBits(0, CodewordWidth_c),  "Mixed[1] Sec");
                ftExpectBeat(net, AxisSlave_c, toUslv(16#03#, Width_g), (Flip_v'range => '0'),         "Mixed[2] clean");

            ---------------------------------------------------------------------------------------
            elsif run("FullEmpty") then
                -- Push Depth_c clean beats; the FIFO must accept all of them (master's In_Ready
                -- handshake handles back-pressure when the FIFO fills). Drain afterwards.
                Flip_v := (others => '0');

                for i in 0 to Depth_c - 1 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i, Width_g));
                end loop;

                for i in 0 to Depth_c - 1 loop
                    check_axi_stream(net, AxisSlave_c, toUslv(i, Width_g), tuser => "00",
                        msg                                                      => "FullEmpty drain " & integer'image(i), blocking => false);
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("BackToBack") then
                -- Push 64 beats (2x depth) - exercises sustained throughput under back-pressure.
                Flip_v := (others => '0');

                for i in 0 to 63 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i + 1, Width_g));
                end loop;

                for i in 0 to 63 loop
                    check_axi_stream(net, AxisSlave_c, toUslv(i + 1, Width_g), tuser => "00",
                        msg                                                          => "BackToBack " & integer'image(i), blocking => false);
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("SecAllBits") then

                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    Flip_v := setBits(bitIdx, CodewordWidth_c);
                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#A5#, Width_g), Flip_v);
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#A5#, Width_g), Flip_v,
                        "SecAllBits flip " & integer'image(bitIdx));
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

                    ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#5A#, Width_g), Flip_v);
                    ftExpectBeat(net, AxisSlave_c, toUslv(16#5A#, Width_g), Flip_v,
                        "DedPair " & integer'image(pair));
                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("LatchedInjection") then
                -- Preload the injection pattern without pushing data, idle a few cycles, then
                -- push a beat. The codec latch must apply the pattern to that single beat.
                In_ErrInj_BitFlip <= setBits(2, CodewordWidth_c);
                In_ErrInj_Valid   <= '1';
                wait until rising_edge(Clk);
                In_ErrInj_Valid   <= '0';

                for i in 0 to 4 loop
                    wait until rising_edge(Clk);
                end loop;

                push_axi_stream(net, AxisMaster_c, toUslv(16#3C#, Width_g));
                ftExpectBeat(net, AxisSlave_c, toUslv(16#3C#, Width_g), setBits(2, CodewordWidth_c),
                    "Latched flip applied");

                wait_until_idle(net, as_sync(AxisSlave_c));

                In_ErrInj_BitFlip <= (others => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#3C#, Width_g));
                ftExpectBeat(net, AxisSlave_c, toUslv(16#3C#, Width_g), (Flip_v'range => '0'), "Latch cleared");

            ---------------------------------------------------------------------------------------
            elsif run("ResetInFlight") then
                -- Fill the FIFO with beats that are never drained (no read expectation queued,
                -- so the slave VC keeps Out_Ready low), then reset mid-operation. The FIFO must
                -- come back empty, with no stale beat, and accept new data cleanly afterwards.

                for i in 0 to 7 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i + 16#40#, Width_g));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                -- Let the beats settle into the FIFO and the decode pipeline
                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Out_Valid, '1', "Out_Valid must be high before the reset");

                -- Reset with the beats still in flight
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Rst <= '0';

                -- Flush longer than the deepest pipeline: no stale valid may re-appear
                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Out_Valid, '0', "Out_Valid must be squashed by the reset");
                check_equal(Empty, '1', "FIFO must be empty after the reset");
                check_equal(In_Level, toUslv(0, In_Level'length), "In_Level must be 0 after the reset");
                check_equal(Out_Level, toUslv(0, Out_Level'length), "Out_Level must be 0 after the reset");

                -- Clean recovery: a fresh beat passes through untouched
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#77#, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(16#77#, Width_g), Flip_v, "Recovery beat");

            ---------------------------------------------------------------------------------------
            elsif run("StatusAndLevels") then
                -- No read expectation is queued during the fill phases, so the slave VC keeps
                -- Out_Ready low
                check_equal(Empty, '1', "Empty must be high after reset");
                check_equal(Full, '0', "Full must be low after reset");
                checkAlmEmpty('1', "after reset");
                checkAlmFull('0', "after reset");
                check_equal(In_Level, toUslv(0, In_Level'length), "In_Level must be 0 after reset");
                check_equal(Out_Level, toUslv(0, Out_Level'length), "Out_Level must be 0 after reset");

                -- Mid fill
                for i in 0 to 15 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i, Width_g));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Empty, '0', "Empty must be low at mid fill");
                checkAlmEmpty('0', "at mid fill");
                checkAlmFull('0', "at mid fill");
                check_equal(Out_Level, toUslv(16, Out_Level'length),
                    "Out_Level must include the beats buffered in the decoder");

                -- Top up until the internal FIFO is full
                for i in 16 to Depth_c + DecCapacity_c - 1 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i, Width_g));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Full, '1', "Full must be high once the internal FIFO is full");
                checkAlmFull('1', "once the internal FIFO is full");
                check_equal(In_Level, toUslv(Depth_c, In_Level'length),
                    "In_Level must report the internal FIFO content");
                check_equal(Out_Level, toUslv(Depth_c + DecCapacity_c, Out_Level'length),
                    "Out_Level must report the entity content");

                -- Drain everything
                for i in 0 to Depth_c + DecCapacity_c - 1 loop
                    check_axi_stream(net, AxisSlave_c, toUslv(i, Width_g), tuser => "00",
                        msg                                                      => "StatusAndLevels drain " & integer'image(i), blocking => false);
                end loop;

                wait_until_idle(net, as_sync(AxisSlave_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Empty, '1', "Empty must be high after the entity is drained");
                checkAlmEmpty('1', "after the entity is drained");
                check_equal(Full, '0', "Full must be low after the drain");
                checkAlmFull('0', "after the drain");
                check_equal(In_Level, toUslv(0, In_Level'length), "In_Level must be 0 when drained");
                check_equal(Out_Level, toUslv(0, Out_Level'length), "Out_Level must be 0 when drained");

            ---------------------------------------------------------------------------------------
            elsif run("ReadEmptyFifo") then
                -- Reading an empty FIFO must not produce data and must not disturb the status
                check_equal(Empty, '1', "Empty must be high before the read attempt");

                wait until rising_edge(Clk);
                Out_ReadyForce <= '1';

                for i in 0 to 9 loop
                    wait until rising_edge(Clk);
                    check_equal(Out_Valid, '0', "Out_Valid must stay low on an empty FIFO");
                end loop;

                Out_ReadyForce <= '0';
                wait until rising_edge(Clk);
                check_equal(Empty, '1', "Empty must still be high after the read attempt");
                check_equal(Out_Level, toUslv(0, Out_Level'length), "Out_Level must still be 0");

                -- The FIFO still works afterwards
                Flip_v := (others => '0');
                ftPushBeat(net, AxisMaster_c, Clk, In_ErrInj_BitFlip, In_ErrInj_Valid, toUslv(16#5A#, Width_g), Flip_v);
                ftExpectBeat(net, AxisSlave_c, toUslv(16#5A#, Width_g), Flip_v, "Beat after empty read");

            ---------------------------------------------------------------------------------------
            elsif run("WriteFullFifo") then

                -- Writing to a full FIFO must be blocked by In_Ready and must not corrupt content
                for i in 0 to Depth_c + DecCapacity_c - 1 loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i, Width_g));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                check_equal(Full, '1', "Full must be high");
                check_equal(In_Ready, '0', "In_Ready must be low while full");

                -- Offer more data while full, it must not be accepted
                for i in 0 to 9 loop
                    wait until rising_edge(Clk);
                    check_equal(In_Ready, '0', "In_Ready must stay low while full");
                end loop;

                -- Everything written before is still delivered in order and unchanged
                for i in 0 to Depth_c + DecCapacity_c - 1 loop
                    check_axi_stream(net, AxisSlave_c, toUslv(i, Width_g), tuser => "00",
                        msg                                                      => "WriteFullFifo drain " & integer'image(i), blocking => false);
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("AlmostFlagsThresholds") then

                -- AlmEmpty is computed inside the entity, so the threshold is checked exactly
                for i in 0 to AlmEmptyLevel_c loop
                    push_axi_stream(net, AxisMaster_c, toUslv(i, Width_g));
                end loop;

                wait_until_idle(net, as_sync(AxisMaster_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                -- Exactly AlmEmptyLevel_c + 1 beats are pending, one above the threshold
                checkAlmEmpty('0', "one beat above the threshold");

                -- Drain one beat, now exactly at the threshold
                check_axi_stream(net, AxisSlave_c, toUslv(0, Width_g), tuser => "00",
                    msg                                                      => "Threshold drain", blocking => false);
                wait_until_idle(net, as_sync(AxisSlave_c));

                for i in 0 to 4 + EccPipeline_g loop
                    wait until rising_edge(Clk);
                end loop;

                checkAlmEmpty('1', "exactly at the threshold");

                -- Drain the rest
                for i in 1 to AlmEmptyLevel_c loop
                    check_axi_stream(net, AxisSlave_c, toUslv(i, Width_g), tuser => "00",
                        msg                                                      => "Threshold rest " & integer'image(i), blocking => false);
                end loop;

            ---------------------------------------------------------------------------------------
            elsif run("ReadyRstState") then
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                check_equal(In_Ready, toStdl(ReadyRstState_g),
                    "In_Ready must follow ReadyRstState_g during reset");
                wait until rising_edge(Clk);
                Rst <= '0';
                wait until rising_edge(Clk);
                check_equal(In_Ready, '1', "In_Ready must be high after reset");

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
    Out_Ready <= Slave_Ready or Out_ReadyForce;

    -----------------------------------------------------------------------------------------------
    -- Status Monitors
    -----------------------------------------------------------------------------------------------
    -- Invariants that must hold in every test case
    p_status_monitor : process (Clk) is
    begin
        if rising_edge(Clk) then
            if Rst = '0' then
                check_false(Empty = '1' and Out_Valid = '1',
                    "Empty asserted while Out_Valid offers a beat");
                check_equal(Full, not In_Ready, "Full must be the inverse of In_Ready");
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_fifo_sync
        generic map (
            Width_g         => Width_g,
            Depth_g         => Depth_c,
            AlmFullOn_g     => AlmFullOn_g,
            AlmFullLevel_g  => AlmFullLevel_c,
            AlmEmptyOn_g    => AlmEmptyOn_g,
            AlmEmptyLevel_g => AlmEmptyLevel_c,
            RamBehavior_g   => RamBehavior_g,
            ReadyRstState_g => toStdl(ReadyRstState_g),
            EccPipeline_g   => EccPipeline_g
        )
        port map (
            Clk               => Clk,
            Rst               => Rst,
            In_Data           => In_Data,
            In_Valid          => In_Valid,
            In_Ready          => In_Ready,
            In_Level          => In_Level,
            Out_Data          => Out_Data,
            Out_Valid         => Out_Valid,
            Out_Ready         => Out_Ready,
            Out_Level         => Out_Level,
            Out_EccSec        => Out_EccSec,
            Out_EccDed        => Out_EccDed,
            Full              => Full,
            AlmFull           => AlmFull,
            Empty             => Empty,
            AlmEmpty          => AlmEmpty,
            In_ErrInj_BitFlip => In_ErrInj_BitFlip,
            In_ErrInj_Valid   => In_ErrInj_Valid
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
            TData  => In_Data
        );

    vc_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Slave_Ready,
            TData  => Out_Data,
            TUser  => Out_TUser
        );

end architecture;
