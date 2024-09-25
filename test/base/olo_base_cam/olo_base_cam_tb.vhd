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

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cam_tb is
    generic (
        Addresses_g             : positive range 8 to 16    := 8;
        ContentWidth_g          : positive range 10 to 256  := 10;
        RamBehavior_g           : string                    := "RBW";
        RamBlockWidth_g         : positive                  := 32;
        RamBlockDepth_g         : positive                  := 512; --9 addr bits
        ClearAfterReset_g       : boolean                   := true; 
        ReadPriority_g          : boolean                   := false;
        StrictOrdering_g        : boolean                   := false;
        UseAddrOut_g            : boolean                   := true;
        RegisterInput_g         : boolean                   := true;
        Register1Hot_g          : boolean                   := true;
        OneHotDecodeLatency_g   : natural                   := 1;
        runner_cfg              : string
    );
end entity olo_base_cam_tb;

architecture sim of olo_base_cam_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant ClkPeriod_c    : time      := 10 ns;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
   ---- *** Verification Compnents ***
	constant camRdMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => ContentWidth_g
	);
	constant cam1HotSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => Addresses_g
	);
    constant camAddrSlave : axi_stream_slave_t := new_axi_stream_slave (
        data_length => log2ceil(Addresses_g),
        user_length => 1
    );
    subtype WrAddr_r is natural range log2ceil(Addresses_g)-1 downto 0;
    subtype WrContent_r is natural range WrAddr_r'left+ContentWidth_g downto WrAddr_r'left+1;
    constant WrWrite_c : natural := WrContent_r'left+1;
    constant WrClear_c : natural := WrWrite_c+1;
    constant WrClearAll_c : natural := WrClear_c+1;
    constant ConfigInStrWidth_c : natural := WrClearAll_c+1;
    constant camWrMaster : axi_stream_master_t := new_axi_stream_master (
        data_length => ConfigInStrWidth_c
    );

    -- *** Procedures ***
    procedure PushConfigIn( signal net  : inout network_t;
                            Content     : integer := 0; 
                            Addr        : integer := 0; 
                            Write       : boolean := false;
                            Clear       : boolean := false;
                            ClearAll    : boolean := false;
                            Blocking    : boolean := false) is
        variable Data_v : std_logic_vector(ConfigInStrWidth_c - 1 downto 0);        
    begin
        Data_v(WrAddr_r) := toUslv(Addr, log2ceil(Addresses_g));
        Data_v(WrContent_r) := toUslv(Content, ContentWidth_g);
        Data_v(WrWrite_c) := choose(Write, '1', '0');
        Data_v(WrClear_c) := choose(Clear, '1', '0');
        Data_v(WrClearAll_c) := choose(ClearAll, '1', '0');
        push_axi_stream(net, camWrMaster, Data_v);
        if Blocking then
            wait_until_idle(net, as_sync(camWrMaster));
        end if;
    end procedure;

    procedure ReadCam(  signal net  : inout network_t;
                        Content     : integer;
                        Addr        : integer := 0;
                        Found       : boolean := true;
                        Blocking    : boolean := false;
                        OneHot      : std_logic_vector := "X";
                        Msg         : string := "") is
        variable Addr_v         : std_logic_vector(log2ceil(Addresses_g)-1 downto 0) := (others => '0');
        variable AddrOneHot_v   : std_logic_vector(Addresses_g-1 downto 0) := (others => '0');
        variable Found_v        : std_logic_vector(0 downto 0) := "0";
    begin
        if Found then
            -- Normally only one bit is set
            if OneHot = "X" then
                AddrOneHot_v(Addr) := '1';
            -- But the user can check for a specific patter
            else
                AddrOneHot_v(OneHot'range) := OneHot;
            end if;
            Addr_v := toUslv(Addr, log2ceil(Addresses_g));
            Found_v := "1";
        end if;
        push_axi_stream(net, camRdMaster, toUslv(Content, ContentWidth_g));
        check_axi_stream(net, cam1HotSlave, AddrOneHot_v, blocking => false, msg => "one hot - " & Msg);
        if UseAddrOut_g then
            check_axi_stream(net, camAddrSlave, Addr_v, tuser => Found_v, blocking => false, msg => "addr - " & Msg);
        end if;
        if Blocking then
            wait_until_idle(net, as_sync(camRdMaster));
            wait_until_idle(net, as_sync(cam1HotSlave));
            wait_until_idle(net, as_sync(camAddrSlave));
        end if;
    end procedure;



    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk                      : std_logic := '0';
    signal Rst                      : std_logic := '0';
    signal CamRd_Valid             : std_logic := '1';
    signal CamRd_Ready             : std_logic;
    signal CamRd_Content           : std_logic_vector(ContentWidth_g-1 downto 0);
    signal CamWr_Valid             : std_logic;
    signal CamWr_Ready             : std_logic;
    signal CamWr_Content           : std_logic_vector(ContentWidth_g-1 downto 0);
    signal CamWr_Addr              : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
    signal CamWr_Write             : std_logic;
    signal CamWr_Clear             : std_logic;
    signal CamWr_ClearAll          : std_logic;
    signal Cam1Hot_Valid           : std_logic;
    signal Cam1Hot_Match           : std_logic_vector(Addresses_g-1 downto 0);
    signal CamAddr_Valid           : std_logic;
    signal CamAddr_Found           : std_logic;
    signal CamAddr_Addr            : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
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
                wait until rising_edge(Clk) and CamRd_Ready = '1' and CamWr_Ready = '1';
            end if;

            -- Reset Values
            if run("ResetValues") then
                -- first cycle after reset
                Rst <= '1';
                wait until rising_edge(Clk);
                check_equal(CamRd_Ready, '0', "CamRd_Ready first");
                check_equal(CamWr_Ready, '0', "CamWr_Ready first");
                check_equal(Cam1Hot_Valid, '0', "Cam1Hot_Valid first");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid first");
                Rst <= '0';
                -- wait until reset done
                if ClearAfterReset_g then
                    for i in 0 to RamBlockDepth_g-1 loop
                        wait until rising_edge(Clk);
                        check_equal(CamRd_Ready, '0', "CamRd_Ready clearing");
                        check_equal(CamWr_Ready, '0', "CamWr_Ready clearing");
                        check_equal(Cam1Hot_Valid, '0', "Cam1Hot_Valid clearing");
                        check_equal(CamAddr_Valid, '0', "CamAddr_Valid clearing");
                    end loop;
                    wait until rising_edge(Clk);
                else
                    wait until rising_edge(Clk);
                end if;
                check_equal(CamRd_Ready, '1', "CamRd_Ready second");
                check_equal(CamWr_Ready, '1', "CamWr_Ready second");
                check_equal(Cam1Hot_Valid, '0', "Cam1Hot_Valid second");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid second");
            end if;

            -- Basic Tests
            if run("ReadEmptyCam") then
                ReadCam(net, Content => 0, Found => false);
                ReadCam(net, Content => 5, Found => false);
            end if;

            if run("SingleEntry") then
                -- Configure
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Write => true);
                wait for 3*ClkPeriod_c;
                -- Read
                ReadCam(net, Content => 16#12#, Addr => 16#3#, Msg => "found");
                ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "not found");
                -- Clear
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Clear => true);
                wait for 3*ClkPeriod_c;
                ReadCam(net, Content => 16#12#, Found => false, Msg => "cleared");
            end if;

            if run("TwoEntries-SingleRead") then
                -- configure
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Write => true);
                PushConfigIn(net, Content => 16#35#, Addr => 16#4#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                ReadCam(net, Content => 16#35#, Addr => 16#4#, Blocking => true, Msg => "found 1");
                wait for 100 ns;
                wait until rising_edge(Clk);
                ReadCam(net, Content => 16#12#, Addr => 16#3#, Blocking => true, Msg => "found 2");
                wait for 100 ns;
                wait until rising_edge(Clk);
                ReadCam(net, Content => 16#13#, Found => false, Msg => "not found");
                -- Clear
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Clear => true);
                PushConfigIn(net, Content => 16#35#, Addr => 16#4#, Clear => true);
            end if;

            if run("TwoEntries-ConsecutiveRead") then
                -- configure
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                PushConfigIn(net, Content => 16#36#, Addr => 16#05#, Write => true, Blocking => true);
                -- Read
                ReadCam(net, Content => 16#36#, Addr => 16#05#, Msg => "read 1");
                ReadCam(net, Content => 16#13#, Addr => 16#04#, Msg => "read 2");
                ReadCam(net, Content => 16#10#, Found => false, Msg => "read 3");
                ReadCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "read 4");
                -- Clear
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                PushConfigIn(net, Content => 16#36#, Addr => 16#05#, Clear => true);
            end if;

            if run("Write-NoCommand") then
                  -- configure
                  PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                  PushConfigIn(net, Content => 16#36#, Addr => 16#05#, Write => true);
                  PushConfigIn(net, Content => 16#13#, Addr => 16#33#); -- Check not cleared, not written
                  PushConfigIn(net, Content => 16#22#, Addr => 16#33#, Blocking => true); -- Check not written
                  -- Read
                  ReadCam(net, Content => 16#13#, Addr => 16#04#, Msg => "rnot overwritten or cleared");
                  ReadCam(net, Content => 16#22#, Found => false, Msg => "not written", Blocking => true);
                  -- Clear
                  PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                  PushConfigIn(net, Content => 16#36#, Addr => 16#05#, Clear => true);       
            end if;

            if run("Read-Write-Priority") then
                -- Queue up reads and writes
                for i in 0 to 3 loop
                    PushConfigIn(net, Content => i, Addr => 4+i, Write => true);
                    ReadCam(net, Content => 8+i, Found => false);
                end loop;
                wait until rising_edge(Clk) and CamRd_Valid = '1' and CamWr_Valid = '1';
                -- Wait for priorizied access to complete and check if the other access is still executing
                if ReadPriority_g then
                    wait until rising_edge(Clk) and CamRd_Valid = '0';
                    check_equal(CamWr_Valid, '1', "Write not still executing");
                else
                    wait until rising_edge(Clk) and CamWr_Valid = '0';
                    check_equal(CamRd_Valid, '1', "Read not still executing");
                end if;
                wait_until_idle(net, as_sync(camRdMaster));
                wait_until_idle(net, as_sync(cam1HotSlave));
                wait_until_idle(net, as_sync(camAddrSlave));
                wait_until_idle(net, as_sync(camWrMaster));
                -- Cleanup
                for i in 0 to 3 loop
                    PushConfigIn(net, Content => i, Addr => 4+i, Clear => true);            
                end loop;   
            end if;

            if run("StrictOrdering") then
                -- Produce Read immediately after write
                wait until rising_edge(Clk);
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                wait until rising_edge(Clk);
                if StrictOrdering_g or RamBehavior_g = "WBR" then
                    -- In this case the data is already written
                    ReadCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "written");
                else
                    -- In this case the data is not yet written
                    ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "not written");
                end if;
                -- Produce Read immediately after clear
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true);
                wait until rising_edge(Clk);
                if StrictOrdering_g or RamBehavior_g = "WBR" then
                    -- In this case the data is already cleared
                    ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "cleared");
                else
                    -- In this case the data is not yet cleared
                    ReadCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "not cleared");
                end if;        
            end if;

            if run("ClearTwice") then
                -- Configure
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                -- Clear Once
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                ReadCam(net, Content => 16#13#, Found => false);
                ReadCam(net, Content => 16#14#, Addr => 16#05#, Blocking => true);
                -- Clear Twice
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                ReadCam(net, Content => 16#13#, Found => false);
                ReadCam(net, Content => 16#14#, Addr => 16#05#, Blocking => true);
                -- Cleanup
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            if run("SameContent-TwoAddresses") then
                -- Configure
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                PushConfigIn(net, Content => 16#13#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                ReadCam(net, Content => 16#14#, Addr => 16#05#, Msg => "Single Entry 1");
                OneHot_v := (4 => '1', 6 => '1', others => '0');
                ReadCam(net, Content => 16#13#, Addr => 16#04#, OneHot => OneHot_v, Blocking => true, Msg => "First entry for double address");
                -- Clear one entry
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                ReadCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 2");
                ReadCam(net, Content => 16#13#, Addr => 16#06#, Blocking => true, Msg => "Second entry for double address");
                -- Clear second entry
                PushConfigIn(net, Content => 16#13#, Addr => 16#06#, Clear => true, Blocking => true);
                wait for 3*ClkPeriod_c;    
                -- Read
                ReadCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 3");
                ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "Both deleted");         
                -- Clear second entry
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            
            if run("ClearAll") then
                -- Configure
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Write => true);
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Write => true);
                PushConfigIn(net, Content => 16#13#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- ClearAll
                PushConfigIn(net, Content => 16#13#, ClearAll => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- Read
                ReadCam(net, Content => 16#14#, Addr => 16#05#,  Msg => "Single Entry 2");
                ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "Both deleted"); 
                -- Clear single entry
                PushConfigIn(net, Content => 16#14#, Addr => 16#05#, Clear => true);
            end if;

            if run("ClearAfterReset") then
                -- Configure
                PushConfigIn(net, Content => 16#000#, Addr => 16#04#, Write => true);
                PushConfigIn(net, Content => 16#100#, Addr => 16#05#, Write => true);
                PushConfigIn(net, Content => 16#082#, Addr => 16#06#, Write => true, Blocking => true);
                wait for 3*ClkPeriod_c;
                -- ClearAll
                wait until rising_edge(Clk);
                Rst <= '1';
                wait until rising_edge(Clk);
                Rst <= '0';
                -- Read 
                if ClearAfterReset_g then
                    -- All data cleared
                    ReadCam(net, Content => 16#000#, Found => false, Msg => "Deleted 1"); 
                    ReadCam(net, Content => 16#100#, Found => false, Msg => "Deleted 2"); 
                    ReadCam(net, Content => 16#082#, Found => false, Blocking => true, Msg => "Deleted 3"); 
                else
                    -- Data not cleared
                    ReadCam(net, Content => 16#000#, Addr => 16#04#, Msg => "Found 1"); 
                    ReadCam(net, Content => 16#100#, Addr => 16#05#, Msg => "Found 2"); 
                    ReadCam(net, Content => 16#082#, Addr => 16#06#, Blocking => true, Msg => "Found 3");   
                end if;                
            end if;


            wait for 1 us;
            wait_until_idle(net, as_sync(camRdMaster));
            wait_until_idle(net, as_sync(cam1HotSlave));
            wait_until_idle(net, as_sync(camAddrSlave));
            wait_until_idle(net, as_sync(camWrMaster));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk  <= not Clk after 0.5 * ClkPeriod_c;

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_cam
        generic map (
            Addresses_g             => Addresses_g,                                         
            ContentWidth_g          => ContentWidth_g,    
            RamBlockWidth_g         => RamBlockWidth_g, 
            RamBlockDepth_g         => RamBlockDepth_g,
            ClearAfterReset_g       => ClearAfterReset_g,
            ReadPriority_g          => ReadPriority_g,
            StrictOrdering_g        => StrictOrdering_g,
            RegisterInput_g         => RegisterInput_g,
            Register1Hot_g          => Register1Hot_g,
            OneHotDecodeLatency_g   => OneHotDecodeLatency_g,
            RamBehavior_g           => RamBehavior_g
        )
        port map (
            Clk                 => Clk,
            Rst                 => Rst,
            CamRd_Valid         => CamRd_Valid,
            CamRd_Ready         => CamRd_Ready,
            CamRd_Content       => CamRd_Content,
            CamWr_Valid         => CamWr_Valid,
            CamWr_Ready         => CamWr_Ready,
            CamWr_Content       => CamWr_Content,
            CamWr_Addr          => CamWr_Addr,
            CamWr_Write         => CamWr_Write,
            CamWr_Clear         => CamWr_Clear,
            CamWr_ClearAll      => CamWr_ClearAll,
            Cam1Hot_Valid       => Cam1Hot_Valid,
            Cam1Hot_Match       => Cam1Hot_Match,
            CamAddr_Valid       => CamAddr_Valid,
            CamAddr_Found       => CamAddr_Found,
            CamAddr_Addr        => CamAddr_Addr
        );

	------------------------------------------------------------
	-- Verification Components
	------------------------------------------------------------
	vc_camin : entity vunit_lib.axi_stream_master
        generic map (
            master => camRdMaster
        )
        port map (
            aclk   => Clk,
            tvalid => CamRd_Valid,
            tready => CamRd_Ready,
            tdata  => CamRd_Content
        );

    vc_camout_onehot : entity vunit_lib.axi_stream_slave
        generic map (
            slave => cam1HotSlave
        )
        port map (
            aclk   => Clk,
            tvalid => Cam1Hot_Valid,
            tdata  => Cam1Hot_Match
        );

    vc_camout_addr : entity vunit_lib.axi_stream_slave
        generic map (
            slave => camAddrSlave
        )
        port map (
            aclk        => Clk,
            tvalid      => CamAddr_Valid,
            tdata       => CamAddr_Addr,
            tuser(0)    => CamAddr_Found
        );

    b_coonfigin : block
        signal Data : std_logic_vector(ConfigInStrWidth_c-1 downto 0);
    begin
        vc_configin : entity vunit_lib.axi_stream_master
            generic map (
                master => camWrMaster
            )
            port map (
                aclk   => Clk,
                tvalid => CamWr_Valid,
                tready => CamWr_Ready,
                tdata  => Data
            );
            CamWr_Addr <= Data(WrAddr_r);
            CamWr_Content <= Data(WrContent_r);
            CamWr_Write <= Data(WrWrite_c);
            CamWr_Clear <= Data(WrClear_c);
            CamWr_ClearAll <= Data(WrClearAll_c);
    end block;


end sim;
