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

library olo;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_ram_tdp_tb is
    generic (
        runner_cfg      : string;
        Width_g         : positive range 5 to 128 := 32;
        RamBehavior_g   : string                  := "RBW";
        UseByteEnable_g : boolean                 := false;
        RdLatency_g     : positive range 1 to 2   := 1;
        InitFormat_g    : string                  := "NONE"
    );
end entity;

architecture sim of olo_base_ram_tdp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant InitString_c : string  := "0x01, 0x5,0x17";
    constant BeWidth_c    : integer := Width_g/8;
    constant BeSigWidth_c : integer := maximum(BeWidth_c, 2); -- Must be at least 2 bits to avoid compile errors with GHDL.
    -- .. GHDL checks ranges also on code in a not executed if-clause.
    constant ClkAPeriod_c : time := 10 ns;
    constant ClkBPeriod_c : time := 33.3 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    procedure write (
        address       : natural;
        data          : natural;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal WrData : out std_logic_vector;
        signal WrEna  : out std_logic) is
    begin
        wait until rising_edge(Clk);
        Addr   <= toUslv(address, Addr'length);
        WrData <= toUslv(data, WrData'length);
        WrEna  <= '1';
        wait until rising_edge(Clk);
        WrEna  <= '0';
        Addr   <= toUslv(0, Addr'length);
        WrData <= toUslv(0, WrData'length);
    end procedure;

    procedure check (
        address       : natural;
        data          : natural;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal RdData : in std_logic_vector;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled
        Addr <= toUslv(0, Addr'length);

        -- Wait for read data to arrive
        for i in 1 to RdLatency_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdData, toUslv(data, RdData'length), message);
    end procedure;

    procedure basicCheck (
        signal Wr_Clk  : in std_logic;
        signal Wr_Addr : out std_logic_vector;
        signal Wr_Data : out std_logic_vector;
        signal Wr_Ena  : out std_logic;
        signal Wr_Be   : out std_logic_vector;
        signal Rd_Clk  : in std_logic;
        signal Rd_Addr : out std_logic_vector;
        signal Rd_Data : in std_logic_vector) is
    begin
        if UseByteEnable_g then
            Wr_Be <= toSslv(-1, Wr_Be'length); -- BE not checked -> all ones
        end if;
        write(1, 5, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
        write(2, 6, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
        write(3, 7, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
        check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 1=5");
        check(2, 6, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 2=6");
        check(3, 7, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 3=7");
        check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: re-read 1=5");
        Wr_Be <= toSslv(0, Wr_Be'length);
    end procedure;

    procedure byteEnableCheck (
        signal Wr_Clk    : in std_logic;
        signal Wr_Addr   : out std_logic_vector;
        signal Wr_Data   : out std_logic_vector;
        signal Wr_Ena    : out std_logic;
        signal Wr_Be     : out std_logic_vector;
        signal Wr_RdData : in std_logic_vector;
        signal Rd_Clk    : in std_logic;
        signal Rd_Addr   : out std_logic_vector;
        signal Rd_Data   : in std_logic_vector) is
    begin
        if UseByteEnable_g and (Width_g mod 8 = 0) and (Width_g > 8) then

            -- Byte 0 test
            Wr_Be    <= toSslv(-1, Wr_Be'length); -- BE not checked -> all ones
            write(1, 0, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
            Wr_Be    <= toSslv(0, Wr_Be'length);
            Wr_Be(0) <= '1';
            write(1, 16#ABCD#, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
            check(1, 16#00CD#, Wr_Clk, Wr_Addr, Wr_RdData, "BE[0]-A");
            check(1, 16#00CD#, Rd_Clk, Rd_Addr, Rd_Data, "BE[0]-B");

            -- Byte 1 test
            Wr_Be    <= toSslv(0, Wr_Be'length);
            Wr_Be(1) <= '1';
            write(1, 16#1234#, Wr_Clk, Wr_Addr, Wr_Data, Wr_Ena);
            check(1, 16#12CD#, Wr_Clk, Wr_Addr, Wr_RdData, "BE[0]-A");
            check(1, 16#12CD#, Rd_Clk, Rd_Addr, Rd_Data, "BE[0]-B");

        end if;
    end procedure;

    procedure readDuringWrite (
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal WrData : out std_logic_vector;
        signal WrEna  : out std_logic;
        signal Be     : out std_logic_vector;
        signal RdData : in std_logic_vector) is
    begin

        -- Initialize
        Be     <= toSslv(-1, Be'length); -- BE not checked -> all ones
        write(1, 5, Clk, Addr, WrData, WrEna);
        write(2, 6, Clk, Addr, WrData, WrEna);
        write(3, 7, Clk, Addr, WrData, WrEna);
        wait until rising_edge(Clk);
        WrEna  <= '1';
        Addr   <= toUslv(1, Addr'length);
        WrData <= toUslv(1, WrData'length);
        wait until rising_edge(Clk);
        Addr   <= toUslv(2, Addr'length);
        WrData <= toUslv(2, WrData'length);
        wait until rising_edge(Clk);
        if RdLatency_g = 1 then
            if RamBehavior_g = "RBW" then
                check_equal(RdData, 5, "rw: 1=5");
            else
                check_equal(RdData, 1, "rw: 1=1 wbr");
            end if;
        end if;
        Addr   <= toUslv(3, Addr'length);
        WrData <= toUslv(3, WrData'length);
        wait until rising_edge(Clk);
        if RdLatency_g = 1 then
            if RamBehavior_g = "RBW" then
                check_equal(RdData, 6, "rw: 2=6");
            else
                check_equal(RdData, 2, "rw: 2=2 wbr");
            end if;
        elsif RdLatency_g = 2 then
            if RamBehavior_g = "RBW" then
                check_equal(RdData, 5, "rw: 1=5");
            else
                check_equal(RdData, 1, "rw: 1=1 wbr");
            end if;
        end if;
        Addr   <= toUslv(4, Addr'length);
        WrData <= toUslv(4, WrData'length);
        wait until rising_edge(Clk);
        if RdLatency_g = 1 then
            if RamBehavior_g = "RBW" then
                check_equal(RdData, 7, "rw: 3=7");
            else
                check_equal(RdData, 3, "rw: 3=3 wbr");
            end if;
        elsif RdLatency_g = 2 then
            if RamBehavior_g = "RBW" then
                check_equal(RdData, 6, "rw: 2=6");
            else
                check_equal(RdData, 2, "rw: 2=2 wbr");
            end if;
        end if;
        Addr   <= toUslv(5, Addr'length);
        WrData <= toUslv(5, WrData'length);
        wait until rising_edge(Clk);
        WrEna  <= '0';
        check(1, 1, Clk, Addr, RdData, "rw: 1=1");
        check(2, 2, Clk, Addr, RdData, "rw: 2=2");
        check(3, 3, Clk, Addr, RdData, "rw: 3=3");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal A_Clk    : std_logic                                 := '0';
    signal A_Addr   : std_logic_vector(7 downto 0);
    signal A_WrEna  : std_logic                                 := '0';
    signal A_Be     : std_logic_vector(BeSigWidth_c-1 downto 0) := (others => '1');
    signal A_WrData : std_logic_vector(Width_g - 1 downto 0);
    signal A_RdData : std_logic_vector(Width_g - 1 downto 0);
    signal B_Clk    : std_logic                                 := '0';
    signal B_Addr   : std_logic_vector(7 downto 0);
    signal B_WrEna  : std_logic                                 := '0';
    signal B_Be     : std_logic_vector(BeSigWidth_c-1 downto 0) := (others => '1');
    signal B_WrData : std_logic_vector(Width_g - 1 downto 0);
    signal B_RdData : std_logic_vector(Width_g - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_ram_tdp
        generic map (
            Depth_g         => 200,
            Width_g         => Width_g,
            RamBehavior_g   => RamBehavior_g,
            UseByteEnable_g => UseByteEnable_g,
            RdLatency_g     => RdLatency_g,
            InitString_g    => InitString_c,
            InitFormat_g    => InitFormat_g
        )
        port map (
            A_Clk       => A_Clk,
            A_Addr      => A_Addr,
            A_WrEna     => A_WrEna,
            A_Be        => A_Be(BeWidth_c-1 downto 0),
            A_WrData    => A_WrData,
            A_RdData    => A_RdData,
            B_Clk       => B_Clk,
            B_Addr      => B_Addr,
            B_WrEna     => B_WrEna,
            B_Be        => B_Be(BeWidth_c-1 downto 0),
            B_WrData    => B_WrData,
            B_RdData    => B_RdData
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    A_Clk <= not A_Clk after 0.5 * ClkAPeriod_c;
    B_Clk <= not B_Clk after 0.5 * ClkBPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Wait for some time
            wait for 1 us;

            -- test initialization values
            if run("Init-Values") then
                if InitFormat_g = "HEX" then
                    check(0, 1, A_Clk, A_Addr, A_RdData, "Init-Values: 0=0x01");
                    check(1, 5, A_Clk, A_Addr, A_RdData, "Init-Values: 1=0x05");
                    check(2, 16#17#, A_Clk, A_Addr, A_RdData, "Init-Values: 2=0x17");
                end if;

            -- write A, Read A
            elsif run("BasicA-A") then
                basicCheck(A_Clk, A_Addr, A_WrData, A_WrEna, A_Be, A_Clk, A_Addr, A_RdData);

            -- write B, Read B
            elsif run("BasicB-B") then
                basicCheck(B_Clk, B_Addr, B_WrData, B_WrEna, B_Be, B_Clk, B_Addr, B_RdData);

            -- write A, Read B
            elsif run("BasicA-B") then
                basicCheck(A_Clk, A_Addr, A_WrData, A_WrEna, A_Be, B_Clk, B_Addr, B_RdData);

            -- write B, Read B
            elsif run("BasicB-A") then
                basicCheck(B_Clk, B_Addr, B_WrData, B_WrEna, A_Be, B_Clk, B_Addr, B_RdData);

            -- check byte enables
            elsif run("ByteEnable-A") then
                byteEnableCheck(A_Clk, A_Addr, A_WrData, A_WrEna, A_Be, A_RdData, B_Clk, B_Addr, B_RdData);

            -- check byte enables
            elsif run("ByteEnable-B") then
                byteEnableCheck(B_Clk, B_Addr, B_WrData, B_WrEna, B_Be, B_RdData, A_Clk, A_Addr, A_RdData);

            -- Read while write
            elsif run("readDuringWrite-A") then
                readDuringWrite(A_Clk, A_Addr, A_WrData, A_WrEna, A_Be, A_RdData);

            -- Read while write
            elsif run("readDuringWrite-B") then
                readDuringWrite(B_Clk, B_Addr, B_WrData, B_WrEna, B_Be, B_RdData);

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
