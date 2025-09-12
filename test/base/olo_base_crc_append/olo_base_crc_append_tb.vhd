---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler, Switzerland
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
    use olo.olo_base_pkg_array.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_crc_append_tb is
    generic (
        runner_cfg      : string;
        CrcWidth_g      : positive := 16; -- allowed: 8, 16
        DataWidth_g     : positive := 16  -- allowed: 8, 16
    );
end entity;

architecture sim of olo_base_crc_append_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    function getPolynomial (crcWidth : natural) return std_logic_vector is
    begin

        -- Get polinomials from https://crccalc.com
        case crcWidth is
            when 8 => return x"D5";
            when 16 => return x"0589";
            when others => report "Error: unuspoorted CrcWdith_g" severity error;
        end case;

        return "X";

    end function;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c       : time := 10 ns;
    shared variable InDelay_v  : time := 0 ns;
    shared variable OutDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure inDelay is
    begin
        if InDelay_v > 0 ns then
            wait for InDelay_v;
        end if;
    end procedure;

    procedure outDelay is
    begin
        if OutDelay_v > 0 ns then
            wait for OutDelay_v;
        end if;
    end procedure;

    -- Data & CRCs for it
    constant Data8_c : StlvArray8_t(0 to 3) := (x"12", x"34", x"56", x"78");
    constant Crc8_c  : StlvArray8_t(1 to 4) := (x"2D", x"AE", x"AD", x"0B");

    constant Data16_c   : StlvArray16_t(0 to 3) := (x"0123", x"4567", x"89AB", x"CDEF");
    constant Crc8_16_c  : StlvArray16_t(1 to 4) := (x"0005", x"00D2", x"0082", x"007D");
    constant Crc16_16_c : StlvArray16_t(1 to 4) := (x"2516", x"8F0D", x"32F1", x"E83A");

    procedure pushPacket (
        signal  net : inout network_t;
        beats       : natural := 1) is
        -- local definitions
        variable Last_v : std_logic := '0';
    begin

        for i in 0 to beats-1 loop
            if i = beats-1 then
                Last_v := '1';
            end if;

            case DataWidth_g is
                when 8 => push_axi_stream(net, AxisMaster_c, Data8_c(i), tlast => Last_v);
                when 16 => push_axi_stream(net, AxisMaster_c, Data16_c(i), tlast => Last_v);
                when others => error("Illegal DataWidth_g: Must be 8 or 16");
            end case;

            inDelay;
        end loop;

    end procedure;

    procedure checkResponse (
        signal  net : inout network_t;
        beats       : natural := 1) is
    begin

        -- Data Section
        for i in 0 to beats-1 loop

            case DataWidth_g is
                when 8 => check_axi_stream(net, AxisSlave_c, Data8_c(i), msg => "Data[" & to_string(i) & "]", tlast => '0');
                when 16 => check_axi_stream(net, AxisSlave_c, Data16_c(i), msg => "Data[" & to_string(i) & "]", tlast => '0');
                when others => error("Illegal DataWidth_g: Must be 8 or 16");
            end case;

            outDelay;
        end loop;

        -- Check CRC
        case DataWidth_g is

            when 8 =>

                -- Only CRC8 allowed
                check_axi_stream(net, AxisSlave_c, Crc8_c(beats), msg => "CRC", tlast => '1');
                outDelay;

            when 16 =>

                case CrcWidth_g is
                    when 8 => check_axi_stream(net, AxisSlave_c, Crc8_16_c(beats), msg => "CRC", tlast => '1');
                    when 16 => check_axi_stream(net, AxisSlave_c, Crc16_16_c(beats), msg => "CRC", tlast => '1');
                    when others => error("Illegal CrcWidth_g: Must be 8 or 16");
                end case;

                outDelay;

            when others => report "Error: Unsupported DataWidth_g" severity error;
        end case;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                  := '0';
    signal Rst       : std_logic                                  := '1';
    signal In_Valid  : std_logic                                  := '0';
    signal In_Ready  : std_logic                                  := '1';
    signal In_Data   : std_logic_vector(DataWidth_g - 1 downto 0) := (others => '0');
    signal In_Last   : std_logic                                  := '0';
    signal Out_Valid : std_logic                                  := '0';
    signal Out_Ready : std_logic                                  := '1';
    signal Out_Data  : std_logic_vector(DataWidth_g - 1 downto 0) := (others => '0');
    signal Out_Last  : std_logic                                  := '0';

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
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for ClkPeriod_c;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- State after reset
            if run("Reset") then
                check_equal(Out_Valid, '0', "Out_Valid");
            end if;

            -- One packket with slwo data
            if run("1Pkt-2Beat-Slow") then
                InDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 2);
                checkResponse(net, 2);
            end if;

            -- One packket with fast data
            if run("1Pkt-3Beat-Fast") then
                pushPacket(net, 3);
                checkResponse(net, 3);
            end if;

            -- One packket with packpressure
            if run("1Pkt-4Beat-BackPress") then
                OutDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 4);
                checkResponse(net, 4);
            end if;

            -- Two packket with fast data
            if run("2Pkt-Fast") then
                pushPacket(net, 3);
                pushPacket(net, 4);
                checkResponse(net, 3);
                checkResponse(net, 4);
            end if;

            -- Two packket with fast data
            if run("2Pkt-BackPress") then
                OutDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 4);
                pushPacket(net, 3);
                checkResponse(net, 4);
                checkResponse(net, 3);
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
    i_dut : entity olo.olo_base_crc_append
        generic map (
            DataWidth_g        => DataWidth_g,
            CrcPolynomial_g    => getPolynomial(CrcWidth_g),
            CrcInitialValue_g  => "0",
            CrcBitOrder_g      => "MSB_FIRST",
            CrcByteOrder_g     => "NONE",
            CrcBitflipOutput_g => false,
            CrcXorOutput_g     => "0"
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Data    => In_Data,
            In_Valid   => In_Valid,
            In_Ready   => In_Ready,
            In_Last    => In_Last,
            Out_Data   => Out_Data,
            Out_Valid  => Out_Valid,
            Out_Ready  => Out_Ready,
            Out_Last   => Out_Last
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
            TData  => Out_Data,
            TLast  => Out_Last
        );

end architecture;
