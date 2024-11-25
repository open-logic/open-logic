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

library osvvm;
    use osvvm.RandomPkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_dyn_sft_tb is
    generic (
        runner_cfg          : string;
        Direction_g         : string   := "LEFT";
        SelBitsPerStage_g   : positive := 4;
        MaxShift_g          : positive := 16;
        SignExtend_g        : boolean  := true
    );
end entity;

architecture sim of olo_base_dyn_sft_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : integer := 16;
    constant ShiftBits_c : integer := log2ceil(MaxShift_g+1);
    constant ValueLow_c  : integer := -(2**(DataWidth_c-1));
    constant ValueHigh_c : integer := 2**(DataWidth_c-1)-1;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable Random_v : RandomPType;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        user_length => ShiftBits_c,
        stall_config => new_stall_config(0.5, 0, 10)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -- *** Procedures ***
    procedure testShift (
        signal net : inout network_t;
        value      : in integer;
        shift      : in integer) is
        variable OutValue_v   : integer;
        variable InUnsigned_v : integer;
    begin
        push_axi_stream(net, AxisMaster_c, toSslv(value, DataWidth_c), tuser => toUslv(shift, ShiftBits_c));
        if Direction_g = "LEFT" then
            OutValue_v := (value * 2**shift) mod 2**DataWidth_c;
        elsif Direction_g = "RIGHT" then
            if SignExtend_g = true then
                -- Workaround for GHDL having rounded up the result of an integer division (instead of down)
                OutValue_v := integer(floor(real(value) / real(2**shift)));
            else
                InUnsigned_v := fromUslv(toSslv(value, DataWidth_c));
                OutValue_v   := (InUnsigned_v / 2**shift);
            end if;
        else
            check_failed("Illegal Direction_g");
        end if;
        check_axi_stream(net, AxisSlave_c, toSslv(OutValue_v, DataWidth_c),
                         blocking => false,
                         msg      => "Wrong Data - input: " & integer'image(value) & " shift: " & integer'image(shift));
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                := '0';
    signal Rst       : std_logic                                := '0';
    signal In_Valid  : std_logic                                := '0';
    signal In_Data   : std_logic_vector(DataWidth_c-1 downto 0) := (others => '0');
    signal In_Shift  : std_logic_vector(ShiftBits_c-1 downto 0) := (others => '0');
    signal Out_Valid : std_logic                                := '0';
    signal Out_Data  : std_logic_vector(DataWidth_c-1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);
        Random_v.InitSeed(Random_v'instance_name);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Loop through shifts
            if run("AllShifts") then

                -- Loop through all possible shifts
                for shift in 0 to MaxShift_g loop
                    testShift(net, Random_v.RandInt(ValueLow_c, ValueHigh_c), shift);
                end loop;

            end if;

            -- Test Random_v data
            if run("Random_vData") then

                -- Loop through random data
                for i in 0 to 100 loop
                    testShift(net, Random_v.RandInt(ValueLow_c, ValueHigh_c), Random_v.RandInt(0, MaxShift_g));
                end loop;

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
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_dyn_sft
        generic map (
            Direction_g         => Direction_g,
            SelBitsPerStage_g   => SelBitsPerStage_g,
            MaxShift_g          => MaxShift_g,
            Width_g             => DataWidth_c,
            SignExtend_g        => SignExtend_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_Shift    => In_Shift,
            In_Data     => In_Data,
            Out_Valid   => Out_Valid,
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
            TUser  => In_Shift,
            TData  => In_Data
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TData  => Out_Data
        );

end architecture;
