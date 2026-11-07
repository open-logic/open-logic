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
entity olo_ft_ram_tdp_tb is
    generic (
        runner_cfg       : string;
        Width_g          : positive range 5 to 128 := 32;
        RamBehavior_g    : string                  := "RBW";
        RamRdLatency_g   : positive range 1 to 2   := 1;
        EccPipeline_g    : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_ram_tdp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkAPeriod_c    : time     := 10 ns;
    constant ClkBPeriod_c    : time     := 33.3 ns;
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
        address         : natural;
        data            : natural;
        flipBits        : std_logic_vector;
        signal Clk      : in std_logic;
        signal Addr     : out std_logic_vector;
        signal WrData   : out std_logic_vector;
        signal WrEna    : out std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic) is
    begin
        wait until rising_edge(Clk);
        Addr     <= toUslv(address, Addr'length);
        WrData   <= toUslv(data, WrData'length);
        WrEna    <= '1';
        InjFlip  <= flipBits;
        InjValid <= '1';
        wait until rising_edge(Clk);
        WrEna    <= '0';
        InjFlip  <= (InjFlip'range => '0');
        InjValid <= '0';
        Addr     <= toUslv(0, Addr'length);
        WrData   <= toUslv(0, WrData'length);
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
        Addr <= toUslv(0, Addr'length);

        -- Wait for read data to arrive
        for i in 1 to RamRdLatency_g + EccPipeline_g loop
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
        Addr <= toUslv(0, Addr'length);

        -- Wait for read data to arrive
        for i in 1 to RamRdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(EccSec, expEccSec, message & " EccSec");
        check_equal(EccDed, expEccDed, message & " EccDed");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal A_Clk            : std_logic                                      := '0';
    signal A_Addr           : std_logic_vector(7 downto 0);
    signal A_WrEna          : std_logic                                      := '0';
    signal A_WrData         : std_logic_vector(Width_g - 1 downto 0);
    signal A_RdEna          : std_logic                                      := '1';
    signal A_ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal A_ErrInj_Valid   : std_logic                                      := '0';
    signal A_RdData         : std_logic_vector(Width_g - 1 downto 0);
    signal A_RdEccSec       : std_logic;
    signal A_RdEccDed       : std_logic;
    signal B_Clk            : std_logic                                      := '0';
    signal B_Addr           : std_logic_vector(7 downto 0);
    signal B_WrEna          : std_logic                                      := '0';
    signal B_WrData         : std_logic_vector(Width_g - 1 downto 0);
    signal B_RdEna          : std_logic                                      := '1';
    signal B_ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal B_ErrInj_Valid   : std_logic                                      := '0';
    signal B_RdData         : std_logic_vector(Width_g - 1 downto 0);
    signal B_RdEccSec       : std_logic;
    signal B_RdEccDed       : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_tdp
        generic map (
            Depth_g          => 200,
            Width_g          => Width_g,
            RamBehavior_g    => RamBehavior_g,
            RamRdLatency_g   => RamRdLatency_g,
            EccPipeline_g    => EccPipeline_g
        )
        port map (
            A_Clk            => A_Clk,
            A_Addr           => A_Addr,
            A_WrEna          => A_WrEna,
            A_WrData         => A_WrData,
            A_RdEna          => A_RdEna,
            A_ErrInj_BitFlip => A_ErrInj_BitFlip,
            A_ErrInj_Valid   => A_ErrInj_Valid,
            A_RdData         => A_RdData,
            A_RdEccSec       => A_RdEccSec,
            A_RdEccDed       => A_RdEccDed,
            B_Clk            => B_Clk,
            B_Addr           => B_Addr,
            B_WrEna          => B_WrEna,
            B_WrData         => B_WrData,
            B_RdEna          => B_RdEna,
            B_ErrInj_BitFlip => B_ErrInj_BitFlip,
            B_ErrInj_Valid   => B_ErrInj_Valid,
            B_RdData         => B_RdData,
            B_RdEccSec       => B_RdEccSec,
            B_RdEccDed       => B_RdEccDed
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    A_Clk <= not A_Clk after 0.5 * ClkAPeriod_c;
    B_Clk <= not B_Clk after 0.5 * ClkBPeriod_c;

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

            -- Basic write and read, no errors expected
            if run("BasicA-A") then
                write(1, 5, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(2, 6, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(3, 7, A_Clk, A_Addr, A_WrData, A_WrEna);
                checkEcc(1, 5, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "A-A 1=5");
                checkEcc(2, 6, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "A-A 2=6");
                checkEcc(3, 7, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "A-A 3=7");
                -- Re-read
                checkEcc(1, 5, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "A-A re-read 1=5");

            elsif run("BasicB-B") then
                write(1, 5, B_Clk, B_Addr, B_WrData, B_WrEna);
                write(2, 6, B_Clk, B_Addr, B_WrData, B_WrEna);
                write(3, 7, B_Clk, B_Addr, B_WrData, B_WrEna);
                checkEcc(1, 5, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "B-B 1=5");
                checkEcc(2, 6, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "B-B 2=6");
                checkEcc(3, 7, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "B-B 3=7");

            -- Cross-port: write A, read B
            elsif run("BasicA-B") then
                write(1, 5, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(2, 6, A_Clk, A_Addr, A_WrData, A_WrEna);
                checkEcc(1, 5, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "A-B 1=5");
                checkEcc(2, 6, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "A-B 2=6");

            -- Cross-port: write B, read A
            elsif run("BasicB-A") then
                write(1, 5, B_Clk, B_Addr, B_WrData, B_WrEna);
                write(2, 6, B_Clk, B_Addr, B_WrData, B_WrEna);
                checkEcc(1, 5, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "B-A 1=5");
                checkEcc(2, 6, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "B-A 2=6");

            -- Various data patterns without errors
            elsif run("NoError-Patterns") then
                write(10, 16#AA#, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(11, 16#55#, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(12, 0, A_Clk, A_Addr, A_WrData, A_WrEna);
                checkEcc(10, 16#AA#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "NoErr AA");
                checkEcc(11, 16#55#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "NoErr 55");
                checkEcc(12, 0, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "NoErr 00");
                -- Cross-port
                checkEcc(10, 16#AA#, '0', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "NoErr AA B");

            -- Single bit error injection and correction via port A
            elsif run("EccSec-PortA") then
                -- Inject single-bit flip (bit 0)
                writeWithFlip(20, 16#AB#, singleBit(0), A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                -- Read back: data corrected, EccSec flagged
                checkEcc(20, 16#AB#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Sec A-A flip0");
                -- Cross-port read
                checkEcc(20, 16#AB#, '1', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "Sec A-B flip0");
                -- Inject single-bit flip (bit 1)
                writeWithFlip(21, 16#CD#, singleBit(1), A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkEcc(21, 16#CD#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Sec A-A flip1");

            -- Single bit error injection via port B
            elsif run("EccSec-PortB") then
                writeWithFlip(25, 16#EF#, singleBit(0), B_Clk, B_Addr, B_WrData, B_WrEna, B_ErrInj_BitFlip, B_ErrInj_Valid);
                checkEcc(25, 16#EF#, '1', '0', B_Clk, B_Addr, B_RdData, B_RdEccSec, B_RdEccDed, "Sec B-B");
                checkEcc(25, 16#EF#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Sec B-A");

            -- Overwrite corrects error
            elsif run("EccSec-Overwrite") then
                writeWithFlip(30, 16#AB#, singleBit(0), A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkEcc(30, 16#AB#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Sec before overwrite");
                -- Overwrite with clean data
                write(30, 16#AB#, A_Clk, A_Addr, A_WrData, A_WrEna);
                checkEcc(30, 16#AB#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Sec after overwrite");

            -- Double bit error detection
            elsif run("EccDed") then
                -- Inject double-bit flip
                writeWithFlip(35, 16#EF#, doubleBit(0, 1), A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                -- Read back: EccDed flagged, data unreliable
                checkDedOnly(35, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "Ded A");
                -- Cross-port
                checkDedOnly(35, '0', '1', B_Clk, B_Addr, B_RdEccSec, B_RdEccDed, "Ded B");
                -- Overwrite clears error
                write(35, 16#EF#, A_Clk, A_Addr, A_WrData, A_WrEna);
                checkEcc(35, 16#EF#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Ded cleared");

            -- Multiple addresses: errors don't cross-contaminate
            elsif run("MultiAddr") then
                write(40, 16#01#, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(41, 16#02#, A_Clk, A_Addr, A_WrData, A_WrEna);
                write(42, 16#03#, A_Clk, A_Addr, A_WrData, A_WrEna);
                -- Inject single error at address 41 only
                writeWithFlip(41, 16#02#, singleBit(0), A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkEcc(40, 16#01#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Multi addr40 clean");
                checkEcc(41, 16#02#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Multi addr41 sec");
                checkEcc(42, 16#03#, '0', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed, "Multi addr42 clean");

            -- SEC across every codeword bit position (full bit-by-bit sweep, port A)
            elsif run("SecAllBits") then

                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    writeWithFlip(bitIdx, 16#A5#, singleBit(bitIdx),
                                  A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                    checkEcc(bitIdx, 16#A5#, '1', '0', A_Clk, A_Addr, A_RdData, A_RdEccSec, A_RdEccDed,
                             "SecAllBits flip " & integer'image(bitIdx));
                end loop;

            -- DED across a representative sample of bit pairs (port A)
            elsif run("DedSampledPairs") then
                writeWithFlip(60, 16#5A#, doubleBit(0, 1),
                              A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkDedOnly(60, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "DedPair (0,1)");
                writeWithFlip(61, 16#5A#, doubleBit(0, CodewordWidth_c - 1),
                              A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkDedOnly(61, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "DedPair (0,N-1)");
                writeWithFlip(62, 16#5A#, doubleBit(1, 2),
                              A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkDedOnly(62, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "DedPair (1,2)");
                writeWithFlip(63, 16#5A#, doubleBit(2, 5),
                              A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkDedOnly(63, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "DedPair (2,5)");
                writeWithFlip(64, 16#5A#, doubleBit(CodewordWidth_c / 2, CodewordWidth_c / 2 + 1),
                              A_Clk, A_Addr, A_WrData, A_WrEna, A_ErrInj_BitFlip, A_ErrInj_Valid);
                checkDedOnly(64, '0', '1', A_Clk, A_Addr, A_RdEccSec, A_RdEccDed, "DedPair (mid,mid+1)");

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
