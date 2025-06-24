---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Rene Brglez (rene.brglez@gmail.com)
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library OSVVM ;
    use OSVVM.RandomBasePkg.all ;
    use OSVVM.RandomPkg.all ;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_arb_wrr_tb is
    generic (
        runner_cfg    : string;
        GrantWidth_g  : positive;
        WeightWidth_g : positive;
        Seed_g        : positive := 42
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture sim of olo_base_arb_wrr_tb is

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                                   := '0';
    signal Rst        : std_logic                                                   := '0';
    signal In_Weights : std_logic_vector(WeightWidth_g * GrantWidth_g - 1 downto 0) := (others => '0');
    signal In_Req     : std_logic_vector(GrantWidth_g - 1 downto 0)                 := (others => '0');
    signal Out_Ready  : std_logic                                                   := '0';
    signal Out_Valid  : std_logic                                                   := '0';
    signal Out_Grant  : std_logic_vector(GrantWidth_g - 1 downto 0)                 := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real     := 100.0e6;
    constant Clk_Period_c    : time     := (1 sec) / Clk_Frequency_c;
    constant Tpd_c           : time     := Clk_Period_c / 10;
    constant NumCycles       : positive := 4;

    -----------------------------------------------------------------------------------------------
    -- Procedures
    -----------------------------------------------------------------------------------------------
    procedure check_weighted_grant (
            signal Clk                : in    std_logic;
            CycleIdx                  : in    natural;
            GrantIdx                  : in    natural;
            signal In_Req             : in    std_logic_vector;
            signal In_Weights         : in    std_logic_vector;
            signal ActualGrant        : in    std_logic_vector;
            signal ActualValid        : in    std_logic;
            variable LastCheckedGrant : inout natural;
            constant Tpd              : in    time    := Tpd_c;
            constant WeightWidth      : in    natural := WeightWidth_g
        ) is
        variable Weight_v        : natural;
        variable ExpectedGrant_v : std_logic_vector(ActualGrant'range);
    begin
        -- Extract the weight for the current grant index from the weight vector
        Weight_v := fromUslv(In_Weights((GrantIdx + 1) * WeightWidth - 1 downto GrantIdx * WeightWidth));
        -- Set the next expected grant vector
        ExpectedGrant_v           := (others => '0');
        ExpectedGrant_v(GrantIdx) := '1';

        if (In_Req(GrantIdx) = '1') then

            for CheckIdx in 0 to Weight_v - 1 loop
                info(
                    "CycleIdx = " & to_string(CycleIdx) & " " &
                    "GrantIdx = " & to_string(GrantIdx) & " " &
                    "CheckIdx = " & to_string(CheckIdx) & " " &
                    "Weight = " & to_string(Weight_v) & " " &
                    "ExpectedGrant = " & to_string(ExpectedGrant_v) & " " &
                    "ActualGrant = " & to_string(Out_Grant)
                );
                check_equal(Out_Grant, ExpectedGrant_v, "Out_Grant Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd;
            end loop;

            -- Save the most recent grant index that was checked and not skipped
            LastCheckedGrant := GrantIdx;
        else
            info(
                "CycleIdx = " & to_string(CycleIdx) & " " &
                "Skipped GrantIdx = " & to_string(GrantIdx) & " because its corresponding request is not active"
            );
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_arb_wrr
        generic map (
            GrantWidth_g  => GrantWidth_g,
            WeightWidth_g => WeightWidth_g
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Weights => In_Weights,
            In_Req     => In_Req,
            Out_Grant  => Out_Grant,
            Out_Ready  => Out_Ready,
            Out_Valid  => Out_Valid
        );

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable ExpectedGrant_v    : std_logic_vector(Out_Grant'range);
        variable Weight_v           : integer;
        variable LastCheckedGrant_v : natural;
        variable RandGen_v          : RandomPType;
    begin
        test_runner_setup(runner, runner_cfg);

        -- Initialize the random generator with a fixed seed for reproducible test results
        RandGen_v.InitSeed(Seed_g);

        while test_suite loop

            -- Reset
            Rst <= '1';
            wait for Clk_Period_c * 5;
            Rst <= '0';

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RRLikeWeights_SingleBit") then
                -- Set Weights to behave as Round Robin arbiter
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(1, WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req                     <= (others => '0');
                In_Req(3 mod GrantWidth_g) <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, In_Req, "Out_Grant 1 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, In_Req, "Out_Grant 2 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '0');
                wait for Tpd_c;
                check_equal(Out_Grant, In_Req, "Out_Grant not de-asserted");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RRLikeWeights_MultiBit") and GrantWidth_g = 5 then
                -- Set Weights to behave as Round Robin arbiter
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(1, WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                In_Req <= "10000";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 3 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= "10111";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant 4 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 5 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 6 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 7 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant 8 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= "00001";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 9 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= "11001";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 10 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#01000#, "Out_Grant 11 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                In_Req <= "00000";
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RRLikeWeights_ReadyLow") and GrantWidth_g = 5 then
                -- Set Weights to behave as Round Robin arbiter
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(1, WeightWidth_g);
                end loop;
                -- Start test
                Out_Ready <= '0';
                In_Req    <= "10011";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 12 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                Out_Ready <= '1';
                check_equal(Out_Grant, 2#10000#, "Out_Grant 12 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 13 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00010#, "Out_Grant 13 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 14 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                In_Req <= "10001";
                check_equal(Out_Grant, 2#00001#, "Out_Grant 14 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 15 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant 15 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 16 Wrong");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00001#, "Out_Grant 16 not kept");
                check_equal(Out_Valid, '1', "Valid low unexpectedly");
                Out_Ready <= '0';
                In_Req    <= "00000";
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RRLikeWeights_ExampleFromDoc") and GrantWidth_g = 5 then
                -- Set Weights to behave as Round Robin arbiter
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(1, WeightWidth_g);
                end loop;
                Out_Ready <= '0';
                wait until rising_edge(Clk);
                In_Req <= "10110";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 0");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 1");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 1");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 2");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 2");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 3");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 3");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00010#, "Out_Grant Wrong, Doc 4");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 4");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#10000#, "Out_Grant Wrong, Doc 5");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 5");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 6");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 6");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 7");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 7");
                wait until rising_edge(Clk);
                In_Req <= "01100";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 8");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 8");
                wait until rising_edge(Clk);
                wait for Tpd_c;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 9");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 9");
                wait until rising_edge(Clk);
                Out_Ready <= '1';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#01000#, "Out_Grant Wrong, Doc 10");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 10");
                wait until rising_edge(Clk);
                Out_Ready <= '0';
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00100#, "Out_Grant Wrong, Doc 11");
                check_equal(Out_Valid, '1', "Valid Wrong, Doc 11");
                wait until rising_edge(Clk);
                In_Req <= "00000";
                wait for Tpd_c;
                check_equal(Out_Grant, 2#00000#, "Out_Grant Wrong, Doc 12");
                check_equal(Out_Valid, '0', "Valid Wrong, Doc 12");
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("IncrementingWeights_AllBits") then
                -- Set Incementing Weights
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(i + 1, WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '1');
                wait for Tpd_c;
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("DecrementingWeights_AllBits") then
                -- Set Incementing Weights
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(GrantWidth_g - i, WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '1');
                wait for Tpd_c;
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomNonZeroWeights_AllBits") then
                -- Set Random Weights
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(RandGen_v.RandInt(1, 2 ** WeightWidth_g - 1), WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '1');
                wait for Tpd_c;
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("AlternatingZeroWeights_AllBits") then
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(i mod 2, WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '1');
                wait for Tpd_c;
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("ChangingRandomNonZeroWeights_AllBits") then
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);
                In_Req <= (others => '1');
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Randomize the weights each cycle
                    for i in 0 to GrantWidth_g - 1 loop
                        In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                            toUslv(RandGen_v.RandInt(1, 2 ** WeightWidth_g - 1), WeightWidth_g);
                    end loop;
                    wait for Tpd_c;
                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

            --------------------------------------------------------------------
            --------------------------------------------------------------------
            if run("RandomNonZeroWeights_RandomNonZeroRequests") then
                -- Set Random Weights
                for i in 0 to GrantWidth_g - 1 loop
                    In_Weights((i + 1) * WeightWidth_g - 1 downto i * WeightWidth_g) <=
                        toUslv(RandGen_v.RandInt(1, 2 ** WeightWidth_g - 1), WeightWidth_g);
                end loop;
                -- Always Rdy
                Out_Ready <= '1';
                wait until rising_edge(Clk);
                wait for Tpd_c;
                ExpectedGrant_v := (others => '0');
                check_equal(Out_Grant, ExpectedGrant_v, "Wrong value after reset");
                check_equal(Out_Valid, '0', "Valid high unexpectedly");
                wait until rising_edge(Clk);

                LastCheckedGrant_v := 0;
                for CycleIdx in 0 to NumCycles - 1 loop
                    -- Randomize the requests each cycle
                    In_Req <= toUslv(RandGen_v.RandInt(1, 2 ** GrantWidth_g - 1), GrantWidth_g);
                    wait for Tpd_c;

                    for GrantIdx in LastCheckedGrant_v - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;

                    -- Loop over each grant index (MSB to LSB)
                    for GrantIdx in GrantWidth_g - 1 downto 0 loop
                        check_weighted_grant(
                            Clk              => Clk,
                            CycleIdx         => CycleIdx,
                            GrantIdx         => GrantIdx,
                            In_Req           => In_Req,
                            In_Weights       => In_Weights,
                            ActualGrant      => Out_Grant,
                            ActualValid      => Out_Valid,
                            LastCheckedGrant => LastCheckedGrant_v
                        );
                    end loop;
                end loop;
                wait for Clk_Period_c * 10;
            end if;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
