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
-- Dedicated test bench for the OPTIONAL internal scrub pacer of olo_ft_ram_sp_scrub. The pacer
-- gates the free-running scrubber down to one pass every ScrubPeriod_g seconds and raises
-- Scrub_Overrun when a pass cannot finish within a period. Because it fundamentally changes the
-- scrubber's activity pattern (idle gaps between paced passes), it is verified here in isolation
-- rather than in the free-running functional test bench olo_ft_ram_sp_scrub_tb.
--
-- ScrubClkHz_g is a simulation stand-in for the real clock frequency: a small value keeps the
-- period a handful of cycles instead of the millions a real-time period would imply. The pacer
-- logic itself lives in olo_ft_private_scrubber and is shared with the SDP wrapper.
-- vunit: run_all_in_same_sim
entity olo_ft_ram_sp_scrub_pacer_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 2    := 0;
        -- Pacer enabled by default: this test bench only makes sense with the pacer on.
        ScrubClkHz_g   : real                    := 10000.0;
        ScrubPeriod_g  : real                    := 0.03
    );
end entity;

architecture sim of olo_ft_ram_sp_scrub_pacer_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    -- A small Depth_c keeps a scrub pass short so a period spans only a few hundred cycles.
    -- PeriodCycles_c is the pacer period in clock cycles: a ScrubClkHz_g/1000 base tick divided by
    -- round(ScrubPeriod_g*1000). PassCycles_c is the worst-case length of one full scrub pass (one
    -- scrub op every RamRdLatency_g+EccPipeline_g+2 cycles, user idle so no aborts); the period must
    -- exceed it for an idle pass to fit.
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);
    constant Depth_c         : positive := 32;
    constant PeriodCycles_c  : natural  := integer(ScrubClkHz_g / 1000.0) * integer(round(ScrubPeriod_g * 1000.0));
    constant PassCycles_c    : natural  := Depth_c * (RamRdLatency_g + EccPipeline_g + 2);

    -----------------------------------------------------------------------------------------------
    -- Bit-flip pattern helper
    -----------------------------------------------------------------------------------------------
    function singleBit (idx : natural) return std_logic_vector is
        variable Result_v : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    begin
        Result_v(idx) := '1';
        return Result_v;
    end function;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    procedure writeWithFlip (
        address         : natural;
        data            : natural;
        flipBits        : std_logic_vector;
        signal Clk      : in  std_logic;
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

    -- Issue a user read on the shared port. RdEna='1' raises the scrubber's inhibit so the read
    -- returns deterministically RamRdLatency_g + EccPipeline_g cycles later; check the result.
    procedure checkEcc (
        address        : natural;
        data           : natural;
        expEccSec      : std_logic;
        expEccDed      : std_logic;
        signal Clk     : in  std_logic;
        signal Addr    : out std_logic_vector;
        signal RdEna   : out std_logic;
        signal RdData  : in  std_logic_vector;
        signal RdValid : in  std_logic;
        signal EccSec  : in  std_logic;
        signal EccDed  : in  std_logic;
        message        : string) is
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

        check_equal(RdValid, '1',       message & " RdValid");
        check_equal(EccSec,  expEccSec, message & " EccSec");
        check_equal(EccDed,  expEccDed, message & " EccDed");
        check_equal(RdData, toUslv(data, RdData'length), message & " data");
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                        := '0';
    signal Rst            : std_logic                                        := '0';
    signal Addr           : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal WrEna          : std_logic                                        := '0';
    signal WrData         : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal RdEna          : std_logic                                        := '0';
    signal RdData         : std_logic_vector(Width_g - 1 downto 0);
    signal RdValid        : std_logic;
    signal RdEccSec       : std_logic;
    signal RdEccDed       : std_logic;
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0)   := (others => '0');
    signal ErrInj_Valid   : std_logic                                        := '0';
    signal Scrub_Enable   : std_logic                                        := '1';
    signal Scrub_EccSec   : std_logic;
    signal Scrub_EccDed   : std_logic;
    signal Scrub_PassDone : std_logic;
    signal Scrub_Overrun  : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Static configuration sanity
    -----------------------------------------------------------------------------------------------
    -- This TB assumes the pacer is on and that one idle pass fits inside a period; a bad config
    -- would otherwise hang or pass vacuously.
    assert ScrubClkHz_g > 0.0
        report "olo_ft_ram_sp_scrub_pacer_tb requires the pacer enabled (ScrubClkHz_g > 0.0)"
        severity failure;
    assert PeriodCycles_c > PassCycles_c
        report "olo_ft_ram_sp_scrub_pacer_tb requires ScrubPeriod_g long enough for one pass to fit"
        severity failure;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sp_scrub
        generic map (
            Depth_g        => Depth_c,
            Width_g        => Width_g,
            RamBehavior_g  => RamBehavior_g,
            RamRdLatency_g => RamRdLatency_g,
            EccPipeline_g  => EccPipeline_g,
            ScrubClkHz_g   => ScrubClkHz_g,
            ScrubPeriod_g  => ScrubPeriod_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Addr            => Addr,
            WrEna           => WrEna,
            WrData          => WrData,
            RdEna           => RdEna,
            RdData          => RdData,
            RdValid         => RdValid,
            RdEccSec        => RdEccSec,
            RdEccDed        => RdEccDed,
            ErrInj_BitFlip  => ErrInj_BitFlip,
            ErrInj_Valid    => ErrInj_Valid,
            Scrub_Enable    => Scrub_Enable,
            Scrub_EccSec    => Scrub_EccSec,
            Scrub_EccDed    => Scrub_EccDed,
            Scrub_PassDone  => Scrub_PassDone,
            Scrub_Overrun   => Scrub_Overrun
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 5 ms);

    p_control : process is
        variable PassCnt_v : natural;
        variable Gap_v     : natural;
        variable Overrun_v : boolean;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset pulse: brings the pacer and the scrubber FSM to a known idle state.
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '1';
            wait until rising_edge(Clk);
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- One pass per period: with the user idle, each paced pass completes well inside the
            -- period, so consecutive Scrub_PassDone pulses are spaced by ~PeriodCycles_c (not
            -- back-to-back by PassCycles_c as a free-running scrubber would be) and Scrub_Overrun
            -- stays low throughout.
            if run("OnePassPerPeriod") then
                Overrun_v := false;

                -- Wait for the first paced pass to complete.
                loop
                    wait until rising_edge(Clk);
                    if Scrub_Overrun = '1' then
                        Overrun_v := true;
                    end if;
                    exit when Scrub_PassDone = '1';
                end loop;

                -- Measure the gap to the next pass completion.
                Gap_v := 0;

                loop
                    wait until rising_edge(Clk);
                    Gap_v := Gap_v + 1;
                    if Scrub_Overrun = '1' then
                        Overrun_v := true;
                    end if;
                    exit when Scrub_PassDone = '1';
                end loop;

                check_true(Gap_v > PassCycles_c,
                           "OnePassPerPeriod: passes are paced apart (gap exceeds a free-running pass)");
                check_true(Gap_v <= 2 * PeriodCycles_c,
                           "OnePassPerPeriod: pass gap is about one period (pacer keeps advancing)");
                check_true(not Overrun_v,
                           "OnePassPerPeriod: no overrun while idle passes finish within the period");

            -- Overrun watchdog: saturate the single user port so the scrubber is starved and can
            -- never finish a pass. When the next period strobe arrives with the pass still
            -- unfinished, Scrub_Overrun must pulse.
            elsif run("OverrunWhenStarved") then
                Overrun_v := false;

                for i in 1 to 3 * PeriodCycles_c loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Addr   <= toUslv(20, Addr'length);
                        WrData <= toUslv(i, Width_g);
                        WrEna  <= '1';
                        RdEna  <= '0';
                    else
                        Addr  <= toUslv(21, Addr'length);
                        WrEna <= '0';
                        RdEna <= '1';
                    end if;
                    if Scrub_Overrun = '1' then
                        Overrun_v := true;
                    end if;
                end loop;

                WrEna <= '0';
                RdEna <= '0';
                Addr  <= (others => '0');

                check_true(Overrun_v,
                           "OverrunWhenStarved: Scrub_Overrun fires when the user starves the scrubber past a period");

            -- Paced scrubbing still repairs: a paced (gated) scrubber must still find and correct a
            -- planted SEC, just on the slower paced schedule. Plant a SEC, idle for two paced
            -- passes, then read the cell back clean.
            elsif run("PacedScrubFixesSec") then
                writeWithFlip(10, 16#AB#, singleBit(0),
                              Clk, Addr, WrData, WrEna, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(10, 16#AB#, '0', '0', Clk, Addr, RdEna, RdData, RdValid, RdEccSec, RdEccDed,
                         "PacedScrubFixesSec: paced scrubber repaired the SEC");

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
