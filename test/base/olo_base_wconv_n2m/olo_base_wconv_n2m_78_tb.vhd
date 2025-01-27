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
entity olo_base_wconv_n2m_78_tb is
    generic (
        runner_cfg      : string;
        Direction_g     : string := "up"
    );
end entity;

architecture sim of olo_base_wconv_n2m_78_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c  : time                                      := 10 ns;
    constant PacketBits_c : positive                                  := 56;
    constant Data1_c      : std_logic_vector(PacketBits_c-1 downto 0) := x"1234567890ABCD";
    constant Data2_c      : std_logic_vector(PacketBits_c-1 downto 0) := x"1A2B3C4D5E6F78";
    constant InWidth_c    : positive                                  := choose(Direction_g = "up", 7, 8);
    constant OutWidth_c   : positive                                  := choose(Direction_g = "up", 8, 7);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => InWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => OutWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure testPacket (
        signal  net : inout network_t;
        data        : std_logic_vector) is
        -- variables
        variable InData_v  : std_logic_vector(InWidth_c-1 downto 0);
        variable OutData_v : std_logic_vector(OutWidth_c-1 downto 0);
        variable IsLast_v  : std_logic;
    begin

        -- Packet Input
        for i in 0 to PacketBits_c/InWidth_c-1 loop
            InData_v := data((i+1)*InWidth_c-1 downto i*InWidth_c);
            IsLast_v := choose(i = PacketBits_c/InWidth_c-1, '1', '0');
            push_axi_stream(net, AxisMaster_c, InData_v, tlast => IsLast_v);
        end loop;

        -- Packet Output
        for i in 0 to PacketBits_c/Outwidth_c-1 loop
            OutData_v := data((i+1)*Outwidth_c-1 downto i*Outwidth_c);
            IsLast_v  := choose(i = PacketBits_c/Outwidth_c-1, '1', '0');
            check_axi_stream(net, AxisSlave_c, OutData_v, tlast => IsLast_v, blocking => false);
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                 := '0';
    signal Rst       : std_logic                                 := '1';
    signal In_Valid  : std_logic                                 := '0';
    signal In_Ready  : std_logic                                 := '0';
    signal In_Data   : std_logic_vector(InWidth_c - 1 downto 0)  := (others => '0');
    signal In_Last   : std_logic                                 := '0';
    signal Out_Valid : std_logic                                 := '0';
    signal Out_Ready : std_logic                                 := '0';
    signal Out_Data  : std_logic_vector(OutWidth_c - 1 downto 0) := (others => '0');
    signal Out_Last  : std_logic                                 := '0';

begin

    assert Direction_g = "up" or Direction_g = "down"
        report "Direction_g must be up or down"
        severity failure;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
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

            -- Transfer two packets
            if run("Transfer-TwoPackets") then

                for pause in 0 to 1 loop

                    -- Packet 1
                    testPacket(net, Data1_c);

                    -- Pause
                    if pause = 1 then
                        wait_until_idle(net, as_sync(AxisMaster_c));
                        wait_until_idle(net, as_sync(AxisSlave_c));
                        wait for 10*ClkPeriod_c;
                    end if;

                    -- Packet 2
                    testPacket(net, Data2_c);
                end loop;

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
