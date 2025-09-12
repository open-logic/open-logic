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

-- single word packets

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_crc_check_tb is
    generic (
        runner_cfg      : string;
        Mode_g          : string   := "FLAG";
        CrcWidth_g      : positive := 16; -- allowed: 8, 16
        DataWidth_g     : positive := 16  -- allowed: 8, 16
    );
end entity;

architecture sim of olo_base_crc_check_tb is

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
    constant ClkPeriod_c       : time     := 10 ns;
    shared variable InDelay_v  : time     := 0 ns;
    shared variable OutDelay_v : time     := 0 ns;
    constant FifoDepth_c       : positive := 16;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0),
        user_length => 1
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
        beats       : natural := 1;
        error_word  : integer := -1) is
        -- Local Definitions
        variable XorMask_v : std_logic_vector(DataWidth_g-1 downto 0) := (others => '0');
    begin

        -- Data Section
        for i in 0 to beats-1 loop

            XorMask_v := (others => '0');
            if error_word = i then
                XorMask_v(0) := '1';
            end if;

            case DataWidth_g is
                when 8 => push_axi_stream(net, AxisMaster_c, Data8_c(i) xor XorMask_v, tlast => '0');
                when 16 => push_axi_stream(net, AxisMaster_c, Data16_c(i) xor XorMask_v, tlast => '0');
                when others => error("Illegal DataWidth_g: Must be 8 or 16");
            end case;

            inDelay;
        end loop;

        -- CRC
        XorMask_v := (others => '0');
        if error_word = beats then
            XorMask_v(0) := '1';
        end if;

        case DataWidth_g is

            when 8 =>

                -- Only CRC8 allowed
                push_axi_stream(net, AxisMaster_c, Crc8_c(beats) xor XorMask_v, tlast => '1');
                outDelay;

            when 16 =>

                case CrcWidth_g is
                    when 8 => push_axi_stream(net, AxisMaster_c, Crc8_16_c(beats) xor XorMask_v, tlast => '1');
                    when 16 => push_axi_stream(net, AxisMaster_c, Crc16_16_c(beats) xor XorMask_v, tlast => '1');
                    when others => error("Illegal CrcWidth_g: Must be 8 or 16");
                end case;

                outDelay;

            when others => report "Error: Unsupported DataWidth_g" severity error;
        end case;

    end procedure;

    procedure checkResponse (
        signal  net : inout network_t;
        beats       : natural := 1;
        error_word  : integer := -1) is
        -- local definitions
        variable Last_v     : std_logic                                := '0';
        variable CrcError_v : std_logic_vector(0 downto 0)             := "0";
        variable XorMask_v  : std_logic_vector(DataWidth_g-1 downto 0) := (others => '0');
    begin

        -- For DROP, errors are not even shown
        if error_word >= 0 then
            if Mode_g = "DROP" then
                return;
            end if;
        end if;

        -- Data Section
        for i in 0 to beats-1 loop

            if i = beats-1 then
                Last_v := '1';
            end if;

            if Last_v = '1' and Mode_g = "FLAG" and error_word >= 0 then
                CrcError_v := "1";
            end if;

            XorMask_v := (others => '0');
            if error_word = i then
                XorMask_v(0) := '1';
            end if;

            case DataWidth_g is
                when 8 => check_axi_stream(net, AxisSlave_c, Data8_c(i) xor XorMask_v,
                                           msg   => "Data[" & to_string(i) & "]",
                                           tuser => CrcError_v, tlast => Last_v);
                when 16 => check_axi_stream(net, AxisSlave_c, Data16_c(i) xor XorMask_v,
                                            msg   => "Data[" & to_string(i) & "]",
                                            tuser => CrcError_v, tlast => Last_v);
                when others => error("Illegal DataWidth_g: Must be 8 or 16");
            end case;

            outDelay;
        end loop;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                  := '0';
    signal Rst        : std_logic                                  := '1';
    signal In_Valid   : std_logic                                  := '0';
    signal In_Ready   : std_logic                                  := '1';
    signal In_Data    : std_logic_vector(DataWidth_g - 1 downto 0) := (others => '0');
    signal In_Last    : std_logic                                  := '0';
    signal Out_Valid  : std_logic                                  := '0';
    signal Out_Ready  : std_logic                                  := '1';
    signal Out_Data   : std_logic_vector(DataWidth_g - 1 downto 0) := (others => '0');
    signal Out_Last   : std_logic                                  := '0';
    signal Out_CrcErr : std_logic                                  := '0';

    -- TB Signals
    signal ErrorCounter : integer := 0;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable ErrorCounterStart_v : integer;
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

            -- *** Correct Cases ***

            -- State after reset
            if run("Reset") then
                check_equal(Out_Valid, '0', "Out_Valid");
                check_equal(ErrorCounter, 0);
            end if;

            -- One packet with slow data
            if run("1Pkt-2Beat-Slow") then
                InDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 2);
                checkResponse(net, 2);
                check_equal(ErrorCounter, 0);
            end if;

            -- One packket with fast data
            if run("1Pkt-3Beat-Fast") then
                pushPacket(net, 3);
                checkResponse(net, 3);
                check_equal(ErrorCounter, 0);
            end if;

            -- One packket with packpressure
            if run("1Pkt-4Beat-BackPress") then
                OutDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 4);
                checkResponse(net, 4);
                check_equal(ErrorCounter, 0);
            end if;

            -- Two packket with fast data
            if run("3Pkt-Fast") then
                pushPacket(net, 3);
                pushPacket(net, 4);
                pushPacket(net, 3);
                checkResponse(net, 3);
                checkResponse(net, 4);
                checkResponse(net, 3);
                check_equal(ErrorCounter, 0);
            end if;

            -- Two packket with Back Pressure
            if run("2Pkt-BackPress") then
                OutDelay_v := 3*ClkPeriod_c;
                pushPacket(net, 4);
                pushPacket(net, 3);
                checkResponse(net, 4);
                checkResponse(net, 3);
                check_equal(ErrorCounter, 0);
            end if;

            -- *** Error Cases ***

            -- Two packket with fast data, error in middle data
            if run("3Pkt-Fast-Error-Data") then

                for i in 0 to 3 loop
                    ErrorCounterStart_v := ErrorCounter;
                    pushPacket(net, 3);
                    pushPacket(net, 4, error_word => i);
                    pushPacket(net, 3);
                    checkResponse(net, 3);
                    checkResponse(net, 4, error_word => i);
                    checkResponse(net, 3);
                    check_equal(ErrorCounter, ErrorCounterStart_v+1);
                end loop;

            end if;

            -- Two packket with fast data, error in middle crc
            if run("3Pkt-Fast-Error-Crc") then
                ErrorCounterStart_v := ErrorCounter;
                pushPacket(net, 3);
                pushPacket(net, 4, error_word => 4);
                pushPacket(net, 3);
                checkResponse(net, 3);
                checkResponse(net, 4, error_word => 4);
                checkResponse(net, 3);
                check_equal(ErrorCounter, ErrorCounterStart_v+1);
            end if;

            -- Two packket with fast data, error in middle data
            if run("3Pkt-Backpressure-Error-Data") then
                OutDelay_v          := 10*ClkPeriod_c;
                ErrorCounterStart_v := ErrorCounter;

                -- Input Loop
                for i in 0 to 3 loop
                    pushPacket(net, 3);
                    pushPacket(net, 4, error_word => i);
                    pushPacket(net, 3);
                end loop;

                -- check loop
                for i in 0 to 3 loop
                    checkResponse(net, 3);
                    checkResponse(net, 4, error_word => i);
                    checkResponse(net, 3);
                end loop;

                check_equal(ErrorCounter, ErrorcounterStart_v+4);
            end if;

            -- Single Data Word Error in Data
            if run("3Pkt-Single-Error-Data") then
                ErrorCounterStart_v := ErrorCounter;
                pushPacket(net, 1);
                pushPacket(net, 1, error_word => 0);
                pushPacket(net, 1);
                checkResponse(net, 1);
                checkResponse(net, 1, error_word => 0);
                checkResponse(net, 1);
                check_equal(ErrorCounter, ErrorCounterStart_v+1);
            end if;

            if run("3Pkt-Single-Error-Crc") then
                ErrorCounterStart_v := ErrorCounter;
                pushPacket(net, 1);
                pushPacket(net, 1, error_word => 1);
                pushPacket(net, 1);
                checkResponse(net, 1);
                checkResponse(net, 1, error_word => 1);
                checkResponse(net, 1);
                check_equal(ErrorCounter, ErrorCounterStart_v+1);
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
    i_dut : entity olo.olo_base_crc_check
        generic map (
            DataWidth_g        => DataWidth_g,
            FifoDepth_g        => FifoDepth_c,
            Mode_g             => Mode_g,
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
            Out_Last   => Out_Last,
            Out_CrcErr => Out_CrcErr
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    p_count : process (Clk) is
        variable CrcErrLast_v : std_logic := '0';
    begin
        if rising_edge(Clk) then
            -- Single cycle errors for DROP
            if Mode_g = "DROP" and Out_CrcErr = '1' then
                ErrorCounter <= ErrorCounter + 1;
            end if;
            -- Might be longer for FLAG
            if Mode_g = "FLAG" and Out_CrcErr = '1'  and CrcErrLast_v = '0' then
                ErrorCounter <= ErrorCounter + 1;
            end if;

            CrcErrLast_v := Out_CrcErr;
        end if;
    end process;

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

    b_resp : block is
        signal Out_User : std_logic;
    begin
        Out_User <= Out_CrcErr when Mode_g = "FLAG" else '0';

        vc_response : entity vunit_lib.axi_stream_slave
            generic map (
                Slave => AxisSlave_c
            )
            port map (
                AClk     => Clk,
                TValid   => Out_Valid,
                TReady   => Out_Ready,
                TData    => Out_Data,
                TLast    => Out_Last,
                TUser(0) => Out_User
            );

    end block;

end architecture;
