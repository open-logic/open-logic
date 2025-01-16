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
        runner_cfg     : string;
        CrcWidth_g     : positive := 16; -- allowed: 5, 8, 16
        DataWidth_g    : positive := 5  -- allowed: 5, 8, 16
    );
end entity;

architecture sim of olo_base_crc_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    function getPolynomial (crcWidth : natural) return std_logic_vector is
    begin
        case crcWidth is
            when 5  => return "10101";
            when 8  => return X"D5";
            when 16 => return X"0589";
            when others => report "Error: unuspoorted CrcWdith_g" severity error;
        end case;
    end function;
    constant InitialValue_c : std_logic_vector(CrcWidth_g-1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c        : time := 10 ns;

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

    procedure pushPacket(
        signal  net : inout network_t;
        beats       : natural := 1;
        useLast     : boolean := true;
        useFirst    : boolean := false) is
        -- constants
        constant Last_c  : std_logic                    := choose(useLast, '1', '0');
        constant First_c : std_logic_vector(0 downto 0) := choose(useFirst, "1", "0");
    begin
        case beats is
            when 1 =>
                push_axi_stream(net, AxisMaster_c, toUslv(16#13#, DataWidth_g), tuser => First_c, tlast => Last_c);
            when 2 => 
                push_axi_stream(net, AxisMaster_c, toUslv(16#13#, DataWidth_g), tuser => First_c, tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#06#, DataWidth_g), tuser => "0", tlast => Last_c);               
            when 3 =>
                push_axi_stream(net, AxisMaster_c, toUslv(16#11#, DataWidth_g), tuser => First_c, tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#12#, DataWidth_g), tuser => "0", tlast => '0');
                push_axi_stream(net, AxisMaster_c, toUslv(16#13#, DataWidth_g), tuser => "0", tlast => Last_c);
            when others => report "Error: Unsupported number of beats" severity error;
        end case;
    end procedure;

    function getResponse(beats       : natural := 1) return std_logic_vector is
        variable Crc_v : natural := 0;
    begin
        case CrcWidth_g is
            when 5  => 
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
            when 8  => 
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
        return toUslv(Crc_v, CrcWidth_g);
    end function;


    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic                                   := '0';
    signal Rst         : std_logic                                   := '1';
    signal In_Valid    : std_logic                                   := '0';
    signal In_Data     : std_logic_vector(DataWidth_g - 1 downto 0)  := (others => '0');
    signal In_Last     : std_logic                                   := '0';
    signal In_First    : std_logic                                   := '0';
    signal Out_Valid   : std_logic                                   := '0';
    signal Out_Crc     : std_logic_vector(CrcWidth_g - 1 downto 0)   := (others => '0');

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

            -- State after reset
            if run("Reset") then
                check_equal(Out_Valid, '0', "Out_Valid");
            end if;

            -- Single Word
            if run("Identity") then
                -- Data: 0x01
                push_axi_stream(net, AxisMaster_c, toUslv(1, DataWidth_g));
                check_axi_stream(net, AxisSlave_c, getPolynomial(CrcWidth_g), msg => "CRC");
            end if;

            if run("Test-SingleBeat") then
                pushPacket(net, beats => 1);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 1), msg => "CRC");
            end if;
            
            if run("Test-MultiBeat") then
                pushPacket(net, beats => 2);
                check_axi_stream(net, AxisSlave_c, getResponse(beats => 2), msg => "CRC");
            end if;

            if run("Test-MultiPacket-Last") then --3 packets: 2 beat, 1 beat, 3 beat
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
            
            if run("Test-16bit-AllInputBits") then
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
            CrcWidth_g     => CrcWidth_g,
            Polynomial_g   => getPolynomial(CrcWidth_g),
            InitialValue_g => InitialValue_c,
            DataWidth_g    => DataWidth_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => In_Data,
            In_Valid  => In_Valid,
            In_Last   => In_Last,
            In_First  => In_First,
            Out_Crc   => Out_Crc,
            Out_Valid => Out_Valid
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
            TData  => Out_Crc
        );

end architecture;
