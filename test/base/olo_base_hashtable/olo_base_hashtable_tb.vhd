library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    use vunit_lib.check_pkg.all;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_base_hashtable_tb is
    generic (
        runner_cfg : string;
        Hash_g : string := "LCG";
        ClearAfterReset_g : boolean := true
    );
end entity;

architecture tb of olo_base_hashtable_tb is

    constant Depth_g : positive := 8;
    constant KeyWidth_g : positive := 16;
    constant ValueWidth_g : positive := 32;
    constant Hash_Lcg_Mult_g : positive := 1103515245;
    constant Hash_Lcg_Incr_g : positive := 12345;
    constant RamStyle_g : string := "auto";
    constant RamBehavior_g : string := "RBW";

    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master(
        data_length => KeyWidth_g + ValueWidth_g,
        user_length => 5
    );
    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave(
        data_length => KeyWidth_g + ValueWidth_g,
        user_length => 1
    );

    constant TEST_KEY : std_logic_vector(31 downto 0) := x"01234567";
    constant TEST_VALUE : std_logic_vector(31 downto 0) := x"89ABCDEF";

    type TestKeys_t is array (natural range<>) of std_logic_vector(KeyWidth_g-1 downto 0);
    type TestValues_t is array (natural range<>) of std_logic_vector(ValueWidth_g-1 downto 0);

    signal Clk : std_logic := '0';
    signal Rst : std_logic := '0';

    constant Clk_Frequency_c : real    := 100.0e6;
    constant Clk_Period_c    : time    := (1 sec) / Clk_Frequency_c;

    constant PAIRS_IDX : integer := log2ceil(Depth_g);

    signal In_Key : std_logic_vector(KeyWidth_g-1 downto 0) := (others => '0');
    signal In_Value : std_logic_vector(ValueWidth_g-1 downto 0) := (others => '0');
    signal Out_Key : std_logic_vector(KeyWidth_g-1 downto 0) := (others => '0');
    signal Out_Value : std_logic_vector(ValueWidth_g-1 downto 0) := (others => '0');
    signal In_Write : std_logic := '0';
    signal In_Read : std_logic := '0';
    signal In_Remove : std_logic := '0';
    signal In_Clear : std_logic := '0';
    signal In_NextKey : std_logic := '0';
    signal In_Valid : std_logic := '0';
    signal In_Ready : std_logic := '0';
    signal Out_Valid : std_logic := '0';
    signal Out_Ready : std_logic := '0';
    signal Out_KeyUnknown : std_logic := '0';
    signal Status_Full : std_logic := '0';
    signal Status_Pairs : std_logic_vector(PAIRS_IDX downto 0) := (others => '0');

    constant OP_NB : integer := 5;
    constant OP_WRITE : std_logic_vector(OP_NB-1 downto 0) := "10000";
    constant OP_WRITE_BIT : integer := 4;
    constant OP_READ : std_logic_vector(OP_NB-1 downto 0) := "01000";
    constant OP_READ_BIT : integer := 3;
    constant OP_REMOVE : std_logic_vector(OP_NB-1 downto 0) := "00100";
    constant OP_REMOVE_BIT : integer := 2;
    constant OP_CLEAR : std_logic_vector(OP_NB-1 downto 0) := "00010";
    constant OP_CLEAR_BIT : integer := 1;
    constant OP_NEXTKEY : std_logic_vector(OP_NB-1 downto 0) := "00001";
    constant OP_NEXTKEY_BIT : integer := 0;

    signal maxis_tdata : std_logic_vector(KeyWidth_g+ValueWidth_g-1 downto 0);
    signal maxis_tuser : std_logic_vector(OP_NB-1 downto 0);

    procedure HtAction (signal net : inout network_t;
                        Action : std_logic_vector(OP_NB-1 downto 0);
                        Key : std_logic_vector(KeyWidth_g-1 downto 0);
                        Value : std_logic_vector(ValueWidth_g-1 downto 0);
                        blocking : boolean) is
    begin
        push_axi_stream(net, AxisMaster_c, (Key & Value), tuser => Action);
        if blocking then
            wait until rising_edge(In_Ready);
        end if;
    end procedure;

    procedure HtWrite (signal net : inout network_t;
                        WrKey : std_logic_vector(KeyWidth_g-1 downto 0);
                        WrValue : std_logic_vector(ValueWidth_g-1 downto 0);
                        blocking : boolean) is
    begin
        HtAction(net, OP_WRITE, WrKey, WrValue, blocking);
    end procedure;

    procedure HtRead (signal net : inout network_t;
                        RdKey : std_logic_vector(KeyWidth_g-1 downto 0);
                        blocking : boolean) is
    begin
        HtAction(net, OP_READ, RdKey, zerosVector(ValueWidth_g), blocking);
    end procedure;

    procedure HtRemove (signal net : inout network_t;
                        RmKey : std_logic_vector(KeyWidth_g-1 downto 0);
                        blocking : boolean) is
    begin
        HtAction(net, OP_REMOVE, RmKey, zerosVector(ValueWidth_g), blocking);
    end procedure;

    procedure HtClear (signal net : inout network_t;
                        blocking : boolean) is
    begin
        HtAction(net, OP_CLEAR, zerosVector(KeyWidth_g), zerosVector(ValueWidth_g), blocking);
    end procedure;

    procedure HtNextKey (signal net : inout network_t;
                        blocking : boolean) is
    begin
        HtAction(net, OP_NEXTKEY, zerosVector(KeyWidth_g), zerosVector(ValueWidth_g), blocking);
    end procedure;

    procedure HtReadCheck(signal net : inout network_t;
                            checkValue : std_logic_vector(ValueWidth_g-1 downto 0);
                            checkMsg : string) is
        variable streamData : std_logic_vector(ValueWidth_g+KeyWidth_g-1 downto 0);
        variable readValue : std_logic_vector(ValueWidth_g-1 downto 0);
        variable tuserDiscard : std_logic;
    begin
        pop_axi_stream(net, AxisSlave_c, streamData, tuserDiscard);
        readValue := streamData(ValueWidth_g-1 downto 0);
        check_equal(readValue, checkValue, checkMsg);
    end procedure;

    procedure HtNextKeyGet(signal net : inout network_t;
                            Key : out std_logic_vector(KeyWidth_g-1 downto 0)) is
        variable streamData : std_logic_vector(ValueWidth_g+KeyWidth_g-1 downto 0);
        variable tuserDiscard : std_logic;
    begin
        pop_axi_stream(net, AxisSlave_c, streamData, tuserDiscard);
        Key := streamData(KeyWidth_g+ValueWidth_g-1 downto ValueWidth_g);
    end procedure;

begin

    assert KeyWidth_g <= 32
        report "Only key widths up to 32 are possible for testbench";
    assert ValueWidth_g <= 32
        report "Only value widths up to 32 are possible for testbench";

    i_dut: entity olo.olo_base_hashtable
    generic map (
        Depth_g => Depth_g, 
        KeyWidth_g => KeyWidth_g, 
        ValueWidth_g => ValueWidth_g, 
        Hash_g => Hash_g, 
        RamStyle_g => RamStyle_g, 
        RamBehavior_g => RamBehavior_g, 
        ClearAfterReset_g => ClearAfterReset_g
    )
    port map (
        Clk => Clk,
        Rst => Rst,
        In_Key => In_Key,
        In_Value => In_Value,
        Out_Key => Out_Key,
        Out_Value => Out_Value,
        In_Write => In_Write,
        In_Read => In_Read,
        In_Remove => In_Remove,
        In_Clear => In_Clear,
        In_NextKey => In_NextKey,
        In_Valid => In_Valid,
        In_Ready => In_Ready,
        Out_Valid => Out_Valid,
        Out_Ready => Out_Ready,
        Out_KeyUnknown => Out_KeyUnknown,
        Status_Full => Status_Full,
        Status_Pairs => Status_Pairs
    );

    axis_master : entity vunit_lib.axi_stream_master
    generic map (
        master => AxisMaster_c
    )
    port map (
        aclk => Clk,
        tvalid => In_Valid,
        tready => In_Ready,
        tdata => maxis_tdata, -- In_Key | In_Value
        tuser => maxis_tuser -- In_Write | In_Read | In_Remove | In_Clear | In_NextKey
    );

    In_Key <= maxis_tdata(KeyWidth_g+ValueWidth_g-1 downto ValueWidth_g);
    In_Value <= maxis_tdata(ValueWidth_g-1 downto 0);
    In_Write <= maxis_tuser(OP_WRITE_BIT);
    In_Read <= maxis_tuser(OP_READ_BIT);
    In_Remove <= maxis_tuser(OP_REMOVE_BIT);
    In_Clear <= maxis_tuser(OP_CLEAR_BIT);
    In_NextKey <= maxis_tuser(OP_NEXTKEY_BIT);

    axis_slave : entity vunit_lib.axi_stream_slave
    generic map (
        slave => AxisSlave_c
    )
    port map (
        aclk => Clk,
        tvalid => Out_Valid,
        tready => Out_Ready,
        tdata => (Out_Key & Out_Value),
        tuser => (0 => Out_KeyUnknown)
    );

    Clk <= not Clk after 0.5 * Clk_Period_c;

    --Show passing tests messages
    show(get_logger(default_checker), display_handler, pass);
    test_runner_watchdog(runner, 5 us);

    main : process
    variable storedPairs : integer := 0;
    variable KeyValid : std_logic := '0';
    variable KeysFound : integer := 0;
    variable TestKeys : TestKeys_t(Depth_g downto 0) := (others => (others => '0'));
    variable TestValues : TestValues_t(Depth_g downto 0) := (others => (others => '0'));
    variable KeyCheck : std_logic_vector(KeyWidth_g-1 downto 0);
    variable TestKeyFound : std_logic_vector(Depth_g-1 downto 0) := (others => '0');
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
                --Check Reset Values
                if ClearAfterReset_g then
                    check(In_Ready = '0', "Hashtable clearing after reset");
                else
                    check(In_Ready = '1', "Hashtable ready after reset");
                end if;
                check(Out_Valid = '0', "No data output after reset");
                check(Status_Full = '0', "Hashtable not full after reset");
                check_equal(Status_Pairs, 0, "Hashtable empty after reset");
                
            elsif run("TestFeatures") then
                --Test all features (filled hashtable)
                --Generate random pairs (one more than Depth_g to prepare write-when-full test)
                TestKeys(0) := TEST_KEY(KeyWidth_g-1 downto 0);
                TestValues(0) := TEST_VALUE(ValueWidth_g-1 downto 0);
                for i in 1 to Depth_g loop
                    TestKeys(i) := std_logic_vector(lcgPrng(
                        unsigned(TestKeys(i-1)), 
                        Hash_Lcg_Mult_g, 
                        Hash_Lcg_Incr_g,
                        KeyWidth_g));
                    TestValues(i) := std_logic_vector(lcgPrng(
                        unsigned(TestValues(i-1)), 
                        Hash_Lcg_Mult_g, 
                        Hash_Lcg_Incr_g,
                        ValueWidth_g));
                    report "Key " & integer'image(i) & ": " & 
                        to_hstring(TestKeys(i));
                    report "Value " & integer'image(i) & ": " & 
                        to_hstring(TestValues(i));
                end loop;
                --Wait for hashtable to be ready
                --NOTE: This behaviour isn't technically standard AXI-STREAM protocol as we are waiting for a slave
                --interface to be ready. The standard specifies that a slave can wait for a master (valid = '1') but
                --not the inverse. In this testbench, however, we need the hashtable to be ready before sending
                --requests but keep in mind that is not how it should be used in HW designs
                wait until In_Ready = '1';
                --Store all pairs
                report "Store all pairs";
                storedPairs := 0;
                for i in 0 to Depth_g-1 loop
                    check(Status_Full = '0', "Hashtable not full");
                    HtWrite(net, TestKeys(i), TestValues(i), true);
                    check(Out_KeyUnknown = '1', "Writing new key");
                    storedPairs := storedPairs + 1;
                    check_equal(Status_Pairs, storedPairs, "Coherent pair counting");
                end loop;
                wait until rising_edge(Clk);
                check(Status_Full = '1', "Hashtable full");
                --Read all pairs
                report "Read all pairs";
                for i in 0 to Depth_g-1 loop
                    -- Non-blocking read as HtReadCheck will set axi-stream slave ready
                    HtRead(net, TestKeys(i), false);
                    --Must check value before KeyUnknown as read operation cannot finish without output being read
                    HtReadCheck(net, TestValues(i), "Check output value");
                    wait until rising_edge(In_Ready);
                    check(Out_KeyUnknown = '0', "Coherent value search result");
                end loop;
                --Get all keys
                report "Get all keys";
                for i in 0 to to_integer(unsigned(Status_Pairs))-1 loop
                    --Recover Next Key
                    --Non-blocking NextKey search as output read (necessary for operation to finish) is
                    --setup in HtNextKeyGet
                    HtNextKey(net, false);
                    HtNextKeyGet(net, KeyCheck);
                    --Check that key exists and hasn't been found before
                    find_key_loop: for j in 0 to Depth_g-1 loop
                        if TestKeys(j) = KeyCheck and TestKeyFound(i) = '0' then
                            KeyValid := '1';
                            TestKeyFound(i) := '1';
                            KeysFound := KeysFound + 1;
                            exit find_key_loop;
                        end if;
                    end loop;
                    check(KeyValid = '1', "Check key valid");
                end loop;
                --Check correct amount of keys were found
                check_equal(KeysFound, Depth_g, "Check all keys found");
                --Modify existing key
                report "Modify existing key";
                TestValues(0) := std_logic_vector(lcgPrng(
                    unsigned(TestValues(Depth_g-1)), 
                    Hash_Lcg_Mult_g, 
                    Hash_Lcg_Incr_g,
                    ValueWidth_g));
                --Try to write new value on existing key
                report "Try to write new value on existing key";
                HtWrite(net, TestKeys(0), TestValues(0), true);
                check(Out_KeyUnknown = '0', "Check key known");
                --Check value overridden
                report "Check value overridden";
                --Non-blocking read to prevent lock (output read by HtReadCheck necessary for read op to finish)
                HtRead(net, TestKeys(0), false);
                HtReadCheck(net, TestValues(0), "Check value overridden");
                wait until In_Ready = '1';
                --Try to write new key
                report "Try to write new key";
                HtWrite(net, TestKeys(Depth_g), TestValues(Depth_g), true);
                check(Out_KeyUnknown = '1', "Check key unknown");
                --Check pair ignored
                report "Check pair ignored";
                --Blocking read as it is expected to fail (no output read necessary to finish)
                HtRead(net, TestKeys(Depth_g), true);
                check(Out_KeyUnknown = '1', "Check value ignored");
                --Remove half keys
                report "Remove half keys";
                for i in 0 to (Depth_g/2)-1 loop
                    HtRemove(net, TestKeys(i), true);
                    check(Out_KeyUnknown = '0', "Check key removed is known");
                end loop;
                --Check coherent key search output
                report "Check coherent key search output";
                for i in 0 to Depth_g-1 loop
                    --Non-blocking read to prevent lock
                    HtRead(net, TestKeys(i), false);
                    if i < Depth_g/2 then --Removed pairs, check unknown
                        wait until In_Ready = '1';
                        check(Out_KeyUnknown = '1', "Coherent value search result");
                    else -- Not removed pairs, check valid
                        --Must check value before KeyUnknown (See previous similar reads)
                        HtReadCheck(net, TestValues(i), "Check output value");
                        wait until In_Ready = '1';
                        check(Out_KeyUnknown = '0', "Coherent value search result");
                    end if;
                end loop;
                --Clear all keys
                report "Clear all keys";
                HtClear(net, true);
                --Check coherent key search output
                report "Check coherent key search output";
                for i in 0 to Depth_g-1 loop
                    --Blocking reads (all expected to fail so no need to read output)
                    HtRead(net, TestKeys(i), true);
                    check(Out_KeyUnknown = '1', "Coherent value search result");
                end loop;
            
            elsif run("AxiStreamTimings") then
                --Prepare test pairs
                TestKeys(0) := TEST_KEY(KeyWidth_g-1 downto 0);
                TestValues(0) := TEST_VALUE(ValueWidth_g-1 downto 0);
                TestKeys(1) := std_logic_vector(lcgPrng(
                    unsigned(TestKeys(0)), 
                    Hash_Lcg_Mult_g, 
                    Hash_Lcg_Incr_g,
                    KeyWidth_g));
                TestValues(1) := std_logic_vector(lcgPrng(
                    unsigned(TestValues(0)), 
                    Hash_Lcg_Mult_g, 
                    Hash_Lcg_Incr_g,
                    ValueWidth_g));
                --Wait for hashtable to be ready
                wait until In_Ready = '1';
                --Send 2 non-blocking write transactions
                for i in 0 to 1 loop
                    HtWrite(net, TestKeys(i), TestValues(i), false);
                end loop;
                --Wait for write transactions
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait until In_Ready = '1';
                --Send 2 non-blocking read transactions
                for i in 0 to 1 loop
                    HtRead(net, TestKeys(i), false);
                end loop;
                --Wait for a moment (enough for hashtable to have to hold read transaction)
                wait for 200 ns;
                --Blocking read (and result check) for hashtable output (second read waits for hashtable)
                for i in 0 to 1 loop
                    HtReadCheck(net, TestValues(i), "Timing values check");
                end loop;
            
            end if;

            wait for 1 us;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
