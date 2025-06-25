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
entity olo_base_crc_initval_tb is
    generic (
        runner_cfg      : string
    );
end entity;

architecture sim of olo_base_crc_initval_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant CrcWidth_c     : natural          := 8;
    constant DataWidth_c    : natural          := 8;
    constant InitialValue_c : std_logic_vector := x"FD";
    constant Polynomial_c   : std_logic_vector := x"1D";

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        user_length => 1,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => CrcWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                  := '0';
    signal Rst       : std_logic                                  := '1';
    signal In_Valid  : std_logic                                  := '0';
    signal In_Ready  : std_logic                                  := '1';
    signal In_Data   : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal In_Last   : std_logic                                  := '0';
    signal In_First  : std_logic                                  := '0';
    signal Out_Valid : std_logic                                  := '0';
    signal Out_Ready : std_logic                                  := '1';
    signal Out_Crc   : std_logic_vector(CrcWidth_c - 1 downto 0)  := (others => '0');

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
            wait until rising_edge(Clk);

            -- CRC-8/I-CODE example from https://crccalc.com/?crc=111213&method=&datatype=hex&outtype=hex
            if run("InitVal") then
                push_axi_stream(net, AxisMaster_c, x"11", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"12", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"13", tlast => '1');
                check_axi_stream(net, AxisSlave_c, x"5c", msg => "CRC");
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
    i_dut : entity olo.olo_base_crc
        generic map (
            Polynomial_g    => Polynomial_c,
            InitialValue_g  => InitialValue_c,
            DataWidth_g     => DataWidth_c
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => In_Data,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready,
            In_Last   => In_Last,
            In_First  => In_First,
            Out_Crc   => Out_Crc,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk      => Clk,
            TValid    => In_Valid,
            TReady    => In_Ready,
            TData     => In_Data,
            TUser(0)  => In_First,
            TLast     => In_Last
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Crc
        );

end architecture;
