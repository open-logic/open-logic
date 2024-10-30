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
entity olo_base_cc_handshake_tb is
    generic (
        runner_cfg      : string;
        RandomStall_g   : boolean               := false;
        ReadyRstState_g : integer               := 1;
        ClockRatio_N_g  : integer               := 1;
        ClockRatio_D_g  : integer               := 1;
        SyncStages_g    : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_handshake_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClockRatio_c    : real      := real(ClockRatio_N_g) / real(ClockRatio_D_g);
    constant DataWidth_c     : integer   := 16;
    constant ReadyRstState_c : std_logic := choose(ReadyRstState_g = 0, '0', '1');

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkIn_Frequency_c    : real := 100.0e6;
    constant ClkIn_Period_c       : time := (1 sec) / ClkIn_Frequency_c;
    constant ClkOut_Frequency_c   : real := ClkIn_Frequency_c * ClockRatio_c;
    constant ClkOut_Period_c      : time := (1 sec) / ClkOut_Frequency_c;
    constant SlowerClock_Period_c : time := (1 sec) / minimum(ClkIn_Frequency_c, ClkOut_Frequency_c);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v  : time := 0 ns;
    shared variable OutDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 20)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 20)
    );

    -- *** Procedures ***
    procedure pushValues (
        signal net : inout network_t;
        values     : integer := 100) is
    begin

        -- Loop over values
        for i in 0 to values-1 loop
            if InDelay_v > 0 ns then
                wait for InDelay_v;
            end if;
            push_axi_stream(net, AxisMaster_c, toUslv(i, DataWidth_c));
        end loop;

    end procedure;

    procedure checkValues (
        signal net : inout network_t;
        values     : integer := 100) is
    begin

        -- Loop over values
        for i in 0 to values-1 loop
            if OutDelay_v > 0 ns then
                wait for OutDelay_v;
            end if;
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
    test_runner_watchdog(runner, 10 ms);

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
            wait until rising_edge(In_Clk) and In_RstOut = '0' and Out_RstOut = '0';

            -- Check values after reset
            if run("ResetValues") then
                check_equal(In_Ready, '1', "In_Ready after reset");
                check_equal(Out_Valid, '0', "Out_Valid after ");
                -- assert reset
                In_RstIn <= '1';
                wait until rising_edge(In_Clk) and In_RstOut = '1' and Out_RstOut = '1';
                wait until rising_edge(Out_Clk) and In_RstOut = '1' and Out_RstOut = '1';
                check_equal(In_Ready, ReadyRstState_c, "In_Ready in reset");

            -- Single Word
            elsif run("Basic") then
                -- One value
                push_axi_stream(net, AxisMaster_c, toUslv(5, DataWidth_c));
                check_axi_stream(net, AxisSlave_c, toUslv(5, DataWidth_c), blocking => false, msg => "data a");
                -- Second value
                wait for 20*SlowerClock_Period_c;
                push_axi_stream(net, AxisMaster_c, toUslv(10, DataWidth_c));
                check_axi_stream(net, AxisSlave_c, toUslv(10, DataWidth_c), blocking => false, msg => "data b");

            elsif run("FullThrottle") then
                if not RandomStall_g then
                    pushValues(net, 20);
                    checkValues(net, 20);
                else
                    pushValues(net, 1000);
                    checkValues(net, 1000);
                end if;

            elsif run("OutLimited") then
                pushValues(net, 20);
                OutDelay_v := SlowerClock_Period_c*20;
                checkValues(net, 20);

            elsif run("InLimited") then
                checkValues(net, 20);
                InDelay_v := SlowerClock_Period_c*20;
                pushValues(net, 20);
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
    In_Clk  <= not In_Clk after 0.5 * ClkIn_Period_c;
    Out_Clk <= not Out_Clk after 0.5 * ClkOut_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_handshake
        generic map (
            Width_g         => DataWidth_c,
            ReadyRstState_g => ReadyRstState_c,
            SyncStages_g    => SyncStages_g
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
