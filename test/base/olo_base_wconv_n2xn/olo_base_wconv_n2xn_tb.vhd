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
entity olo_base_wconv_n2xn_tb is
    generic (
        runner_cfg      : string;
        WidthRatio_g    : positive range 1 to 3 := 2
    );
end entity;

architecture sim of olo_base_wconv_n2xn_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant InWidth_c   : natural := 4;
    constant OutWidth_c  : natural := InWidth_c*WidthRatio_g;
    constant ClkPeriod_c : time    := 10 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable WordDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => InWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => OutWidth_c,
        user_length => WidthRatio_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    function counterValue (start : integer) return std_logic_vector is
        variable Value_v : std_logic_vector(OutWidth_c-1 downto 0);
    begin

        -- Iterate through wider vector
        for i in 0 to WidthRatio_g-1 loop
            Value_v(4*i+3 downto 4*i) := toUslv(start+i, 4);
        end loop;

        return Value_v;
    end function;

    procedure pushCounterValue (
        signal  net : inout network_t;
        start       : integer;
        count       : integer;
        last        : std_logic) is
        variable LastCheck_v : std_logic := '0';
    begin

        -- Iterate through samples
        for i in 0 to count-1 loop
            if i = count-1 then
                LastCheck_v := last;
            end if;
            if WordDelay_v > 0 ns then
                wait for WordDelay_v;
            end if;
            push_axi_stream(net, AxisMaster_c, toUslv(start+i, 4), tlast => LastCheck_v);
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic                                   := '0';
    signal Rst         : std_logic                                   := '1';
    signal In_Valid    : std_logic                                   := '0';
    signal In_Ready    : std_logic                                   := '0';
    signal In_Data     : std_logic_vector(InWidth_c - 1 downto 0)    := (others => '0');
    signal In_Last     : std_logic                                   := '0';
    signal Out_WordEna : std_logic_vector(WidthRatio_g - 1 downto 0) := (others => '0');
    signal Out_Valid   : std_logic                                   := '0';
    signal Out_Ready   : std_logic                                   := '0';
    signal Out_Data    : std_logic_vector(OutWidth_c - 1 downto 0)   := (others => '0');
    signal Out_Last    : std_logic                                   := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v           : std_logic_vector(Out_Data'range);
        variable Last_v           : std_logic;
        variable WordEna_v        : std_logic_vector(Out_WordEna'range);
        variable TKeep_v, TStrb_v : std_logic_vector(OutWidth_c/8-1 downto 0);
        variable TDest_v, TId_v   : std_logic_vector(-1 downto 0);
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
                pushCounterValue(net, start => 1, count => WidthRatio_g, last => '0');
                check_axi_stream(net, AxisSlave_c, counterValue(1), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                -- With last
                pushCounterValue(net, start => 3, count => WidthRatio_g, last => '1');
                check_axi_stream(net, AxisSlave_c, counterValue(3), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
            end if;

            if run("FullThrottle") then
                pushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                pushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                pushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
                check_axi_stream(net, AxisSlave_c, counterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                check_axi_stream(net, AxisSlave_c, counterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                check_axi_stream(net, AxisSlave_c, counterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
            end if;

            if run("OutLimited") then
                pushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                pushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                pushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
                wait for 200 ns;
                check_axi_stream(net, AxisSlave_c, counterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                wait for 200 ns;
                check_axi_stream(net, AxisSlave_c, counterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                wait for 200 ns;
                check_axi_stream(net, AxisSlave_c, counterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
            end if;

            if run("InLimited") then
                WordDelay_v := 200 ns;
                check_axi_stream(net, AxisSlave_c, counterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data a");
                check_axi_stream(net, AxisSlave_c, counterValue(4), tlast => '1', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data b");
                check_axi_stream(net, AxisSlave_c, counterValue(5), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "data c");
                pushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                pushCounterValue(net, start => 4, count => WidthRatio_g, last => '1');
                pushCounterValue(net, start => 5, count => WidthRatio_g, last => '0');
            end if;

            if run("PartialWord") then
                pushCounterValue(net, start => 3, count => WidthRatio_g, last => '0');
                check_axi_stream(net, AxisSlave_c, counterValue(3), tlast => '0', tuser => onesVector(WidthRatio_g), blocking => false, msg => "full Word");
                push_axi_stream(net, AxisMaster_c, toUslv(7, 4), tlast => '1');
                pop_axi_stream(net, AxisSlave_c,
                    tdata => Data_v, tlast => Last_v,  tkeep => TKeep_v, tstrb => TStrb_v,
                    tid   => TId_v,  tdest => TDest_v, tuser => WordEna_v);
                check_equal(Data_v(3 downto 0), 7, "lastWord Data_v");
                check_equal(Last_v, '1', "lastWord Last");
                check_equal(WordEna_v, 1, "lastWort WordEna");
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
    i_dut : entity olo.olo_base_wconv_n2xn
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
            Out_WordEna => Out_WordEna,
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
            TLast  => Out_Last,
            TUser  => Out_WordEna

        );

end architecture;
