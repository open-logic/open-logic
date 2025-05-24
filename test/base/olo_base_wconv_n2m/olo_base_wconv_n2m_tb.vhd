---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Switzerland
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
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_wconv_n2m_tb is
    generic (
        runner_cfg      : string;
        InWidth_g       : positive := 16;
        OutWidth_g      : positive := 24
    );
end entity;

architecture sim of olo_base_wconv_n2m_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c   : time    := 10 ns;
    constant ElementSize_c : integer := greatestCommonFactor(InWidth_g, OutWidth_g);
    constant InElements_c  : integer := InWidth_g/ElementSize_c;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => InWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => OutWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure pushElements (
        signal  net : inout network_t;
        count       : positive;
        last        : std_logic := '1';
        start       : integer   := 0;
        validDelay  : time      := 0 ns) is
        -- variables
        variable InData_v   : std_logic_vector(InWidth_g - 1 downto 0) := (others => '0');
        variable ElInWord_v : natural                                  := 0;
    begin
        assert count < 2**ElementSize_c
            report "pushElements: count too large"
            severity failure;

        -- Push elements
        for i in 1 to count loop
            if ElInWord_v = InWidth_g/ElementSize_c then
                if validDelay /= 0 ns then
                    wait for validDelay;
                end if;
                push_axi_stream(net, AxisMaster_c, InData_v, tlast => '0');
                ElInWord_v := 0;
                InData_v   := (others => '0');
            end if;
            InData_v((ElInWord_v+1)*ElementSize_c-1 downto ElInWord_v*ElementSize_c) := toUslv(i+start, ElementSize_c);
            ElInWord_v                                                               := ElInWord_v + 1;
        end loop;

        -- Push last word
        if validDelay /= 0 ns then
            wait for validDelay;
        end if;
        push_axi_stream(net, AxisMaster_c, InData_v, tlast => last);

    end procedure;

    procedure expectElements (
        signal net : inout network_t;
        count      : positive;
        last       : std_logic := '1';
        msg        : string    := "msg";
        start      : integer   := 0;
        readyDelay : time      := 0 ns) is
        -- variables
        variable OutData_v  : std_logic_vector(OutWidth_g - 1 downto 0) := (others => '0');
        variable ElInWord_v : natural                                   := 0;
        variable Blocking_v : boolean                                   := choose(readyDelay = 0 ns, false, true);
    begin
        assert count < 2**ElementSize_c
            report "expectElements: count too large"
            severity failure;

        -- Check elements
        for i in 1 to count loop
            if ElInWord_v = OutWidth_g/ElementSize_c then
                if Blocking_v then
                    wait for readyDelay;
                end if;
                check_axi_stream(net, AxisSlave_c, OutData_v, tlast => '0', msg => msg & " - any-data", blocking => Blocking_v);
                ElInWord_v := 0;
                OutData_v  := (others => '0');
            end if;
            OutData_v((ElInWord_v+1)*ElementSize_c-1 downto ElInWord_v*ElementSize_c) := toUslv(i+start, ElementSize_c);
            ElInWord_v                                                                := ElInWord_v + 1;
        end loop;

        -- Check last word
        if Blocking_v then
            wait for readyDelay;
        end if;
        check_axi_stream(net, AxisSlave_c, OutData_v, tlast => last, msg => msg & " - last-data", blocking => Blocking_v);
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                 := '0';
    signal Rst       : std_logic                                 := '1';
    signal In_Valid  : std_logic                                 := '0';
    signal In_Ready  : std_logic                                 := '0';
    signal In_Data   : std_logic_vector(InWidth_g - 1 downto 0)  := (others => '0');
    signal In_Last   : std_logic                                 := '0';
    signal Out_Valid : std_logic                                 := '0';
    signal Out_Ready : std_logic                                 := '0';
    signal Out_Data  : std_logic_vector(OutWidth_g - 1 downto 0) := (others => '0');
    signal Out_Last  : std_logic                                 := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        constant FullBeatElements_c : integer := leastCommonMultiple(InWidth_g, OutWidth_g)/ElementSize_c;
        variable AddElements_v      : integer;
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

            -- Reset state
            if run("Reset") then
                -- Outside of reset
                check_equal(Out_Valid, '0', "Out_Valid");
                -- Ready going low in reset
                Rst <= '1';
                wait until rising_edge(Clk);
                check_equal(In_Ready, '0', "In_Ready Rst");
                check_equal(Out_Valid, '0', "Out_Valid Rst");
            end if;

            -- Transfer Integer word width (no packet end)
            if run("Transfer-LCM-Words") then
                pushElements(net, FullBeatElements_c);
                expectElements(net, FullBeatElements_c);
            end if;

            -- Transfer two packets, full word with pause
            if run("Transfer-TwoPackets-FullWord") then

                AddElements_v := 0;

                while AddElements_v < FullBeatElements_c loop

                    for pause in 0 to 1 loop

                        -- Packet 1
                        pushElements(net, FullBeatElements_c*2+AddElements_v);
                        expectElements(net, FullBeatElements_c*2+AddElements_v);

                        -- Pause
                        if pause = 1 then
                            wait_until_idle(net, as_sync(AxisMaster_c));
                            wait_until_idle(net, as_sync(AxisSlave_c));
                            wait for 10*ClkPeriod_c;
                        end if;

                        -- Packet 2
                        pushElements(net, FullBeatElements_c*2+AddElements_v);
                        expectElements(net, FullBeatElements_c*2+AddElements_v);
                    end loop;

                    -- Increase by one more input word
                    AddElements_v := AddElements_v + InElements_c;
                end loop;

            end if;

            -- Single word packet
            if run("Transfer-SingleWord") then

                for pause in 0 to 1 loop

                    -- Packet 1
                    pushElements(net, InElements_c);
                    expectElements(net, InElements_c);

                    -- Pause
                    if pause = 1 then
                        wait_until_idle(net, as_sync(AxisMaster_c));
                        wait_until_idle(net, as_sync(AxisSlave_c));
                        wait for 10*ClkPeriod_c;
                    end if;

                    -- Packet 2
                    pushElements(net, InElements_c, start => 5);
                    expectElements(net, InElements_c, start => 5);
                end loop;

            end if;

            -- Rate Limit Input
            if run("RateLimit-Input") then
                expectElements(net, FullBeatElements_c*2);
                expectElements(net, FullBeatElements_c*2, start => 5);
                pushElements(net, FullBeatElements_c*2, validDelay => 10*ClkPeriod_c);
                pushElements(net, FullBeatElements_c*2, start => 5, validDelay => 10*ClkPeriod_c);
            end if;

            -- Rate Limit Output
            if run("RateLimit-Output") then
                pushElements(net, FullBeatElements_c*2);
                pushElements(net, FullBeatElements_c*2, start => 5);
                expectElements(net, FullBeatElements_c*2, readyDelay => 10*ClkPeriod_c);
                expectElements(net, FullBeatElements_c*2, start => 5, readyDelay => 10*ClkPeriod_c);
            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_wconv_n2m
        generic map (
            InWidth_g    => InWidth_g,
            OutWidth_g   => OutWidth_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_Ready    => In_Ready,
            In_Data     => In_Data,
            In_Last     => In_Last,
            Out_Valid   => Out_Valid,
            Out_Ready   => Out_Ready,
            Out_Data    => Out_Data,
            Out_Last    => Out_Last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
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

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data,
            TLast  => Out_Last
        );

end architecture;
