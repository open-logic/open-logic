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
    use olo.olo_base_pkg_logic.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_ram_sp_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 1    := 0
    );
end entity;

architecture sim of olo_ft_ram_sp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

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

    -- Write with simultaneous error injection (legacy semantics: flip applied immediately).
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

    -- Preload an injection pattern without writing. Pattern is held in the entity's latch and
    -- applied to the next write.
    procedure preloadFlip (
        flipBits        : std_logic_vector;
        signal Clk      : in std_logic;
        signal InjFlip  : out std_logic_vector;
        signal InjValid : out std_logic) is
    begin
        wait until rising_edge(Clk);
        InjFlip  <= flipBits;
        InjValid <= '1';
        wait until rising_edge(Clk);
        InjFlip  <= (InjFlip'range => '0');
        InjValid <= '0';
    end procedure;

    procedure checkEcc (
        address        : natural;
        data           : natural;
        expEccSec      : std_logic;
        expEccDed      : std_logic;
        signal Clk     : in std_logic;
        signal Addr    : out std_logic_vector;
        signal RdData  : in std_logic_vector;
        signal RdValid : in std_logic;
        signal EccSec  : in std_logic;
        signal EccDed  : in std_logic;
        message        : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled

        -- Wait for read data to arrive
        for i in 1 to RamRdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdValid, '1',                          message & " RdValid");
        check_equal(RdData,  toUslv(data, RdData'length),  message & " data");
        check_equal(EccSec,  expEccSec,                    message & " EccSec");
        check_equal(EccDed,  expEccDed,                    message & " EccDed");
    end procedure;

    procedure checkDedOnly (
        address        : natural;
        expEccSec      : std_logic;
        expEccDed      : std_logic;
        signal Clk     : in std_logic;
        signal Addr    : out std_logic_vector;
        signal RdValid : in std_logic;
        signal EccSec  : in std_logic;
        signal EccDed  : in std_logic;
        message        : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= toUslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled

        -- Wait for read data to arrive
        for i in 1 to RamRdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(RdValid, '1',       message & " RdValid");
        check_equal(EccSec,  expEccSec, message & " EccSec");
        check_equal(EccDed,  expEccDed, message & " EccDed");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                := '0';
    signal Addr           : std_logic_vector(7 downto 0)             := (others => '0');
    signal WrEna          : std_logic                                := '0';
    signal WrData         : std_logic_vector(Width_g - 1 downto 0);
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Valid   : std_logic                                := '0';
    signal RdData         : std_logic_vector(Width_g - 1 downto 0);
    signal RdValid        : std_logic;
    signal RdEccSec       : std_logic;
    signal RdEccDed       : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sp
        generic map (
            Depth_g        => 200,
            Width_g        => Width_g,
            RamBehavior_g  => RamBehavior_g,
            RamRdLatency_g => RamRdLatency_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk            => Clk,
            Addr           => Addr,
            WrEna          => WrEna,
            WrData         => WrData,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid,
            RdData         => RdData,
            RdValid        => RdValid,
            RdEccSec       => RdEccSec,
            RdEccDed       => RdEccDed
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
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Basic re-read 1=5");

            -- Single bit error injection and correction (immediate: ErrInj_Valid + WrEna same cycle)
            elsif run("EccSec") then
                writeWithFlip(20, 16#AB#, setBits(0, CodewordWidth_c), Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkEcc(20, 16#AB#, '1', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Sec flip0");
                writeWithFlip(21, 16#CD#, setBits(1, CodewordWidth_c), Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkEcc(21, 16#CD#, '1', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Sec flip1");
                -- Overwrite clears error
                write(20, 16#AB#, Clk, Addr, WrData, WrEna);
                checkEcc(20, 16#AB#, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Sec cleared");

            -- Double bit error detection
            elsif run("EccDed") then
                writeWithFlip(30, 16#EF#, setBits(0, 1, CodewordWidth_c), Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(30, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "Ded");
                -- Overwrite clears error
                write(30, 16#EF#, Clk, Addr, WrData, WrEna);
                checkEcc(30, 16#EF#, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Ded cleared");

            -- Multiple addresses: errors don't cross-contaminate
            elsif run("MultiAddr") then
                write(40, 16#01#, Clk, Addr, WrData, WrEna);
                write(41, 16#02#, Clk, Addr, WrData, WrEna);
                write(42, 16#03#, Clk, Addr, WrData, WrEna);
                writeWithFlip(41, 16#02#, setBits(0, CodewordWidth_c), Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkEcc(40, 16#01#, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Multi addr40 clean");
                checkEcc(41, 16#02#, '1', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Multi addr41 sec");
                checkEcc(42, 16#03#, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed, "Multi addr42 clean");

            -- SEC across every codeword bit position (full bit-by-bit sweep)
            elsif run("SecAllBits") then
                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    writeWithFlip(bitIdx, 16#A5#, setBits(bitIdx, CodewordWidth_c),
                                  Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                    checkEcc(bitIdx, 16#A5#, '1', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed,
                             "SecAllBits flip " & integer'image(bitIdx));
                end loop;

            -- DED across a representative sample of bit pairs (parity+parity, parity+data, data+data, far-apart)
            elsif run("DedSampledPairs") then
                writeWithFlip(60, 16#5A#, setBits(0, 1, CodewordWidth_c),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(60, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "DedPair (0,1)");
                writeWithFlip(61, 16#5A#, setBits(0, CodewordWidth_c - 1, CodewordWidth_c),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(61, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "DedPair (0,N-1)");
                writeWithFlip(62, 16#5A#, setBits(1, 2, CodewordWidth_c),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(62, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "DedPair (1,2)");
                writeWithFlip(63, 16#5A#, setBits(2, 5, CodewordWidth_c),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(63, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "DedPair (2,5)");
                writeWithFlip(64, 16#5A#, setBits(CodewordWidth_c / 2, CodewordWidth_c / 2 + 1, CodewordWidth_c),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);
                checkDedOnly(64, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed, "DedPair (mid,mid+1)");

            -- Latched-injection semantics: preload a pattern with ErrInj_Valid='1' & WrEna='0',
            -- wait a few cycles, then issue a write. The latched pattern must be applied to the
            -- delayed write. Also covers that the latch is cleared after the write so a subsequent
            -- write does not re-apply the pattern.
            elsif run("LatchedInjection") then
                -- Preload a single-bit flip; wait a few idle cycles; then write.
                preloadFlip(setBits(0, CodewordWidth_c), Clk, ErrInj_BitFlip, ErrInj_Valid);
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                write(70, 16#3C#, Clk, Addr, WrData, WrEna);
                checkEcc(70, 16#3C#, '1', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed,
                         "Latched flip applied to delayed write");

                -- After the latched write, the latch should be cleared. A subsequent write to a
                -- different address must NOT trigger any ECC error.
                write(71, 16#5A#, Clk, Addr, WrData, WrEna);
                checkEcc(71, 16#5A#, '0', '0', Clk, Addr, RdData, RdValid, RdEccSec, RdEccDed,
                         "Latch cleared after write");

                -- Re-preloading a different pattern overwrites any previously stored one.
                preloadFlip(setBits(2, CodewordWidth_c), Clk, ErrInj_BitFlip, ErrInj_Valid);
                preloadFlip(setBits(0, 1, CodewordWidth_c), Clk, ErrInj_BitFlip, ErrInj_Valid);
                write(72, 16#A5#, Clk, Addr, WrData, WrEna);
                checkDedOnly(72, '0', '1', Clk, Addr, RdValid, RdEccSec, RdEccDed,
                             "Latest preload wins (DED pair after re-preload)");

            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
