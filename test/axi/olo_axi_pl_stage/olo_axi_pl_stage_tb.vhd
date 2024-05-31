------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
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

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_axi_pl_stage_tb is
    generic (
        IdWidth_g       : integer := 0;
        AddrWidth_g     : integer := 32;
        UserWidth_g     : integer := 0;
        DataWidth_g     : integer := 16;
        Stages_g        : positive := 2;
        runner_cfg      : string  
    );
end entity olo_axi_pl_stage_tb;

architecture sim of olo_axi_pl_stage_tb is
    -------------------------------------------------------------------------
    -- AXI Definition
    -------------------------------------------------------------------------
    constant ByteWidth_c     : integer   := DataWidth_g/8;
    
    subtype IdRange_r   is natural range IdWidth_g-1 downto 0;
    subtype AddrRange_r is natural range AddrWidth_g-1 downto 0;
    subtype UserRange_r is natural range UserWidth_g-1 downto 0;
    subtype DataRange_r is natural range DataWidth_g-1 downto 0;
    subtype ByteRange_r is natural range ByteWidth_c-1 downto 0;
    
    signal AxiMs_m, AxiMs_s : AxiMs_r ( ArId(IdRange_r), AwId(IdRange_r),
                                        ArAddr(AddrRange_r), AwAddr(AddrRange_r),
                                        ArUser(UserRange_r), AwUser(UserRange_r), WUser(UserRange_r),
                                        WData(DataRange_r),
                                        WStrb(ByteRange_r));
    
    signal AxiSm_m, AxiSm_s : AxiSm_r ( RId(IdRange_r), BId(IdRange_r),
                                        RUser(UserRange_r), BUser(UserRange_r),
                                        RData(DataRange_r));

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------    

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;
    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant axiMaster : olo_test_axi_master_t := new_olo_test_axi_master (
        dataWidth => DataWidth_g,
        addrWidth => AddrWidth_g,
        idWidth => IdWidth_g,
        userWidth => UserWidth_g
    );

    constant axiSlave : olo_test_axi_slave_t := new_olo_test_axi_slave (
        dataWidth => DataWidth_g,
        addrWidth => AddrWidth_g,
        idWidth => IdWidth_g,
        userWidth => UserWidth_g
    );

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
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
                push_single_write(net, axiMaster, X"12345678", X"ABCD");
                -- Slave
                expect_single_write(net, axiSlave, X"12345678", X"ABCD");
            end if;

            -- Single Read
            if run("SingleRead") then
                -- Master
                expect_single_read(net, axiMaster, X"AFFE0000", X"1234");
                -- Slave
                push_single_read(net, axiSlave, X"AFFE0000", X"1234");
            end if;

            -- Read and write at the same time
            if run("ReadAndWrite") then
                -- Master
                push_single_write(net, axiMaster, X"12345678", X"ABCD");
                expect_single_read(net, axiMaster, X"AFFE0000", X"1234");
                -- Slave
                expect_single_write(net, axiSlave, X"12345678", X"ABCD");
                push_single_read(net, axiSlave, X"AFFE0000", X"1234");
            end if;           

            -- Pipelined Write - AwReady driven
            if run("PipelinedWrites-AwReadyDelay") then
                -- Blocked Aw-Ready
                push_single_write(net, axiMaster, X"00000001", X"0001");
                expect_single_write(net, axiSlave, X"00000001", X"0001", AwReadyDelay => 200 ns);
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, axiMaster, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, axiSlave, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;
            end if;

            -- Pipelined Write - WReady driven
            if run("PipelinedWrites-WReadyDelay") then
                -- Blocked Aw-Ready
                push_single_write(net, axiMaster, X"00000001", X"0001");
                expect_single_write(net, axiSlave, X"00000001", X"0001", WReadyDelay => 200 ns);
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, axiMaster, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, axiSlave, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;
            end if;    
            
            -- Pipelined Write - BReady driven
            if run("PipelinedWrites-BReadyDelay") then
                -- Blocked Aw-Ready
                push_single_write(net, axiMaster, X"00000001", X"0001", BReadyDelay => 200 ns);
                expect_single_write(net, axiSlave, X"00000001", X"0001");
                for i in 1 to Stages_g*3 loop
                    push_single_write(net, axiMaster, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    expect_single_write(net, axiSlave, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;
            end if; 

            -- Pipelined Read - ArReady driven
            if run("PipelinedRead-ArReadyDelay") then
                -- Blocked Ar-Ready
                expect_single_read(net, axiMaster, X"00000001", X"0001");
                push_single_read(net, axiSlave, X"00000001", X"0001", ArReadyDelay => 200 ns);
                for i in 1 to Stages_g*3 loop
                    expect_single_read(net, axiMaster, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    push_single_read(net, axiSlave, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;
            end if;

            -- Pipelined Read - RReady driven
            if run("PipelinedRead-RReadyDelay") then
                -- Blocked Ar-Ready
                expect_single_read(net, axiMaster, X"00000001", X"0001", RReadyDelay => 200 ns);
                push_single_read(net, axiSlave, X"00000001", X"0001");
                for i in 1 to Stages_g*3 loop
                    expect_single_read(net, axiMaster, to_unsigned(256*i, 32), to_unsigned(i, 16));
                    push_single_read(net, axiSlave, to_unsigned(256*i, 32), to_unsigned(i, 16));
                end loop;
            end if;

            -- Burst Write
            if run("BurstWrite") then
                -- Master
                push_burst_write_aligned(net, axiMaster, X"12345678", X"ABCD", 1, 16);
                -- Slave
                expect_burst_write_aligned(net, axiSlave, X"12345678", X"ABCD", 1, 16);
            end if;

            -- Burst Read
            if run("BurstRead") then
                -- Master
                expect_burst_read_aligned(net, axiMaster, X"AFFE0000", X"1234", 1, 16);
                -- Slave
                push_burst_read_aligned(net, axiSlave, X"AFFE0000", X"1234", 1, 16);
            end if;
                    
            -- Wait for idle
            wait_until_idle(net, as_sync(axiMaster));
            wait_until_idle(net, as_sync(axiSlave));
            wait for 1 us;

        end loop;
        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;


    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
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
            S_AwId     => AxiMs_m.AwId,
            S_AwAddr   => AxiMs_m.AwAddr,
            S_AwValid  => AxiMs_m.AwValid,
            S_AwReady  => AxiSm_m.AwReady,
            S_AwLen    => AxiMs_m.AwLen,
            S_AwSize   => AxiMs_m.AwSize,
            S_AwBurst  => AxiMs_m.AwBurst,
            S_AwLock   => AxiMs_m.AwLock,
            S_AwCache  => AxiMs_m.AwCache,
            S_AwProt   => AxiMs_m.AwProt,
            S_AwQos    => AxiMs_m.AwQos,
            S_AwUser   => AxiMs_m.AwUser,
            -- write data channel
            S_WData    => AxiMs_m.WData,
            S_WStrb    => AxiMs_m.WStrb,
            S_WValid   => AxiMs_m.WValid,
            S_WReady   => AxiSm_m.WReady,
            S_WLast    => AxiMs_m.WLast,
            S_WUser    => AxiMs_m.WUser,
            -- write response channel
            S_BId      => AxiSm_m.BId,
            S_BResp    => AxiSm_m.BResp,
            S_BValid   => AxiSm_m.BValid,
            S_BReady   => AxiMs_m.BReady,
            S_BUser    => AxiSm_m.BUser,
            -- read address channel
            S_ArId     => AxiMs_m.ArId,
            S_ArAddr   => AxiMs_m.ArAddr,
            S_ArValid  => AxiMs_m.ArValid,
            S_ArReady  => AxiSm_m.ArReady,
            S_ArLen    => AxiMs_m.ArLen,
            S_ArSize   => AxiMs_m.ArSize,
            S_ArBurst  => AxiMs_m.ArBurst,
            S_ArLock   => AxiMs_m.ArLock,
            S_ArCache  => AxiMs_m.ArCache,
            S_ArProt   => AxiMs_m.ArProt,
            S_ArQos    => AxiMs_m.ArQos,
            S_ArUser   => AxiMs_m.ArUser,
            -- read data channel
            S_RId      => AxiSm_m.RId,
            S_RData    => AxiSm_m.RData,
            S_RValid   => AxiSm_m.RValid,
            S_RReady   => AxiMs_m.RReady,
            S_RResp    => AxiSm_m.RResp,
            S_RLast    => AxiSm_m.RLast,
            S_RUser    => AxiSm_m.RUser,
            -- Master Interface
            -- write address channel
            M_AwId     => AxiMs_s.AwId,
            M_AwAddr   => AxiMs_s.AwAddr,
            M_AwValid  => AxiMs_s.AwValid,
            M_AwReady  => AxiSm_s.AwReady,
            M_AwLen    => AxiMs_s.AwLen,
            M_AwSize   => AxiMs_s.AwSize,
            M_AwBurst  => AxiMs_s.AwBurst,
            M_AwLock   => AxiMs_s.AwLock,
            M_AwCache  => AxiMs_s.AwCache,
            M_AwProt   => AxiMs_s.AwProt,
            M_AwQos    => AxiMs_s.AwQos,
            M_AwUser   => AxiMs_s.AwUser,
            -- write data channel
            M_WData    => AxiMs_s.WData,
            M_WStrb    => AxiMs_s.WStrb,
            M_WValid   => AxiMs_s.WValid,
            M_WReady   => AxiSm_s.WReady,
            M_WLast    => AxiMs_s.WLast,
            M_WUser    => AxiMs_s.WUser,
            -- write response channel
            M_BId      => AxiSm_s.BId,
            M_BResp    => AxiSm_s.BResp,
            M_BValid   => AxiSm_s.BValid,
            M_BReady   => AxiMs_s.BReady,
            M_BUser    => AxiSm_s.BUser,
            -- read address channel
            M_ArId     => AxiMs_s.ArId,
            M_ArAddr   => AxiMs_s.ArAddr,
            M_ArValid  => AxiMs_s.ArValid,
            M_ArReady  => AxiSm_s.ArReady,
            M_ArLen    => AxiMs_s.ArLen,
            M_ArSize   => AxiMs_s.ArSize,
            M_ArBurst  => AxiMs_s.ArBurst,
            M_ArLock   => AxiMs_s.ArLock,
            M_ArCache  => AxiMs_s.ArCache,
            M_ArProt   => AxiMs_s.ArProt,
            M_ArQos    => AxiMs_s.ArQos,
            M_ArUser   => AxiMs_s.ArUser,
            -- read data channel
            M_RId      => AxiSm_s.RId,
            M_RData    => AxiSm_s.RData,
            M_RValid   => AxiSm_s.RValid,
            M_RReady   => AxiMs_s.RReady,
            M_RResp    => AxiSm_s.RResp,
            M_RLast    => AxiSm_s.RLast,
            M_RUser    => AxiSm_s.RUser
    );

    ------------------------------------------------------------
    -- Verification Components
    ------------------------------------------------------------
    vc_master : entity work.olo_test_axi_master_vc
        generic map (
            instance => axiMaster
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            AxiMs => AxiMs_m,
            AxiSm => AxiSm_m
        );

    vc_slave : entity work.olo_test_axi_slave_vc
        generic map (
            instance => axiSlave
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            AxiMs => AxiMs_s,
            AxiSm => AxiSm_s
        );


end sim;
