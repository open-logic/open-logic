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
        Depth_g : positive := 8;
        KeyWidth_g : positive := 16;
        ValueWidth_g : positive := 32;
        Hash_g : string := "CRC32";
        Hash_Lcg_Mult_g : positive := 1103515245;
        Hash_Lcg_Incr_g : positive := 12345;
        RamStyle_g : string := "auto";
        RamBehavior_g : string := "RBW";
        ClearAfterReset_g : boolean := true
    );
end entity;

architecture tb of olo_base_hashtable_tb is

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
    constant OP_READ : std_logic_vector(OP_NB-1 downto 0) := "01000";
    constant OP_REMOVE : std_logic_vector(OP_NB-1 downto 0) := "00100";
    constant OP_CLEAR : std_logic_vector(OP_NB-1 downto 0) := "00010";
    constant OP_NEXTKEY : std_logic_vector(OP_NB-1 downto 0) := "00001";

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
    begin
        pop_axi_stream(net, AxisSlave_c, streamData, open);
        readValue := streamData(ValueWidth_g-1 downto 0);
        check_equal(readValue, checkValue, checkMsg);
    end procedure;

    procedure HtNextKeyGet(signal net : inout network_t;
                            Key : out std_logic_vector(ValueWidth_g-1 downto 0)) is
        variable streamData : std_logic_vector(ValueWidth_g+KeyWidth_g-1 downto 0);
    begin
        pop_axi_stream(net, AxisSlave_c, streamData, open);
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
        tdata => (In_Key & In_Value),
        tuser => (In_Write & In_Read & In_Remove & In_Clear & In_NextKey)
    );
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
                
            elsif run("MultiplePairs") then
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
                        integer'image(to_integer(unsigned(TestKeys(i))));
                    report "Value " & integer'image(i) & ": " & 
                        integer'image(to_integer(unsigned(TestValues(i))));
                end loop;
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
                    HtRead(net, TestValues(i), true);
                    check(Out_KeyUnknown = '0', "Coherent value search result");
                    HtReadCheck(net, TestValues(i), "Check output value");
                    wait until rising_edge(In_Ready);
                end loop;
                --Get all keys
                report "Get all keys";
                for i in 0 to to_integer(unsigned(Status_Pairs))-1 loop
                    --Recover Next Key
                    HtNextKey(net, true);
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
                HtRead(net, TestKeys(0), true);
                HtReadCheck(net, TestValues(0), "Check value overridden");
                --Try to write new key
                report "Try to write new key";
                HtWrite(net, TestKeys(Depth_g), TestValues(Depth_g), true);
                check(Out_KeyUnknown = '1', "Check key unknown");
                --Check pair ignored
                report "Check pair ignored";
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
                    HtRead(net, TestKeys(i), true);
                    if i < Depth_g/2 then --Removed pairs, check unknown
                        check(Out_KeyUnknown = '1', "Coherent value search result");
                    else -- Not removed pairs, check valid
                        check(Out_KeyUnknown = '0', "Coherent value search result");
                        HtReadCheck(net, TestValues(i), "Check output value");
                    end if;
                end loop;
                --Clear all keys
                report "Clear all keys";
                HtClear(net, true);
                --Check coherent key search output
                report "Check coherent key search output";
                for i in 0 to Depth_g-1 loop
                    HtRead(net, TestKeys(i), true);
                    check(Out_KeyUnknown = '1', "Coherent value search result");
                end loop;
            end if;

            wait for 1 us;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
