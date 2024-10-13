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

library work;
    use work.olo_test_pkg_axi.all;
    use work.olo_test_axi_slave_pkg.all;
    use work.olo_test_axi_master_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_axi_pl_stage_tb is
    generic (
        IdWidth_g       : integer  := 0;
        AddrWidth_g     : integer  := 32;
        UserWidth_g     : integer  := 0;
        DataWidth_g     : integer  := 16;
        Stages_g        : positive := 2;
        runner_cfg      : string
    );
end entity;

architecture sim of olo_axi_pl_stage_tb is

    -----------------------------------------------------------------------------------------------
    -- AXI Definition
    -----------------------------------------------------------------------------------------------
    constant ByteWidth_c : integer := DataWidth_g/8;

    subtype IdRange_c   is natural range IdWidth_g-1 downto 0;
    subtype AddrRange_c is natural range AddrWidth_g-1 downto 0;
    subtype UserRange_c is natural range UserWidth_g-1 downto 0;
    subtype DataRange_c is natural range DataWidth_g-1 downto 0;
    subtype ByteRange_c is natural range ByteWidth_c-1 downto 0;

    signal AxiMs_M, AxiMs_S : AxiMs_r (ArId(IdRange_c), AwId(IdRange_c),
                                        ArAddr(AddrRange_c), AwAddr(AddrRange_c),
                                        ArUser(UserRange_c), AwUser(UserRange_c), WUser(UserRange_c),
                                        WData(DataRange_c),
                                        WStrb(ByteRange_c));

    signal AxiSm_M, AxiSm_S : AxiSm_r (RId(IdRange_c), BId(IdRange_c),
                                        RUser(UserRange_c), BUser(UserRange_c),
                                        RData(DataRange_c));

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
        data_width => DataWidth_g,
        addr_width => AddrWidth_g,
        id_width => IdWidth_g,
        user_width => UserWidth_g
    );

    constant AxiSlave_c : olo_test_axi_slave_t := new_olo_test_axi_slave (
        data_width => DataWidth_g,
        addr_width => AddrWidth_g,
        id_width => IdWidth_g,
        user_width => UserWidth_g
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

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

            if run("SingleWrite") then
                -- Master
                push_single_write(net, AxiMaster_c, X"12345678", X"ABCD");
                -- Slave
                expect_single_write(net, AxiSlave_c, X"12345678", X"ABCD");
            end if;

            -- Single Read
            if run("SingleRead") then
                -- Master
                expect_single_read(net, AxiMaster_c, X"AFFE0000", X"1234");
                -- Slave
                push_single_read(net, AxiSlave_c, X"AFFE0000", X"1234");
            end if;

            -- Read and write at the same time
            if run("ReadAndWrite") then
                -- Master
                push_single_write(net, AxiMaster_c, X"12345678", X"ABCD");
                expect_single_read(net, AxiMaster_c, X"AFFE0000", X"1234");
                -- Slave
                expect_single_write(net, AxiSlave_c, X"12345678", X"ABCD");
                push_single_read(net, AxiSlave_c, X"AFFE0000", X"1234");
            end if;

            -- Pipelined Write - AwReady driven
            if run("PipelinedWrites-aw_ready_delay") then
                -- Blocked Aw-Ready
                push_single_write(net, AxiMaster_c, X"00000001", X"0001");
                expect_single_write(net, AxiSlave_c, X"00000001", X"0001", aw_ready_delay => 200 ns);

                -- Do a sane number of transactions
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, AxiMaster_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, AxiSlave_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;

            end if;

            -- Pipelined Write - WReady driven
            if run("PipelinedWrites-w_ready_delay") then
                -- Blocked Aw-Ready
                push_single_write(net, AxiMaster_c, X"00000001", X"0001");
                expect_single_write(net, AxiSlave_c, X"00000001", X"0001", w_ready_delay => 200 ns);

                -- Do a sane number of transactions
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, AxiMaster_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, AxiSlave_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;

            end if;

            -- Pipelined Write - BReady driven
            if run("PipelinedWrites-b_ready_delay") then
                -- Blocked Aw-Ready
                push_single_write(net, AxiMaster_c, X"00000001", X"0001", b_ready_delay => 200 ns);
                expect_single_write(net, AxiSlave_c, X"00000001", X"0001");

                -- Do a sane number of transactions
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, AxiMaster_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, AxiSlave_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;

            end if;

            -- Pipelined Read - ArReady driven
            if run("PipelinedRead-ar_ready_delay") then
                -- Blocked Ar-Ready
                expect_single_read(net, AxiMaster_c, X"00000001", X"0001");
                push_single_read(net, AxiSlave_c, X"00000001", X"0001", ar_ready_delay => 200 ns);

                -- Do a sane number of transactions
                for i in 1 to Stages_g*3 loop
                    expect_single_read(net, AxiMaster_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    push_single_read(net, AxiSlave_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;

            end if;

            -- Pipelined Read - RReady driven
            if run("PipelinedRead-r_ready_delay") then
                -- Blocked Ar-Ready
                expect_single_read(net, AxiMaster_c, X"00000001", X"0001", r_ready_delay => 200 ns);
                push_single_read(net, AxiSlave_c, X"00000001", X"0001");

                -- Do a sane number of transactions
                for i in 1 to Stages_g*3 loop
                    expect_single_read(net, AxiMaster_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    push_single_read(net, AxiSlave_c, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;

            end if;

            -- Burst Write
            if run("BurstWrite") then
                -- Master
                push_burst_write_aligned(net, AxiMaster_c, X"12345678", X"ABCD", 1, 16);
                -- Slave
                expect_burst_write_aligned(net, AxiSlave_c, X"12345678", X"ABCD", 1, 16);
            end if;

            -- Burst Read
            if run("BurstRead") then
                -- Master
                expect_burst_read_aligned(net, AxiMaster_c, X"AFFE0000", X"1234", 1, 16);
                -- Slave
                push_burst_read_aligned(net, AxiSlave_c, X"AFFE0000", X"1234", 1, 16);
            end if;

            -- Wait for idle
            wait_until_idle(net, as_sync(AxiMaster_c));
            wait_until_idle(net, as_sync(AxiSlave_c));
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
    i_dut : entity olo.olo_axi_pl_stage
        generic map (
            AddrWidth_g     => AddrWidth_g,
            DataWidth_g     => DataWidth_g,
            IdWidth_g       => IdWidth_g,
            UserWidth_g     => UserWidth_g,
            Stages_g        => Stages_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            -- Slave Interface
            -- write address channel
            S_AwId      => AxiMs_M.AwId,
            S_AwAddr    => AxiMs_M.AwAddr,
            S_AwValid   => AxiMs_M.AwValid,
            S_AwReady   => AxiSm_M.AwReady,
            S_AwLen     => AxiMs_M.AwLen,
            S_AwSize    => AxiMs_M.AwSize,
            S_AwBurst   => AxiMs_M.AwBurst,
            S_AwLock    => AxiMs_M.AwLock,
            S_AwCache   => AxiMs_M.AwCache,
            S_AwProt    => AxiMs_M.AwProt,
            S_AwQos     => AxiMs_M.AwQos,
            S_AwUser    => AxiMs_M.AwUser,
            -- write data channel
            S_WData     => AxiMs_M.WData,
            S_WStrb     => AxiMs_M.WStrb,
            S_WValid    => AxiMs_M.WValid,
            S_WReady    => AxiSm_M.WReady,
            S_WLast     => AxiMs_M.WLast,
            S_WUser     => AxiMs_M.WUser,
            -- write response channel
            S_BId       => AxiSm_M.BId,
            S_BResp     => AxiSm_M.BResp,
            S_BValid    => AxiSm_M.BValid,
            S_BReady    => AxiMs_M.BReady,
            S_BUser     => AxiSm_M.BUser,
            -- read address channel
            S_ArId      => AxiMs_M.ArId,
            S_ArAddr    => AxiMs_M.ArAddr,
            S_ArValid   => AxiMs_M.ArValid,
            S_ArReady   => AxiSm_M.ArReady,
            S_ArLen     => AxiMs_M.ArLen,
            S_ArSize    => AxiMs_M.ArSize,
            S_ArBurst   => AxiMs_M.ArBurst,
            S_ArLock    => AxiMs_M.ArLock,
            S_ArCache   => AxiMs_M.ArCache,
            S_ArProt    => AxiMs_M.ArProt,
            S_ArQos     => AxiMs_M.ArQos,
            S_ArUser    => AxiMs_M.ArUser,
            -- read data channel
            S_RId       => AxiSm_M.RId,
            S_RData     => AxiSm_M.RData,
            S_RValid    => AxiSm_M.RValid,
            S_RReady    => AxiMs_M.RReady,
            S_RResp     => AxiSm_M.RResp,
            S_RLast     => AxiSm_M.RLast,
            S_RUser     => AxiSm_M.RUser,
            -- Master Interface
            -- write address channel
            M_AwId      => AxiMs_S.AwId,
            M_AwAddr    => AxiMs_S.AwAddr,
            M_AwValid   => AxiMs_S.AwValid,
            M_AwReady   => AxiSm_S.AwReady,
            M_AwLen     => AxiMs_S.AwLen,
            M_AwSize    => AxiMs_S.AwSize,
            M_AwBurst   => AxiMs_S.AwBurst,
            M_AwLock    => AxiMs_S.AwLock,
            M_AwCache   => AxiMs_S.AwCache,
            M_AwProt    => AxiMs_S.AwProt,
            M_AwQos     => AxiMs_S.AwQos,
            M_AwUser    => AxiMs_S.AwUser,
            -- write data channel
            M_WData     => AxiMs_S.WData,
            M_WStrb     => AxiMs_S.WStrb,
            M_WValid    => AxiMs_S.WValid,
            M_WReady    => AxiSm_S.WReady,
            M_WLast     => AxiMs_S.WLast,
            M_WUser     => AxiMs_S.WUser,
            -- write response channel
            M_BId       => AxiSm_S.BId,
            M_BResp     => AxiSm_S.BResp,
            M_BValid    => AxiSm_S.BValid,
            M_BReady    => AxiMs_S.BReady,
            M_BUser     => AxiSm_S.BUser,
            -- read address channel
            M_ArId      => AxiMs_S.ArId,
            M_ArAddr    => AxiMs_S.ArAddr,
            M_ArValid   => AxiMs_S.ArValid,
            M_ArReady   => AxiSm_S.ArReady,
            M_ArLen     => AxiMs_S.ArLen,
            M_ArSize    => AxiMs_S.ArSize,
            M_ArBurst   => AxiMs_S.ArBurst,
            M_ArLock    => AxiMs_S.ArLock,
            M_ArCache   => AxiMs_S.ArCache,
            M_ArProt    => AxiMs_S.ArProt,
            M_ArQos     => AxiMs_S.ArQos,
            M_ArUser    => AxiMs_S.ArUser,
            -- read data channel
            M_RId       => AxiSm_S.RId,
            M_RData     => AxiSm_S.RData,
            M_RValid    => AxiSm_S.RValid,
            M_RReady    => AxiMs_S.RReady,
            M_RResp     => AxiSm_S.RResp,
            M_RLast     => AxiSm_S.RLast,
            M_RUser     => AxiSm_S.RUser
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_master : entity work.olo_test_axi_master_vc
        generic map (
            Instance => AxiMaster_c
        )
        port map (
            Clk    => Clk,
            Rst    => Rst,
            Axi_Ms => AxiMs_M,
            Axi_Sm => AxiSm_M
        );

    vc_slave : entity work.olo_test_axi_slave_vc
        generic map (
            Instance => AxiSlave_c
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            Axi_Ms => AxiMs_S,
            Axi_Sm => AxiSm_S
        );

end architecture;
