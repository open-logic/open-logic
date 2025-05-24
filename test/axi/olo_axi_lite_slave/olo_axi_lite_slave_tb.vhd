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
    use olo.olo_axi_pkg_protocol.all;

library work;
    use work.olo_test_pkg_axi.all;
    use work.olo_test_axi_master_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_axi_lite_slave_tb is
    generic (
        AxiAddrWidth_g      : positive                          := 32;
        AxiDataWidth_g      : positive range 8 to positive'high := 16;
        runner_cfg          : string
    );
end entity;

architecture sim of olo_axi_lite_slave_tb is

    -----------------------------------------------------------------------------------------------
    -- AXI Definition
    -----------------------------------------------------------------------------------------------
    constant IdWidth_c   : integer := 0;
    constant AddrWidth_c : integer := AxiAddrWidth_g;
    constant UserWidth_c : integer := 0;
    constant DataWidth_c : integer := AxiDataWidth_g;
    constant ByteWidth_c : integer := DataWidth_c/8;

    subtype IdRange_c   is natural range IdWidth_c-1 downto 0;
    subtype AddrRange_c is natural range AddrWidth_c-1 downto 0;
    subtype UserRange_c is natural range UserWidth_c-1 downto 0;
    subtype DataRange_c is natural range DataWidth_c-1 downto 0;
    subtype ByteRange_c is natural range ByteWidth_c-1 downto 0;

    signal AxiMs : axi_ms_t (ar_id(IdRange_c), aw_id(IdRange_c),
                              ar_addr(AddrRange_c), aw_addr(AddrRange_c),
                              ar_user(UserRange_c), aw_user(UserRange_c), w_user(UserRange_c),
                              w_data(DataRange_c),
                              w_strb(ByteRange_c));

    signal AxiSm : axi_sm_t (r_id(IdRange_c), b_id(IdRange_c),
                              r_user(UserRange_c), b_user(UserRange_c),
                              r_data(DataRange_c));

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;
    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant AxiMaster_c : olo_test_axi_master_t := new_olo_test_axi_master (
        data_width => DataWidth_c,
        addr_width => AddrWidth_c,
        id_width => IdWidth_c
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    -- Control
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

    -- Register Interface
    signal Rb_Addr    : std_logic_vector(AxiAddrWidth_g - 1 downto 0);
    signal Rb_Wr      : std_logic;
    signal Rb_ByteEna : std_logic_vector((AxiDataWidth_g/8) - 1 downto 0);
    signal Rb_WrData  : std_logic_vector(AxiDataWidth_g - 1 downto 0);
    signal Rb_Rd      : std_logic;
    signal Rb_RdData  : std_logic_vector(AxiDataWidth_g - 1 downto 0);
    signal Rb_RdValid : std_logic := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Addr_v : unsigned(AxiAddrWidth_g - 1 downto 0);
        variable Data_v : unsigned(AxiDataWidth_g - 1 downto 0);
        variable Strb_v : std_logic_vector((AxiDataWidth_g/8) - 1 downto 0);
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

            -- check register reset values
            if run("RstValues") then
                check_equal(Rb_Wr, '0', "Reg_Wr reset value failed");
                check_equal(Rb_Rd, '0', "Reg_Rd reset value failed");
            end if;

            -- Single write to registers
            if run("SingleWrite") then
                push_single_write(net, AxiMaster_c, to_unsigned(32, AddrWidth_c), X"1D");
                -- Check write on RB side
                wait until rising_edge(Clk) and Rb_Wr = '1';
                check_equal(Rb_Addr, 32, "Rb_Addr wrong");
                check_equal(Rb_WrData, 16#1D#, "Rb_WrData wrong");
                check_equal(Rb_ByteEna, onesVector(Rb_ByteEna'length), "Rb_ByteEna wrong");
                -- Check de-assertion or Write
                wait until rising_edge(Clk);
                check_equal(Rb_Wr, '0', "Rb_Wr not de-asserted");
            end if;

            -- Single read from registers
            if run("SingleReads") then
                Rb_RdData <= (others => '0');

                -- Loop through different read delays
                for rdDel in 0 to 3 loop
                    -- Values for iteration
                    Addr_v := to_unsigned(64*4*rdDel, AddrWidth_c);
                    Data_v := to_unsigned(1+rdDel, AxiDataWidth_g);
                    -- Operate VC
                    expect_single_read(net, AxiMaster_c, Addr_v, Data_v);
                    -- Check read on RB side
                    wait until rising_edge(Clk) and Rb_Rd = '1';
                    check_equal(Rb_Addr, Addr_v, "Rb_Addr wrong, rdDel = " & integer'image(rdDel));

                    -- Delay
                    for i in 0 to rdDel loop
                        wait until rising_edge(Clk);
                        check_equal(Rb_Rd, '0', "Rb_Rd not de-asserted, rdDel = " & integer'image(rdDel));
                    end loop;

                    Rb_RdData  <= std_logic_vector(Data_v);
                    Rb_RdValid <= '1';
                    wait until rising_edge(Clk);
                    check_equal(Rb_Rd, '0', "Rb_Rd not de-asserted, rdDel = " & integer'image(rdDel));
                    Rb_RdValid <= '0';
                    Rb_RdData  <= (others => '0');
                end loop;

            end if;

            -- Write strobes
            if run("WriteStrobes") then

                -- Loop through bytes
                for byteIdx in 0 to (AxiDataWidth_g/8)-1 loop
                    -- Values for iteration
                    Strb_v          := (others => '0');
                    Strb_v(byteIdx) := '1';
                    -- Operate VC
                    push_single_write(net, AxiMaster_c, to_unsigned(128, AddrWidth_c), X"1D", strb => Strb_v);
                    -- Check write on RB side
                    wait until rising_edge(Clk) and Rb_Wr = '1';
                    check_equal(Rb_Addr, 128, "Rb_Addr wrong");
                    check_equal(Rb_WrData, 16#1D#, "Rb_WrData wrong");
                    check_equal(Rb_ByteEna, Strb_v, "Rb_ByteEna wrong");
                    -- Check de-assertion or Write
                    wait until rising_edge(Clk);
                    check_equal(Rb_Wr, '0', "Rb_Wr not de-asserted");
                end loop;

            end if;

            -- Read timeout
            if run("ReadTimeout") then
                -- Operate VC
                push_ar(net, AxiMaster_c, addr => to_unsigned(16, AddrWidth_c));
                expect_r(net, AxiMaster_c, X"0", resp => AxiResp_SlvErr_c, ignore_data => true);
            end if;

            -- Write Timing
            if run("WriteTiming") then
                push_single_write(net, AxiMaster_c, to_unsigned(32, AddrWidth_c), X"D0", b_ready_delay => 100 ns);
                push_single_write(net, AxiMaster_c, to_unsigned(64, AddrWidth_c), X"D4", w_valid_delay => 100 ns);
                -- Check write on RB side [0]
                wait until rising_edge(Clk) and Rb_Wr = '1';
                check_equal(Rb_Addr, 32, "Rb_Addr wrong");
                check_equal(Rb_WrData, 16#D0#, "Rb_WrData wrong");
                check_equal(Rb_ByteEna, onesVector(Rb_ByteEna'length), "Rb_ByteEna wrong");
                -- Check de-assertion or Write
                wait until rising_edge(Clk);
                check_equal(Rb_Wr, '0', "Rb_Wr not de-asserted");
                -- Check write on RB side [1]
                wait until rising_edge(Clk) and Rb_Wr = '1';
                check_equal(Rb_Addr, 64, "Rb_Addr wrong");
                check_equal(Rb_WrData, 16#D4#, "Rb_WrData wrong");
                check_equal(Rb_ByteEna, onesVector(Rb_ByteEna'length), "Rb_ByteEna wrong");
                -- Check de-assertion or Write
                wait until rising_edge(Clk);
                check_equal(Rb_Wr, '0', "Rb_Wr not de-asserted");
            end if;

            -- Read Timing
            if run("ReadTiming") then
                Rb_RdData <= (others => '0');
                -- Operate VC
                expect_single_read(net, AxiMaster_c, X"A0", X"01", r_ready_delay => 100 ns);
                expect_single_read(net, AxiMaster_c, X"B0", X"02");
                -- Check read on RB side [0]
                wait until rising_edge(Clk) and Rb_Rd = '1';
                check_equal(Rb_Addr, 16#A0#, "Rb_Addr wrong [0]");
                Rb_RdData  <= toUslv(16#01#, AxiDataWidth_g);
                Rb_RdValid <= '1';
                wait until rising_edge(Clk);
                check_equal(Rb_Rd, '0', "Rb_Rd not de-asserted [0]");
                Rb_RdValid <= '0';
                Rb_RdData  <= (others => '0');
                -- Check read on RB side [1]
                wait until rising_edge(Clk) and Rb_Rd = '1';
                check_equal(Rb_Addr, 16#B0#, "Rb_Addr wrong [1]");
                Rb_RdData  <= toUslv(16#02#, AxiDataWidth_g);
                Rb_RdValid <= '1';
                wait until rising_edge(Clk);
                check_equal(Rb_Rd, '0', "Rb_Rd not de-asserted [1]");
                Rb_RdValid <= '0';
                Rb_RdData  <= (others => '0');
            end if;

            -- Address MAsking
            if run("AddressMasking") then
                push_single_write(net, AxiMaster_c, X"8F", X"AB");
                -- Check write on RB side
                wait until rising_edge(Clk) and Rb_Wr = '1';

                -- Select width
                case AxiDataWidth_g is
                    when 8 => check_equal(Rb_Addr, 16#8F#, "Rb_Addr wrong 8");
                    when 16 => check_equal(Rb_Addr, 16#8E#, "Rb_Addr wrong 16");
                    when 32 => check_equal(Rb_Addr, 16#8C#, "Rb_Addr wrong 32");
                    when 64 => check_equal(Rb_Addr, 16#88#, "Rb_Addr wrong 64");
                    when 128 => check_equal(Rb_Addr, 16#80#, "Rb_Addr wrong 128");
                    when others => check(false, "Illegal AxiDataWidth_g (must be btween 8 and 128)");
                end case;

                check_equal(Rb_WrData, 16#AB#, "Rb_WrData wrong");
                check_equal(Rb_ByteEna, onesVector(Rb_ByteEna'length), "Rb_ByteEna wrong");
                -- Check de-assertion or Write
                wait until rising_edge(Clk);
                check_equal(Rb_Wr, '0', "Rb_Wr not de-asserted");
            end if;

            -- Wait for idle
            wait_until_idle(net, as_sync(AxiMaster_c));
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
    i_dut : entity olo.olo_axi_lite_slave
        generic map (
            AxiAddrWidth_g      => AxiAddrWidth_g,
            AxiDataWidth_g      => AxiDataWidth_g
        )
        port map (
            -- System
            Clk                 => Clk,
            Rst                 => Rst,
            -- Read address channel
            S_AxiLite_ArAddr    => AxiMs.ar_addr,
            S_AxiLite_ArValid   => AxiMs.ar_valid,
            S_AxiLite_ArReady   => AxiSm.ar_ready,
            -- Read data channel
            S_AxiLite_RData     => AxiSm.r_data,
            S_AxiLite_RResp     => AxiSm.r_resp,
            S_AxiLite_RValid    => AxiSm.r_valid,
            S_AxiLite_RReady    => AxiMs.r_ready,
            -- Write address channel
            S_AxiLite_AwAddr    => AxiMs.aw_addr,
            S_AxiLite_AwValid   => AxiMs.aw_valid,
            S_AxiLite_AwReady   => AxiSm.aw_ready,
            -- Write data channel
            S_AxiLite_WData     => AxiMs.w_data,
            S_AxiLite_WStrb     => AxiMs.w_strb,
            S_AxiLite_WValid    => AxiMs.w_valid,
            S_AxiLite_WReady    => AxiSm.w_ready,
            -- Write response channel
            S_AxiLite_BResp     => AxiSm.b_resp,
            S_AxiLite_BValid    => AxiSm.b_valid,
            S_AxiLite_BReady    => AxiMs.b_ready,
            -- Register Interface
            Rb_Addr             => Rb_Addr,
            Rb_Wr               => Rb_Wr,
            Rb_ByteEna          => Rb_ByteEna,
            Rb_WrData           => Rb_WrData,
            Rb_Rd               => Rb_Rd,
            Rb_RdData           => Rb_RdData,
            Rb_RdValid          => Rb_RdValid
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity work.olo_test_axi_lite_master_vc
        generic map (
            Instance => AxiMaster_c
        )
        port map (
            Clk    => Clk,
            Axi_Ms => AxiMs,
            Axi_Sm => AxiSm
        );

end architecture;
