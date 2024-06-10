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
    use olo.olo_axi_pkg_protocol.all;

library work;
    use work.olo_test_pkg_axi.all;
    use work.olo_test_axi_slave_pkg.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_axi_master_simple_tb is
    generic (
        AxiAddrWidth_g              : natural range 16 to 64   := 32;   
        AxiDataWidth_g              : natural range 16 to 64   := 32;   
        AxiMaxOpenTransactions_g    : natural range 1 to 8     := 2;     
        ImplRead_g                  : boolean                  := true; 
        ImplWrite_g                 : boolean                  := true; 
        RamBehavior_g               : string                   := "RBW"; 
        runner_cfg                  : string  
    );
end entity olo_axi_master_simple_tb;

architecture sim of olo_axi_master_simple_tb is
    -------------------------------------------------------------------------
    -- Fixed Generics
    -------------------------------------------------------------------------   
    constant UserTransactionSizeBits_c   : natural      := 10; 
    constant AxiMaxBeats_c               : natural      := 32;
    constant DataFifoDepth_c             : natural      := 16;

    -------------------------------------------------------------------------
    -- AXI Definition
    -------------------------------------------------------------------------
    constant ByteWidth_c     : integer   := AxiDataWidth_g/8;
    
    subtype IdRange_r   is natural range -1 downto 0;
    subtype AddrRange_r is natural range AxiAddrWidth_g-1 downto 0;
    subtype UserRange_r is natural range 1 downto 0;
    subtype DataRange_r is natural range AxiDataWidth_g-1 downto 0;
    subtype ByteRange_r is natural range ByteWidth_c-1 downto 0;
    
    signal AxiMs : AxiMs_r (ArId(IdRange_r), AwId(IdRange_r),
                            ArAddr(AddrRange_r), AwAddr(AddrRange_r),
                            ArUser(UserRange_r), AwUser(UserRange_r), WUser(UserRange_r),
                            WData(DataRange_r),
                            WStrb(ByteRange_r));
    
    signal AxiSm : AxiSm_r (RId(IdRange_r), BId(IdRange_r),
                            RUser(UserRange_r), BUser(UserRange_r),
                            RData(DataRange_r));

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------   
    subtype CmdAddrRange_r is natural range AxiAddrWidth_g-1 downto 0;
    subtype CmdSizeRange_r is natural range UserTransactionSizeBits_c+CmdAddrRange_r'high downto CmdAddrRange_r'high+1;
    constant CmdLowLat_r : natural := CmdSizeRange_r'high+1;

    subtype DatDataRange_r is natural range AxiDataWidth_g-1 downto 0;
    subtype DatBeRange_r is natural range AxiDataWidth_g/8+DatDataRange_r'high downto DatDataRange_r'high+1;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;

    type Response_t is (RespSuccess, RespError);
        

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    -- Contral Sginal
    signal Clk             : std_logic                                                   := '0';
    signal Rst             : std_logic                                                   := '0';
    -- Write Command Interface
    signal CmdWr_Addr      : std_logic_vector(AxiAddrWidth_g - 1 downto 0)               := (others => '0'); 
    signal CmdWr_Size      : std_logic_vector(UserTransactionSizeBits_c - 1 downto 0)    := (others => '0'); 
    signal CmdWr_LowLat    : std_logic                                                   := '0';             
    signal CmdWr_Valid     : std_logic                                                   := '0';             
    signal CmdWr_Ready     : std_logic;                                                                    
    -- Read Command Interface
    signal CmdRd_Addr      : std_logic_vector(AxiAddrWidth_g - 1 downto 0)               := (others => '0');  
    signal CmdRd_Size      : std_logic_vector(UserTransactionSizeBits_c - 1 downto 0)    := (others => '0');  
    signal CmdRd_LowLat    : std_logic                                                   := '0';              
    signal CmdRd_Valid     : std_logic                                                   := '0';              
    signal CmdRd_Ready     : std_logic;                                                                     
    -- Write Data
    signal Wr_Data         : std_logic_vector(AxiDataWidth_g - 1 downto 0)               := (others => '0');
    signal Wr_Be           : std_logic_vector(AxiDataWidth_g / 8 - 1 downto 0)           := (others => '0');
    signal Wr_Valid        : std_logic                                                   := '0';            
    signal Wr_Ready        : std_logic;                                                                      
    -- Read Data
    signal Rd_Data         : std_logic_vector(AxiDataWidth_g - 1 downto 0);                                 
    signal Rd_Valid        : std_logic;                                                                     
    signal Rd_Ready        : std_logic                                                   := '0';            
    -- Response
    signal Wr_Done         : std_logic;                                                                       
    signal Wr_Error        : std_logic;                                                                       
    signal Rd_Done         : std_logic;                                                                       
    signal Rd_Error        : std_logic;  
    signal Rd_Last         : std_logic;
    
    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant axiSlave : olo_test_axi_slave_t := new_olo_test_axi_slave (
        dataWidth => AxiDataWidth_g,
        addrWidth => AxiAddrWidth_g,
        idWidth => 0
    );
	constant rdDataSlave : axi_stream_slave_t := new_axi_stream_slave (
		data_length => AxiDataWidth_g,
		stall_config => new_stall_config(0.0, 0, 0)
	);
    constant wrCmdMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => AxiAddrWidth_g+UserTransactionSizeBits_c+1,
		stall_config => new_stall_config(0.0, 0, 0)
	);
    constant rdCmdMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => AxiAddrWidth_g+UserTransactionSizeBits_c+1,
		stall_config => new_stall_config(0.0, 0, 0)
	);
    constant wrDataMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => AxiDataWidth_g+AxiDataWidth_g/8,
		stall_config => new_stall_config(0.0, 0, 0)
	);

    procedure PushCommand(  signal net  : inout network_t;
                            CmdMaster   : axi_stream_master_t;
                            CmdAddr     : unsigned;
                            CmdSize     : integer;
                            CmdLowLat   : std_logic := '0') is
        variable TData : std_logic_vector(CmdLowLat_r downto 0);
    begin
        TData(CmdAddrRange_r) := std_logic_vector(resize(CmdAddr, AxiAddrWidth_g));
        TData(CmdSizeRange_r) := toUslv(CmdSize, UserTransactionSizeBits_c);
        TData(CmdLowLat_r) := CmdLowLat;
        push_axi_stream(net, CmdMaster, TData);
    end procedure;

    procedure PushWrData(   signal net      : inout network_t;
                            startValue      : unsigned;
                            increment       : natural               := 1; 
                            beats           : natural               := 1;
                            firstStrb       : std_logic_vector      := onesVector(AxiDataWidth_g/8);
                            lastStrb        : std_logic_vector      := onesVector(AxiDataWidth_g/8)) is
        variable TData : std_logic_vector(DatBeRange_r'high downto 0);
        variable Data : unsigned(AxiDataWidth_g-1 downto 0);
    begin
        Data := resize(startValue, AxiDataWidth_g);
        for i in 0 to beats-1 loop
            TData(DatDataRange_r) := std_logic_vector(Data);
            if i = 0 then
                TData(DatBeRange_r) := firstStrb;
            elsif i = beats-1 then
                TData(DatBeRange_r) := lastStrb;
            else
                TData(DatBeRange_r) := (others => '1');
            end if;
            push_axi_stream(net, wrDataMaster, TData);
            Data := Data + increment;
        end loop;
    end procedure;

    procedure ExpectRdData( signal net      : inout network_t;
                            startValue      : unsigned;
                            increment       : natural               := 1;
                            beats           : natural               := 1) is
        variable Data : unsigned(AxiDataWidth_g-1 downto 0);
        variable Last : std_logic := '0';
    begin
        Data := resize(startValue, AxiDataWidth_g);
        for i in 0 to beats-1 loop
            -- Last is set on the last beat
            if i = beats-1 then
                Last := '1';
            end if;
            check_axi_stream(net, rdDataSlave, std_logic_vector(Data), blocking => false, tlast => Last, msg => "RdData " & integer'image(i));
            Data := Data + increment;
        end loop;
    end procedure;

    procedure ExpectWrResponse(Response : Response_t) is
    begin
        wait until rising_edge(Clk) and ((Wr_Done = '1') or (Wr_Error = '1'));
        if Response = RespSuccess then
            check_equal(Wr_Error, '0', "Wrong Wr_Error");
            check_equal(Wr_Done, '1', "Wrong Wr_Done");
        else
            check_equal(Wr_Error, '1', "Wrong Wr_Error");
            check_equal(Wr_Done, '0', "Wrong Wr_Done");
        end if;
    end procedure;

    procedure ExpectRdResponse(Response : Response_t) is
    begin
        wait until rising_edge(Clk) and ((Rd_Done = '1') or (Rd_Error = '1'));
        if Response = RespSuccess then
            check_equal(Rd_Error, '0', "Wrong Rd_Error");
            check_equal(Rd_Done, '1', "Wrong Rd_Done");
        else
            check_equal(Rd_Error, '1', "Wrong Rd_Error");
            check_equal(Rd_Done, '0', "Wrong Rd_Done");
        end if;
    end procedure;

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

            if run("ResetValues") then
                if ImplRead_g then
                    check_equal(Rd_Valid, '0', "Rd_Valid");
                    check_equal(Rd_Done, '0', "Rd_Done");
                    check_equal(Rd_Error, '0', "Rd_Error");
                end if;
                if ImplWrite_g then                
                    check_equal(Wr_Done, '0', "Wr_Done");
                    check_equal(Wr_Error, '0', "Wr_Error");
                end if;

            end if;

            -- *** Single Writes ***
            if run("SingleWrite-DataCmdTogether") then
                -- Only applies if Write is implemented
                if ImplWrite_g then
                    for LowLatency in 0 to 1 loop
                        -- Slave
                        expect_single_write (net, axiSlave, X"1080", X"ABCD");
                        -- Master
                        PushCommand(net, wrCmdMaster, X"1080", 1, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        PushWrData(net, X"ABCD");                
                        -- Blocking
                        ExpectWrResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("SingleWrite-DataBeforeCmd") then
                -- Only applies if Write is implemented
                if ImplWrite_g then
                    for LowLatency in 0 to 1 loop
                        -- Slave
                        expect_single_write (net, axiSlave, X"1088", X"ABC1");
                        -- Master
                        PushWrData(net, X"ABC1"); 
                        wait for 200 ns;
                        PushCommand(net, wrCmdMaster, X"1088", 1, CmdLowLat => choose(LowLatency=1, '1', '0'));                               
                        -- Blocking
                        ExpectWrResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("SingleWrite-CmdBeforeData") then
                if ImplWrite_g then
                    for LowLatency in 0 to 1 loop
                        -- Master
                        PushCommand(net, wrCmdMaster, X"1090", 1, CmdLowLat => choose(LowLatency=1, '1', '0')); 
                        wait for 200 ns;
                        if LowLatency = 0 then
                            check_equal(AxiMs.AwValid, '0', "HighLatency write executed before data was present");
                        else
                            check_equal(AxiMs.AwValid, '1', "LowLatency write not executed before data was present");
                        end if;
                        PushWrData(net, X"ABC2");    
                        -- Slave
                        expect_single_write (net, axiSlave, X"1090", X"ABC2");                    
                        -- Blocking
                        ExpectWrResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("SingleWrite-DelayedAwReady") then
                if ImplWrite_g then
                    -- Slave
                    expect_single_write (net, axiSlave, X"0100", X"03", AwReadyDelay => 200 ns);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0100", 1);
                    PushWrData(net, X"03");                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

            if run("SingleWrite-DelayedWReady") then
                if ImplWrite_g then
                    -- Slave
                    expect_single_write (net, axiSlave, X"0200", X"04", WReadyDelay => 200 ns);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0200", 1);
                    PushWrData(net, X"04");                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

            if run("SingleWrite-DelayedBValid") then
                if ImplWrite_g then
                    -- Slave
                    expect_single_write (net, axiSlave, X"0208", X"05", BValidDelay => 200 ns);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0208", 1);
                    PushWrData(net, X"05");                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

            if run("SingleWrite-RespError") then
                if ImplWrite_g then
                    -- Slave
                    expect_aw(net, axiSlave, X"0300");
                    expect_w(net, axiSlave, X"05");
                    push_b(net, axiSlave, resp => xRESP_SLVERR_c);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0300", 1);
                    PushWrData(net, X"05");                
                    -- Blocking
                    ExpectWrResponse(RespError);
                end if;
            end if;         

            -- *** Single Reads ***
            if run("SingleRead") then
                if ImplRead_g then
                    for LowLatency in 0 to 1 loop
                        -- Slave
                        push_single_read (net, axiSlave, X"0200", X"120A");
                        -- Master
                        PushCommand(net, rdCmdMaster, X"0200", 1, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        ExpectRdData(net, X"120A");                
                        -- Blocking
                        ExpectRdResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("SingleRead-DelayedArReady") then
                if ImplRead_g then 
                    -- Slave
                    push_single_read (net, axiSlave, X"0208", X"10", ArReadyDelay => 200 ns);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"0208", 1);
                    ExpectRdData(net, X"10");                
                    -- Blocking
                    ExpectRdResponse(RespSuccess);
                end if;
            end if;

            if run("SingleRead-DelayedRValid") then
                if ImplRead_g then
                    -- Slave
                    push_single_read (net, axiSlave, X"0210", X"20", RVAlidDelay => 200 ns);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"0210", 1);
                    ExpectRdData(net, X"20");                
                    -- Blocking
                    ExpectRdResponse(RespSuccess);
                end if;
            end if;

            if run("SingleRead-RespError") then
                if ImplRead_g then
                    -- Slave
                    expect_ar(net, axiSlave, X"0300");
                    push_r(net, axiSlave, X"23", resp => xRESP_SLVERR_c);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"0300", 1);
                    ExpectRdData(net, X"23");                
                    -- Blocking
                    ExpectRdResponse(RespError);
                end if;
            end if;

            -- *** Burst Writes ***
            if run("BurstWrite") then
                if ImplWrite_g then
                    for LowLatency in 0 to 1 loop
                        -- Slave
                        expect_burst_write_aligned(net, axiSlave, X"0100", X"1234", 1, 12);
                        -- Master
                        PushCommand(net, wrCmdMaster, X"0100", 12, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        PushWrData(net, X"1234", 1, 12);                
                        -- Blocking
                        ExpectWrResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("BurstWriteOver4kBoundary") then
                if ImplWrite_g then
                    -- 2 words before boundary, 6 after, 8 total
                    -- Slave
                    expect_burst_write_aligned(net, axiSlave, X"1000"-2*AxiDataWidth_g/8, X"1234", 1, 2);
                    expect_burst_write_aligned(net, axiSlave, X"1000", X"1236", 1, 6);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"1000"-2*AxiDataWidth_g/8, 8);
                    PushWrData(net, X"1234", 1, 8);                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

            if run("BurstWrite-FirstBurstError") then
                if ImplWrite_g then
                    -- 2 words before boundary, 6 after, 8 total
                    -- Slave first burst
                    expect_aw(net, axiSlave, X"2000"-2*AxiDataWidth_g/8, len => 2);
                    expect_w(net, axiSlave, X"12", beats => 2);
                    push_b(net, axiSlave, resp => xRESP_SLVERR_c);
                    -- Slave second burst
                    expect_burst_write_aligned(net, axiSlave, X"2000", X"14", 1, 6);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"2000"-2*AxiDataWidth_g/8, 8);
                    PushWrData(net, X"12", 1, 8);                
                    -- Blocking
                    ExpectWrResponse(RespError);
                end if;
            end if;


            -- *** Burst Reads ***
            if run("BurstRead") then
                if ImplRead_g then
                    for LowLatency in 0 to 1 loop
                        -- Slave
                        push_burst_read_aligned (net, axiSlave, X"0210", X"10EF", 1, 12);
                        -- Master
                        PushCommand(net, rdCmdMaster, X"0210", 12, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        ExpectRdData(net, X"10EF", 1, 12);                
                        -- Blocking
                        ExpectRdResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            if run("BurstReadOver4kBoundary") then
                if ImplRead_g then
                    -- 2 words before boundary, 6 after, 8 total
                    -- Slave
                    push_burst_read_aligned (net, axiSlave, X"2000"-2*AxiDataWidth_g/8, X"09", 1, 2);
                    push_burst_read_aligned (net, axiSlave, X"2000", X"0B", 1, 6);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"2000"-2*AxiDataWidth_g/8, 8);
                    ExpectRdData(net, X"09", 1, 8);                
                    -- Blocking
                    ExpectRdResponse(RespSuccess);
                end if;
            end if;

            if run("BurstRead-FirstBurstError") then
                if ImplRead_g then
                    -- 2 words before boundary, 6 after, 8 total
                    -- Slave first burst
                    expect_ar(net, axiSlave, X"3000"-2*AxiDataWidth_g/8, len => 2);
                    push_r(net, axiSlave, X"12", beats => 2, resp => xRESP_SLVERR_c);
                    -- Slave second burst
                    push_burst_read_aligned (net, axiSlave, X"3000", X"14", 1, 6);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"3000"-2*AxiDataWidth_g/8, 8);
                    ExpectRdData(net, X"12", 1, 8);                
                    -- Blocking
                    ExpectRdResponse(RespError);
                end if;
            end if;

            -- *** Check if high-latency read command with full FIFO is delayed ***
            if run("BurstRead-FifoFull") then
                if ImplRead_g then
                    for LowLatency in 0 to 1 loop
                        -- Fill FIFO
                        PushCommand(net, rdCmdMaster, X"4000", DataFifoDepth_c, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        wait for 100 ns;
                        check_equal(AxiMs.ArValid, '1', "Fill Command not Valid");
                        push_burst_read_aligned (net, axiSlave, X"4000", X"10", 1, DataFifoDepth_c);
                        -- Push Second Command with full FIFO
                        PushCommand(net, rdCmdMaster, X"5000", 4, CmdLowLat => choose(LowLatency=1, '1', '0'));
                        wait for 100 ns;
                        if LowLatency = 0 then
                            check_equal(AxiMs.ArValid, '0', "Second Command Valid despite full FIFO");
                        else
                            check_equal(AxiMs.ArValid, '1', "Second Command not Valid despite low-latency");
                        end if;
                        -- Execute both commands
                        ExpectRdData(net, X"10", 1, DataFifoDepth_c); 
                        ExpectRdResponse(RespSuccess);
                        push_burst_read_aligned (net, axiSlave, X"5000", X"40", 1, 4);
                        ExpectRdData(net, X"40", 1, 4);                     
                        ExpectRdResponse(RespSuccess);
                    end loop;
                end if;
            end if;

            -- *** Test handshake on Data Lane ***
            if run("BurstRead-SlowData") then
                if ImplRead_g then
                    -- Slave
                    push_burst_read_aligned (net, axiSlave, X"0210", X"10EF", 1, 12, beatDelay => 50 ns);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"0210", 12, CmdLowLat => '0');
                    ExpectRdData(net, X"10EF", 1, 12);                
                    -- Blocking
                    ExpectRdResponse(RespSuccess);
                end if;
            end if;

            if run("BurstWrite-SlowData") then
                if ImplWrite_g then
                    -- Slave
                    expect_burst_write_aligned(net, axiSlave, X"0100", X"1234", 1, 12, beatDelay => 50 ns);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0100", 12, CmdLowLat => '0');
                    PushWrData(net, X"1234", 1, 12);                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

            -- *** Split Transfers at Maximum Transaction Size ***
            if run("BurstRead-MaxTransactionSize") then
                if ImplRead_g then
                    -- Slave
                    push_burst_read_aligned (net, axiSlave, X"0210", X"10EF", 1, AxiMaxBeats_c);
                    push_burst_read_aligned (net, axiSlave, X"0210"+AxiMaxBeats_c*ByteWidth_c, X"10EF"+AxiMaxBeats_c, 1, AxiMaxBeats_c);
                    push_burst_read_aligned (net, axiSlave, X"0210"+AxiMaxBeats_c*2*ByteWidth_c, X"10EF"+AxiMaxBeats_c*2, 1, 5);
                    -- Master
                    PushCommand(net, rdCmdMaster, X"0210", AxiMaxBeats_c*2+5, CmdLowLat => '1'); -- must be lowlatency becuause larger than FIFO
                    ExpectRdData(net, X"10EF", 1, AxiMaxBeats_c*2+5);                
                    -- Blocking
                    ExpectRdResponse(RespSuccess);
                end if;
            end if;

            if run("BurstWrite-MaxTransactionSize") then
                if ImplWrite_g then
                    -- Slave
                    expect_burst_write_aligned(net, axiSlave, X"0100", X"1234", 1, AxiMaxBeats_c);
                    expect_burst_write_aligned(net, axiSlave, X"0100"+AxiMaxBeats_c*ByteWidth_c, X"1234"+AxiMaxBeats_c, 1, AxiMaxBeats_c);
                    expect_burst_write_aligned(net, axiSlave, X"0100"+AxiMaxBeats_c*2*ByteWidth_c, X"1234"+AxiMaxBeats_c*2, 1, 5);
                    -- Master
                    PushCommand(net, wrCmdMaster, X"0100", AxiMaxBeats_c*2+5, CmdLowLat => '1'); -- must be lowlatency becuause larger than FIFO
                    PushWrData(net, X"1234", 1, AxiMaxBeats_c*2+5);                
                    -- Blocking
                    ExpectWrResponse(RespSuccess);
                end if;
            end if;

                    
            -- Wait for idle
            wait_until_idle(net, as_sync(axiSlave));
            wait_until_idle(net, as_sync(rdDataSlave));
            wait_until_idle(net, as_sync(wrCmdMaster));
            wait_until_idle(net, as_sync(rdCmdMaster));
            wait_until_idle(net, as_sync(wrDataMaster));
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
    i_dut : entity olo.olo_axi_master_simple
        generic map (
            AxiAddrWidth_g              => AxiAddrWidth_g, 
            AxiDataWidth_g              => AxiDataWidth_g,
            AxiMaxBeats_g               => AxiMaxBeats_c,
            AxiMaxOpenTransactions_g    => AxiMaxOpenTransactions_g,  
            -- User Configuration
            UserTransactionSizeBits_g   => UserTransactionSizeBits_c, 
            DataFifoDepth_g             => DataFifoDepth_c,
            ImplRead_g                  => ImplRead_g,
            ImplWrite_g                 => ImplWrite_g,
            RamBehavior_g               => RamBehavior_g
        )
        port map (
            -- Control Signals
            Clk            => Clk,     
            Rst            => Rst,   
            -- User Command Interface
            CmdWr_Addr     => CmdWr_Addr,
            CmdWr_Size     => CmdWr_Size,
            CmdWr_LowLat   => CmdWr_LowLat,           
            CmdWr_Valid    => CmdWr_Valid,        
            CmdWr_Ready    => CmdWr_Ready,                                                                
            -- User Command Interface
            CmdRd_Addr     => CmdRd_Addr,
            CmdRd_Size     => CmdRd_Size,
            CmdRd_LowLat   => CmdRd_LowLat,          
            CmdRd_Valid    => CmdRd_Valid,            
            CmdRd_Ready    => CmdRd_Ready,                                                                  
            -- Write Data
            Wr_Data        => Wr_Data,
            Wr_Be          => Wr_Be,
            Wr_Valid       => Wr_Valid,         
            Wr_Ready       => Wr_Ready,                                                      
            -- Read Data
            Rd_Data        => Rd_Data,              
            Rd_Valid       => Rd_Valid,
            Rd_Ready       => Rd_Ready,  
            Rd_Last        => Rd_Last,          
            -- Response
            Wr_Done        => Wr_Done,                                                                      
            Wr_Error       => Wr_Error,                                                               
            Rd_Done        => Rd_Done,                                                     
            Rd_Error       => Rd_Error,                                                               
            -- AXI Address Write Channel
            M_Axi_AwAddr   => AxiMs.AwAddr,
            M_Axi_AwValid  => AxiMs.AwValid,
            M_Axi_AwReady  => AxiSm.AwReady,
            M_Axi_AwLen    => AxiMs.AwLen,
            M_Axi_AwSize   => AxiMs.AwSize,
            M_Axi_AwBurst  => AxiMs.AwBurst,
            M_Axi_AwLock   => AxiMs.AwLock,
            M_Axi_AwCache  => AxiMs.AwCache,
            M_Axi_AwProt   => AxiMs.AwProt,        
            -- AXI Write Data Channel      
            M_Axi_WData    => AxiMs.WData,
            M_Axi_WStrb    => AxiMs.WStrb,
            M_Axi_WValid   => AxiMs.WValid,
            M_Axi_WReady   => AxiSm.WReady,
            M_Axi_WLast    => AxiMs.WLast,    
            -- AXI Write Response Channel
            M_Axi_BResp    => AxiSm.BResp,
            M_Axi_BValid   => AxiSm.BValid,
            M_Axi_BReady   => AxiMs.BReady,         
            -- AXI Read Address Channel
            M_Axi_ArAddr   => AxiMs.ArAddr,
            M_Axi_ArValid  => AxiMs.ArValid,
            M_Axi_ArReady  => AxiSm.ArReady,
            M_Axi_ArLen    => AxiMs.ArLen,
            M_Axi_ArSize   => AxiMs.ArSize,
            M_Axi_ArBurst  => AxiMs.ArBurst,
            M_Axi_ArLock   => AxiMs.ArLock,
            M_Axi_ArCache  => AxiMs.ArCache,
            M_Axi_ArProt   => AxiMs.ArProt,         
            -- AXI Read Data Channel 
            M_Axi_RData    => AxiSm.RData,
            M_Axi_RValid   => AxiSm.RValid,
            M_Axi_RReady   => AxiMs.RReady,
            M_Axi_RResp    => AxiSm.RResp,
            M_Axi_RLast    => AxiSm.RLast            
        );

    ------------------------------------------------------------
    -- Verification Components
    ------------------------------------------------------------
    vc_slave : entity work.olo_test_axi_slave_vc
        generic map (
            instance => axiSlave
        )
        port map (
            Clk   => Clk,
            Rst   => Rst,
            AxiMs => AxiMs,
            AxiSm => AxiSm
        );

    vc_rd_data : entity vunit_lib.axi_stream_slave
	    generic map (
	        slave => rdDataSlave
	    )
	    port map (
	        aclk   => Clk,
	        tvalid => Rd_Valid,
            tready => Rd_Ready,
	        tdata  => Rd_Data,
            tlast  => Rd_Last   
	    );

    b_wr_cmd : block
        signal TData : std_logic_vector(CmdLowLat_r downto 0);
    begin
        vc_wr_cmd : entity vunit_lib.axi_stream_master
            generic map (
                master => wrCmdMaster
            )
            port map (
                aclk   => Clk,
                tvalid => CmdWr_Valid,
                tready => CmdWr_Ready,
                tdata => TData
            );

        CmdWr_Addr <= TData(CmdAddrRange_r);
        CmdWr_Size <= TData(CmdSizeRange_r);
        CmdWr_LowLat <= TData(CmdLowLat_r);
    end block;

    b_rd_cmd : block
        signal TData : std_logic_vector(CmdLowLat_r downto 0);
    begin
        vc_rd_cmd : entity vunit_lib.axi_stream_master
            generic map (
                master => rdCmdMaster
            )
            port map (
                aclk   => Clk,
                tvalid => CmdRd_Valid,
                tready => CmdRd_Ready,
                tdata => TData
            );
        
        CmdRd_Addr <= TData(CmdAddrRange_r);
        CmdRd_Size <= TData(CmdSizeRange_r);
        CmdRd_LowLat <= TData(CmdLowLat_r);
    end block;

    b_wr_data : block
        signal TData : std_logic_vector(DatBeRange_r'high downto 0);
    begin
        vc_wr_data : entity vunit_lib.axi_stream_master
            generic map (
                master => wrDataMaster
            )
            port map (
                aclk   => Clk,
                tvalid => Wr_Valid,
                tready => Wr_Ready,
                tdata => TData
            );

        Wr_Data <= TData(DatDataRange_r);
        Wr_Be <= TData(DatBeRange_r);
    end block;


end sim;
