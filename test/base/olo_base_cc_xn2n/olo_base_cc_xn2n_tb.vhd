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
entity olo_base_cc_xn2n_tb is
    generic (
        runner_cfg      : string;
        ClockRatio_g    : integer := 3
    );
end entity;

architecture sim of olo_base_cc_xn2n_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : integer := 16;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant InClk_Frequency_c    : real := 100.0e6;
    constant InClk_Period_c       : time := (1 sec) / InClk_Frequency_c;
    constant OutClk_Period_c      : time := ClockRatio_g*InClk_Period_c;
    constant SlowerClock_Period_c : time := maximum(InClk_Period_c, OutClk_Period_c);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v  : time := 0 ns;
    shared variable OutDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -- *** Procedures ***
    procedure push100 (signal net : inout network_t) is
    begin

        -- Push 100 values
        for i in 0 to 99 loop
            wait for InDelay_v;
            push_axi_stream(net, AxisMaster_c, toUslv(i, DataWidth_c));
        end loop;

    end procedure;

    procedure check100 (signal net : inout network_t) is
    begin

        -- Check 100 values
        for i in 0 to 99 loop
            wait for OutDelay_v;
            check_axi_stream(net, AxisSlave_c, toUslv(i, DataWidth_c), blocking => false, msg => "data " & integer'image(i));
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk     : std_logic                                  := '0';
    signal In_RstIn   : std_logic                                  := '0';
    signal In_RstOut  : std_logic                                  := '0';
    signal In_Valid   : std_logic                                  := '0';
    signal In_Ready   : std_logic                                  := '0';
    signal In_Data    : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal Out_Clk    : std_logic                                  := '0';
    signal Out_RstIn  : std_logic                                  := '0';
    signal Out_RstOut : std_logic                                  := '0';
    signal Out_Valid  : std_logic                                  := '0';
    signal Out_Ready  : std_logic                                  := '0';
    signal Out_Data   : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');

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

            InDelay_v  := 0 ns;
            OutDelay_v := 0 ns;

            -- Reset
            wait until rising_edge(In_Clk);
            In_RstIn <= '1';
            wait for 1 us;
            wait until rising_edge(In_Clk);
            In_RstIn <= '0';
            wait until rising_edge(In_Clk);

            -- Single Word
            if run("Basic") then
                -- One value
                push_axi_stream(net, AxisMaster_c, toUslv(5, DataWidth_c));
                check_axi_stream(net, AxisSlave_c, toUslv(5, DataWidth_c), blocking => false, msg => "data a");
                -- Second value
                wait for 5*SlowerClock_Period_c;
                push_axi_stream(net, AxisMaster_c, toUslv(10, DataWidth_c));
                check_axi_stream(net, AxisSlave_c, toUslv(10, DataWidth_c), blocking => false, msg => "data b");
            end if;

            if run("FullThrottle") then
                push100(net);
                check100(net);
            end if;

            if run("OutLimited") then
                push100(net);
                OutDelay_v := SlowerClock_Period_c*5;
                check100(net);
            end if;

            if run("InLimited") then
                check100(net);
                InDelay_v := SlowerClock_Period_c*5;
                push100(net);
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
    p_clk : process is
    begin

        -- Faster clock toggle during slower clock half-period
        for i in 0 to ClockRatio_g-1 loop
            wait for 0.5 * InClk_Period_c;
            In_Clk <= not In_Clk;
        end loop;

        -- Toggle slower clock
        Out_Clk <= not Out_Clk;
    end process;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_xn2n
        generic map (
            Width_g       => DataWidth_c
        )
        port map (
            In_Clk      => In_Clk,
            In_RstIn    => In_RstIn,
            In_RstOut   => In_RstOut,
            In_Valid    => In_Valid,
            In_Ready    => In_Ready,
            In_Data     => In_Data,
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => Out_RstOut,
            Out_Valid   => Out_Valid,
            Out_Ready   => Out_Ready,
            Out_Data    => Out_Data
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => In_Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Out_Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data
        );

end architecture;
