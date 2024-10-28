---------------------------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

-- This testbench tests the drop, next and repeat handshaking (i.e. if those can be signalled between data beats)

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
	context vunit_lib.vunit_context;
    context vunit_lib.com_context;
	context vunit_lib.vc_context;

library osvvm;
    use osvvm.RandomPkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_fifo_packet_hs_tb is
    generic (
        runner_cfg      : string
    );
end entity;

architecture sim of olo_base_fifo_packet_hs_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant Width_c      : integer := 16;
    constant Depth_c      : integer := 32;
    constant MaxPackets_c : integer := 4;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ClockFrequency_c : real := 100.0e6;
    constant ClockPeriod_c    : time := (1 sec) / ClockFrequency_c;
    constant CaseDelay_c      : time := ClockPeriod_c*20;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk          : std_logic := '0';
    signal Rst          : std_logic;
    signal In_Valid     : std_logic := '0';
    signal In_Ready     : std_logic;
    signal In_Data      : std_logic_vector(Width_c - 1 downto 0);
    signal In_Last      : std_logic := '0';
    signal In_Drop      : std_logic := '0';
    signal In_IsDropped : std_logic;
    signal Out_Valid    : std_logic;
    signal Out_Ready    : std_logic := '0';
    signal Out_Data     : std_logic_vector(Width_c - 1 downto 0);
    signal Out_Last     : std_logic;
    signal Out_Next     : std_logic := '0';
    signal Out_Repeat   : std_logic := '0';
    signal PacketLevel  : std_logic_vector(log2ceil(MaxPackets_c + 1) - 1 downto 0);
    signal FreeWords    : std_logic_vector(log2ceil(Depth_c + 1) - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Default Values
            In_Valid   <= '0';
            In_Drop    <= '0';
            In_Last    <= '0';
            In_Data    <= (others => '0');
            Out_Ready  <= '0';
            Out_Next   <= '0';
            Out_Repeat <= '0';

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for ClockPeriod_c*3;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- *** Normal Packet (to test TB) ***

            if run("NormalPacket") then

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                check_equal(FreeWords, Depth_c, "FreeWords");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-1, "FreeWords");
                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-2, "FreeWords");
                In_Valid <= '0';

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-2, "FreeWords");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-2, "FreeWords");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            -- *** In_Drop operation between samples ***

            if run("Drop-BeforePacket") then -- ignored

                -- Drop Before Packet
                In_Drop <= '1';
                wait until rising_edge(Clk);

                In_Drop <= '0';

                -- Push Packet
                check_equal(PacketLevel, 0, "PacketLevel");
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-1, "FreeWords");
                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-2, "FreeWords");
                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Drop-DuringPacket") then -- detected

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-1, "FreeWords");
                In_Valid <= '0';
                In_Drop  <= '1';
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-1, "FreeWords");
                In_Drop  <= '0';
                In_Valid <= '1';
                In_Data  <= x"0002";
                In_Last  <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                check_equal(FreeWords, Depth_c, "FreeWords");

                -- Packet is dropped
                wait for 20*ClockPeriod_c;

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            -- *** Out_Next operation between samples ***
            if run("Next-BeforePacket") then -- ignored

                -- Next Before Packet
                Out_Next <= '1';
                wait until rising_edge(Clk);

                Out_Next <= '0';

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");

                wait until rising_edge(Clk);
                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Next-BeforeReady") then -- detected

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Next <= '1';
                wait until rising_edge(Clk);

                Out_Next  <= '0';
                Out_Ready <= '1';

                -- One word must be provided because AXI-S does not allow deasserting Valid
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Next-DuringPacket") then  -- detected

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                wait until rising_edge(Clk);

                In_Data <= x"0003";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-3, "FreeWords");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                Out_Ready <= '0';
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Next <= '1';
                wait until rising_edge(Clk);

                Out_Next <= '0';
                wait until rising_edge(Clk) and Out_Valid = '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            -- *** Out_Repeat operation between samples ***
            if run("Repeat-BeforePacket") then -- ignored

                -- Next Before Packet
                Out_Repeat <= '1';
                wait until rising_edge(Clk);

                Out_Repeat <= '0';

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                check_equal(FreeWords, Depth_c-2, "FreeWords");
                wait until rising_edge(Clk);
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Repeat-BeforeReady") then -- detected

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                wait until falling_edge(Clk);

                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Repeat <= '1';
                wait until rising_edge(Clk);

                Out_Repeat <= '0';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);

                Out_Ready <= '1';

                -- Check Packet (twice because repeated)
                for i in 0 to 1 loop
                    wait until rising_edge(Clk) and Out_Valid = '1';

                    check_equal(Out_Data, 1, "Out_Data");
                    check_equal(Out_Last, '0', "Out_Last");
                    wait until rising_edge(Clk) and Out_Valid = '1';

                    check_equal(Out_Data, 2, "Out_Data");
                    check_equal(Out_Last, '1', "Out_Last");
                    wait until falling_edge(Clk);

                    check_equal(PacketLevel, 1-i, "PacketLevel");
                    check_equal(FreeWords, Depth_c-2, "FreeWords");
                end loop;

                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Repeat-DuringPacket") then

                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                wait until rising_edge(Clk);

                In_Data <= x"0003";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-3, "FreeWords");

                -- Check Packet 1
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                Out_Ready <= '0';
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Repeat <= '1';
                wait until rising_edge(Clk);

                Out_Repeat <= '0';
                wait until rising_edge(Clk) and Out_Valid = '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 3, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-3, "FreeWords");

                -- Valid low pulse between packets
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-3, "FreeWords");

                -- Check Packet 2
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 3, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            if run("Repeat-BetweenPackets") then -- ignored

                -- Packet 0
                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0001";
                wait until rising_edge(Clk);

                In_Data <= x"0002";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                In_Last  <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 1, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 2, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                check_equal(FreeWords, Depth_c, "FreeWords");

                -- Repeat Before Packet
                Out_Repeat <= '1';
                wait until rising_edge(Clk);

                Out_Repeat <= '0';

                -- Packet 1
                -- Push Packet
                In_Valid <= '1';
                In_Data  <= x"0005";
                wait until rising_edge(Clk);

                In_Data <= x"0006";
                In_Last <= '1';
                wait until rising_edge(Clk);

                In_Valid <= '0';
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 1, "PacketLevel");
                check_equal(FreeWords, Depth_c-2, "FreeWords");

                -- Check Packet
                Out_Ready <= '1';
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 5, "Out_Data");
                check_equal(Out_Last, '0', "Out_Last");
                wait until rising_edge(Clk) and Out_Valid = '1';

                check_equal(Out_Data, 6, "Out_Data");
                check_equal(Out_Last, '1', "Out_Last");
                wait until rising_edge(Clk);

                check_equal(Out_Valid, '0', "Out_Valid");
                wait until falling_edge(Clk);

                check_equal(PacketLevel, 0, "PacketLevel");
                check_equal(FreeWords, Depth_c, "FreeWords");
            end if;

            -- End case condition
            wait for CaseDelay_c;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*ClockPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_fifo_packet
        generic map (
            Width_g             => Width_c,
            Depth_g             => Depth_c,
            RamStyle_g          => "auto",
            RamBehavior_g       => "RBW",
            SmallRamStyle_g     => "same",
            SmallRamBehavior_g  => "same",
            MaxPackets_g        => MaxPackets_c
        )
        port map (
            Clk           => Clk,
            Rst           => Rst,
            In_Valid      => In_Valid,
            In_Ready      => In_Ready,
            In_Data       => In_Data,
            In_Last       => In_Last,
            In_Drop       => In_Drop,
            In_IsDropped  => In_IsDropped,
            Out_Valid     => Out_Valid,
            Out_Ready     => Out_Ready,
            Out_Data      => Out_Data,
            Out_Last      => Out_Last,
            Out_Next      => Out_Next,
            Out_Repeat    => Out_Repeat,
            PacketLevel   => PacketLevel,
            FreeWords     => FreeWords
        );

end architecture;
