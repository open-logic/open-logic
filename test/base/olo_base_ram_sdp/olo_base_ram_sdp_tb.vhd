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
entity olo_base_ram_sdp_tb is
    generic (
        runner_cfg      : string;
        Width_g         : positive range 5 to 128 := 32;
        RamBehavior_g   : string                  := "RBW";
        UseByteEnable_g : boolean                 := false;
        IsAsync_g       : boolean                 := false;
        RdLatency_g     : positive range 1 to 2   := 1;
        InitFormat_g    : string                  := "NONE"
    );
end entity;

architecture sim of olo_base_ram_sdp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant InitString_c  : string  := "0x01, 0x5,0x1317";
    constant BeWidth_c     : integer := Width_g/8;
    constant BeSigWidth_c  : integer := maximum(BeWidth_c, 2); -- Must be at least 2 bits to avoid compile errors with GHDL.
    -- .. GHDL checks ranges also on code in a not executed if-clause.
    constant ClkPeriod_c   : time := 10 ns;
    constant RdClkPeriod_c : time := 33.3 ns;

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

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk     : std_logic                                 := '0';
    signal Wr_Addr : std_logic_vector(7 downto 0)              := (others => '0');
    signal Wr_Ena  : std_logic                                 := '0';
    signal Wr_Be   : std_logic_vector(BeSigWidth_c-1 downto 0) := (others => '1');
    signal Wr_Data : std_logic_vector(Width_g - 1 downto 0)    := (others => '0');
    signal Rd_Clk  : std_logic                                 := '0';
    signal Rd_Addr : std_logic_vector(7 downto 0)              := (others => '0');
    signal Rd_Ena  : std_logic                                 := '1';
    signal Rd_Data : std_logic_vector(Width_g - 1 downto 0)    := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_ram_sdp
        generic map (
            Depth_g         => 200,
            Width_g         => Width_g,
            RamBehavior_g   => RamBehavior_g,
            UseByteEnable_g => UseByteEnable_g,
            IsAsync_g       => IsAsync_g,
            RdLatency_g     => RdLatency_g,
            InitString_g    => InitString_c,
            InitFormat_g    => InitFormat_g
        )
        port map (
            Clk         => Clk,
            Wr_Addr     => Wr_Addr,
            Wr_Ena      => Wr_Ena,
            Wr_Be       => Wr_Be(BeWidth_c-1 downto 0),
            Wr_Data     => Wr_Data,
            Rd_Clk      => Rd_Clk,
            Rd_Addr     => Rd_Addr,
            Rd_Ena      => Rd_Ena,
            Rd_Data     => Rd_Data
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    g_async : if IsAsync_g generate
        Rd_Clk <= not Rd_Clk after 0.5 * RdClkPeriod_c;
    end generate;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 100 us);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Wait for some time
            wait for 1 us;
            wait until rising_edge(Clk);

            -- test initialization values
            if run("Init-Values") then
                if InitFormat_g = "HEX" then
                    if IsAsync_g then
                        check(0, 1, Rd_Clk, Rd_Addr, Rd_Data, "Init-Values: 0=0x01");
                        check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "Init-Values: 1=0x05");
                        check(2, 16#1317#, Rd_Clk, Rd_Addr, Rd_Data, "Init-Values: 2=0x17");
                    else
                        check(0, 1, Clk, Rd_Addr, Rd_Data, "Init-Values: 0=0x01");
                        check(1, 5, Clk, Rd_Addr, Rd_Data, "Init-Values: 1=0x05");
                        check(2, 16#1317#, Clk, Rd_Addr, Rd_Data, "Init-Values: 2=0x17");
                    end if;
                end if;
            end if;

            -- write 3 Values, Read back
            if run("Basic") then
                if UseByteEnable_g then
                    Wr_Be <= (others => '1'); -- BE not checked -> all ones
                end if;
                write(1, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(2, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(3, 7, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                if IsAsync_g then
                    check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 1=5");
                    check(2, 6, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 2=6");
                    check(3, 7, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: 3=7");
                    check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "3vrb: re-read 1=5");
                else
                    check(1, 5, Clk, Rd_Addr, Rd_Data, "3vrb: 1=5");
                    check(2, 6, Clk, Rd_Addr, Rd_Data, "3vrb: 2=6");
                    check(3, 7, Clk, Rd_Addr, Rd_Data, "3vrb: 3=7");
                    check(1, 5, Clk, Rd_Addr, Rd_Data, "3vrb: re-read 1=5");
                end if;
                Wr_Be <= (others => '0');
            end if;

            -- No read enable
            if run("NoRdEna") then
                Wr_Be <= (others => '1');
                write(0, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena); -- Addr0 must be used because check always returns to zero
                write(1, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                if IsAsync_g then
                    check(0, 5, Rd_Clk, Rd_Addr, Rd_Data, "No update with Rd_Ena = '1'");
                    Rd_Ena <= '0';
                    check(1, 5, Rd_Clk, Rd_Addr, Rd_Data, "Unexpected Update with Rd_Ena = '0'");
                else
                    check(0, 5, Clk, Rd_Addr, Rd_Data, "No update with Rd_Ena = '1'");
                    Rd_Ena <= '0';
                    check(1, 5, Clk, Rd_Addr, Rd_Data, "Unexpected Update with Rd_Ena = '0'");
                end if;
            end if;
            Rd_Ena <= '1';

            -- check byte enables
            if run("ByteEnable") then
                if UseByteEnable_g and (Width_g mod 8 = 0) and (Width_g > 8) then
                    -- Byte 0 test
                    Wr_Be    <= (others => '1');
                    write(1, 0, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    Wr_Be    <= (others => '0');
                    Wr_Be(0) <= '1';
                    write(1, 16#ABCD#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    if IsAsync_g then
                        check(1, 16#00CD#, Rd_Clk, Rd_Addr, Rd_Data, "BE[0]");
                    else
                        check(1, 16#00CD#, Clk, Rd_Addr, Rd_Data, "BE[0]");
                    end if;
                    -- Byte 1 test
                    Wr_Be    <= (others => '0');
                    Wr_Be(1) <= '1';
                    write(1, 16#1234#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    if IsAsync_g then
                        check(1, 16#12CD#, Rd_Clk, Rd_Addr, Rd_Data, "BE[0]");
                    else
                        check(1, 16#12CD#, Clk, Rd_Addr, Rd_Data, "BE[0]");
                    end if;
                end if;
            end if;

            -- Read while write
            if run("ReadDuringwrite") then
                -- Only makes sense in Sync CAse
                if not IsAsync_g then
                    -- Initialize
                    Wr_Be   <= (others => '1');
                    write(1, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    write(2, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    write(3, 7, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                    wait until rising_edge(Clk);
                    Wr_Ena  <= '1';
                    Wr_Addr <= toUslv(1, Wr_Addr'length);
                    Rd_Addr <= toUslv(1, Rd_Addr'length);
                    Wr_Data <= toUslv(1, Wr_Data'length);
                    wait until rising_edge(Clk);
                    Wr_Addr <= toUslv(2, Wr_Addr'length);
                    Rd_Addr <= toUslv(2, Rd_Addr'length);
                    Wr_Data <= toUslv(2, Wr_Data'length);
                    wait until rising_edge(Clk);
                    if RdLatency_g = 1 then
                        if RamBehavior_g = "RBW" then
                            check_equal(Rd_Data, 5, "rw: 1=5");
                        else
                            check_equal(Rd_Data, 1, "rw: 1=1 wbr");
                        end if;
                    end if;
                    Wr_Addr <= toUslv(3, Wr_Addr'length);
                    Rd_Addr <= toUslv(3, Rd_Addr'length);
                    Wr_Data <= toUslv(3, Wr_Data'length);
                    wait until rising_edge(Clk);
                    if RdLatency_g = 1 then
                        if RamBehavior_g = "RBW" then
                            check_equal(Rd_Data, 6, "rw: 2=6");
                        else
                            check_equal(Rd_Data, 2, "rw: 2=2 wbr");
                        end if;
                    elsif RdLatency_g = 2 then
                        if RamBehavior_g = "RBW" then
                            check_equal(Rd_Data, 5, "rw: 1=5");
                        else
                            check_equal(Rd_Data, 1, "rw: 1=1 wbr");
                        end if;
                    end if;
                    Wr_Addr <= toUslv(4, Wr_Addr'length);
                    Rd_Addr <= toUslv(4, Rd_Addr'length);
                    Wr_Data <= toUslv(4, Wr_Data'length);
                    wait until rising_edge(Clk);
                    if RdLatency_g = 1 then
                        if RamBehavior_g = "RBW" then
                            check_equal(Rd_Data, 7, "rw: 3=7");
                        else
                            check_equal(Rd_Data, 3, "rw: 3=3 wbr");
                        end if;
                    elsif RdLatency_g = 2 then
                        if RamBehavior_g = "RBW" then
                            check_equal(Rd_Data, 6, "rw: 2=6");
                        else
                            check_equal(Rd_Data, 2, "rw: 2=2 wbr");
                        end if;
                    end if;
                    Wr_Addr <= toUslv(5, Wr_Addr'length);
                    Rd_Addr <= toUslv(5, Rd_Addr'length);
                    Wr_Data <= toUslv(5, Wr_Data'length);
                    wait until rising_edge(Clk);
                    Wr_Ena  <= '0';
                    check(1, 1, Clk, Rd_Addr, Rd_Data, "rw: 1=1");
                    check(2, 2, Clk, Rd_Addr, Rd_Data, "rw: 2=2");
                    check(3, 3, Clk, Rd_Addr, Rd_Data, "rw: 3=3");
                end if;
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
