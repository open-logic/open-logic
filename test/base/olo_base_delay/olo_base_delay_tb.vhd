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
entity olo_base_delay_tb is
    generic (
        runner_cfg      : string;
        Delay_g         : natural;
        Resource_g      : string  := "AUTO";   -- AUTO, SRL or BRAM     -- Number of delay taps to start using BRAM from (if Resource_g = AUTO)
        RstState_g      : boolean := True;     -- True = '0' is outputted after reset, '1' after reset the existing state is outputted
        RamBehavior_g   : string  := "RBW";    -- "RBW" = read-before-write, "WBR" = write-before-read
        RandomStall_g   : boolean := false
    );
end entity;

architecture sim of olo_base_delay_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c     : integer := 16;
    constant BramThreshold_c : integer := 16;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable InDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 10)
    );

    -- *** Procedures ***
    procedure push100 (signal net : inout network_t) is
    begin

        -- Push 100 samples
        for i in 0 to 99 loop
            wait for InDelay_v;
            push_axi_stream(net, AxisMaster_c, toUslv(i, DataWidth_c));
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk      : std_logic                                  := '0';
    signal Rst      : std_logic                                  := '0';
    signal In_Valid : std_logic                                  := '0';
    signal In_Data  : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal Out_Data : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');

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

            InDelay_v := 0 ns;

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("FullThrottle") then
                push100(net);
            end if;

            if run("InLimited") then
                InDelay_v := Clk_Period_c*5;
                push100(net);
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
    i_dut : entity olo.olo_base_delay
        generic map (
            Width_g         => DataWidth_c,
            Delay_g         => Delay_g,
            Resource_g      => Resource_g,
            BramThreshold_g => BramThreshold_c,
            RstState_g      => RstState_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
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
                if unsigned(In_Data) >= Delay_g then
                    check_equal(Out_Data, fromUslv(In_Data)-Delay_g, "Wrong Value in Normal Operation");
                -- First samples after reset
                else
                    -- Only check in "reset state" case
                    if RstState_g then
                        check_equal(Out_Data, 0, "Wrong Value after Reset");
                    end if;
                end if;

            end if;

        end if;
    end process;

end architecture;
