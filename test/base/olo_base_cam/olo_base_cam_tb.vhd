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
    use olo.olo_base_cam_pkg.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_cam_tb is
    generic (
        Addresses_g     : positive range 8 to 16    := 8;
        ContentWidth_g  : positive range 10 to 256  := 10;
        RamBlockWidth_g : positive := 10;
        RamBlockDepth_g : positive := 512; --9 addr bits
        runner_cfg      : string
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
	constant camInMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => ContentWidth_g
	);
	constant camOutOneHotSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => Addresses_g
	);
    constant camOutAddrSlave : axi_stream_slave_t := new_axi_stream_slave (
        data_length => log2ceil(Addresses_g),
        user_length => 1
    );
    subtype ConfigInAddr_r is natural range log2ceil(Addresses_g)-1 downto 0;
    subtype ConfigInContent_r is natural range ConfigInAddr_r'left+ContentWidth_g downto ConfigInAddr_r'left+1;
    subtype ConfigInCmd_r is natural range ConfigInContent_r'left+2 downto ConfigInContent_r'left+1;
    constant ConfigInStrWidth_c : natural := ConfigInCmd_r'left+1;
    constant configInMaster : axi_stream_master_t := new_axi_stream_master (
        data_length => ConfigInStrWidth_c
    );
    constant configOutSlave : axi_stream_slave_t := new_axi_stream_slave (
        data_length => ContentWidth_g,
        user_length => 1
    );

    -- *** Procedures ***
    procedure PushConfigIn( signal net  : inout network_t;
                            Content     : integer := 0; 
                            Addr        : integer := 0; 
                            Cmd         : std_logic_vector(1 downto 0)) is
        variable Data_v : std_logic_vector(ConfigInStrWidth_c - 1 downto 0);        
    begin
        Data_v(ConfigInAddr_r) := toUslv(Addr, log2ceil(Addresses_g));
        Data_v(ConfigInContent_r) := toUslv(Content, ContentWidth_g);
        Data_v(ConfigInCmd_r) := Cmd;
        push_axi_stream(net, configInMaster, Data_v);
    end procedure;

    procedure ExpectConfigOut( signal net  : inout network_t;
                               Content     : integer := 0; 
                               ErrOccupied : boolean := false; 
                               ErrEmpty    : boolean := false;
                               Blocking    : boolean := false;
                               Msg         : string  := "") is
        constant Tuser_c : std_logic_vector(0 downto 0) := choose(ErrOccupied, "1", "0");
        constant Tlast_c : std_logic := choose(ErrEmpty, '1', '0');
    begin
        check_axi_stream(net, configOutSlave, toUslv(Content, ContentWidth_g), tuser => Tuser_c, tlast => Tlast_c, blocking => Blocking, msg => "config out - " & Msg);
    end procedure;

    procedure ReadCam(  signal net  : inout network_t;
                        Content     : integer;
                        Addr        : integer := 0;
                        Found       : boolean := true;
                        Blocking    : boolean := false;
                        Msg         : string := "") is
        variable Addr_v         : std_logic_vector(log2ceil(Addresses_g)-1 downto 0) := (others => '0');
        variable AddrOneHot_v   : std_logic_vector(Addresses_g-1 downto 0) := (others => '0');
        variable Found_v        : std_logic_vector(0 downto 0) := "0";
    begin
        if Found then
            AddrOneHot_v(Addr) := '1';
            Addr_v := toUslv(Addr, log2ceil(Addresses_g));
            Found_v := "1";
        end if;
        push_axi_stream(net, camInMaster, toUslv(Content, ContentWidth_g));
        check_axi_stream(net, camOutOneHotSlave, AddrOneHot_v, blocking => false, msg => "one hot - " & Msg);
        check_axi_stream(net, camOutAddrSlave, Addr_v, tuser => Found_v, blocking => false, msg => "addr - " & Msg);
        if Blocking then
            wait_until_idle(net, as_sync(camInMaster));
            wait_until_idle(net, as_sync(camOutOneHotSlave));
            wait_until_idle(net, as_sync(camOutAddrSlave));
        end if;
    end procedure;



    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk                      : std_logic := '0';
    signal Rst                      : std_logic := '0';
    signal CamIn_Valid              : std_logic := '0';
    signal CamIn_Ready              : std_logic;
    signal CamIn_Content            : std_logic_vector(ContentWidth_g - 1 downto 0) := (others => '0');
    signal CamOneHot_Valid          : std_logic;
    signal CamOneHot_Match          : std_logic_vector(Addresses_g-1 downto 0);
    signal CamAddr_Valid            : std_logic;
    signal CamAddr_Found            : std_logic;
    signal CamAddr_Addr             : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
    signal ConfigIn_Valid           : std_logic := '0';
    signal ConfigIn_Ready           : std_logic;
    signal ConfigIn_Addr            : std_logic_vector(log2ceil(Addresses_g)-1 downto 0) := (others => '0');
    signal ConfigIn_Cmd             : std_logic_vector(1 downto 0) := (others => '0');
    signal ConfigIn_Content         : std_logic_vector(ContentWidth_g - 1 downto 0) := (others => '0');
    signal ConfigOut_Valid          : std_logic;
    signal ConfigOut_ErrOccupied    : std_logic;
    signal ConfigOut_ErrEmpty       : std_logic;
    signal ConfigOut_Content        : std_logic_vector(ContentWidth_g - 1 downto 0);

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

            -- Reset Values
            if run("ResetValues") then
                -- first cycle after reset
                check_equal(CamIn_Ready, '1', "CamIn_Ready first");
                check_equal(CamOneHot_Valid, '0', "CamOneHot_Valid first");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid first");
                check_equal(ConfigIn_Ready, '0', "ConfigIn_Ready first");
                check_equal(ConfigOut_Valid, '0', "ConfigOut_Valid first");
                -- second cycle after reset
                wait until rising_edge(Clk);
                check_equal(CamIn_Ready, '1', "CamIn_Ready second");
                check_equal(CamOneHot_Valid, '0', "CamOneHot_Valid second");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid second");
                check_equal(ConfigIn_Ready, '1', "ConfigIn_Ready second");
                check_equal(ConfigOut_Valid, '0', "ConfigOut_Valid second");
            end if;

            -- Basic Tests
            if run("ReadEmptyCam") then
                ReadCam(net, Content => 0, Found => false);
            end if;

            if run("SingleEntry") then
                -- Configure
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Blocking => true, Msg => "write");
                -- Read
                ReadCam(net, Content => 16#12#, Addr => 16#3#, Msg => "found");
                ReadCam(net, Content => 16#13#, Found => false, Blocking => true, Msg => "not found");
                -- Clear
                PushConfigIn(net, Addr => 16#3#, Cmd => CMD_CLEAR_ADDR);
                ExpectConfigOut(net, Content => 16#12#, Blocking => true, Msg => "clear");
                ReadCam(net, Content => 16#12#, Found => false, Msg => "cleared");
            end if;

            if run("TwoEntries-SingleRead") then
                -- configure
                PushConfigIn(net, Content => 16#12#, Addr => 16#3#, Cmd => CMD_WRITE);
                PushConfigIn(net, Content => 16#35#, Addr => 16#4#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Blocking => false, Msg => "write 1");
                ExpectConfigOut(net, Blocking => true, Msg => "write 2");
                -- Read
                ReadCam(net, Content => 16#35#, Addr => 16#4#, Blocking => true);
                wait for 100 ns;
                wait until rising_edge(Clk);
                ReadCam(net, Content => 16#12#, Addr => 16#3#, Blocking => true);
                wait for 100 ns;
                wait until rising_edge(Clk);
                ReadCam(net, Content => 16#13#, Found => false);
                -- Clear
                PushConfigIn(net, Addr => 16#3#, Cmd => CMD_CLEAR_ADDR);
                PushConfigIn(net, Addr => 16#4#, Cmd => CMD_CLEAR_ADDR);
            end if;

            if run("TwoEntries-ConsecutiveRead") then
                -- configure
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Cmd => CMD_WRITE);
                PushConfigIn(net, Content => 16#36#, Addr => 16#05#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Blocking => false, Msg => "write 1");
                ExpectConfigOut(net, Blocking => true, Msg => "write 2");
                -- Read
                ReadCam(net, Content => 16#36#, Addr => 16#05#, Msg => "read 1");
                ReadCam(net, Content => 16#13#, Addr => 16#04#, Msg => "read 2");
                ReadCam(net, Content => 16#10#, Found => false, Msg => "read 3");
                ReadCam(net, Content => 16#13#, Addr => 16#04#, Blocking => true, Msg => "read 4");
                -- Clear
                PushConfigIn(net, Addr => 16#04#, Cmd => CMD_CLEAR_ADDR);
                PushConfigIn(net, Addr => 16#05#, Cmd => CMD_CLEAR_ADDR);
            end if;

            -- Config Tests
            if run("ConfigReadback") then
                -- Test
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Msg => "write 1");
                PushConfigIn(net, Addr => 16#05#, Cmd => CMD_READ);
                ExpectConfigOut(net, Content => 0, ErrEmpty => true, Msg => "Unknown");
                PushConfigIn(net, Addr => 16#04#, Cmd => CMD_READ);
                ExpectConfigOut(net, Content => 16#13#, Msg => "Known");
                -- Clear
                PushConfigIn(net, Addr => 16#04#, Cmd => CMD_CLEAR_ADDR);
            end if;

            if run("ConfigClearEmpty") then
                PushConfigIn(net, Addr => 16#04#, Cmd => CMD_CLEAR_ADDR);
                ExpectConfigOut(net, Content => 0, ErrEmpty => true, Msg => "clear empty");
            end if;

            if run("ConfigWriteOccupied") then
                -- Test
                PushConfigIn(net, Content => 16#13#, Addr => 16#04#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Msg => "write 1");
                PushConfigIn(net, Content => 16#36#, Addr => 16#04#, Cmd => CMD_WRITE);
                ExpectConfigOut(net, Content => 16#13#, ErrOccupied => true, Msg => "write 2");
                -- Clear
                PushConfigIn(net, Addr => 16#04#, Cmd => CMD_CLEAR_ADDR);
            end if;



            wait for 1 us;
            wait_until_idle(net, as_sync(camInMaster));
            wait_until_idle(net, as_sync(camOutOneHotSlave));
            wait_until_idle(net, as_sync(camOutAddrSlave));
            wait_until_idle(net, as_sync(configInMaster));
            wait_until_idle(net, as_sync(configOutSlave));

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
            Addresses_g     => Addresses_g,                                    
            ContentWidth_g  => ContentWidth_g,    
            RamBlockWidth_g => RamBlockWidth_g,
            RamBlockDepth_g => RamBlockDepth_g
        )
        port map (   
            Clk                     => Clk,
            Rst                     => Rst,
            CamIn_Valid             => CamIn_Valid,
            CamIn_Ready             => CamIn_Ready,
            CamIn_Content           => CamIn_Content,
            CamOneHot_Valid         => CamOneHot_Valid,
            CamOneHot_Match         => CamOneHot_Match,
            CamAddr_Valid           => CamAddr_Valid,
            CamAddr_Found           => CamAddr_Found,
            CamAddr_Addr            => CamAddr_Addr,
            ConfigIn_Valid          => ConfigIn_Valid,
            ConfigIn_Ready          => ConfigIn_Ready,
            ConfigIn_Addr           => ConfigIn_Addr,
            ConfigIn_Cmd            => ConfigIn_Cmd,
            ConfigIn_Content        => ConfigIn_Content,
            ConfigOut_Valid         => ConfigOut_Valid,
            ConfigOut_ErrOccupied   => ConfigOut_ErrOccupied,
            ConfigOut_ErrEmpty      => ConfigOut_ErrEmpty,
            ConfigOut_Content       => ConfigOut_Content
        );

	------------------------------------------------------------
	-- Verification Components
	------------------------------------------------------------
	vc_camin : entity vunit_lib.axi_stream_master
        generic map (
            master => camInMaster
        )
        port map (
            aclk   => Clk,
            tvalid => CamIn_Valid,
            tready => CamIn_Ready,
            tdata  => CamIn_Content
        );

    vc_camout_onehot : entity vunit_lib.axi_stream_slave
        generic map (
            slave => camOutOneHotSlave
        )
        port map (
            aclk   => Clk,
            tvalid => CamOneHot_Valid,
            tdata  => CamOneHot_Match
        );

    vc_camout_addr : entity vunit_lib.axi_stream_slave
        generic map (
            slave => camOutAddrSlave
        )
        port map (
            aclk        => Clk,
            tvalid      => CamAddr_Valid,
            tdata       => CamAddr_Addr,
            tuser(0)    => CamAddr_Found
        );

    vc_configout : entity vunit_lib.axi_stream_slave
        generic map (
            slave => configOutSlave
        )
        port map (
            aclk        => Clk,
            tvalid      => ConfigOut_Valid,
            tdata       => ConfigOut_Content,
            tuser(0)    => ConfigOut_ErrOccupied,
            tlast       => ConfigOut_ErrEmpty
        );

    b_coonfigin : block
        signal Data : std_logic_vector(ConfigInStrWidth_c-1 downto 0);
    begin
        vc_configin : entity vunit_lib.axi_stream_master
            generic map (
                master => configInMaster
            )
            port map (
                aclk   => Clk,
                tvalid => ConfigIn_Valid,
                tready => ConfigIn_Ready,
                tdata  => Data
            );
            ConfigIn_Addr <= Data(ConfigInAddr_r);
            ConfigIn_Content <= Data(ConfigInContent_r);
            ConfigIn_Cmd <= Data(ConfigInCmd_r);
    end block;


end sim;
