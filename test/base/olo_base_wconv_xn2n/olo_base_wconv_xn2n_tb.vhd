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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_wconv_xn2n_tb is
    generic (
        runner_cfg      : string;
        WidthRatio_g    : positive range 2 to 3 := 2
    );
end entity;

architecture sim of olo_base_wconv_xn2n_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant OutWidth_c  : natural := 4;
    constant InWidth_c   : natural := OutWidth_c*WidthRatio_g;
    constant ClkPeriod_c : time    := 10 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable WordDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => InWidth_c,
        user_length => WidthRatio_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => OutWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    function counterValue (start : integer) return std_logic_vector is
        variable Value_v : std_logic_vector(InWidth_c-1 downto 0);
    begin

        -- Iterate through wider vector
        for i in 0 to WidthRatio_g-1 loop
            Value_v(4*i+3 downto 4*i) := toUslv(start+i, 4);
        end loop;

        return Value_v;
    end function;

    procedure checkCounerValue (signal net : inout network_t; start : integer; last : std_logic) is
        variable LastCheck_v : std_logic := '0';
    begin

        -- Iterate through samples
        for i in 0 to WidthRatio_g-1 loop
            if i = WidthRatio_g-1 then
                LastCheck_v := last;
            end if;
            if WordDelay_v > 0 ns then
                wait for WordDelay_v;
            end if;
            check_axi_stream(net, AxisSlave_c, toUslv(start+i, 4),
                tlast    => LastCheck_v,
                blocking => false,
                msg      => "data " & integer'image(start+i));
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                             := '0';
    signal Rst        : std_logic                                             := '1';
    signal In_Valid   : std_logic                                             := '0';
    signal In_Ready   : std_logic                                             := '0';
    signal In_Data    : std_logic_vector(InWidth_c - 1 downto 0)              := (others => '0');
    signal In_Last    : std_logic                                             := '0';
    signal In_WordEna : std_logic_vector(InWidth_c / OutWidth_c - 1 downto 0) := (others => '0');
    signal Out_Valid  : std_logic                                             := '0';
    signal Out_Ready  : std_logic                                             := '0';
    signal Out_Data   : std_logic_vector(OutWidth_c - 1 downto 0)             := (others => '0');
    signal Out_Last   : std_logic                                             := '0';

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

            WordDelay_v := 0 ns;

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
                checkCounerValue(net, 1, '0');
                push_axi_stream(net, AxisMaster_c, counterValue(1), tuser => onesVector(WidthRatio_g), tlast => '0');
                -- With last
                checkCounerValue(net, 2, '1');
                push_axi_stream(net, AxisMaster_c, counterValue(2), tuser => onesVector(WidthRatio_g), tlast => '1');
            end if;

            if run("FullThrottle") then
                checkCounerValue(net, 3, '0');
                checkCounerValue(net, 4, '1');
                checkCounerValue(net, 5, '0');
                push_axi_stream(net, AxisMaster_c, counterValue(3), tuser => onesVector(WidthRatio_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, counterValue(4), tuser => onesVector(WidthRatio_g), tlast => '1');
                push_axi_stream(net, AxisMaster_c, counterValue(5), tuser => onesVector(WidthRatio_g), tlast => '0');
            end if;

            if run("OutLimited") then
                WordDelay_v := 200 ns;
                push_axi_stream(net, AxisMaster_c, counterValue(3), tuser => onesVector(WidthRatio_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, counterValue(4), tuser => onesVector(WidthRatio_g), tlast => '1');
                push_axi_stream(net, AxisMaster_c, counterValue(5), tuser => onesVector(WidthRatio_g), tlast => '0');
                checkCounerValue(net, 3, '0');
                checkCounerValue(net, 4, '1');
                checkCounerValue(net, 5, '0');
            end if;

            if run("InLimited") then
                checkCounerValue(net, 3, '0');
                checkCounerValue(net, 4, '1');
                checkCounerValue(net, 5, '0');
                push_axi_stream(net, AxisMaster_c, counterValue(3), tuser => onesVector(WidthRatio_g), tlast => '0');
                wait for 200 ns;
                push_axi_stream(net, AxisMaster_c, counterValue(4), tuser => onesVector(WidthRatio_g), tlast => '1');
                wait for 200 ns;
                push_axi_stream(net, AxisMaster_c, counterValue(5), tuser => onesVector(WidthRatio_g), tlast => '0');
            end if;

            if run("PartialWord") then
                -- Test word(0) enabled
                checkCounerValue(net, 3, '0');
                check_axi_stream(net, AxisSlave_c, toUslv(7, OutWidth_c), tlast => '1', blocking => false, msg => "lastWord a");
                push_axi_stream(net, AxisMaster_c, counterValue(3), tuser => onesVector(WidthRatio_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(7, inWidth_c), tuser => toUslv(1, WidthRatio_g), tlast => '1');
                -- Test word(1) enabled
                checkCounerValue(net, 4, '0');
                check_axi_stream(net, AxisSlave_c, toUslv(9, OutWidth_c), tlast => '1', blocking => false, msg => "lastWord b");
                push_axi_stream(net, AxisMaster_c, counterValue(4), tuser => onesVector(WidthRatio_g), tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(9*16, inWidth_c), tuser => toUslv(2#10#, WidthRatio_g), tlast => '1');
                -- Test words 0 and 2 enabled
                if WidthRatio_g >= 3 then
                    checkCounerValue(net, 5, '0');
                    check_axi_stream(net, AxisSlave_c, toUslv(5, OutWidth_c), tlast => '0', blocking => false, msg => "first word c");
                    check_axi_stream(net, AxisSlave_c, toUslv(3, OutWidth_c), tlast => '1', blocking => false, msg => "last word c");
                    push_axi_stream(net, AxisMaster_c, counterValue(5), tuser => onesVector(WidthRatio_g), tlast => '0');
                    push_axi_stream(net, AxisMaster_c, toUslv(3*2**8+5, inWidth_c), tuser => toUslv(2#101#, WidthRatio_g), tlast => '1');

                end if;
            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));

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
    i_dut : entity olo.olo_base_wconv_xn2n
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
            In_WordEna  => In_WordEna,
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
            TLast  => In_Last,
            TUser  => In_WordEna
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
