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
    use work.olo_test_axi_slave_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_axi_master_full_tb is
    generic (
        AxiAddrWidth_g              : natural range 16 to 64 := 32;
        AxiDataWidth_g              : natural range 16 to 64 := 32;
        UserDataWidth_g             : natural                := 16;
        ImplRead_g                  : boolean                := true;
        ImplWrite_g                 : boolean                := true;
        RamBehavior_g               : string                 := "RBW";
        runner_cfg                  : string
    );
end entity;

architecture sim of olo_axi_master_full_tb is

    -----------------------------------------------------------------------------------------------
    -- Fixed Generics
    -----------------------------------------------------------------------------------------------
    constant UserTransactionSizeBits_c : natural := 10;
    constant AxiMaxBeats_c             : natural := 32;
    constant DataFifoDepth_c           : natural := 16;
    constant AxiMaxOpenTransactions_c  : natural := 2;

    -----------------------------------------------------------------------------------------------
    -- AXI Definition
    -----------------------------------------------------------------------------------------------
    constant ByteWidth_c : integer := AxiDataWidth_g/8;

    subtype IdRange_c   is natural range -1 downto 0;
    subtype AddrRange_c is natural range AxiAddrWidth_g-1 downto 0;
    subtype UserRange_c is natural range 1 downto 0;
    subtype DataRange_c is natural range AxiDataWidth_g-1 downto 0;
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
    subtype CmdAddrRange_c is natural range AxiAddrWidth_g-1 downto 0;
    subtype CmdSizeRange_c is natural range UserTransactionSizeBits_c+CmdAddrRange_c'high downto CmdAddrRange_c'high+1;
    constant CmdLowLat_c : natural := CmdSizeRange_c'high+1;

    constant UserBytes_c : natural := UserDataWidth_g/8;
    constant AxiBytes_c  : natural := AxiDataWidth_g/8;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    type Response_t is (RespSuccess, RespError);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    -- Contral Sginal
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic := '0';
    -- Write Command Interface
    signal CmdWr_Addr   : std_logic_vector(AxiAddrWidth_g - 1 downto 0)            := (others => '0');
    signal CmdWr_Size   : std_logic_vector(UserTransactionSizeBits_c - 1 downto 0) := (others => '0');
    signal CmdWr_LowLat : std_logic                                                := '0';
    signal CmdWr_Valid  : std_logic                                                := '0';
    signal CmdWr_Ready  : std_logic;
    -- Read Command Interface
    signal CmdRd_Addr   : std_logic_vector(AxiAddrWidth_g - 1 downto 0)            := (others => '0');
    signal CmdRd_Size   : std_logic_vector(UserTransactionSizeBits_c - 1 downto 0) := (others => '0');
    signal CmdRd_LowLat : std_logic                                                := '0';
    signal CmdRd_Valid  : std_logic                                                := '0';
    signal CmdRd_Ready  : std_logic;
    -- Write Data
    signal Wr_Data      : std_logic_vector(UserDataWidth_g - 1 downto 0) := (others => '0');
    signal Wr_Valid     : std_logic                                      := '0';
    signal Wr_Ready     : std_logic;
    -- Read Data
    signal Rd_Data      : std_logic_vector(UserDataWidth_g - 1 downto 0);
    signal Rd_Valid     : std_logic;
    signal Rd_Ready     : std_logic;
    signal Rd_Last      : std_logic;
    -- Response
    signal Wr_Done      : std_logic;
    signal Wr_Error     : std_logic;
    signal Rd_Done      : std_logic;
    signal Rd_Error     : std_logic;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant AxiSlave_c     : olo_test_axi_slave_t := new_olo_test_axi_slave (
        data_width => AxiDataWidth_g,
        addr_width => AxiAddrWidth_g,
        id_width => 0
    );
    constant RdDataSlave_c  : axi_stream_slave_t   := new_axi_stream_slave (
        data_length => UserDataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant WrCmdMaster_c  : axi_stream_master_t  := new_axi_stream_master (
        data_length => AxiAddrWidth_g+UserTransactionSizeBits_c+1,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant RdCmdMaster_c  : axi_stream_master_t  := new_axi_stream_master (
        data_length => AxiAddrWidth_g+UserTransactionSizeBits_c+1,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant WrDataMaster_c : axi_stream_master_t  := new_axi_stream_master (
        data_length => UserDataWidth_g,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -- Apply a Command
    procedure pushCommand (
        signal net : inout network_t;
        CmdMaster  : axi_stream_master_t;
        CmdAddr    : unsigned;
        CmdSize    : integer;
        CmdLowLat  : std_logic := '0') is
        variable TData_v : std_logic_vector(CmdLowLat_c downto 0);
    begin
        TData_v(CmdAddrRange_c) := std_logic_vector(resize(CmdAddr, AxiAddrWidth_g));
        TData_v(CmdSizeRange_c) := toUslv(CmdSize, UserTransactionSizeBits_c);
        TData_v(CmdLowLat_c)    := CmdLowLat;
        push_axi_stream(net, CmdMaster, TData_v);
    end procedure;

    -- Apply Write Data
    procedure pushWrData (
        signal net : inout network_t;
        startValue : unsigned;
        increment  : natural := 1;
        beats      : natural := 1) is
        variable Data_v : unsigned(UserDataWidth_g-1 downto 0);
    begin
        Data_v := resize(startValue, UserDataWidth_g);

        -- Loop through data beats
        for i in 0 to beats-1 loop
            push_axi_stream(net, WrDataMaster_c, std_logic_vector(Data_v));
            Data_v := Data_v + increment;
        end loop;

    end procedure;

    -- Check REad DAta
    procedure expectRdData (
        signal net : inout network_t;
        startValue : unsigned;
        increment  : natural := 1;
        beats      : natural := 1) is
        variable Data_v : unsigned(UserDataWidth_g-1 downto 0);
        variable Last_v : std_logic := '0';
    begin
        Data_v := resize(startValue, UserDataWidth_g);

        -- Loop through beats
        for i in 0 to beats-1 loop
            -- Last is set on the last beat
            if i = beats-1 then
                Last_v := '1';
            end if;
            check_axi_stream(net, RdDataSlave_c, std_logic_vector(Data_v), blocking => false, tlast => Last_v, msg => "RdData " & integer'image(i));
            Data_v := Data_v + increment;
        end loop;

    end procedure;

    -- Expect Write Response
    procedure expectWrResponse (Response : Response_t) is
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

    -- Expect Read Response
    procedure expectRdResponse (Response : Response_t) is
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

    -- Cut off intra-word bits from the address
    function axiWordAddr (address : unsigned) return unsigned is
        variable Address_v : unsigned(AxiAddrWidth_g-1 downto 0) := address;
    begin
        Address_v(log2(AxiBytes_c)-1 downto 0) := (others => '0');
        return Address_v;
    end function;

    -- Convert counter data to a continuous vector (as required by the olo_axi_slave_vc)
    function dataAsVector (
        startValue      : unsigned;
        increment       : natural               := 1;
        beats           : natural               := 1) return unsigned is
        variable Vector_v : unsigned(beats*UserDataWidth_g-1 downto 0) := (others => '0');
        variable Data_v   : unsigned(UserDataWidth_g-1 downto 0)       := startValue;
    begin

        -- Loop through beats
        for i in 0 to beats-1 loop
            Vector_v((i+1)*UserDataWidth_g-1 downto i*UserDataWidth_g) := Data_v;
            Data_v                                                     := Data_v + increment;
        end loop;

        return Vector_v;
    end function;

    -- convert coutner data to a AXI aligned vector (as required by the olo_axi_slave_vc)
    -- The vector contains all AXI transactions (including bytes prior and after the addressed range)
    function dataAsVectorAligned (
        address         : unsigned;
        startValue      : unsigned;
        increment       : natural               := 1;
        bytes           : natural               := 1) return unsigned is
        -- constants
        constant Beats_c        : natural  := (bytes+UserBytes_c-1)/UserBytes_c;
        constant PrependBytes_c : natural  := to_integer(address(log2(AxiBytes_c)-1 downto 0));
        constant DataVector_c   : unsigned := dataAsVector(startValue, increment, Beats_c);
        constant AppendBytes_c  : natural  := (AxiBytes_c-((bytes+PrependBytes_c) mod AxiBytes_c)) mod AxiBytes_c;

        -- Variables
        variable Out_v : unsigned(bytes*8+PrependBytes_c*8+AppendBytes_c*8-1 downto 0) := (others => '0');
    begin
        Out_v := unsigned(zerosVector(AppendBytes_c*8)) & DataVector_c(8*bytes-1 downto 0) & unsigned(zerosVector(PrependBytes_c*8));
        return Out_v;
    end function;

    -- Generate strobes aligned with DataAsVectorAligned()
    function strbAsVectorAligned (
        address         : unsigned;
        bytes           : natural) return std_logic_vector is
        -- Constants
        constant PrependBytes_c : natural := to_integer(address(log2(AxiBytes_c)-1 downto 0));
        constant AppendBytes_c  : natural := (AxiBytes_c-((bytes+PrependBytes_c) mod AxiBytes_c)) mod AxiBytes_c;

        -- Variables
        variable Strb_v : std_logic_vector(bytes+PrependBytes_c+AppendBytes_c-1 downto 0) := (others => '1');
    begin
        Strb_v(PrependBytes_c-1 downto 0)                      := (others => '0');
        Strb_v(Strb_v'high downto Strb_v'length-AppendBytes_c) := (others => '0');
        return Strb_v;
    end function;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Addr_v      : unsigned(AxiAddrWidth_g -1 downto 0);
        variable Data_v      : unsigned(UserDataWidth_g-1 downto 0);
        variable AxiBeats_v  : natural;
        variable UserBeats_v : natural;
        variable DataBytes_v : natural;
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

            -- *** Single Byte Writes ***
            if run("SingleByteWrites") then
                if ImplWrite_g then

                    -- Loop through different offsets / alignments
                    for addrOffs in 0 to AxiBytes_c-1 loop
                        Addr_v := resize(x"0800"+addrOffs, AxiAddrWidth_g);
                        Data_v := resize(x"10"+addrOffs, UserDataWidth_g);
                        -- Slave
                        expect_single_write(net, AxiSlave_c, axiWordAddr(Addr_v),
                            dataAsVectorAligned(Addr_v, Data_v), strb => strbAsVectorAligned(Addr_v, 1));
                        -- Master
                        pushCommand(net, WrCmdMaster_c, Addr_v, 1);
                        pushWrData(net, Data_v);
                        -- Blocking
                        expectWrResponse(RespSuccess);
                    end loop;

                end if;
            end if;

            -- *** Single Byte Reads ***
            if run("SingleByteReads") then
                if ImplRead_g then

                    -- Loop through different offsets / alignments
                    for addrOffs in 0 to AxiBytes_c-1 loop
                        Addr_v := resize(x"1800"+addrOffs, AxiAddrWidth_g);
                        Data_v := resize(x"20"+addrOffs, UserDataWidth_g);
                        -- Slave
                        push_single_read(net, AxiSlave_c, axiWordAddr(Addr_v), dataAsVectorAligned(Addr_v, Data_v));
                        -- Master
                        pushCommand(net, RdCmdMaster_c, Addr_v, 1);
                        -- Blocking
                        expectRdResponse(RespSuccess);
                        expectRdData(net, Data_v, beats => 1);
                    end loop;

                end if;
            end if;

            -- *** Burst Writes ***
            if run("BurstWrites") then
                if ImplWrite_g then

                    -- Loop through different offsets / alignments
                    for addrOffs in 0 to AxiBytes_c-1 loop

                        -- Loop through transfer sizes
                        for dataBytes in 2*AxiBytes_c to 3*AxiBytes_c-1 loop
                            Addr_v      := resize(x"0800"+addrOffs, AxiAddrWidth_g);
                            Data_v      := resize(x"10"+dataBytes, UserDataWidth_g);
                            AxiBeats_v  := to_integer(axiWordAddr(Addr_v+dataBytes-1)-axiWordAddr(Addr_v))/AxiBytes_c+1;
                            UserBeats_v := (dataBytes+UserBytes_c-1)/UserBytes_c;
                            -- Slave
                            expect_aw (net, AxiSlave_c, axiWordAddr(Addr_v), len => AxiBeats_v, burst => AxiBurst_Incr_c);
                            expect_w_arbitrary (net, AxiSlave_c, AxiBeats_v,
                                                dataAsVectorAligned(Addr_v, Data_v, bytes => dataBytes),
                                                strbAsVectorAligned(Addr_v, dataBytes));
                            push_b(net, AxiSlave_c, resp => AxiResp_Okay_c);
                            -- Master
                            pushCommand(net, WrCmdMaster_c, Addr_v, dataBytes);
                            pushWrData(net, Data_v, beats => UserBeats_v);
                            -- Blocking
                            expectWrResponse(RespSuccess);
                        end loop;

                    end loop;

                end if;
            end if;

            if run("BurstWritesPipelined") then
                if ImplWrite_g then

                    -- Do 3 accesses
                    for i in 0 to 2 loop
                        Addr_v      := resize(x"08FF"+i, AxiAddrWidth_g);
                        Data_v      := resize(x"10"+16*i, UserDataWidth_g);
                        DataBytes_v := 2*AxiBytes_c;
                        AxiBeats_v  := to_integer(axiWordAddr(Addr_v+DataBytes_v-1)-axiWordAddr(Addr_v))/AxiBytes_c+1;
                        UserBeats_v := (DataBytes_v+UserBytes_c-1)/UserBytes_c;
                        -- Slave
                        expect_aw (net, AxiSlave_c, axiWordAddr(Addr_v), len => AxiBeats_v, burst => AxiBurst_Incr_c);
                        expect_w_arbitrary (net, AxiSlave_c, AxiBeats_v,
                                            dataAsVectorAligned(Addr_v, Data_v, bytes => DataBytes_v),
                                            strbAsVectorAligned(Addr_v, DataBytes_v));
                        push_b(net, AxiSlave_c, resp => AxiResp_Okay_c);
                        -- Master
                        pushCommand(net, WrCmdMaster_c, Addr_v, DataBytes_v);
                        pushWrData(net, Data_v, beats => UserBeats_v);
                    end loop;

                    -- Expect the 3 responses
                    for i in 0 to 2 loop
                        expectWrResponse(RespSuccess);
                    end loop;

                end if;
            end if;

            if run("BurstWritesPipelinedBackpressure") then
                if ImplWrite_g then

                    -- Do 3 accesses
                    for i in 0 to 2 loop
                        Addr_v      := resize(x"08FF"+i, AxiAddrWidth_g);
                        Data_v      := resize(x"10"+16*i, UserDataWidth_g);
                        DataBytes_v := 12*AxiBytes_c;
                        AxiBeats_v  := to_integer(axiWordAddr(Addr_v+DataBytes_v-1)-axiWordAddr(Addr_v))/AxiBytes_c+1;
                        UserBeats_v := (DataBytes_v+UserBytes_c-1)/UserBytes_c;
                        -- Slave
                        expect_aw (net, AxiSlave_c, axiWordAddr(Addr_v), len => AxiBeats_v, burst => AxiBurst_Incr_c);
                        expect_w_arbitrary (net, AxiSlave_c, AxiBeats_v,
                                            dataAsVectorAligned(Addr_v, Data_v, bytes => DataBytes_v),
                                            strbAsVectorAligned(Addr_v, DataBytes_v), delay => 200 ns, beat_delay => 100 ns);
                        push_b(net, AxiSlave_c, resp => AxiResp_Okay_c);
                        -- Master
                        pushCommand(net, WrCmdMaster_c, Addr_v, DataBytes_v);
                        pushWrData(net, Data_v, beats => UserBeats_v);
                    end loop;

                    -- Expect all responses
                    for i in 0 to 2 loop
                        expectWrResponse(RespSuccess);
                    end loop;

                end if;
            end if;

            -- *** Burst Reads ***
            if run("BurstReads") then
                if ImplRead_g then

                    -- Loop through different offsets / alignments
                    for addrOffs in 0 to AxiBytes_c-1 loop

                        -- Loop through transfer sizes
                        for dataBytes in 2*AxiBytes_c to 3*AxiBytes_c-1 loop
                            Addr_v      := resize(x"1800"+addrOffs, AxiAddrWidth_g);
                            Data_v      := resize(x"20"+dataBytes, UserDataWidth_g);
                            AxiBeats_v  := to_integer(axiWordAddr(Addr_v+dataBytes-1)-axiWordAddr(Addr_v))/AxiBytes_c+1;
                            UserBeats_v := (dataBytes+UserBytes_c-1)/UserBytes_c;
                            -- Slave
                            expect_ar (net, AxiSlave_c, axiWordAddr(Addr_v), len => AxiBeats_v, burst => AxiBurst_Incr_c);
                            push_r_arbitrary (net, AxiSlave_c, AxiBeats_v, dataAsVectorAligned(Addr_v, Data_v, bytes => dataBytes));
                            -- Master
                            pushCommand(net, RdCmdMaster_c, Addr_v, dataBytes);
                            -- Blocking
                            expectRdResponse(RespSuccess);
                            expectRdData(net, Data_v, beats => UserBeats_v);
                        end loop;

                    end loop;

                end if;
            end if;

            if run("BurstReadsPipelined") then
                if ImplRead_g then

                    -- do 3 accesses
                    for i in 0 to 2 loop
                        Addr_v      := resize(x"08FF"+i, AxiAddrWidth_g);
                        Data_v      := resize(x"10"+16*i, UserDataWidth_g);
                        DataBytes_v := 2*AxiBytes_c;
                        AxiBeats_v  := to_integer(axiWordAddr(Addr_v+DataBytes_v-1)-axiWordAddr(Addr_v))/AxiBytes_c+1;
                        UserBeats_v := (DataBytes_v+UserBytes_c-1)/UserBytes_c;
                        -- Slave
                        expect_ar (net, AxiSlave_c, axiWordAddr(Addr_v), len => AxiBeats_v, burst => AxiBurst_Incr_c);
                        push_r_arbitrary (net, AxiSlave_c, AxiBeats_v, dataAsVectorAligned(Addr_v, Data_v, bytes => DataBytes_v));
                        -- Master
                        pushCommand(net, RdCmdMaster_c, Addr_v, DataBytes_v);
                        expectRdData(net, Data_v, beats => UserBeats_v);
                    end loop;

                    -- Expect all responses
                    for i in 0 to 2 loop
                        expectRdResponse(RespSuccess);
                    end loop;

                end if;
            end if;

            -- Wait for idle
            wait_until_idle(net, as_sync(AxiSlave_c));
            wait_until_idle(net, as_sync(RdDataSlave_c));
            wait_until_idle(net, as_sync(WrCmdMaster_c));
            wait_until_idle(net, as_sync(RdCmdMaster_c));
            wait_until_idle(net, as_sync(WrDataMaster_c));
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
    i_dut : entity olo.olo_axi_master_full
        generic map (
            AxiAddrWidth_g              => AxiAddrWidth_g,
            AxiDataWidth_g              => AxiDataWidth_g,
            AxiMaxBeats_g               => AxiMaxBeats_c,
            AxiMaxOpenTransactions_g    => AxiMaxOpenTransactions_c,
            -- User Configuration
            UserTransactionSizeBits_g   => UserTransactionSizeBits_c,
            DataFifoDepth_g             => DataFifoDepth_c,
            UserDAtaWidth_g             => UserDataWidth_g,
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
            M_Axi_AwAddr   => AxiMs.aw_addr,
            M_Axi_AwValid  => AxiMs.aw_valid,
            M_Axi_AwReady  => AxiSm.aw_ready,
            M_Axi_AwLen    => AxiMs.aw_len,
            M_Axi_AwSize   => AxiMs.aw_size,
            M_Axi_AwBurst  => AxiMs.aw_burst,
            M_Axi_AwLock   => AxiMs.aw_lock,
            M_Axi_AwCache  => AxiMs.aw_cache,
            M_Axi_AwProt   => AxiMs.aw_prot,
            -- AXI Write Data Channel
            M_Axi_WData    => AxiMs.w_data,
            M_Axi_WStrb    => AxiMs.w_strb,
            M_Axi_WValid   => AxiMs.w_valid,
            M_Axi_WReady   => AxiSm.w_ready,
            M_Axi_WLast    => AxiMs.w_last,
            -- AXI Write Response Channel
            M_Axi_BResp    => AxiSm.b_resp,
            M_Axi_BValid   => AxiSm.b_valid,
            M_Axi_BReady   => AxiMs.b_ready,
            -- AXI Read Address Channel
            M_Axi_ArAddr   => AxiMs.ar_addr,
            M_Axi_ArValid  => AxiMs.ar_valid,
            M_Axi_ArReady  => AxiSm.ar_ready,
            M_Axi_ArLen    => AxiMs.ar_len,
            M_Axi_ArSize   => AxiMs.ar_size,
            M_Axi_ArBurst  => AxiMs.ar_burst,
            M_Axi_ArLock   => AxiMs.ar_lock,
            M_Axi_ArCache  => AxiMs.ar_cache,
            M_Axi_ArProt   => AxiMs.ar_prot,
            -- AXI Read Data Channel
            M_Axi_RData    => AxiSm.r_data,
            M_Axi_RValid   => AxiSm.r_valid,
            M_Axi_RReady   => AxiMs.r_ready,
            M_Axi_RResp    => AxiSm.r_resp,
            M_Axi_RLast    => AxiSm.r_last
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    i_slave_vc : entity work.olo_test_axi_slave_vc
        generic map (
            Instance => AxiSlave_c
        )
        port map (
            Clk    => Clk,
            Axi_Ms => AxiMs,
            Axi_Sm => AxiSm
        );

    vc_rd_data : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => RdDataSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Rd_Valid,
            TReady => Rd_Ready,
            TData  => Rd_Data,
            TLast  => Rd_Last
        );

    b_wr_cmd : block is
        signal TDataLocal : std_logic_vector(CmdLowLat_c downto 0);
    begin

        vc_wr_cmd : entity vunit_lib.axi_stream_master
            generic map (
                Master => WrCmdMaster_c
            )
            port map (
                AClk   => Clk,
                TValid => CmdWr_Valid,
                TReady => CmdWr_Ready,
                TData  => TDataLocal
            );

        CmdWr_Addr   <= TDataLocal(CmdAddrRange_c);
        CmdWr_Size   <= TDataLocal(CmdSizeRange_c);
        CmdWr_LowLat <= TDataLocal(CmdLowLat_c);
    end block;

    b_rd_cmd : block is
        signal TDataLocal : std_logic_vector(CmdLowLat_c downto 0);
    begin

        vc_rd_cmd : entity vunit_lib.axi_stream_master
            generic map (
                Master => RdCmdMaster_c
            )
            port map (
                Aclk   => Clk,
                TValid => CmdRd_Valid,
                TReady => CmdRd_Ready,
                TData  => TDataLocal
            );

        CmdRd_Addr   <= TDataLocal(CmdAddrRange_c);
        CmdRd_Size   <= TDataLocal(CmdSizeRange_c);
        CmdRd_LowLat <= TDataLocal(CmdLowLat_c);
    end block;

    b_wr_data : block is
    begin

        vc_wr_data : entity vunit_lib.axi_stream_master
            generic map (
                Master => WrDataMaster_c
            )
            port map (
                AClk   => Clk,
                TValid => Wr_Valid,
                TReady => Wr_Ready,
                TData  => Wr_Data
            );

    end block;

end architecture;
