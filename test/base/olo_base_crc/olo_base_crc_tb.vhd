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
entity olo_base_crc_tb is
    generic (
        runner_cfg      : string;
        BitOrder_g      : string   := "MSB_FIRST";
        ByteOrder_g     : string   := "NONE";
        CrcWidth_g      : positive := 8; -- allowed: 5, 8, 16
        DataWidth_g     : positive := 8; -- allowed: 5, 8, 16
        BitflipOutput_g : boolean  := false;
        InvertOutput_g  : boolean  := false
    );
end entity;

architecture sim of olo_base_crc_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant XorOutput_c : std_logic_vector(CrcWidth_g-1 downto 0) := toSslv(choose(InvertOutput_g, -1, 0), CrcWidth_g); -- all 1 or all 0

    function getPolynomial (crcWidth : natural) return std_logic_vector is
    begin

        -- Get polinomials from https://crccalc.com
        case crcWidth is
            when 5 => return "10101";
            when 8 => return x"D5";
            when 16 => return x"0589";
            when others => report "Error: unuspoorted CrcWdith_g" severity error;
        end case;

    end function;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c      : time := 10 ns;
    shared variable InDelay_v : time := 0 ns;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_g,
        user_length => 1,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => CrcWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -- Reorder data according to BitOrder_g and ByteOrder_g
    function reorderData (data : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(DataWidth_g-1 downto 0);
    begin
        Result_v := toUslv(data, DataWidth_g);

        if BitOrder_g = "LSB_FIRST" then
            if ByteOrder_g = "MSB_FIRST" then
                assert DataWidth_g mod 8 = 0
                    report "Error: ByteOrder_g only supported for DataWidth = N*8"
                    severity error;

                -- Reorder bytewise
                for byte in 0 to (DataWidth_g/8)-1 loop
                    Result_v(byte*8+7 downto byte*8) := invertBitOrder(Result_v(byte*8+7 downto byte*8));
                end loop;

            else
                -- reorder all bits
                Result_v := invertBitOrder(Result_v);
            end if;

        elsif BitOrder_g = "MSB_FIRST" then
            if ByteOrder_g = "LSB_FIRST" then
                Result_v := invertByteOrder(Result_v);
            end if;

        else
            report "Error: Unsupported BitOrder_g" severity error;
        end if;

        return Result_v;
    end function;

    procedure inDelay is
    begin
        if InDelay_v > 0 ns then
            wait for InDelay_v;
        end if;
    end procedure;

    procedure pushPacket (
        signal  net : inout network_t;
        beats       : natural := 1;
        useLast     : boolean := true;
        useFirst    : boolean := false) is
        -- constants
        constant Last_c  : std_logic                    := choose(useLast, '1', '0');
        constant First_c : std_logic_vector(0 downto 0) := choose(useFirst, "1", "0");
    begin

        -- Push packets (data for 1-3 beats is defined);
        inDelay;

        case beats is
            when 1 =>
                push_axi_stream(net, AxisMaster_c, reorderData(16#13#), tuser => First_c, tlast => Last_c);
            when 2 =>
                push_axi_stream(net, AxisMaster_c, reorderData(16#13#), tuser => First_c, tlast => '0');
                inDelay;
                push_axi_stream(net, AxisMaster_c, reorderData(16#06#), tuser => "0", tlast => Last_c);
            when 3 =>
                push_axi_stream(net, AxisMaster_c, reorderData(16#11#), tuser => First_c, tlast => '0');
                inDelay;
                push_axi_stream(net, AxisMaster_c, reorderData(16#12#), tuser => "0", tlast => '0');
                inDelay;
                push_axi_stream(net, AxisMaster_c, reorderData(16#13#), tuser => "0", tlast => Last_c);
            when others => report "Error: Unsupported number of beats" severity error;
        end case;

    end procedure;

    function getResponse (beats       : natural := 1) return std_logic_vector is
        variable Crc_v      : natural := 0;
        variable CrcStdlv_v : std_logic_vector(CrcWidth_g-1 downto 0);
    begin

        -- Responses per CRC
        case CrcWidth_g is
            when 5 =>

                -- CRC5 responses per datawidth
                case DataWidth_g is
                    when 5 =>

                        -- Responses calculated with excel attached
                        case beats is
                            when 1 => Crc_v := 16#13#;
                            when 2 => Crc_v := 16#07#;
                            when 3 => Crc_v := 16#16#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 8 =>

                        -- Responses calculated with excel attached
                        case beats is
                            when 1 => Crc_v := 16#13#;
                            when 2 => Crc_v := 16#07#;
                            when 3 => Crc_v := 16#15#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 16 =>

                        -- Responses calculated with excel attached
                        case beats is
                            when 1 => Crc_v := 16#13#;
                            when 2 => Crc_v := 16#07#;
                            when 3 => Crc_v := 16#1A#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when others => report "Error: Unsupported DataWidth_g/CrcWidth_g combination" severity error;
                end case;

            when 8 =>

                -- CRC8 responses per datawidth
                case DataWidth_g is
                    when 5 =>

                        -- Responses calculated with excel attached
                        case beats is
                            when 1 => Crc_v := 16#F8#;
                            when 2 => Crc_v := 16#AE#;
                            when 3 => Crc_v := 16#E0#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 8 =>

                        -- Responses calculated with https://crccalc.com
                        case beats is
                            when 1 => Crc_v := 16#F8#;
                            when 2 => Crc_v := 16#2C#;
                            when 3 => Crc_v := 16#C4#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 16 =>

                        -- Responses calculated with https://crccalc.com
                        case beats is
                            when 1 => Crc_v := 16#F8#;
                            when 2 => Crc_v := 16#C8#;
                            when 3 => Crc_v := 16#67#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when others => report "Error: Unsupported DataWidth_g/CrcWidth_g combination" severity error;
                end case;

            when 16 =>

                -- CRC16 responses per datawidth
                case DataWidth_g is
                    when 5 =>

                        -- Responses calculated with excel attached
                        case beats is
                            when 1 => Crc_v := 16#560B#;
                            when 2 => Crc_v := 16#FB0C#;
                            when 3 => Crc_v := 16#67E1#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 8 =>

                        -- Responses calculated with https://crccalc.com
                        case beats is
                            when 1 => Crc_v := 16#560B#;
                            when 2 => Crc_v := 16#3459#;
                            when 3 => Crc_v := 16#2898#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when 16 =>

                        -- Responses calculated with https://crccalc.com
                        case beats is
                            when 1 => Crc_v := 16#560B#;
                            when 2 => Crc_v := 16#EAD7#;
                            when 3 => Crc_v := 16#B7DF#;
                            when others => report "Error: Unsupported number of beats" severity error;
                        end case;

                    when others => report "Error: Unsupported DataWidth_g/CrcWidth_g combination" severity error;
                end case;

            when others => report "Error: Unsupported CrcWidth_g" severity error;
        end case;

        CrcStdlv_v := toUslv(Crc_v, CrcWidth_g);
        if BitflipOutput_g then
            CrcStdlv_v := invertBitOrder(CrcStdlv_v);
        end if;
        if InvertOutput_g then
            CrcStdlv_v := not CrcStdlv_v;
        end if;
        return CrcStdlv_v;
    end function;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                  := '0';
    signal Rst       : std_logic                                  := '1';
    signal In_Valid  : std_logic                                  := '0';
    signal In_Ready  : std_logic                                  := '1';
    signal In_Data   : std_logic_vector(DataWidth_g - 1 downto 0) := (others => '0');
    signal In_Last   : std_logic                                  := '0';
    signal In_First  : std_logic                                  := '0';
    signal Out_Valid : std_logic                                  := '0';
    signal Out_Ready : std_logic                                  := '1';
    signal Out_Crc   : std_logic_vector(CrcWidth_g - 1 downto 0)  := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v   : std_logic_vector(DataWidth_g-1 downto 0);
        variable Result_v : std_logic_vector(CrcWidth_g-1 downto 0);
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

            -- State after reset
            if run("Reset") then
                check_equal(Out_Valid, '0', "Out_Valid");
            end if;

            -- Single Word
            if run("Identity") then
                -- Set the bit that is shifted into the CRC last
                Data_v := (others => '0');
                if BitOrder_g = "MSB_FIRST" then
                    if ByteOrder_g = "LSB_FIRST" then
                        Data_v(DataWidth_g-8) := '1';
                    else
                        Data_v(0) := '1';
                    end if;
                else
                    if ByteOrder_g = "MSB_FIRST" then
                        Data_v(7) := '1';
                    else
                        Data_v(DataWidth_g-1) := '1';
                    end if;
                end if;
                push_axi_stream(net, AxisMaster_c, Data_v);
                Result_v := getPolynomial(CrcWidth_g);
                if BitflipOutput_g then
                    Result_v := invertBitOrder(Result_v);
                end if;
                if InvertOutput_g then
                    Result_v := not Result_v;
                end if;
                check_axi_stream(net, AxisSlave_c, Result_v, msg => "CRC");
            end if;

            if run("Test-SingleBeat") then
                pushPacket(net, beats => 1);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "CRC");
            end if;

            if run("Test-MultiBeat") then
                pushPacket(net, beats => 2);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "CRC");
            end if;

            if run("Test-MultiPacket-Last") then
                -- Packet 0 (2 beats)
                pushPacket(net, beats => 2, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "Pkt0");
                -- Packet 1 (1 beat)
                pushPacket(net, beats => 1, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "Pkt1");
                -- Packet 2 (3 beats)
                pushPacket(net, beats => 3, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 3),  msg => "Pkt2");
            end if;

            if run("Test-MultiPacket-First") then
                -- Packet 0 (2 beats)
                pushPacket(net, beats => 2, useLast => false, useFirst => true);
                wait_until_idle(net, as_sync(AxisMaster_c));
                check_equal(getResponse(beats => 2), Out_Crc, "Pkt0");
                -- Packet 1 (1 beat)
                pushPacket(net, beats => 1, useLast => false, useFirst => true);
                wait_until_idle(net, as_sync(AxisMaster_c));
                check_equal(getResponse(beats => 1), Out_Crc, "Pkt1");
                -- Packet 2 (3 beats)
                pushPacket(net, beats => 3, useLast => false, useFirst => true);
                wait_until_idle(net, as_sync(AxisMaster_c));
                check_equal(getResponse(beats => 3), Out_Crc, "Pkt2");
            end if;

            if run("Test-MultiPacket-FirstAndLast") then
                -- Packet 0 (2 beats)
                pushPacket(net, beats => 2, useLast => true, useFirst => true);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "Pkt0");
                -- Packet 1 (1 beat)
                pushPacket(net, beats => 1, useLast => true, useFirst => true);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "Pkt1");
                -- Packet 2 (3 beats)
                pushPacket(net, beats => 3, useLast => true, useFirst => true);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 3),  msg => "Pkt2");
            end if;

            if run("Test-Backpressure") then
                -- Queue 3 packets for input
                pushPacket(net, beats => 2, useLast => true, useFirst => false);
                pushPacket(net, beats => 1, useLast => true, useFirst => false);
                pushPacket(net, beats => 3, useLast => true, useFirst => false);

                -- Check 3 packets with delay
                wait for 1 us;
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "Pkt0");
                wait for 1 us;
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "Pkt1");
                wait for 1 us;
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 3),  msg => "Pkt2");
            end if;

            if run("Test-InDelay") then
                InDelay_v := 100 ns;

                -- Packet 0 (2 beats)
                pushPacket(net, beats => 2, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "Pkt0");
                -- Packet 1 (1 beat)
                pushPacket(net, beats => 1, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "Pkt1");
                -- Packet 2 (3 beats)
                pushPacket(net, beats => 3, useLast => true, useFirst => false);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 3),  msg => "Pkt2");
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
            Polynomial_g    => getPolynomial(CrcWidth_g),
            DataWidth_g     => DataWidth_g,
            BitOrder_g      => BitOrder_g,
            ByteOrder_g     => ByteOrder_g,
            BitflipOutput_g => BitflipOutput_g,
            XorOutput_g     => XorOutput_c
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
