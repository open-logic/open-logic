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
entity olo_base_delay_cfg_tb is
    generic (
        runner_cfg      : string;
        SupportZero_g   : boolean := false;
        RamBehavior_g   : string  := "RBW";
        RandomStall_g   : boolean := false;
        MaxDelay_g      : integer := 20
    );
end entity;

architecture sim of olo_base_delay_cfg_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : integer := 16;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk      : std_logic                                           := '0';
    signal Rst      : std_logic                                           := '0';
    signal Delay    : std_logic_vector(log2ceil(MaxDelay_g+1)-1 downto 0) := (others => '0');
    signal In_Valid : std_logic                                           := '0';
    signal In_Data  : std_logic_vector(DataWidth_c - 1 downto 0)          := (others => '0');
    signal Out_Data : std_logic_vector(DataWidth_c - 1 downto 0)          := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v       : time := 0 ns;
    shared variable DataCounter_v   : integer;
    shared variable StartChecking_v : integer;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 10)
    );

    -- *** Procedures ***
    procedure pushSamples (
        signal net : inout network_t;
        count      : integer) is
    begin
        wait for 0.1 ns; -- make sure Delay signal is updated
        StartChecking_v := max(DataCounter_v + 5, fromUslv(Delay)); -- start checking on 5th sample or delay (the bigger, output must be valid)
        report integer'image(StartChecking_v);

        -- Iterate through samples
        for i in 0 to count-1 loop
            wait for InDelay_v;
            push_axi_stream(net, AxisMaster_c, toUslv(DataCounter_v, DataWidth_c));
            DataCounter_v := DataCounter_v + 1;
        end loop;

    end procedure;

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

            InDelay_v     := 0 ns;
            DataCounter_v := 0;

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("FixDelay0") then
                -- Skip if zero is not supported
                if SupportZero_g then
                    Delay <= toUslv(0, Delay'length);
                    pushSamples(net, 20);
                end if;
            end if;

            if run("FixDelay1") then
                Delay <= toUslv(1, Delay'length);
                pushSamples(net, 20);
            end if;

            if run("FixDelay2") then
                Delay <= toUslv(2, Delay'length);
                pushSamples(net, 20);
            end if;

            if run("FixDelay3") then
                Delay <= toUslv(3, Delay'length);
                pushSamples(net, 20);
            end if;

            if run("FixDelay5") then
                Delay <= toUslv(5, Delay'length);
                pushSamples(net, 20);
            end if;

            if run("FixDelayMax") then
                Delay <= toUslv(MaxDelay_g, Delay'length);
                pushSamples(net, 40);
            end if;

            if run("IncreaseDelay") then
                Delay <= toUslv(5, Delay'length);
                pushSamples(net, 40);
                wait_until_idle(net, as_sync(AxisMaster_c));
                Delay <= toUslv(7, Delay'length);
                pushSamples(net, 40);
            end if;

            if run("DecreaseDelay") then
                Delay <= toUslv(7, Delay'length);
                pushSamples(net, 40);
                wait_until_idle(net, as_sync(AxisMaster_c));
                Delay <= toUslv(2, Delay'length);
                pushSamples(net, 10);
                wait_until_idle(net, as_sync(AxisMaster_c));
                Delay <= toUslv(1, Delay'length);
                pushSamples(net, 10);
            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_delay_cfg
        generic map (
            Width_g         => DataWidth_c,
            MaxDelay_g      => MaxDelay_g,
            SupportZero_g   => SupportZero_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            Delay       => Delay,
            In_Valid    => In_Valid,
            In_Data     => In_Data,
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
            AClk   => Clk,
            TValid => In_Valid,
            TReady => '1',
            TData  => In_Data
        );

    -----------------------------------------------------------------------------------------------
    -- Custom Processes
    -----------------------------------------------------------------------------------------------
    p_checkout : process (Clk) is
    begin
        if rising_edge(Clk) then
            if In_Valid = '1' then
                -- Normal operation
                if unsigned(In_Data) >= StartChecking_v then
                    check_equal(Out_Data, fromUslv(In_Data)-fromUslv(Delay), "Wrong Value");
                end if;
            end if;
        end if;
    end process;

end architecture;
