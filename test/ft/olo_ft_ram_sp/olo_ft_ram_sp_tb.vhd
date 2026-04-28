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
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -----------------------------------------------------------------------------------------------
    -- Bit-flip pattern helpers
    -----------------------------------------------------------------------------------------------
    function singleBit (idx : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    begin
        Result_v(idx) := '1';
        return Result_v;
    end function;

    function doubleBit (idxA : natural; idxB : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    begin
        Result_v(idxA) := '1';
        Result_v(idxB) := '1';
        return Result_v;
    end function;

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
        flipBits      : std_logic_vector;
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
        WrFlip <= (WrFlip'range => '0');
        Addr   <= toUslv(0, Addr'length);
        WrData <= toUslv(0, WrData'length);
    end procedure;

    procedure checkEcc (
        address       : natural;
        data          : natural;
        expEccSec     : std_logic;
        expEccDed     : std_logic;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal RdData : in std_logic_vector;
        signal EccSec : in std_logic;
        signal EccDed : in std_logic;
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
        check_equal(EccSec, expEccSec, message & " EccSec");
        check_equal(EccDed, expEccDed, message & " EccDed");
    end procedure;

    procedure checkDedOnly (
        address       : natural;
        expEccSec     : std_logic;
        expEccDed     : std_logic;
        signal Clk    : in std_logic;
        signal Addr   : out std_logic_vector;
        signal EccSec : in std_logic;
        signal EccDed : in std_logic;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled

        -- Wait for read data to arrive
        for i in 1 to RdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(EccSec, expEccSec, message & " EccSec");
        check_equal(EccDed, expEccDed, message & " EccDed");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                := '0';
    signal Addr         : std_logic_vector(7 downto 0)             := (others => '0');
    signal WrEna        : std_logic                                := '0';
    signal WrData       : std_logic_vector(Width_g - 1 downto 0);
    signal WrEccBitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal RdData       : std_logic_vector(Width_g - 1 downto 0);
    signal RdEccSec     : std_logic;
    signal RdEccDed     : std_logic;

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
            RdEccSec     => RdEccSec,
            RdEccDed     => RdEccDed
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
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Basic re-read 1=5");

            -- Single bit error injection and correction
            elsif run("EccSec") then
                writeWithFlip(20, 16#AB#, singleBit(0), Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(20, 16#AB#, '1', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Sec flip0");
                writeWithFlip(21, 16#CD#, singleBit(1), Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(21, 16#CD#, '1', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Sec flip1");
                -- Overwrite clears error
                write(20, 16#AB#, Clk, Addr, WrData, WrEna);
                checkEcc(20, 16#AB#, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Sec cleared");

            -- Double bit error detection
            elsif run("EccDed") then
                writeWithFlip(30, 16#EF#, doubleBit(0, 1), Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(30, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "Ded");
                -- Overwrite clears error
                write(30, 16#EF#, Clk, Addr, WrData, WrEna);
                checkEcc(30, 16#EF#, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Ded cleared");

            -- Multiple addresses: errors don't cross-contaminate
            elsif run("MultiAddr") then
                write(40, 16#01#, Clk, Addr, WrData, WrEna);
                write(41, 16#02#, Clk, Addr, WrData, WrEna);
                write(42, 16#03#, Clk, Addr, WrData, WrEna);
                writeWithFlip(41, 16#02#, singleBit(0), Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkEcc(40, 16#01#, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Multi addr40 clean");
                checkEcc(41, 16#02#, '1', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Multi addr41 sec");
                checkEcc(42, 16#03#, '0', '0', Clk, Addr, RdData, RdEccSec, RdEccDed, "Multi addr42 clean");

            -- SEC across every codeword bit position (full bit-by-bit sweep)
            elsif run("SecAllBits") then
                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    writeWithFlip(bitIdx, 16#A5#, singleBit(bitIdx),
                                  Clk, Addr, WrData, WrEna, WrEccBitFlip);
                    checkEcc(bitIdx, 16#A5#, '1', '0', Clk, Addr, RdData, RdEccSec, RdEccDed,
                             "SecAllBits flip " & integer'image(bitIdx));
                end loop;

            -- DED across a representative sample of bit pairs (parity+parity, parity+data, data+data, far-apart)
            elsif run("DedSampledPairs") then
                writeWithFlip(60, 16#5A#, doubleBit(0, 1),
                              Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(60, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "DedPair (0,1)");
                writeWithFlip(61, 16#5A#, doubleBit(0, CodewordWidth_c - 1),
                              Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(61, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "DedPair (0,N-1)");
                writeWithFlip(62, 16#5A#, doubleBit(1, 2),
                              Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(62, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "DedPair (1,2)");
                writeWithFlip(63, 16#5A#, doubleBit(2, 5),
                              Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(63, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "DedPair (2,5)");
                writeWithFlip(64, 16#5A#, doubleBit(CodewordWidth_c / 2, CodewordWidth_c / 2 + 1),
                              Clk, Addr, WrData, WrEna, WrEccBitFlip);
                checkDedOnly(64, '0', '1', Clk, Addr, RdEccSec, RdEccDed, "DedPair (mid,mid+1)");

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
