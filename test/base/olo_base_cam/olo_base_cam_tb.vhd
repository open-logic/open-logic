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
        Addresses_g     : positive := 8;
        ContentWidth_g  : positive := 16;
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

    procedure PushConfigIn( signal net : inout network_t;
                            Content : std_logic_vector(ContentWidth_g - 1 downto 0); 
                            Addr : std_logic_vector(log2ceil(Addresses_g)-1 downto 0); 
                            Cmd : std_logic_vector(1 downto 0)) is
        variable Data_v : std_logic_vector(ConfigInStrWidth_c - 1 downto 0);        
    begin
        Data_v(ConfigInAddr_r) := Addr;
        Data_v(ConfigInContent_r) := Content;
        Data_v(ConfigInCmd_r) := Cmd;
        push_axi_stream(net, configInMaster, Data_v);
    end procedure;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk                 : std_logic := '0';
    signal Rst                 : std_logic := '0';
    signal CamIn_Valid         : std_logic := '0';
    signal CamIn_Ready         : std_logic;
    signal CamIn_Content       : std_logic_vector(ContentWidth_g - 1 downto 0) := (others => '0');
    signal CamOneHot_Valid     : std_logic;
    signal CamOneHot_Match     : std_logic_vector(Addresses_g-1 downto 0);
    signal CamAddr_Valid       : std_logic;
    signal CamAddr_Found       : std_logic;
    signal CamAddr_Addr        : std_logic_vector(log2ceil(Addresses_g)-1 downto 0);
    signal ConfigIn_Valid      : std_logic := '0';
    signal ConfigIn_Ready      : std_logic;
    signal ConfigIn_Addr       : std_logic_vector(log2ceil(Addresses_g)-1 downto 0) := (others => '0');
    signal ConfigIn_Cmd        : std_logic_vector(1 downto 0) := (others => '0');
    signal ConfigIn_Content    : std_logic_vector(ContentWidth_g - 1 downto 0) := (others => '0');

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
                check_equal(CamIn_Ready, '0', "CamIn_Ready first");
                check_equal(CamOneHot_Valid, '0', "CamOneHot_Valid first");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid first");
                check_equal(ConfigIn_Ready, '0', "ConfigIn_Ready first");
                -- second cycle after reset
                wait until rising_edge(Clk);
                check_equal(CamIn_Ready, '1', "CamIn_Ready second");
                check_equal(CamOneHot_Valid, '0', "CamOneHot_Valid second");
                check_equal(CamAddr_Valid, '0', "CamAddr_Valid second");
                check_equal(ConfigIn_Ready, '1', "ConfigIn_Ready second");
            end if;

            -- Basic Tests
            if run("ReadEmptyCam") then
                push_axi_stream(net, camInMaster, toUslv(16#12#, ContentWidth_g));
                check_axi_stream(net, camOutOneHotSlave, toUslv(0, Addresses_g), blocking => false, msg => "one hot");
                check_axi_stream(net, camOutAddrSlave, toUslv(0, log2ceil(Addresses_g)), tuser => "0", blocking => false, msg => "addr");
            end if;

            if run("SingleEntry") then
                -- Configure
                PushConfigIn(net, Content => toUslv(16#12#, ContentWidth_g), Addr => toUslv(16#3#, log2ceil(Addresses_g)), Cmd => CMD_WRITE);
                wait for 20 * ClkPeriod_c;
                wait until rising_edge(Clk);
                -- Read
                push_axi_stream(net, camInMaster, toUslv(16#12#, ContentWidth_g));
                OneHot_v := (others => '0');
                OneHot_v(16#3#) := '1';
                check_axi_stream(net, camOutOneHotSlave, OneHot_v, blocking => false, msg => "one hot");
                check_axi_stream(net, camOutAddrSlave, toUslv(3, log2ceil(Addresses_g)), tuser => "1", blocking => false, msg => "addr");
            end if;

            if run("TwoEntries-SingleRead") then
                -- configure
                PushConfigIn(net, Content => toUslv(16#12#, ContentWidth_g), Addr => toUslv(16#3#, log2ceil(Addresses_g)), Cmd => CMD_WRITE);
                PushConfigIn(net, Content => toUslv(16#35#, ContentWidth_g), Addr => toUslv(16#4#, log2ceil(Addresses_g)), Cmd => CMD_WRITE);
                -- Read 1
                wait for 20 * ClkPeriod_c;
                wait until rising_edge(Clk);
                push_axi_stream(net, camInMaster, toUslv(16#35#, ContentWidth_g));
                OneHot_v := (others => '0');
                OneHot_v(16#4#) := '1';
                check_axi_stream(net, camOutOneHotSlave, OneHot_v, blocking => false, msg => "one hot 1");
                check_axi_stream(net, camOutAddrSlave, toUslv(4, log2ceil(Addresses_g)), tuser => "1", blocking => false, msg => "addr 1");
                -- Read 2
                wait for 20 * ClkPeriod_c;
                wait until rising_edge(Clk);
                push_axi_stream(net, camInMaster, toUslv(16#12#, ContentWidth_g));
                OneHot_v := (others => '0');
                OneHot_v(16#3#) := '1';
                check_axi_stream(net, camOutOneHotSlave, OneHot_v, blocking => false, msg => "one hot 2");
                check_axi_stream(net, camOutAddrSlave, toUslv(3, log2ceil(Addresses_g)), tuser => "1", blocking => false, msg => "addr 2");
                -- Read inexistend
                wait for 20 * ClkPeriod_c;
                wait until rising_edge(Clk);
                push_axi_stream(net, camInMaster, toUslv(16#03#, ContentWidth_g));
                check_axi_stream(net, camOutOneHotSlave, toUslv(0, Addresses_g), blocking => false, msg => "one hot 3");
                check_axi_stream(net, camOutAddrSlave, toUslv(0, log2ceil(Addresses_g)), tuser => "0", blocking => false, msg => "addr 3");
            end if;

            if run("woEntries-ConsecutiveRead") then
                -- Merge Readout into procedure
            end if;

            if run ("EntryOverride") then
            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(camInMaster));
            wait_until_idle(net, as_sync(camOutOneHotSlave));
            wait_until_idle(net, as_sync(camOutAddrSlave));

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
            Clk                 => Clk,
            Rst                 => Rst,
            CamIn_Valid         => CamIn_Valid,
            CamIn_Ready         => CamIn_Ready,
            CamIn_Content       => CamIn_Content,
            CamOneHot_Valid     => CamOneHot_Valid,
            CamOneHot_Match     => CamOneHot_Match,
            CamAddr_Valid       => CamAddr_Valid,
            CamAddr_Found       => CamAddr_Found,
            CamAddr_Addr        => CamAddr_Addr,
            ConfigIn_Valid      => ConfigIn_Valid,
            ConfigIn_Ready      => ConfigIn_Ready,
            ConfigIn_Addr       => ConfigIn_Addr,
            ConfigIn_Cmd        => ConfigIn_Cmd,
            ConfigIn_Content    => ConfigIn_Content
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
    --
	--vc_response : entity vunit_lib.axi_stream_slave
	--generic map (
	--    slave => camOutOneHotSlave
	--)
	--port map (
	--    aclk   => Clk,
	--    tvalid => Out_Valid,
    --    tready => Out_Ready,
	--    tdata  => Out_Data,
    --    tlast  => Out_Last,
    --    tuser  => Out_WordEna
    --
	--);

end sim;
