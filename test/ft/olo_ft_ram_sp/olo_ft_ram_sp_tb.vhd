---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
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
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_ram_sp_tb is
    generic (
        runner_cfg    : string;
        Width_g       : positive range 5 to 128 := 32;
        RamBehavior_g : string                  := "RBW";
        RdLatency_g   : positive range 1 to 2   := 1;
        EccPipeline_g : natural range 0 to 1    := 0
    );
end entity;

architecture sim of olo_ft_ram_sp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
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

    procedure writeWithFlip (
        address       : natural;
        data          : natural;
        flipBits      : std_logic_vector(1 downto 0);
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal WrData : out std_logic_vector;
        signal WrEna  : out std_logic;
        signal WrFlip : out std_logic_vector) is
    begin
        wait until rising_edge(Clk);
        Addr   <= toUslv(address, Addr'length);
        WrData <= toUslv(data, WrData'length);
        WrEna  <= '1';
        WrFlip <= flipBits;
        wait until rising_edge(Clk);
        WrEna  <= '0';
        WrFlip <= "00";
        Addr   <= toUslv(0, Addr'length);
        WrData <= toUslv(0, WrData'length);
    end procedure;

    procedure checkEcc (
        address       : natural;
        data          : natural;
        expSecErr     : std_logic;
        expDedErr     : std_logic;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal RdData : in std_logic_vector;
        signal SecErr : in std_logic;
        signal DedErr : in std_logic;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled

        -- Wait for read data to arrive
        for i in 1 to RdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdData, toUslv(data, RdData'length), message & " data");
        check_equal(SecErr, expSecErr, message & " SecErr");
        check_equal(DedErr, expDedErr, message & " DedErr");
    end procedure;

    procedure checkDedOnly (
        address       : natural;
        expSecErr     : std_logic;
        expDedErr     : std_logic;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal SecErr : in std_logic;
        signal DedErr : in std_logic;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled

        -- Wait for read data to arrive
        for i in 1 to RdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(SecErr, expSecErr, message & " SecErr");
        check_equal(DedErr, expDedErr, message & " DedErr");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                := '0';
    signal Addr         : std_logic_vector(7 downto 0)             := (others => '0');
    signal WrEna        : std_logic                                := '0';
    signal WrData       : std_logic_vector(Width_g - 1 downto 0);
    signal WrEccBitFlip : std_logic_vector(1 downto 0)             := "00";
    signal RdData       : std_logic_vector(Width_g - 1 downto 0);
    signal RdSecErr     : std_logic;
    signal RdDedErr     : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sp
        generic map (
            Depth_g       => 200,
            Width_g       => Width_g,
            RamBehavior_g => RamBehavior_g,
            RdLatency_g   => RdLatency_g,
            EccPipeline_g => EccPipeline_g
        )
        port map (
            Clk          => Clk,
            Addr         => Addr,
            WrEna        => WrEna,
            WrData       => WrData,
            WrEccBitFlip => WrEccBitFlip,
            RdData       => RdData,
            RdSecErr     => RdSecErr,
            RdDedErr     => RdDedErr
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Wait for some time
            wait for 1 us;
            wait until rising_edge(Clk);

            -- Basic write and read
            if run("Basic") then
                write(1, 5, Clk, Addr, WrData, WrEna);
                write(2, 6, Clk, Addr, WrData, WrEna);
                write(3, 7, Clk, Addr, WrData, WrEna);
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Basic re-read 1=5");

            -- Single bit error injection and correction
            elsif run("SecErr") then
                writeWithFlip(20, 16#AB#, "01", Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(20, 16#AB#, '1', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Sec flip0");
                writeWithFlip(21, 16#CD#, "10", Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(21, 16#CD#, '1', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Sec flip1");
                -- Overwrite clears error
                write(20, 16#AB#, Clk, Addr, WrData, WrEna);
                checkEcc(20, 16#AB#, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Sec cleared");

            -- Double bit error detection
            elsif run("DedErr") then
                writeWithFlip(30, 16#EF#, "11", Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(30, '0', '1', Clk, Addr, RdSecErr, RdDedErr, "Ded");
                -- Overwrite clears error
                write(30, 16#EF#, Clk, Addr, WrData, WrEna);
                checkEcc(30, 16#EF#, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Ded cleared");

            -- Multiple addresses: errors don't cross-contaminate
            elsif run("MultiAddr") then
                write(40, 16#01#, Clk, Addr, WrData, WrEna);
                write(41, 16#02#, Clk, Addr, WrData, WrEna);
                write(42, 16#03#, Clk, Addr, WrData, WrEna);
                writeWithFlip(41, 16#02#, "01", Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(40, 16#01#, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Multi addr40 clean");
                checkEcc(41, 16#02#, '1', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Multi addr41 sec");
                checkEcc(42, 16#03#, '0', '0', Clk, Addr, RdData, RdSecErr, RdDedErr, "Multi addr42 clean");

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
