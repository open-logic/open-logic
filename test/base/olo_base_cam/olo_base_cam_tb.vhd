---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024-2025 by Oliver Bruendler, Switzerland
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
entity olo_base_cam_tb is
    generic (
        Addresses_g             : positive range 8 to 1024 := 8;
        ContentWidth_g          : positive range 10 to 256 := 10;
        RamBehavior_g           : string                   := "RBW";
        RamBlockDepth_g         : positive                 := 512; -- 9 addr bits
        ClearAfterReset_g       : boolean                  := true;
        ReadPriority_g          : boolean                  := false;
        StrictOrdering_g        : boolean                  := false;
        UseAddrOut_g            : boolean                  := true;
        RegisterInput_g         : boolean                  := true;
        RegisterMatch_g         : boolean                  := true;
        FirstBitDecLatency_g    : natural                  := 1;
        runner_cfg              : string
    );
end entity;

architecture sim of olo_base_cam_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    -- *** Verification Compnents ***
    constant RdMaster_c   : axi_stream_master_t := new_axi_stream_master (
        data_length => ContentWidth_g
    );
    constant MatchSlave_c : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => Addresses_g
    );
    constant AddrSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => log2ceil(Addresses_g),
        user_length => 1
    );

    -- Range Definitions
    subtype WrAddr_c    is natural range log2ceil(Addresses_g)-1 downto 0;
    subtype WrContent_c is natural range WrAddr_c'left+ContentWidth_g downto WrAddr_c'left+1;
    constant WrWrite_c          : natural := WrContent_c'left+1;
    constant WrClear_c          : natural := WrWrite_c+1;
    constant WrClearAll_c       : natural := WrClear_c+1;
    constant ConfigInStrWidth_c : natural := WrClearAll_c+1;

    constant WrMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => ConfigInStrWidth_c
    );

    -- *** Procedures ***
    procedure pushConfigIn (
        signal net : inout network_t;
        Content    : integer := 0;
        Addr       : integer := 0;
        Write      : boolean := false;
        Clear      : boolean := false;
        ClearAll   : boolean := false;
        Blocking   : boolean := false) is
        variable Data_v : std_logic_vector(ConfigInStrWidth_c - 1 downto 0);
    begin
        Data_v(WrAddr_c)     := toUslv(Addr, log2ceil(Addresses_g));
        Data_v(WrContent_c)  := toUslv(Content, ContentWidth_g);
        Data_v(WrWrite_c)    := choose(Write, '1', '0');
        Data_v(WrClear_c)    := choose(Clear, '1', '0');
        Data_v(WrClearAll_c) := choose(ClearAll, '1', '0');
        push_axi_stream(net, WrMaster_c, Data_v);
        if Blocking then
            wait_until_idle(net, as_sync(WrMaster_c));
        end if;
    end procedure;

    procedure readCam (
        signal net : inout network_t;
        Content    : integer;
        Addr       : integer          := 0;
        Found      : boolean          := true;
        Blocking   : boolean          := false;
        OneHot     : std_logic_vector := "X";
        Msg        : string           := "") is
        variable Addr_v       : std_logic_vector(log2ceil(Addresses_g)-1 downto 0) := (others => '0');
        variable AddrOneHot_v : std_logic_vector(Addresses_g-1 downto 0)           := (others => '0');
        variable Found_v      : std_logic_vector(0 downto 0)                       := "0";
    begin
        if Found then
            -- Normally only one bit is set
            if OneHot = "X" then
                AddrOneHot_v(Addr) := '1';
            -- But the user can check for a specific patter
            else
                AddrOneHot_v(OneHot'range) := OneHot;
            end if;
            Addr_v  := toUslv(Addr, log2ceil(Addresses_g));
            Found_v := "1";
        end if;
        push_axi_stream(net, RdMaster_c, toUslv(Content, ContentWidth_g));
        check_axi_stream(net, MatchSlave_c, AddrOneHot_v, blocking => false, msg => "one hot - " & Msg);
        if UseAddrOut_g then
            check_axi_stream(net, AddrSlave_c, Addr_v, tuser => Found_v, blocking => false, msg => "addr - " & Msg);
        end if;
        if Blocking then
            wait_until_idle(net, as_sync(RdMaster_c));
            wait_until_idle(net, as_sync(MatchSlave_c));
            wait_until_idle(net, as_sync(AddrSlave_c));
        end if;
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk         : std_logic := '0';
    signal Rst         : std_logic := '0';
    signal Rd_Valid    : std_logic := '1';
    signal Rd_Ready    : std_logic;
    signal Rd_Content  : std_logic_vector(ContentWidth_g-1 downto 0);
    signal Wr_Valid    : std_logic;
    signal Wr_Ready    : std_logic;
    signal Wr_Content  : std_logic_vector(ContentWidth_g-1 downto 0);
    signal Wr_Addr     : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
    signal Wr_Write    : std_logic;
    signal Wr_Clear    : std_logic;
    signal Wr_ClearAll : std_logic;
    signal Match_Valid : std_logic;
    signal Match_Match : std_logic_vector(Addresses_g-1 downto 0);
    signal Addr_Valid  : std_logic;
    signal Addr_Found  : std_logic;
    signal Addr_Addr   : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable OneHot_v : std_logic_vector(Addresses_g-1 downto 0);
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
            if ClearAfterReset_g then
                wait until rising_edge(Clk) and Rd_Ready = '1' and Wr_Ready = '1';
            end if;

            -- Reset Values
            if run("ResetValues") then
                -- first cycle after reset
                Rst <= '1';
                wait until rising_edge(Clk);
                check_equal(Rd_Ready, '0', "Rd_Ready first");
                check_equal(Wr_Ready, '0', "Wr_Ready first");
                check_equal(Match_Valid, '0', "Match_Valid first");
                check_equal(Addr_Valid, '0', "Addr_Valid first");
                Rst <= '0';
                -- wait until reset done
                if ClearAfterReset_g then

                    -- check signal levels during reset
                    for i in 0 to RamBlockDepth_g-1 loop
                        wait until rising_edge(Clk);
                        check_equal(Rd_Ready, '0', "Rd_Ready clearing");
                        check_equal(Wr_Ready, '0', "Wr_Ready clearing");
                        check_equal(Match_Valid, '0', "Match_Valid clearing");
                        check_equal(Addr_Valid, '0', "Addr_Valid clearing");
                    end loop;

                    wait until rising_edge(Clk);
                else
                    wait until rising_edge(Clk);
                end if;
                check_equal(Rd_Ready, '1', "Rd_Ready second");
                check_equal(Wr_Ready, '1', "Wr_Ready second");
                check_equal(Match_Valid, '0', "Match_Valid second");
                check_equal(Addr_Valid, '0', "Addr_Valid second");
            end if;

            -- Basic Tests
            if run("ReadEmptyCam") then
                readCam(net, Content => 0, Found => false);
                readCam(net, Content => 5, Found => false);
            end if;

            if run("SingleEntry") then
                -- Configure
                pushConfigIn(net, Content => 16#12#, Addr => 16#3#, Write => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#12#, Addr => 16#3#, Msg => "found");
                readCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "not found");
                -- Clear
                pushConfigIn(net, Content => 16#12#, Addr => 16#3#, Clear => true);
                wait for 3*ClkPeriod_c;
                readCam(net, Content => 16#12#, Found => false, Msg => "cleared");
            end if;

            if run("TwoEntries-SingleRead") then
                -- configure
                pushConfigIn(net, Content => 16#12#, Addr => 16#3#, Write => true);
                pushConfigIn(net, Content => 16#35#, Addr => 16#4#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#35#, Addr => 16#4#, Blocking => true, Msg => "found 1");
                wait for 100 ns;
                wait until rising_edge(Clk);
                readCam(net, Content => 16#12#, Addr => 16#3#, Blocking => true, Msg => "found 2");
                wait for 100 ns;
                wait until rising_edge(Clk);
                readCam(net, Content => 16#13#, Found => false, Msg => "not found");
                -- Clear
                pushConfigIn(net, Content => 16#12#, Addr => 16#3#, Clear => true);
                pushConfigIn(net, Content => 16#35#, Addr => 16#4#, Clear => true);
            end if;

            if run("TwoEntries-ConsecutiveRead") then
                -- configure
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#36#, Addr => 16#05#, Write => true, Blocking => true);
                -- Read
                readCam(net, Content => 16#36#, Addr => 16#05#, Msg => "read 1");
                readCam(net, Content => 16#13#, Addr => 16#04#, Msg => "read 2");
                readCam(net, Content => 16#10#, Found => false, Msg => "read 3");
                readCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "read 4");
                -- Clear
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                pushConfigIn(net, Content => 16#36#, Addr => 16#05#, Clear => true);
            end if;

            if run("Write-NoCommand") then
                -- configure
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#36#, Addr => 16#05#, Write => true);
                pushConfigIn(net, Content => 16#13#, Addr => 16#33#); -- Check not cleared, not written
                pushConfigIn(net, Content => 16#22#, Addr => 16#33#, Blocking => true); -- Check not written
                -- Read
                readCam(net, Content => 16#13#, Addr => 16#04#, Msg => "rnot overwritten or cleared");
                readCam(net, Content => 16#22#, Found => false, Msg => "not written", Blocking => true);
                -- Clear
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                pushConfigIn(net, Content => 16#36#, Addr => 16#05#, Clear => true);
            end if;

            if run("Read-Write-Priority") then

                -- Initialize CAM
                for i in 0 to 3 loop
                    pushConfigIn(net, Content => 8+i, Addr => 2*i, Write => true, Blocking => true);
                end loop;

                wait for 3*ClkPeriod_c;

                -- Queue up reads and writes
                for i in 0 to 3 loop
                    pushConfigIn(net, Content => i, Addr => 4+i, Write => true);
                    readCam(net, Content => 8+i, Addr => i*2, Found => true);
                end loop;

                wait until rising_edge(Clk) and Rd_Valid = '1' and Wr_Valid = '1';
                -- Wait for priorizied access to complete and check if the other access is still executing
                if ReadPriority_g then
                    wait until rising_edge(Clk) and Rd_Valid = '0';
                    check_equal(Wr_Valid, '1', "Write not still executing");
                elsif StrictOrdering_g and RamBehavior_g = "RBW" then
                    wait until rising_edge(Clk) and Wr_Valid = '0';
                    check_equal(Rd_Valid, '1', "Read not still executing");
                else
                -- With non-strict ordering reads can be executed interleaved
                end if;
                wait_until_idle(net, as_sync(RdMaster_c));
                wait_until_idle(net, as_sync(MatchSlave_c));
                wait_until_idle(net, as_sync(AddrSlave_c));
                wait_until_idle(net, as_sync(WrMaster_c));

                -- Cleanup
                for i in 0 to 3 loop
                    pushConfigIn(net, Content => i, Addr => 4+i, Clear => true);
                end loop;

            end if;

            if run("StrictOrdering") then
                -- Produce Read immediately after write
                wait until rising_edge(Clk);
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                wait until rising_edge(Clk);
                if StrictOrdering_g or RamBehavior_g = "WBR" then
                    -- In this case the data is already written
                    readCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "written");
                else
                    -- In this case the data is not yet written
                    readCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "not written");
                end if;
                -- Produce Read immediately after clear
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                wait until rising_edge(Clk);
                if StrictOrdering_g or RamBehavior_g = "WBR" then
                    -- In this case the data is already cleared
                    readCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "cleared");
                else
                    -- In this case the data is not yet cleared
                    readCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "not cleared");
                end if;
            end if;

            if run("ClearTwice") then
                -- Configure
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                -- Clear Once
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                readCam(net, Content => 16#13#, Found => false);
                readCam(net, Content => 16#14#, Addr => 16#05#, Blocking => true);
                -- Clear Twice
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                readCam(net, Content => 16#13#, Found => false);
                readCam(net, Content => 16#14#, Addr => 16#05#, Blocking => true);
                -- Cleanup
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            if run("SameContent-TwoAddresses") then
                -- Configure
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                pushConfigIn(net, Content => 16#13#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#14#, Addr => 16#05#, Msg => "Single Entry 1");
                OneHot_v := (4 => '1',
                             6 => '1',
                             others => '0');
                readCam(net, Content => 16#13#, Addr => 16#04#, OneHot => OneHot_v, Blocking => true, Msg => "First entry for double address");
                -- Clear one entry
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 2");
                readCam(net, Content => 16#13#, Addr => 16#06#, Blocking => true, Msg => "Second entry for double address");
                -- Clear second entry
                pushConfigIn(net, Content => 16#13#, Addr => 16#06#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 3");
                readCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "Both deleted");
                -- Clear second entry
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            if run("ClearAll") then
                -- Configure
                pushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                pushConfigIn(net, Content => 16#13#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- ClearAll
                pushConfigIn(net, Content => 16#13#, ClearAll => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                readCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 2");
                readCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "Both deleted");
                -- Clear single entry
                pushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            if run("ClearAfterReset") then
                -- Configure
                pushConfigIn(net, Content => 16#000#, Addr => 16#04#, Write => true);
                pushConfigIn(net, Content => 16#100#, Addr => 16#05#, Write => true);
                pushConfigIn(net, Content => 16#082#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- ClearAll
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                Rst <= '0';
                -- Read
                if ClearAfterReset_g then
                    -- All data cleared
                    readCam(net, Content => 16#000#, Found => false, Msg => "Deleted 1");
                    readCam(net, Content => 16#100#, Found => false, Msg => "Deleted 2");
                    readCam(net, Content => 16#082#, Found => false, Blocking => true, Msg => "Deleted 3");
                else
                    -- Data not cleared
                    readCam(net, Content => 16#000#, Addr => 16#04#, Msg => "Found 1");
                    readCam(net, Content => 16#100#, Addr => 16#05#, Msg => "Found 2");
                    readCam(net, Content => 16#082#, Addr => 16#06#, Blocking => true, Msg => "Found 3");
                end if;
            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(RdMaster_c));
            wait_until_idle(net, as_sync(MatchSlave_c));
            wait_until_idle(net, as_sync(AddrSlave_c));
            wait_until_idle(net, as_sync(WrMaster_c));

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
    i_dut : entity olo.olo_base_cam
        generic map (
            Addresses_g             => Addresses_g,
            ContentWidth_g          => ContentWidth_g,
            RamBlockDepth_g         => RamBlockDepth_g,
            ClearAfterReset_g       => ClearAfterReset_g,
            ReadPriority_g          => ReadPriority_g,
            StrictOrdering_g        => StrictOrdering_g,
            RegisterInput_g         => RegisterInput_g,
            RegisterMatch_g         => RegisterMatch_g,
            FirstBitDecLatency_g    => FirstBitDecLatency_g,
            RamBehavior_g           => RamBehavior_g
        )
        port map (
            Clk              => Clk,
            Rst              => Rst,
            Rd_Valid         => Rd_Valid,
            Rd_Ready         => Rd_Ready,
            Rd_Content       => Rd_Content,
            Wr_Valid         => Wr_Valid,
            Wr_Ready         => Wr_Ready,
            Wr_Content       => Wr_Content,
            Wr_Addr          => Wr_Addr,
            Wr_Write         => Wr_Write,
            Wr_Clear         => Wr_Clear,
            Wr_ClearAll      => Wr_ClearAll,
            Match_Valid      => Match_Valid,
            Match_Match      => Match_Match,
            Addr_Valid       => Addr_Valid,
            Addr_Found       => Addr_Found,
            Addr_Addr        => Addr_Addr
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_camin : entity vunit_lib.axi_stream_master
        generic map (
            Master => RdMaster_c
        )
        port map (
            Aclk   => Clk,
            TValid => Rd_Valid,
            TReady => Rd_Ready,
            TData  => Rd_Content
        );

    vc_camout_onehot : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => MatchSlave_c
        )
        port map (
            Aclk   => Clk,
            TValid => Match_Valid,
            TData  => Match_Match
        );

    vc_camout_addr : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AddrSlave_c
        )
        port map (
            Aclk        => Clk,
            TValid      => Addr_Valid,
            TData       => Addr_Addr,
            TUser(0)    => Addr_Found
        );

    b_coonfigin : block is
        signal Data : std_logic_vector(ConfigInStrWidth_c-1 downto 0);
    begin

        vc_configin : entity vunit_lib.axi_stream_master
            generic map (
                Master => WrMaster_c
            )
            port map (
                Aclk   => Clk,
                TValid => Wr_Valid,
                TReady => Wr_Ready,
                TData  => Data
            );

        Wr_Addr     <= Data(WrAddr_c);
        Wr_Content  <= Data(WrContent_c);
        Wr_Write    <= Data(WrWrite_c);
        Wr_Clear    <= Data(WrClear_c);
        Wr_ClearAll <= Data(WrClearAll_c);

    end block;

end architecture;
