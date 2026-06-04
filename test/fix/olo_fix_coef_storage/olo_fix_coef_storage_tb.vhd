---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
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
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_coef_storage_tb is
    generic (
        runner_cfg    : string;
        StorageType_g : string   := "ROM";
        RamReadback_g : boolean  := false;
        RamBehavior_g : string   := "RBW";
        RdLatency_g   : positive := 1
    );
end entity;

architecture sim of olo_fix_coef_storage_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Fmt_c     : FixFormat_t := (1, 4, 4);
    constant Depth_c   : positive    := 4;
    -- Init_g has 2 entries: addr 0 = 1.0, addr 1 = 0.5; addr 2-3 are uninitialized (= 0.0)
    constant InitStr_c : string := "1.0, 0.5";

    -- Address assignments:
    --   0, 1 : initialized values - NEVER written by TB so InitValues always sees clean data
    --   2    : uninitialized, NEVER written by TB so UninitElements always sees zero
    --   3    : scratch address used by write tests
    constant AddrInit0_c   : natural := 0;
    constant AddrInit1_c   : natural := 1;
    constant AddrUninit_c  : natural := 2;
    constant AddrScratch_c : natural := 3;

    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic                                          := '0';
    signal Rst          : std_logic                                          := '0';
    signal Cfg_Addr     : std_logic_vector(log2Ceil(Depth_c) - 1 downto 0)   := (others => 'X');
    signal Cfg_WrEna    : std_logic                                          := '0';
    signal Cfg_WrData   : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0) := (others => 'X');
    signal Cfg_RdEna    : std_logic                                          := '0';
    signal Cfg_RdData   : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0);
    signal Cfg_RdValid  : std_logic;
    signal Coef_Addr    : std_logic_vector(log2Ceil(Depth_c) - 1 downto 0)   := (others => 'X');
    signal Coef_RdEna   : std_logic                                          := '0';
    signal Coef_RdData  : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0);
    signal Coef_RdValid : std_logic;

    -----------------------------------------------------------------------------------------------
    -- Procedures
    -----------------------------------------------------------------------------------------------

    -- Single-cycle write to the Cfg port.
    procedure cfgWrite (
        address       : natural;
        value         : real;
        signal Clk    : in  std_logic;
        signal Addr   : out std_logic_vector(log2Ceil(Depth_c) - 1 downto 0);
        signal WrData : out std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0);
        signal WrEna  : out std_logic) is
    begin
        wait until rising_edge(Clk);
        wait for 100 ps;
        Addr   <= toUslv(address, Addr'length);
        WrData <= cl_fix_from_real(value, Fmt_c);
        WrEna  <= '1';
        wait until rising_edge(Clk);
        wait for 100 ps;
        WrEna  <= '0';
        Addr   <= (others => 'X');
        WrData <= (others => 'X');
    end procedure;

    -- Single read from either the Cfg or the Coef port.
    procedure portRead (
        address         : natural;
        expected        : real;
        msg             : string;
        signal Clk      : in  std_logic;
        signal Addr     : out std_logic_vector(log2Ceil(Depth_c) - 1 downto 0);
        signal RdEna    : out std_logic;
        signal RdData   : in  std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0);
        signal RdValid  : in  std_logic;
        expectedRdValid : std_logic := '1') is
    begin
        wait until rising_edge(Clk);
        wait for 100 ps;
        Addr  <= toUslv(address, Addr'length);
        RdEna <= '1';
        check_equal(RdValid, '0', msg & " - RdValid prematurely high");
        wait until rising_edge(Clk);
        wait for 100 ps;
        RdEna <= '0';
        Addr  <= (others => 'X');
        if expectedRdValid = '1' then

            for i in 1 to RdLatency_g - 1 loop
                wait until falling_edge(Clk);
                check_equal(RdValid, '0', msg & " - RdValid too early at step " & integer'image(i));
            end loop;

            wait until falling_edge(Clk); -- data valid here
            check_equal(RdData, cl_fix_from_real(expected, Fmt_c), msg & " - data");
            check_equal(RdValid, '1', msg & " - RdValid not high");
            wait until rising_edge(Clk); -- RdValid deasserts here (RdEna already dropped)
            wait for 100 ps;
            check_equal(RdValid, '0', msg & " - RdValid not deasserted");
        else

            for i in 1 to RdLatency_g + 1 loop
                wait until falling_edge(Clk);
                check_equal(RdData, cl_fix_from_real(expected, Fmt_c), msg & " - data not zero cycle " & integer'image(i));
                check_equal(RdValid, '0', msg & " - RdValid not zero cycle " & integer'image(i));
            end loop;

        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset before each test (clears valid pipes; RAM/ROM data is unaffected)
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** InitValues: addresses 0 and 1 carry their Init_g values ***
            -- Addresses 0 and 1 are never written by any test case.
            if run("InitValues") then
                portRead(AddrInit0_c, 1.0, "InitValues: addr0", Clk, Coef_Addr, Coef_RdEna, Coef_RdData, Coef_RdValid);
                portRead(AddrInit1_c, 0.5, "InitValues: addr1", Clk, Coef_Addr, Coef_RdEna, Coef_RdData, Coef_RdValid);
            end if;

            -- *** UninitElements: element with no Init_g entry must come out as zero ***
            -- Address 2 is never written by any test case.
            if run("UninitElements") then
                portRead(AddrUninit_c, 0.0, "UninitElements", Clk, Coef_Addr, Coef_RdEna, Coef_RdData, Coef_RdValid);
            end if;

            -- *** RomWriteIgnored: writing via Cfg port has no effect for StorageType_g = "ROM" ***
            if run("RomWriteIgnored") then
                if StorageType_g = "ROM" then
                    -- Attempt to write 2.0 over the 1.0 init value at addr 0
                    cfgWrite(AddrInit0_c, 2.0, Clk, Cfg_Addr, Cfg_WrData, Cfg_WrEna);
                    -- ROM must still return the original 1.0
                    portRead(AddrInit0_c, 1.0, "RomWriteIgnored", Clk, Coef_Addr, Coef_RdEna, Coef_RdData, Coef_RdValid);
                end if;
            end if;

            -- *** ReadbackDisabled: Cfg_RdValid stay zero regardless of Cfg_RdEna ***
            -- Applies when StorageType_g = "ROM" or RamReadback_g = false.
            if run("ReadbackDisabled") then
                if StorageType_g = "ROM" or not RamReadback_g then
                    portRead(AddrInit0_c, 0.0, "ReadbackDisabled", Clk, Cfg_Addr, Cfg_RdEna, Cfg_RdData, Cfg_RdValid,
                             expectedRdValid => '0');
                end if;
            end if;

            -- *** ReadbackEnabled: write via Cfg, then read back via Cfg port ***
            -- Only active when StorageType_g = "RAM" and RamReadback_g = true.
            if run("ReadbackEnabled") then
                if StorageType_g = "RAM" and RamReadback_g then
                    cfgWrite(AddrScratch_c, 2.0, Clk, Cfg_Addr, Cfg_WrData, Cfg_WrEna);
                    portRead(AddrScratch_c, 2.0, "ReadbackEnabled", Clk, Cfg_Addr, Cfg_RdEna, Cfg_RdData, Cfg_RdValid);
                end if;
            end if;

            -- *** RamBehavior: simultaneous Cfg write + Coef read at same address ***
            -- Only active for StorageType_g = "RAM".
            if run("RamBehavior") then
                if StorageType_g = "RAM" then
                    -- Pre-load scratch address with known value 1.0
                    cfgWrite(AddrScratch_c, 1.0, Clk, Cfg_Addr, Cfg_WrData, Cfg_WrEna);

                    -- Simultaneously write 2.0 and read scratch address in the same clock cycle
                    wait until rising_edge(Clk);
                    wait for 100 ps;
                    Cfg_Addr   <= toUslv(AddrScratch_c, Cfg_Addr'length);
                    Cfg_WrData <= cl_fix_from_real(2.0, Fmt_c);
                    Cfg_WrEna  <= '1';
                    Coef_Addr  <= toUslv(AddrScratch_c, Coef_Addr'length);
                    Coef_RdEna <= '1';
                    wait until rising_edge(Clk); -- simultaneous write and read sampled
                    wait for 100 ps;
                    Cfg_WrEna  <= '0';
                    Coef_RdEna <= '0';
                    Cfg_Addr   <= (others => 'X');
                    Coef_Addr  <= (others => 'X');
                    Cfg_WrData <= (others => 'X');

                    for i in 1 to RdLatency_g - 1 loop
                        wait until falling_edge(Clk);
                    end loop;

                    wait until falling_edge(Clk);
                    check_equal(Coef_RdValid, '1', "RamBehavior: Coef_RdValid");
                    if RamBehavior_g = "RBW" then
                        check_equal(Coef_RdData, cl_fix_from_real(1.0, Fmt_c),
                                    "RamBehavior: RBW - expects old value 1.0");
                    else
                        check_equal(Coef_RdData, cl_fix_from_real(2.0, Fmt_c),
                                    "RamBehavior: WBR - expects new value 2.0");
                    end if;
                end if;
            end if;

            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_coef_storage
        generic map (
            Depth_g       => Depth_c,
            Fmt_g         => to_string(Fmt_c),
            Init_g        => InitStr_c,
            StorageType_g => StorageType_g,
            RamReadback_g => RamReadback_g,
            RamBehavior_g => RamBehavior_g,
            RdLatency_g   => RdLatency_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            Cfg_Addr     => Cfg_Addr,
            Cfg_WrEna    => Cfg_WrEna,
            Cfg_WrData   => Cfg_WrData,
            Cfg_RdEna    => Cfg_RdEna,
            Cfg_RdData   => Cfg_RdData,
            Cfg_RdValid  => Cfg_RdValid,
            Coef_Addr    => Coef_Addr,
            Coef_RdEna   => Coef_RdEna,
            Coef_RdData  => Coef_RdData,
            Coef_RdValid => Coef_RdValid
        );

end architecture;
