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
entity olo_ft_ram_sdp_scrub_tb is
    generic (
        runner_cfg     : string;
        Width_g        : positive range 5 to 128 := 32;
        RamBehavior_g  : string                  := "RBW";
        RamRdLatency_g : positive range 1 to 2   := 1;
        EccPipeline_g  : natural range 0 to 2    := 0
    );
end entity;

architecture sim of olo_ft_ram_sdp_scrub_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
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

    procedure preloadFlip (
        flipBits        : std_logic_vector;
        signal Clk      : in  std_logic;
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
        message        : string;
        CheckData      : boolean := true) is
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
        if CheckData then
            check_equal(RdData, toUslv(data, RdData'length), message & " data");
        end if;
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk             : std_logic                                        := '0';
    signal Rst             : std_logic                                        := '0';
    signal Wr_Addr         : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Wr_Ena          : std_logic                                        := '0';
    signal Wr_Data         : std_logic_vector(Width_g - 1 downto 0)           := (others => '0');
    signal Rd_Addr         : std_logic_vector(log2ceil(Depth_c) - 1 downto 0) := (others => '0');
    signal Rd_Ena          : std_logic                                        := '0';
    signal Rd_Data         : std_logic_vector(Width_g - 1 downto 0);
    signal Rd_Valid        : std_logic;
    signal Rd_EccSec       : std_logic;
    signal Rd_EccDed       : std_logic;
    signal ErrInj_BitFlip  : std_logic_vector(CodewordWidth_c - 1 downto 0)   := (others => '0');
    signal ErrInj_Valid    : std_logic                                        := '0';
    signal Scrub_Enable    : std_logic                                        := '1';
    signal Scrub_Rd_Valid  : std_logic;
    signal Scrub_Rd_EccSec : std_logic;
    signal Scrub_Rd_EccDed : std_logic;
    signal Scrub_PassDone  : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ram_sdp_scrub
        generic map (
            Depth_g        => Depth_c,
            Width_g        => Width_g,
            RamBehavior_g  => RamBehavior_g,
            RamRdLatency_g => RamRdLatency_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Wr_Addr         => Wr_Addr,
            Wr_Ena          => Wr_Ena,
            Wr_Data         => Wr_Data,
            Rd_Addr         => Rd_Addr,
            Rd_Ena          => Rd_Ena,
            Rd_Data         => Rd_Data,
            Rd_Valid        => Rd_Valid,
            Rd_EccSec       => Rd_EccSec,
            Rd_EccDed       => Rd_EccDed,
            ErrInj_BitFlip  => ErrInj_BitFlip,
            ErrInj_Valid    => ErrInj_Valid,
            Scrub_Enable    => Scrub_Enable,
            Scrub_Rd_Valid  => Scrub_Rd_Valid,
            Scrub_Rd_EccSec => Scrub_Rd_EccSec,
            Scrub_Rd_EccDed => Scrub_Rd_EccDed,
            Scrub_PassDone  => Scrub_PassDone
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
        variable PassCnt_v    : natural;
        variable RdValidCnt_v : natural;
        variable MaskFail_v   : boolean;
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
                checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 1=5");
                checkEcc(2, 6, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 2=6");
                checkEcc(3, 7, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic 3=7");
                checkEcc(1, 5, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed, "Basic re-read 1=5");

            elsif run("ScrubPassDone") then
                PassCnt_v := 0;

                while PassCnt_v < 3 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "Scrub_PassDone pulsed >= 3 times");

            elsif run("ScrubFixesSec") then
                writeWithFlip(10, 16#AB#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(20, 16#CD#, singleBit(2),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(10, 16#AB#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubFixesSec addr10 cleaned");
                checkEcc(20, 16#CD#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubFixesSec addr20 cleaned");

            elsif run("ScrubDoesNotWriteOnDed") then
                writeWithFlip(70, 16#EE#, doubleBit(0, 1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(70, 0, '0', '1', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "ScrubDoesNotWriteOnDed addr70 still Ded", CheckData => false);

            -- Plant SEC at addr 80, then drive user writes to addr 80 every other cycle for
            -- 400 cycles. User data is always authoritative: any user activity inhibits the
            -- scrubber for the duration, so the scrubber never gets a chance to write back.
            -- The user's writes (clean value 16#BB#, no injection) accumulate; addr 80 must
            -- read clean at the end.
            elsif run("UserWriteWinsDuringContention") then
                writeWithFlip(80, 16#AA#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 400 loop
                    wait until rising_edge(Clk);
                    if (i mod 2) = 0 then
                        Wr_Addr <= toUslv(80, Wr_Addr'length);
                        Wr_Data <= toUslv(16#BB#, Width_g);
                        Wr_Ena  <= '1';
                    else
                        Wr_Ena <= '0';
                    end if;
                end loop;

                wait until rising_edge(Clk);
                Wr_Ena  <= '0';
                Wr_Addr <= (others => '0');
                Wr_Data <= (others => '0');

                checkEcc(80, 16#BB#, '0', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "UserWriteWinsDuringContention: user write wins");

            elsif run("ScrubEnableSuspends") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                for i in 1 to 2 * Depth_c loop
                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "Scrub_PassDone='0' while Scrub_Enable='0' at cycle " & integer'image(i));
                end loop;

                Scrub_Enable <= '1';

                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_true(true, "Scrub_PassDone resumes pulsing after Scrub_Enable='1'");

            elsif run("LatchedInjectionUnderPause") then
                Scrub_Enable <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                preloadFlip(singleBit(0), Clk, ErrInj_BitFlip, ErrInj_Valid);

                for i in 1 to 8 loop
                    wait until rising_edge(Clk);
                end loop;

                write(110, 16#A5#, Clk, Wr_Addr, Wr_Data, Wr_Ena);

                checkEcc(110, 16#A5#, '1', '0', Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Latched injection landed on user write under Scrub_Enable='0'");

                Scrub_Enable <= '1';

            -- PassDone must pulse for exactly one cycle. Observe 3 consecutive pulses and check
            -- Scrub_PassDone is back to '0' on the cycle immediately following each rising edge.
            elsif run("ScrubPassDonePulseWidth") then

                for k in 1 to 3 loop

                    loop
                        wait until rising_edge(Clk);
                        exit when Scrub_PassDone = '1';
                    end loop;

                    wait until rising_edge(Clk);
                    check_equal(Scrub_PassDone, '0',
                                "PassDone pulse width = 1 (pulse " & integer'image(k) & ")");
                end loop;

            -- With the user idle: Scrub_Rd_Valid pulse count = Depth_c per pass, user-facing
            -- Rd_Valid stays '0' (scrubber-owned reads masked). Scrub_Rd_EccSec /
            -- Scrub_Rd_EccDed are pass-throughs of the codec output and not gated, so they
            -- are meaningful only on cycles where Scrub_Rd_Valid='1' -- not checked here.
            elsif run("ScrubRdValidIntegrity") then

                loop
                    wait until rising_edge(Clk);
                    exit when Scrub_PassDone = '1';
                end loop;

                PassCnt_v    := 0;
                RdValidCnt_v := 0;
                MaskFail_v   := false;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_Rd_Valid = '1' then
                        RdValidCnt_v := RdValidCnt_v + 1;
                    end if;
                    if Rd_Valid /= '0' then
                        MaskFail_v := true;
                    end if;
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                check_equal(RdValidCnt_v, 2 * Depth_c,
                            "Scrub_Rd_Valid pulse count = 2 * Depth_c over 2 passes");
                check_true(not MaskFail_v,
                           "User-facing Rd_Valid stays '0' while user is idle (scrubber masking works)");

            -- Address-wrap boundary: SEC at addr 0 (first) and at addr Depth_c - 1 (last,
            -- where Incr_s wraps and PassDone fires).
            elsif run("ScrubBoundaryAddresses") then
                writeWithFlip(0, 16#11#, singleBit(0),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                writeWithFlip(Depth_c - 1, 16#22#, singleBit(1),
                              Clk, Wr_Addr, Wr_Data, Wr_Ena, ErrInj_BitFlip, ErrInj_Valid);
                PassCnt_v := 0;

                while PassCnt_v < 2 loop
                    wait until rising_edge(Clk);
                    if Scrub_PassDone = '1' then
                        PassCnt_v := PassCnt_v + 1;
                    end if;
                end loop;

                checkEcc(0, 16#11#, '0', '0',
                         Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Boundary: SEC at addr 0 corrected");
                checkEcc(Depth_c - 1, 16#22#, '0', '0',
                         Clk, Rd_Addr, Rd_Ena, Rd_Data, Rd_Valid, Rd_EccSec, Rd_EccDed,
                         "Boundary: SEC at addr Depth_c - 1 corrected");

            end if;

        end loop;

        test_runner_cleanup(runner);
    end process;

end architecture;
