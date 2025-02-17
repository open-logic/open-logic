---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
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

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library work;
    use work.olo_test_activity_pkg.all;

library olo;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cc_simple_tb is
    generic (
        runner_cfg     : string;
        ClockRatio_N_g : integer               := 3;
        ClockRatio_D_g : integer               := 2;
        SyncStages_g   : positive range 2 to 4 := 2
    );
end entity;

architecture sim of olo_base_cc_simple_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClockRatio_c : real    := real(ClockRatio_N_g) / real(ClockRatio_D_g);
    constant DataWidth_c  : integer := 8;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkIn_Frequency_c  : real := 100.0e6;
    constant ClkIn_Period_c     : time := (1 sec) / ClkIn_Frequency_c;
    constant ClkOut_Frequency_c : real := ClkIn_Frequency_c * ClockRatio_c;
    constant ClkOut_Period_c    : time := (1 sec) / ClkOut_Frequency_c;
    constant MaxRatePeriod_c    : time := ClkOut_Period_c * (3+SyncStages_g);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Clk     : std_logic                                  := '0';
    signal In_RstIn   : std_logic                                  := '1';
    signal In_RstOut  : std_logic;
    signal In_Data    : std_logic_vector(DataWidth_c - 1 downto 0) := x"00";
    signal In_Valid   : std_logic                                  := '0';
    signal Out_Clk    : std_logic                                  := '0';
    signal Out_RstIn  : std_logic                                  := '1';
    signal Out_RstOut : std_logic;
    signal Out_Data   : std_logic_vector(DataWidth_c - 1 downto 0);
    signal Out_Valid  : std_logic;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cc_simple
        generic map (
            Width_g      => DataWidth_c,
            SyncStages_g => SyncStages_g
        )
        port map (
            -- Clock Domain A
            In_Clk      => In_Clk,
            In_RstIn    => In_RstIn,
            In_RstOut   => In_RstOut,
            In_Data     => In_Data,
            In_Valid    => In_Valid,
            -- Clock Domain B
            Out_Clk     => Out_Clk,
            Out_RstIn   => Out_RstIn,
            Out_RstOut  => Out_RstOut,
            Out_Data    => Out_Data,
            Out_Valid   => Out_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    In_Clk  <= not In_Clk after 0.5 * ClkIn_Period_c;
    Out_Clk <= not Out_Clk after 0.5 * ClkOut_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Stdlv_v : std_logic_vector(In_Data'range);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            In_RstIn  <= '1';
            Out_RstIn <= '1';
            wait for 1 us;

            -- Check if both sides are in reset
            check(In_RstOut = '1', "In_RstOut not asserted");
            check(Out_RstOut = '1', "Out_RstOut not asserted");

            -- Remove reset
            wait until rising_edge(In_Clk);
            In_RstIn  <= '0';
            wait until rising_edge(Out_Clk);
            Out_RstIn <= '0';
            wait for 1 us;

            -- Check if both sides exited reset
            check(In_RstOut = '0', "In_RstOut not de-asserted");
            check(Out_RstOut = '0', "Out_RstOut not de-asserted");

            -- *** Reset Tests ***
            if run("Reset") then

                -- Check if RstA is propagated to both sides
                pulse_sig(In_RstIn, In_Clk);
                wait for 1 us;
                check(In_RstOut = '0', "In_RstOut not de-asserted after In_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after In_RstIn");
                check(In_RstOut'last_event < 1 us, "In_RstOut not asserted after In_RstIn");
                check(Out_RstOut'last_event < 1 us, "Out_RstOut not asserted afterIn_RstIn");

                -- Check if RstB is propagated to both sides
                pulse_sig(Out_RstIn, Out_Clk);
                wait for 1 us;
                check(In_RstOut = '0', "In_RstOut not de-asserted after Out_RstIn");
                check(Out_RstOut = '0', "Out_RstOut not de-asserted after Out_RstIn");
                check(In_RstOut'last_event < 1 us, "In_RstOut not asserted after Out_RstIn");
                check(Out_RstOut'last_event < 1 us, "Out_RstOut not asserted after Out_RstIn");

            -- *** Data Tests ***
            elsif run("Transfer") then

                wait until rising_edge(In_Clk);
                In_Data  <= x"AB";
                In_Valid <= '1';
                wait until rising_edge(In_Clk);
                In_Data  <= x"00";
                In_Valid <= '0';
                wait until rising_edge(Out_Clk) and Out_Valid = '1';
                check_equal(Out_Data, 16#AB#, "Received wrong value 1");
                check_no_activity_stdlv(Out_Data, 10*ClkOut_Period_c, "Value was not kept after Vld going low 1");

                wait until rising_edge(In_Clk);
                In_Data  <= x"CD";
                In_Valid <= '1';
                wait until rising_edge(In_Clk);
                In_Data  <= x"00";
                In_Valid <= '0';
                wait until rising_edge(Out_Clk) and Out_Valid = '1';
                check_equal(Out_Data, 16#CD#, "Received wrong value 2");
                check_no_activity_stdlv(Out_Data, 10*ClkOut_Period_c, "Value was not kept after Vld going low 2");

            elsif run("MaxRate") then

                for i in 1 to 10 loop
                    wait until rising_edge(In_Clk);
                    Stdlv_v  := std_logic_vector(to_unsigned(i, In_Data'length));
                    In_Data  <= Stdlv_v;
                    In_Valid <= '1';
                    check_axi_stream(net, AxisSlave_c, Stdlv_v, blocking => false);
                    wait until rising_edge(In_Clk);
                    In_Valid <= '0';
                    wait for MaxRatePeriod_c-ClkOut_Period_c;
                end loop;

                wait_until_idle(net, as_sync(AxisSlave_c));
            end if;
        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Out_Clk,
            TValid => Out_Valid,
            TData  => Out_Data
        );

end architecture;
