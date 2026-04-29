---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler, Switzerland
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
    use vunit_lib.check_pkg.all;
    context vunit_lib.vc_context;

library osvvm;
    use osvvm.RandomPkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_hashtable_tb is
    generic (
        runner_cfg        : string;
        Hash_g            : string  := "CRC32";
        ClearAfterReset_g : boolean := true
    );
end entity;

architecture sim of olo_base_hashtable_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Depth_c       : positive := 8;
    constant KeyWidth_c    : positive := 16;
    constant ValueWidth_c  : positive := 32;
    constant RamStyle_c    : string   := "auto";
    constant RamBehavior_c : string   := "RBW";

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    shared variable Random_v : RandomPType;

    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    constant TestKey_c   : std_logic_vector(31 downto 0) := x"01234567";
    constant TestValue_c : std_logic_vector(31 downto 0) := x"89ABCDEF";
    constant PairsIdx_c  : integer                       := log2ceil(Depth_c);

    type TestKeys_t is array (natural range<>) of std_logic_vector(KeyWidth_c-1 downto 0);
    type TestValues_t is array (natural range<>) of std_logic_vector(ValueWidth_c-1 downto 0);

    constant OpNb_c         : integer                             := 5;
    constant OpWrite_c      : std_logic_vector(OpNb_c-1 downto 0) := "10000";
    constant OpWriteBit_c   : integer                             := 4;
    constant OpRead_c       : std_logic_vector(OpNb_c-1 downto 0) := "01000";
    constant OpReadBit_c    : integer                             := 3;
    constant OpRemove_c     : std_logic_vector(OpNb_c-1 downto 0) := "00100";
    constant OpRemoveBit_c  : integer                             := 2;
    constant OpClear_c      : std_logic_vector(OpNb_c-1 downto 0) := "00010";
    constant OpClearBit_c   : integer                             := 1;
    constant OpNextKey_c    : std_logic_vector(OpNb_c-1 downto 0) := "00001";
    constant OpNextKeyBit_c : integer                             := 0;

    signal AxisMasterData : std_logic_vector(KeyWidth_c+ValueWidth_c-1 downto 0);
    signal AxisMasterUser : std_logic_vector(OpNb_c-1 downto 0);

    -- *** Verification Compnents ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master(
        data_length => KeyWidth_c + ValueWidth_c,
        user_length => 5
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave(
        data_length => KeyWidth_c + ValueWidth_c,
        user_length => 1
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------

    signal Clk            : std_logic                                 := '0';
    signal Rst            : std_logic                                 := '0';
    signal In_Key         : std_logic_vector(KeyWidth_c-1 downto 0)   := (others => '0');
    signal In_Value       : std_logic_vector(ValueWidth_c-1 downto 0) := (others => '0');
    signal Out_Key        : std_logic_vector(KeyWidth_c-1 downto 0)   := (others => '0');
    signal Out_Value      : std_logic_vector(ValueWidth_c-1 downto 0) := (others => '0');
    signal In_Write       : std_logic                                 := '0';
    signal In_Read        : std_logic                                 := '0';
    signal In_Remove      : std_logic                                 := '0';
    signal In_Clear       : std_logic                                 := '0';
    signal In_NextKey     : std_logic                                 := '0';
    signal In_Valid       : std_logic                                 := '0';
    signal In_Ready       : std_logic                                 := '0';
    signal Out_Valid      : std_logic                                 := '0';
    signal Out_Ready      : std_logic                                 := '0';
    signal Out_KeyUnknown : std_logic                                 := '0';
    signal Status_Busy    : std_logic                                 := '0';
    signal Status_Full    : std_logic                                 := '0';
    signal Status_Pairs   : std_logic_vector(PairsIdx_c downto 0)     := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- Proceduresy
    -----------------------------------------------------------------------------------------------
    procedure htAction (
        signal net : inout network_t;
        Action     : std_logic_vector(OpNb_c-1 downto 0);
        Key        : std_logic_vector(KeyWidth_c-1 downto 0);
        Value      : std_logic_vector(ValueWidth_c-1 downto 0);
        blocking   : boolean) is
    begin
        push_axi_stream(net, AxisMaster_c, (Key & Value), tuser => Action);
        if blocking then
            wait until rising_edge(In_Ready);
        end if;
    end procedure;

    procedure htWrite (
        signal net : inout network_t;
        WrKey      : std_logic_vector(KeyWidth_c-1 downto 0);
        WrValue    : std_logic_vector(ValueWidth_c-1 downto 0);
        blocking   : boolean) is
    begin
        htAction(net, OpWrite_c, WrKey, WrValue, blocking);
    end procedure;

    procedure htRead (
        signal net : inout network_t;
        RdKey      : std_logic_vector(KeyWidth_c-1 downto 0);
        blocking   : boolean) is
    begin
        htAction(net, OpRead_c, RdKey, zerosVector(ValueWidth_c), blocking);
    end procedure;

    procedure htRemove (
        signal net : inout network_t;
        RmKey      : std_logic_vector(KeyWidth_c-1 downto 0);
        blocking   : boolean) is
    begin
        htAction(net, OpRemove_c, RmKey, zerosVector(ValueWidth_c), blocking);
    end procedure;

    procedure htClear (
        signal net : inout network_t;
        blocking   : boolean) is
    begin
        htAction(net, OpClear_c, zerosVector(KeyWidth_c), zerosVector(ValueWidth_c), blocking);
    end procedure;

    procedure htNextKey (
        signal net : inout network_t;
        blocking   : boolean) is
    begin
        htAction(net, OpNextKey_c, zerosVector(KeyWidth_c), zerosVector(ValueWidth_c), blocking);
    end procedure;

    procedure htReadCheck (
        signal net : inout network_t;
        checkValue : std_logic_vector(ValueWidth_c-1 downto 0);
        checkMsg   : string) is
        variable StreamData_v   : std_logic_vector(ValueWidth_c+KeyWidth_c-1 downto 0);
        variable ReadValue_v    : std_logic_vector(ValueWidth_c-1 downto 0);
        variable TuserDiscard_v : std_logic;
    begin
        pop_axi_stream(net, AxisSlave_c, StreamData_v, TuserDiscard_v);
        ReadValue_v := StreamData_v(ValueWidth_c-1 downto 0);
        check_equal(ReadValue_v, checkValue, checkMsg);
    end procedure;

    procedure htNextKeyGet (
        signal net : inout network_t;
        Key        : out std_logic_vector(KeyWidth_c-1 downto 0)) is
        variable StreamData_v   : std_logic_vector(ValueWidth_c+KeyWidth_c-1 downto 0);
        variable TuserDiscard_v : std_logic;
    begin
        pop_axi_stream(net, AxisSlave_c, StreamData_v, TuserDiscard_v);
        Key := StreamData_v(KeyWidth_c+ValueWidth_c-1 downto ValueWidth_c);
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert KeyWidth_c <= 32
        report "Only key widths up to 32 are possible for testbench"
        severity error;
    assert ValueWidth_c <= 32
        report "Only value widths up to 32 are possible for testbench"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- Show passing tests messages
    show(get_logger(default_checker), display_handler, pass);
    -- Setup watchdog
    test_runner_watchdog(runner, 6 us);

    p_main : process is
        variable StoredPairs_v  : integer                              := 0;
        variable KeyValid_v     : std_logic                            := '0';
        variable KeysFound_v    : integer                              := 0;
        variable TestKeys_v     : TestKeys_t(Depth_c downto 0)         := (others => (others => '0'));
        variable TestValues_v   : TestValues_t(Depth_c downto 0)       := (others => (others => '0'));
        variable KeyCheck_v     : std_logic_vector(KeyWidth_c-1 downto 0);
        variable TestKeyFound_v : std_logic_vector(Depth_c-1 downto 0) := (others => '0');
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
                -- Check Reset Values
                if ClearAfterReset_g then
                    check(In_Ready = '0', "Hashtable AXIS clearing after reset");
                    check(Status_Busy = '1', "Hashtable status clearing after reset");
                else
                    check(In_Ready = '1', "Hashtable AXIS ready after reset");
                    check(Status_Busy = '0', "Hashtable status ready after reset");
                end if;
                check(Out_Valid = '0', "No data output after reset");
                check(Status_Full = '0', "Hashtable not full after reset");
                check_equal(Status_Pairs, 0, "Hashtable empty after reset");

            elsif run("TestFeatures") then
                -- Test all features (filled hashtable)
                -- Generate random pairs (one more than Depth_c to prepare write-when-full test)
                TestKeys_v(0)   := TestKey_c(KeyWidth_c-1 downto 0);
                TestValues_v(0) := TestValue_c(ValueWidth_c-1 downto 0);

                for i in 1 to Depth_c loop
                    TestKeys_v(i)   := Random_v.RandSlv(KeyWidth_c);
                    TestValues_v(i) := Random_v.RandSlv(ValueWidth_c);
                    report "Key " & integer'image(i) & ": " &
                           to_hstring(TestKeys_v(i));
                    report "Value " & integer'image(i) & ": " &
                           to_hstring(TestValues_v(i));
                end loop;

                -- Wait for hashtable to be ready
                if Status_Busy = '1' then
                    wait until Status_Busy = '0';
                end if;
                -- Store all pairs
                report "Store all pairs";
                StoredPairs_v := 0;

                for i in 0 to Depth_c-1 loop
                    check(Status_Full = '0', "Hashtable not full");
                    htWrite(net, TestKeys_v(i), TestValues_v(i), true);
                    check(Out_KeyUnknown = '1', "Writing new key");
                    StoredPairs_v := StoredPairs_v + 1;
                    check_equal(Status_Pairs, StoredPairs_v, "Coherent pair counting");
                end loop;

                wait until rising_edge(Clk);
                check(Status_Full = '1', "Hashtable full");
                -- Read all pairs
                report "Read all pairs";

                for i in 0 to Depth_c-1 loop
                    -- Non-blocking read as htReadCheck will set axi-stream slave ready
                    htRead(net, TestKeys_v(i), false);
                    -- Must check value before KeyUnknown as read operation cannot finish without output being read
                    htReadCheck(net, TestValues_v(i), "Check output value");
                    wait until rising_edge(In_Ready);
                    check(Out_KeyUnknown = '0', "Coherent value search result");
                end loop;

                -- Get all keys
                report "Get all keys";

                for i in 0 to to_integer(unsigned(Status_Pairs))-1 loop
                    -- Recover Next Key
                    -- Non-blocking NextKey search as output read (necessary for operation to finish) is
                    -- setup in htNextKeyGet
                    htNextKey(net, false);
                    htNextKeyGet(net, KeyCheck_v);
                    -- Check that key exists and hasn't been found before

                    l_findkey : for j in 0 to Depth_c-1 loop
                        if TestKeys_v(j) = KeyCheck_v and TestKeyFound_v(i) = '0' then
                            KeyValid_v        := '1';
                            TestKeyFound_v(i) := '1';
                            KeysFound_v       := KeysFound_v + 1;
                            exit l_findKey;
                        end if;
                    end loop;

                    check(KeyValid_v = '1', "Check key valid");
                end loop;

                -- Check correct amount of keys were found
                check_equal(KeysFound_v, Depth_c, "Check all keys found");
                -- Modify existing key
                report "Modify existing key";
                TestValues_v(0) := Random_v.RandSlv(ValueWidth_c);
                -- Try to write new value on existing key
                report "Try to write new value on existing key";
                htWrite(net, TestKeys_v(0), TestValues_v(0), true);
                check(Out_KeyUnknown = '0', "Check key known");
                -- Check value overridden
                report "Check value overridden";
                -- Non-blocking read to prevent lock (output read by htReadCheck necessary for read op to finish)
                htRead(net, TestKeys_v(0), false);
                htReadCheck(net, TestValues_v(0), "Check value overridden");
                wait until In_Ready = '1';
                -- Try to write new key
                report "Try to write new key";
                htWrite(net, TestKeys_v(Depth_c), TestValues_v(Depth_c), true);
                check(Out_KeyUnknown = '1', "Check key unknown");
                -- Check pair ignored
                report "Check pair ignored";
                -- Blocking read as it is expected to fail (no output read necessary to finish)
                htRead(net, TestKeys_v(Depth_c), true);
                check(Out_KeyUnknown = '1', "Check value ignored");
                -- Remove half keys
                report "Remove half keys";

                for i in 0 to (Depth_c/2)-1 loop
                    htRemove(net, TestKeys_v(i), true);
                    check(Out_KeyUnknown = '0', "Check key removed is known");
                end loop;

                -- Check coherent key search output
                report "Check coherent key search output";

                for i in 0 to Depth_c-1 loop
                    -- Non-blocking read to prevent lock
                    htRead(net, TestKeys_v(i), false);
                    if i < Depth_c/2 then -- Removed pairs, check unknown
                        wait until In_Ready = '1';
                        check(Out_KeyUnknown = '1', "Coherent value search result");
                    else -- Not removed pairs, check valid
                        -- Must check value before KeyUnknown (See previous similar reads)
                        htReadCheck(net, TestValues_v(i), "Check output value");
                        wait until In_Ready = '1';
                        check(Out_KeyUnknown = '0', "Coherent value search result");
                    end if;
                end loop;

                -- Clear all keys
                report "Clear all keys";
                htClear(net, true);
                -- Check coherent key search output
                report "Check coherent key search output";

                for i in 0 to Depth_c-1 loop
                    -- Blocking reads (all expected to fail so no need to read output)
                    htRead(net, TestKeys_v(i), true);
                    check(Out_KeyUnknown = '1', "Coherent value search result");
                end loop;

            elsif run("AxiStreamTimings") then
                -- Prepare test pairs
                TestKeys_v(0)   := TestKey_c(KeyWidth_c-1 downto 0);
                TestValues_v(0) := TestValue_c(ValueWidth_c-1 downto 0);
                TestKeys_v(1)   := Random_v.RandSlv(KeyWidth_c);
                TestValues_v(1) := Random_v.RandSlv(ValueWidth_c);
                -- Wait for hashtable to be ready
                report "Wait for hashtable to be ready";
                if Status_Busy = '1' then
                    wait until Status_Busy = '0';
                end if;
                report "Non-blocking transactions";
                -- Send 2 non-blocking write transactions

                for i in 0 to 1 loop
                    htWrite(net, TestKeys_v(i), TestValues_v(i), false);
                end loop;

                -- Wait for write transactions
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait until In_Ready = '1';
                -- Send 2 non-blocking read transactions

                for i in 0 to 1 loop
                    htRead(net, TestKeys_v(i), false);
                end loop;

                report "Blocking transactions";
                -- Wait for a moment (enough for hashtable to have to hold read transaction)
                wait for 200 ns;
                -- Blocking read (and result check) for hashtable output (second read waits for hashtable)

                for i in 0 to 1 loop
                    htReadCheck(net, TestValues_v(i), "Timing values check");
                end loop;

            end if;

            wait for 1 us;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_hashtable
        generic map (
            Depth_g           => Depth_c,
            KeyWidth_g        => KeyWidth_c,
            ValueWidth_g      => ValueWidth_c,
            Hash_g            => Hash_g,
            RamStyle_g        => RamStyle_c,
            RamBehavior_g     => RamBehavior_c,
            ClearAfterReset_g => ClearAfterReset_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Key         => In_Key,
            In_Value       => In_Value,
            Out_Key        => Out_Key,
            Out_Value      => Out_Value,
            In_Write       => In_Write,
            In_Read        => In_Read,
            In_Remove      => In_Remove,
            In_Clear       => In_Clear,
            In_NextKey     => In_NextKey,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Out_KeyUnknown => Out_KeyUnknown,
            Status_Busy    => Status_Busy,
            Status_Full    => Status_Full,
            Status_Pairs   => Status_Pairs
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_axis_master : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            Aclk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => AxisMasterData,
            TUser  => AxisMasterUser
        );

    In_Key     <= AxisMasterData(KeyWidth_c+ValueWidth_c-1 downto ValueWidth_c);
    In_Value   <= AxisMasterData(ValueWidth_c-1 downto 0);
    In_Write   <= AxisMasterUser(OpWriteBit_c);
    In_Read    <= AxisMasterUser(OpReadBit_c);
    In_Remove  <= AxisMasterUser(OpRemoveBit_c);
    In_Clear   <= AxisMasterUser(OpClearBit_c);
    In_NextKey <= AxisMasterUser(OpNextKeyBit_c);

    vc_axis_slave : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            Aclk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => (Out_Key & Out_Value),
            TUser  => (0 => Out_KeyUnknown)
        );

end architecture;
