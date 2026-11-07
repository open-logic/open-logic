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
entity olo_ft_ram_sdp_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        IsAsync_g      : boolean                 := false;
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_ram_sdp_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant RdClkPeriod_c   : time     := 33.3 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);
    constant Depth_c         : positive := 200;

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
        signal RdEna  : out std_logic;
        signal RdData : in std_logic_vector;
        signal EccSec : in std_logic;
        signal EccDed : in std_logic;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr  <= toUslv(address, Addr'length);
        RdEna <= '1';
        wait until rising_edge(Clk);
        Addr  <= toUslv(0, Addr'length);
        RdEna <= '0';

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
        signal RdEna  : out std_logic;
        signal EccSec : in std_logic;
        signal EccDed : in std_logic;
        message       : string) is
    begin
        wait until rising_edge(Clk);
        Addr  <= toUslv(address, Addr'length);
        RdEna <= '1';
        wait until rising_edge(Clk);
        Addr  <= toUslv(0, Addr'length);
        RdEna <= '0';

        for i in 1 to RamRdLatency_g + EccPipeline_g loop
            wait until rising_edge(Clk);
        end loop;

        check_equal(EccSec, expEccSec, message & " EccSec");
        check_equal(EccDed, expEccDed, message & " EccDed");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic := '0';
    signal Rst            : std_logic := '0';
    -- Write port
    signal Wr_Addr        : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Wr_Ena         : std_logic                                        := '0';
    signal Wr_Data        : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    -- Read port
    signal Rd_Clk         : std_logic                                        := '0';
    signal Rd_Rst         : std_logic                                        := '0';
    signal Rd_Addr        : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Rd_Ena         : std_logic                                        := '0';
    signal Rd_Data        : std_logic_vector(Width_g - 1 downto 0);
    signal Rd_Valid       : std_logic;
    signal Rd_EccSec      : std_logic;
    signal Rd_EccDed      : std_logic;
    -- Error injection
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Valid   : std_logic                                      := '0';

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sdp
        generic map (
            Depth_g        => Depth_c,
            Width_g        => Width_g,
            RamBehavior_g  => RamBehavior_g,
            IsAsync_g      => IsAsync_g,
            RamRdLatency_g => RamRdLatency_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            Wr_Addr        => Wr_Addr,
            Wr_Ena         => Wr_Ena,
            Wr_Data        => Wr_Data,
            Rd_Clk         => Rd_Clk,
            Rd_Rst         => Rd_Rst,
            Rd_Addr        => Rd_Addr,
            Rd_Ena         => Rd_Ena,
            Rd_Data        => Rd_Data,
            Rd_Valid       => Rd_Valid,
            Rd_EccSec      => Rd_EccSec,
            Rd_EccDed      => Rd_EccDed,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
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
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("Basic") then
                write(1, 5, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(2, 6, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(3, 7, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                if IsAsync_g then
                    checkEcc(1, 5, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 1=5");
                    checkEcc(2, 6, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 2=6");
                    checkEcc(3, 7, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 3=7");
                    checkEcc(1, 5, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic re-read 1=5");
                else
                    checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 1=5");
                    checkEcc(2, 6, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 2=6");
                    checkEcc(3, 7, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic 3=7");
                    checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Basic re-read 1=5");
                end if;

            elsif run("EccSec") then
                writeWithFlip(20, 16#AB#, singleBit(0), Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                if IsAsync_g then
                    checkEcc(20, 16#AB#, '1', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Sec flip0");
                else
                    checkEcc(20, 16#AB#, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Sec flip0");
                end if;
                write(20, 16#AB#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                if IsAsync_g then
                    checkEcc(20, 16#AB#, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Sec cleared");
                else
                    checkEcc(20, 16#AB#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Sec cleared");
                end if;

            elsif run("EccDed") then
                writeWithFlip(30, 16#EF#, doubleBit(0, 1), Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                if IsAsync_g then
                    checkDedOnly(30, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "Ded");
                else
                    checkDedOnly(30, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "Ded");
                end if;
                write(30, 16#EF#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                if IsAsync_g then
                    checkEcc(30, 16#EF#, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Ded cleared");
                else
                    checkEcc(30, 16#EF#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Ded cleared");
                end if;

            elsif run("MultiAddr") then
                write(40, 16#01#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(41, 16#02#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                write(42, 16#03#, Clk, Wr_Addr, Wr_Data, Wr_Ena);
                writeWithFlip(41, 16#02#, singleBit(0), Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                if IsAsync_g then
                    checkEcc(40, 16#01#, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr40 clean");
                    checkEcc(41, 16#02#, '1', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr41 sec");
                    checkEcc(42, 16#03#, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr42 clean");
                else
                    checkEcc(40, 16#01#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr40 clean");
                    checkEcc(41, 16#02#, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr41 sec");
                    checkEcc(42, 16#03#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed, "Multi addr42 clean");
                end if;

            elsif run("SecAllBits") then

                for bitIdx in 0 to CodewordWidth_c - 1 loop
                    writeWithFlip(bitIdx, 16#A5#, singleBit(bitIdx),
                                  Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                    if IsAsync_g then
                        checkEcc(bitIdx, 16#A5#, '1', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed,
                                 "SecAllBits flip " & integer'image(bitIdx));
                    else
                        checkEcc(bitIdx, 16#A5#, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed,
                                 "SecAllBits flip " & integer'image(bitIdx));
                    end if;
                end loop;

            elsif run("DedSampledPairs") then
                writeWithFlip(60, 16#5A#, doubleBit(0, 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(61, 16#5A#, doubleBit(0, CodewordWidth_c - 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(62, 16#5A#, doubleBit(1, 2),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(63, 16#5A#, doubleBit(2, 5),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(64, 16#5A#, doubleBit(CodewordWidth_c / 2, CodewordWidth_c / 2 + 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                if IsAsync_g then
                    checkDedOnly(60, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (0,1)");
                    checkDedOnly(61, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (0,N-1)");
                    checkDedOnly(62, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (1,2)");
                    checkDedOnly(63, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (2,5)");
                    checkDedOnly(64, '0', '1', Rd_Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (mid,mid+1)");
                else
                    checkDedOnly(60, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (0,1)");
                    checkDedOnly(61, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (0,N-1)");
                    checkDedOnly(62, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (1,2)");
                    checkDedOnly(63, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (2,5)");
                    checkDedOnly(64, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_EccSec, Rd_EccDed, "DedPair (mid,mid+1)");
                end if;

            elsif run("ResetInFlight") then
                -- A reset asserted while reads are in flight must squash the read-valid
                -- pipeline: with reads still enabled, Rst forces Rd_Valid to '0' (otherwise the
                -- continuous Rd_Ena would keep it high), none leaks out after release, and the RAM
                -- recovers (contents survive, fresh reads decode correctly). Exercises the
                -- read-side reset wired into the base RAM: Rst in sync mode, Rd_Rst in async mode.
                -- Rd_Valid responds through the RamRdLatency_g + EccPipeline_g read-valid pipeline,
                -- so the pipeline is allowed to flush before Rd_Valid is required to be low.
                write(50, 16#3C#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                if IsAsync_g then
                    -- Fill the read pipeline with continuous reads on the read clock
                    wait until rising_edge(Rd_Clk);
                    Rd_Addr <= toUslv(50, Rd_Addr'length);
                    Rd_Ena  <= '1';
                    wait until rising_edge(Rd_Clk);
                    wait until rising_edge(Rd_Clk);
                    -- Assert read-side reset, keep reads enabled, let the pipeline flush
                    Rd_Rst <= '1';

                    for i in 1 to RamRdLatency_g + EccPipeline_g + 1 loop
                        wait until rising_edge(Rd_Clk);
                    end loop;

                    -- Reset must hold Rd_Valid low even though Rd_Ena is still asserted
                    for i in 1 to 3 loop
                        wait until rising_edge(Rd_Clk);
                        check_equal(Rd_Valid, '0', "ResetInFlight: Rd_Valid squashed under Rd_Rst");
                    end loop;

                    -- Release; with no new reads no stale valid may emerge
                    Rd_Ena  <= '0';
                    Rd_Addr <= toUslv(0, Rd_Addr'length);
                    Rd_Rst  <= '0';

                    for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                        wait until rising_edge(Rd_Clk);
                        check_equal(Rd_Valid, '0', "ResetInFlight: no stale Rd_Valid after Rd_Rst");
                    end loop;

                    checkEcc(50, 16#3C#, '0', '0', Rd_Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed,
                             "ResetInFlight recovery");
                else
                    wait until rising_edge(Clk);
                    Rd_Addr <= toUslv(50, Rd_Addr'length);
                    Rd_Ena  <= '1';
                    wait until rising_edge(Clk);
                    wait until rising_edge(Clk);
                    Rst     <= '1';

                    for i in 1 to RamRdLatency_g + EccPipeline_g + 1 loop
                        wait until rising_edge(Clk);
                    end loop;

                    for i in 1 to 3 loop
                        wait until rising_edge(Clk);
                        check_equal(Rd_Valid, '0', "ResetInFlight: Rd_Valid squashed under Rst");
                    end loop;

                    Rd_Ena  <= '0';
                    Rd_Addr <= toUslv(0, Rd_Addr'length);
                    Rst     <= '0';

                    for i in 1 to RamRdLatency_g + EccPipeline_g + 2 loop
                        wait until rising_edge(Clk);
                        check_equal(Rd_Valid, '0', "ResetInFlight: no stale Rd_Valid after Rst");
                    end loop;

                    checkEcc(50, 16#3C#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_EccSec, Rd_EccDed,
                             "ResetInFlight recovery");
                end if;

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
