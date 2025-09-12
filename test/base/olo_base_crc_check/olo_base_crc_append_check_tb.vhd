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

library osvvm;
    use osvvm.RandomPkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_crc_append_check_tb is
    generic (
        runner_cfg      : string;
        CheckMode_g     : string := "DROP"
    );
end entity;

architecture sim of olo_base_crc_append_check_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c     : positive                      := 16;
    constant CrcPolynomial_c : std_logic_vector(15 downto 0) := x"0589";
    constant FifoDepth_c     : positive                      := 16;
    constant RandomPackets_c : positive                      := 50;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time := 10 ns;
    shared variable Random_v : RandomPType;

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.25, 0, 6)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.5, 0, 6),
        user_length => 1
    );
    constant Bitflip_c    : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    procedure testPacket (
        signal  net : inout network_t;
        beats       : natural := 1;
        pktNum      : natural := 0;
        crcError    : boolean := false) is
        -- Local Definitions
        constant Zero16_c : std_logic_vector(DataWidth_c-1 downto 0) := (others => '0');
        variable Data_v   : std_logic_vector(DataWidth_c-1 downto 0) := (others => '0');
        variable TLast_v  : std_logic                                := '0';
        variable Flag_v   : std_logic_vector(0 downto 0)             := "0";
    begin

        -- Data
        for i in 0 to beats-1 loop
            Data_v(DataWidth_c-1 downto 8) := std_logic_vector(to_unsigned(pktNum, 8));
            Data_v(7 downto 0)             := std_logic_vector(to_unsigned(i, 8));
            TLast_v                        := choose(i = beats-1, '1', '0');
            -- Sender
            push_axi_stream(net, AxisMaster_c, Data_v, tlast => TLast_v);
            -- Data section is never corrupted
            push_axi_stream(net, Bitflip_c, Zero16_c);
            -- Receiver
            if not (crcError) or (CheckMode_g /= "DROP") then
                if i = beats-1 and crcError then
                    Flag_v := "1";
                end if;
                check_axi_stream(net, AxisSlave_c, Data_v,
                                tlast => TLast_v, tuser => Flag_v, blocking => false,
                                msg   => "Pkt[" & to_string(pktNum) & "] Data[" & to_string(i) & "]");
            end if;
        end loop;

        -- CRC flip if required
        if crcError then
            push_axi_stream(net, Bitflip_c, not Zero16_c);
        else
            push_axi_stream(net, Bitflip_c, Zero16_c);
        end if;

    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                  := '0';
    signal Rst        : std_logic                                  := '1';
    signal In_Valid   : std_logic                                  := '0';
    signal In_Ready   : std_logic                                  := '1';
    signal In_Data    : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal In_Last    : std_logic                                  := '0';
    signal Chnl_Valid : std_logic                                  := '0';
    signal Chnl_Ready : std_logic                                  := '1';
    signal Chnl_Data  : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal Chnl_Last  : std_logic                                  := '0';
    signal Out_Valid  : std_logic                                  := '0';
    signal Out_Ready  : std_logic                                  := '1';
    signal Out_Data   : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal Out_Last   : std_logic                                  := '0';
    signal Out_CrcErr : std_logic                                  := '0';

    -- Channel Signals
    signal ChnlBeat : std_logic                                  := '0';
    signal ChnlData : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');
    signal ChnlFlip : std_logic_vector(DataWidth_c - 1 downto 0) := (others => '0');

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
            wait for ClkPeriod_c;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- One packet with slow data
            if run("no-error-x5") then

                -- loop over 5 packets
                for i in 0 to 4 loop
                    testPacket(net, 4, i, false);
                end loop;

            end if;

            -- Two packets with errors
            if run("two-errors") then
                testPacket(net, 4, 0, false);
                testPacket(net, 4, 1, true);
                testPacket(net, 4, 2, true);
                testPacket(net, 4, 3, false);
            end if;

            -- Randomized packets
            if run("random-packets") then

                -- loop over packets
                for pkt in 0 to RandomPackets_c-1 loop
                    testPacket(net, Random_v.RandInt(1, 10), pkt, Random_v.RandInt(0, 4) < 2);
                end loop;

            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(Bitflip_c));
            wait_until_idle(net, as_sync(AxisSlave_c));
            wait for 1 us;

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
    i_dut_append : entity olo.olo_base_crc_append
        generic map (
            DataWidth_g        => DataWidth_c,
            CrcPolynomial_g    => CrcPolynomial_c
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Data    => In_Data,
            In_Valid   => In_Valid,
            In_Ready   => In_Ready,
            In_Last    => In_Last,
            Out_Data   => Chnl_Data,
            Out_Valid  => Chnl_Valid,
            Out_Ready  => Chnl_Ready,
            Out_Last   => Chnl_Last
        );

    i_dut : entity olo.olo_base_crc_check
        generic map (
            DataWidth_g        => DataWidth_c,
            FifoDepth_g        => FifoDepth_c,
            Mode_g             => CheckMode_g,
            CrcPolynomial_g    => CrcPolynomial_c
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Data    => ChnlData,
            In_Valid   => Chnl_Valid,
            In_Ready   => Chnl_Ready,
            In_Last    => Chnl_Last,
            Out_Data   => Out_Data,
            Out_Valid  => Out_Valid,
            Out_Ready  => Out_Ready,
            Out_Last   => Out_Last,
            Out_CrcErr => Out_CrcErr
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

    -- Error Injection
    ChnlData <= Chnl_Data xor ChnlFlip;
    ChnlBeat <= Chnl_Valid and Chnl_Ready;

    vc_bitflip : entity vunit_lib.axi_stream_master
        generic map (
            Master => Bitflip_c
        )
        port map (
            AClk      => Clk,
            TValid    => open,
            TReady    => ChnlBeat,
            TData     => ChnlFlip
        );

    b_resp : block is
        signal Out_User : std_logic;
    begin
        Out_User <= Out_CrcErr when CheckMode_g = "FLAG" else '0';

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
