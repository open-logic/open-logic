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
    constant ClkPeriod_c : time    := 10 ns;

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

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic                                   := '0';
    signal Rst         : std_logic                                   := '1';
    signal In_Valid    : std_logic                                   := '0';
    signal In_Ready    : std_logic                                   := '0';
    signal In_Data     : std_logic_vector(InWidth_g - 1 downto 0)    := (others => '0');
    signal In_Last     : std_logic                                   := '0';
    signal Out_Valid   : std_logic                                   := '0';
    signal Out_Ready   : std_logic                                   := '0';
    signal Out_Data    : std_logic_vector(OutWidth_g - 1 downto 0)   := (others => '0');
    signal Out_Last    : std_logic                                   := '0';

begin

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

            -- Reset state
            if run("Reset") then
                -- Outside of reset
                check_equal(In_Ready, '1', "In_Ready");
                check_equal(Out_Valid, '0', "Out_Valid");
                -- Ready going low in reset
                Rst <= '1';
                wait until rising_edge(Clk);
                check_equal(In_Ready, '0', "In_Ready Rst");
                check_equal(Out_Valid, '0', "Out_Valid Rst");
            end if;

            -- Transfer Integer word width (no packet end)
            if run("Transfer-LCM-Words") then
                push_axi_stream(net, AxisMaster_c, toUslv(16#0201#, InWidth_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#0403#, InWidth_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#0605#, InWidth_g), tlast => '0');
                check_axi_stream(net, AxisSlave_c, toUslv(16#030201#, OutWidth_g), tlast => '0', msg => "data 0");
                check_axi_stream(net, AxisSlave_c, toUslv(16#060504#, OutWidth_g), tlast => '0', msg => "data 1");
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
