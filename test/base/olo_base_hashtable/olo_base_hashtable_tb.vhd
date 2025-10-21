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
        Hash_g : string := "DIVISION";
        RamStyle_g : string := "auto";
        RamBehavior_g : string := "RBW";
        ClearAfterReset_g : boolean := true
    );
end entity;

architecture tb of olo_base_hashtable_tb is
    signal Clk       : std_logic                              := '0';
    signal Rst       : std_logic                              := '0';

    constant Clk_Frequency_c : real    := 100.0e6;
    constant Clk_Period_c    : time    := (1 sec) / Clk_Frequency_c;

    constant PAIRS_IDX : integer := log2ceil(Depth_g);

    signal In_Key : std_logic_vector(KeyWidth_g-1 downto 0);
    signal In_Value : std_logic_vector(ValueWidth_g-1 downto 0);
    signal Out_Key : std_logic_vector(KeyWidth_g-1 downto 0);
    signal Out_Value : std_logic_vector(ValueWidth_g-1 downto 0);
    signal In_Write : std_logic;
    signal In_Read : std_logic;
    signal In_Remove : std_logic;
    signal In_Clear : std_logic;
    signal In_NextKey : std_logic;
    signal In_OpValid : std_logic;
    signal Out_OpReady : std_logic;
    signal Out_DataValid : std_logic;
    signal In_DataReady : std_logic;
    signal Out_KeyUnknown : std_logic;
    signal Out_Full : std_logic;
    signal Out_Pairs : std_logic_vector(PAIRS_IDX downto 0);

begin

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
    test_runner_watchdog(runner, 1 ms);

    main : process
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
                --Request write
                In_OpValid <= '1';
                In_Write <= '1';
                In_Key <= x"1234";
                In_Value <= x"56789ABC";
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
                check_equal(Out_Value, 16#56789ABC#, "Coherent read value");
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
                check_equal(Out_Key, 16#1234#, "Coherent key output");
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

            --elsif run("MultiplePairsNoCollision") then
                --Tests with multiple values but no collisions
            --elsif run("MultiplePairsCollisions") then
                --Tests with multiple values and collisions
            --elsif run("Saturate") then
                --Tests on full hashtable
                --Write to full hashtable and check that
                    --Pre-existing keys overridden
                    --Non-existing keys ignored
            end if;

            wait for 1 us;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
