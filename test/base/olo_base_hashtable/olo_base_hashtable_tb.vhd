library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    use vunit_lib.check_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_base_hashtable_tb is
    generic (
        runner_cfg : string;
        Depth_g : positive := 8;
        KeyWidth_g : positive := 16;
        ValueWidth_g : positive := 32;
        Hash_g : string := "LCG";
        LcgMult_g : positive := 1103515245;
        LcgIncr_g : positive := 12345;
        RamStyle_g : string := "auto";
        RamBehavior_g : string := "RBW";
        ClearAfterReset_g : boolean := true
    );
end entity;

architecture tb of olo_base_hashtable_tb is
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
    signal In_OpValid : std_logic := '0';
    signal Out_OpReady : std_logic := '0';
    signal Out_DataValid : std_logic := '0';
    signal In_DataReady : std_logic := '0';
    signal Out_KeyUnknown : std_logic := '0';
    signal Out_Full : std_logic := '0';
    signal Out_Pairs : std_logic_vector(PAIRS_IDX downto 0) := (others => '0');

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
        In_OpValid => In_OpValid,
        Out_OpReady => Out_OpReady,
        Out_DataValid => Out_DataValid,
        In_DataReady => In_DataReady,
        Out_KeyUnknown => Out_KeyUnknown,
        Out_Full => Out_Full,
        Out_Pairs => Out_Pairs
    );

    Clk <= not Clk after 0.5 * Clk_Period_c;

    --Show passing tests messages
    show(get_logger(default_checker), display_handler, pass);
    test_runner_watchdog(runner, 5 us);

    main : process
    variable storedPairs : integer := 0;
    variable KeyValid : std_logic := '0';
    variable KeysFound : integer := 0;
    variable TestKeys : TestKeys_t(Depth_g-1 downto 0) := (others => (others => '0'));
    variable TestValues : TestValues_t(Depth_g-1 downto 0) := (others => (others => '0'));
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

            if run("SinglePair") then 
                --Tests with single key-value pair
                --Check Reset Values
                if ClearAfterReset_g then
                    check(Out_OpReady = '0', "Hashtable clearing after reset");
                else
                    check(Out_OpReady = '1', "Hashtable ready after reset");
                end if;
                check(Out_DataValid = '0', "No data output after reset");
                check(Out_Full = '0', "Hashtable not full after reset");
                check_equal(Out_Pairs, 0, "Hashtable empty after reset");
                --Request write
                In_OpValid <= '1';
                In_Write <= '1';
                In_Key <= TEST_KEY(In_Key'range);
                In_Value <= TEST_VALUE(In_Value'range);
                --Wait for hashtable to be ready
                wait until rising_edge(Clk);
                if Out_OpReady /= '1' then
                    wait until rising_edge(Out_OpReady);
                    wait until rising_edge(Clk);
                end if;
                In_Write <= '0';
                --Wait till write done
                wait until rising_edge(Out_OpReady);
                wait until rising_edge(Clk);
                --Check that key wasn't found
                check(Out_KeyUnknown = '1', "Writing non-existing key");
                --Check that hashtable now contains 1 pair
                check_equal(Out_Pairs, 1, "Coherent pair counting");
                --Request read with same key
                In_Read <= '1';
                wait until rising_edge(Clk);
                In_Read <= '0';
                --Wait till value output
                In_DataReady <= '1';
                wait until rising_edge(Clk);
                if Out_DataValid /= '1' then
                    wait until rising_edge(Out_DataValid);
                    wait until rising_edge(Clk);
                end if;
                In_DataReady <= '0';
                --Check that value was found and is correct
                check(Out_KeyUnknown = '0', "Reading existing key");
                check_equal(Out_Value, TEST_VALUE(ValueWidth_g-1 downto 0), "Coherent read value");
                --Request key output
                In_NextKey <= '1';
                wait until rising_edge(Clk);
                if Out_OpReady /= '1' then
                    wait until rising_edge(Out_OpReady);
                    wait until rising_edge(Clk);
                end if;
                In_NextKey <= '0';
                --Wait till output
                In_DataReady <= '1';
                wait until rising_edge(Clk);
                if Out_DataValid /= '1' then
                    wait until rising_edge(Out_DataValid);
                    wait until rising_edge(Clk);
                end if;
                In_DataReady <= '0';
                --Check that key corresponds to input
                check_equal(Out_Key, TEST_KEY(KeyWidth_g-1 downto 0), "Coherent key output");
                --Request Clear
                In_Clear <= '1';
                wait until rising_edge(Clk);
                if Out_OpReady /= '1' then
                    wait until rising_edge(Out_OpReady);
                    wait until rising_edge(Clk);
                end if;
                In_Clear <= '0';
                --Wait clear done
                wait until rising_edge(Out_OpReady);
                --Check that hashtable is empty
                check_equal(Out_Pairs, 0, "Coherent pair counting after clear");
                --Request read with same key
                In_Read <= '1';
                wait until rising_edge(Clk);
                In_Read <= '0';
                --Wait till hashtable ready again
                wait until rising_edge(Out_OpReady);
                wait until rising_edge(Clk);
                --Check that key wasn't found
                check(Out_KeyUnknown = '1', "Non-existing value after clear");

            elsif run("MultiplePairs") then
                --Tests with multiple values
                --Generate random pairs
                TestKeys(0) := TEST_KEY(KeyWidth_g-1 downto 0);
                TestValues(0) := TEST_VALUE(ValueWidth_g-1 downto 0);
                for i in 1 to Depth_g-1 loop
                    TestKeys(i) := std_logic_vector(lcg_prng(
                        unsigned(TestKeys(i-1)), 
                        LcgMult_g, 
                        LcgIncr_g
                        )(KeyWidth_g-1 downto 0));
                    TestValues(i) := std_logic_vector(lcg_prng(
                        unsigned(TestValues(i-1)), 
                        LcgMult_g, 
                        LcgIncr_g
                        )(ValueWidth_g-1 downto 0));
                    report "Key: " & 
                        integer'image(to_integer(unsigned(TestKeys(i))));
                end loop;
                --Store all pairs
                report "Store all pairs";
                storedPairs := 0;
                In_Write <= '1';
                for i in 0 to Depth_g-1 loop
                    check(Out_Full = '0', "Hashtable not full");
                    In_Key <= TestKeys(i);
                    In_Value <= TestValues(i);
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    wait until rising_edge(Out_OpReady);
                    check(Out_KeyUnknown = '1', "Writing new key");
                    storedPairs := storedPairs + 1;
                    check_equal(Out_Pairs, storedPairs, "Coherent pair counting");
                end loop;
                wait until rising_edge(Clk);
                check(Out_Full = '1', "Hashtable full");
                In_Write <= '0';
                --Read all pairs
                report "Read all pairs";
                In_Read <= '1';
                for i in 0 to Depth_g-1 loop
                    In_Key <= TestKeys(i);
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    In_DataReady <= '1';
                    wait until rising_edge(Out_DataValid);
                    wait until rising_edge(Clk);
                    In_DataReady <= '0';
                    check(Out_KeyUnknown = '0', "Coherent value search result");
                    check_equal(Out_Value, TestValues(i), "Check output value");
                    wait until rising_edge(Out_OpReady);
                end loop;
                In_Read <= '0';
                --Get all keys
                report "Get all keys";
                In_NextKey <= '1';
                for i in 0 to to_integer(unsigned(Out_Pairs))-1 loop
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    In_DataReady <= '1';
                    wait until rising_edge(Out_DataValid);
                    wait until rising_edge(Clk);
                    In_DataReady <= '0';
                    KeyValid := '0';
                    find_key_loop: for j in 0 to Depth_g-1 loop
                        if TestKeys(j) = Out_Key then
                            KeyValid := '1';
                            KeysFound := KeysFound + 1;
                            exit find_key_loop;
                        end if;
                    end loop;
                    check(KeyValid = '1', "Check key valid");
                    wait until rising_edge(Out_OpReady);
                end loop;
                check_equal(KeysFound, Depth_g, "Check all keys found");
                In_NextKey <= '0';
                --Modify existing key
                report "Modify existing key";
                TestValues(0) := std_logic_vector(lcg_prng(
                    unsigned(TestValues(Depth_g-1)), 
                    LcgMult_g, 
                    LcgIncr_g
                    )(ValueWidth_g-1 downto 0));
                --Try to write new value on existing key
                report "Try to write new value on existing key";
                In_Write <= '1';
                In_Key <= TestKeys(0);
                In_Value <= TestValues(0);
                In_OpValid <= '1';
                wait until falling_edge(Out_OpReady);
                In_Write <= '0';
                In_OpValid <= '0';
                wait until rising_edge(Out_OpReady);
                check(Out_KeyUnknown = '0', "Check key known");
                --Check value overridden
                report "Check value overridden";
                In_Read <= '1';
                In_OpValid <= '1';
                wait until falling_edge(Out_OpReady);
                In_Read <= '0';
                In_OpValid <= '0';
                In_DataReady <= '1';
                wait until rising_edge(Out_DataValid);
                wait until rising_edge(Clk);
                In_DataReady <= '0';
                check_equal(Out_Value, TestValues(0), "Check value overridden");
                wait until rising_edge(Out_OpReady);
                --Create excess key-value pair
                report "Create excess key-value pair";
                In_Key <= std_logic_vector(lcg_prng(
                    unsigned(TestKeys(Depth_g-1)), 
                    LcgMult_g, 
                    LcgIncr_g
                    )(KeyWidth_g-1 downto 0));
                In_Value <= TEST_VALUE(ValueWidth_g-1 downto 0);
                --Try to write new key
                report "Try to write new key";
                In_Write <= '1';
                In_OpValid <= '1';
                wait until falling_edge(Out_OpReady);
                In_Write <= '0';
                In_OpValid <= '0';
                wait until rising_edge(Out_OpReady);
                check(Out_KeyUnknown = '1', "Check key unknown");
                --Check pair ignored
                report "Check pair ignored";
                In_Read <= '1';
                In_OpValid <= '1';
                wait until falling_edge(Out_OpReady);
                In_Read <= '0';
                In_OpValid <= '0';
                wait until rising_edge(Out_OpReady);
                check(Out_KeyUnknown = '1', "Check value ignored");
                --Remove half keys
                report "Remove half keys";
                In_Remove <= '1';
                for i in 0 to (Depth_g/2)-1 loop
                    In_Key <= TestKeys(i);
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    wait until rising_edge(Out_OpReady);
                    check(Out_KeyUnknown = '0', "Check key removed is known");
                end loop;
                In_Remove <= '0';
                --Check coherent key search output
                report "Check coherent key search output";
                In_Read <= '1';
                for i in 0 to Depth_g-1 loop
                    In_Key <= TestKeys(i);
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    if i < Depth_g/2 then --Removed pairs, check unknown
                        wait until rising_edge(Out_OpReady);
                        check(Out_KeyUnknown = '1', "Coherent value search result");
                    else -- Not removed pairs, check valid
                        In_DataReady <= '1';
                        wait until rising_edge(Out_DataValid);
                        wait until rising_edge(Clk);
                        In_DataReady <= '0';
                        check_equal(Out_Value, TestValues(i), "Check output value");
                        wait until rising_edge(Out_OpReady);
                        check(Out_KeyUnknown = '0', "Coherent value search result");
                    end if;
                end loop;
                In_Read <= '0';
                --Clear all keys
                report "Clear all keys";
                In_Clear <= '1';
                wait until rising_edge(Out_OpReady);
                In_Clear <= '0';
                --Check coherent key search output
                report "Check coherent key search output";
                In_Read <= '1';
                for i in 0 to Depth_g-1 loop
                    In_Key <= TestKeys(i);
                    In_OpValid <= '1';
                    wait until falling_edge(Out_OpReady);
                    In_OpValid <= '0';
                    wait until rising_edge(Out_OpReady);
                    check(Out_KeyUnknown = '1', "Coherent value search result");
                end loop;
                In_Read <= '0';

            end if;

            wait for 1 us;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
