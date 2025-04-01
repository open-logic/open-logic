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
entity olo_base_decode_firstbit_tb is
    generic (
        InWidth_g       : positive range 16 to positive'high := 64;
        InReg_g         : boolean                            := true;
        OutReg_g        : boolean                            := true;
        PlRegs_g        : natural                            := 1;
        runner_cfg      : string
    );
end entity;

architecture sim of olo_base_decode_firstbit_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => InWidth_g
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => log2ceil(InWidth_g),
        user_length => 1
	);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic := '0';
    signal In_Data      : std_logic_vector(InWidth_g-1 downto 0);
    signal In_Valid     : std_logic;
    signal Out_FirstBit : std_logic_vector(log2ceil(InWidth_g)-1 downto 0);
    signal Out_Found    : std_logic;
    signal Out_Valid    : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v : std_logic_vector(In_Data'range);
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

            -- Reset Values
            if run("ResetValues") then
                check_equal(Out_Valid, '0', "Out_Valid");
            end if;

            -- Test all inputs
            if run("AllInputs") then

                -- Test all bits
                for i in 0 to InWidth_g-1 loop
                    Data_v    := (others => '0');
                    Data_v(i) := '1';
                    push_axi_stream(net, AxisMaster_c, Data_v);
                    check_axi_stream(net, AxisSlave_c, toUslv(i, Out_FirstBit'length), tuser => "1", blocking => false, msg => "Data - " & integer'image(i));
                end loop;

            end if;

            -- Test Two bits set
            if run("TwoBits") then
                -- Next to each other
                Data_v    := (others => '0');
                Data_v(2) := '1';
                Data_v(3) := '1';
                push_axi_stream(net, AxisMaster_c, Data_v);
                check_axi_stream(net, AxisSlave_c, toUslv(2, Out_FirstBit'length), tuser => "1", blocking => false, msg => "Data - Next");
                -- Far apart
                Data_v                := (others => '0');
                Data_v(Data_v'high-1) := '1';
                Data_v(3)             := '1';
                push_axi_stream(net, AxisMaster_c, Data_v);
                check_axi_stream(net, AxisSlave_c, toUslv(3, Out_FirstBit'length), tuser => "1", blocking => false, msg => "Data - Far");
            end if;

            -- Test none set
            if run("NoneSet") then
                -- Next to each other
                Data_v := (others => '0');
                push_axi_stream(net, AxisMaster_c, Data_v);
                wait until rising_edge(Clk) and Out_Valid = '1';
                check_equal(Out_Found, '0', "Out_Found");
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
    i_dut : entity olo.olo_base_decode_firstbit
        generic map (
            InWidth_g => InWidth_g,
            InReg_g   => InReg_g,
            OutReg_g  => OutReg_g,
            PlRegs_g  => PlRegs_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            In_Data      => In_Data,
            In_Valid     => In_Valid,
            Out_FirstBit => Out_FirstBit,
            Out_Found    => Out_Found,
            Out_Valid    => Out_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            Aclk   => Clk,
            TValid => In_Valid,
            TData  => In_Data
        );

    vc_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            Aclk     => Clk,
            TValid   => Out_Valid,
            TData    => Out_FirstBit,
            TUser(0) => Out_Found
        );

end architecture;
