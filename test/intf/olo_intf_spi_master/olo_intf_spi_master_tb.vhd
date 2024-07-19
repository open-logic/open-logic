------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

library work;
    use work.olo_test_spi_slave_pkg.all;
    use work.olo_test_activity_pkg.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_intf_spi_master_tb is
    generic (
        BusFrequency_g              : integer := 10_000_000;
        LsbFirst_g                  : boolean := false;
        SpiCpha_g                   : integer range 0 to 1 := 0;
        SpiCpol_g                   : integer range 0 to 1 := 0;
        runner_cfg                  : string  
    );
end entity olo_intf_spi_master_tb;

architecture sim of olo_intf_spi_master_tb is
    -------------------------------------------------------------------------
    -- Fixed Generics
    ------------------------------------------------------------------------- 
    constant SclkFreq_c      : real                      := real(BusFrequency_g);
    constant MaxTransWidth_c : positive                  := 32;
    constant CsHighTime_c    : real                      := 100.0e-9;
    constant SlaveCnt_c      : positive                  := 2;
    constant MosiIdleState_c : std_logic                 := '0';

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    -- Contral Sginal
    signal Clk             : std_logic                                                  := '0';
    signal Rst             : std_logic                                                  := '0';
    signal Start           : std_logic                                                  := '0';
    signal Slave           : std_logic_vector(log2ceil(SlaveCnt_c) - 1 downto 0)        := (others => '0');
    signal Busy            : std_logic;
    signal Done            : std_logic;
    signal WrData          : std_logic_vector(MaxTransWidth_c - 1 downto 0)             := (others => '0');
    signal RdData          : std_logic_vector(MaxTransWidth_c - 1 downto 0);
    signal TransWidth      : std_logic_vector(log2ceil(MaxTransWidth_c+1)-1 downto 0)   := (others => '0');
    signal SpiSclk         : std_logic;
    signal SpiMosi         : std_logic;
    signal SpiMiso         : std_logic                                                   := '0';
    signal SpiCs_n         : std_logic_vector(SlaveCnt_c - 1 downto 0)                   := (others => '1');
    
    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------

    -- *** Verification Compnents ***
    constant slave0 : olo_test_spi_slave_t := new_olo_test_spi_slave( 
        busFrequency    => SclkFreq_c,
        lsbFirst        => LsbFirst_g,
        maxTransWidth   => MaxTransWidth_c,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

    constant slave1 : olo_test_spi_slave_t := new_olo_test_spi_slave( 
        busFrequency    => SclkFreq_c,
        lsbFirst        => LsbFirst_g,
        maxTransWidth   => MaxTransWidth_c,
        cpha            => SpiCpha_g,
        cpol            => SpiCpol_g
    );

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 50 ms);
    p_control : process
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- TODO: Check RLast

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);
            


            -- *** Basics ***
            if run("ResetValues") then
                wait for 1 us;
                check_equal(Busy, '0', "Busy");
                check_equal(Done, '0', "Done");
                check_equal(SpiCs_n, onesVector(SlaveCnt_c), "SpiCs_n");
            end if;

        end loop;
        -- TB done
        test_runner_cleanup(runner);
    end process;

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_intf_spi_master
        generic map (
            ClkFreq_g       => Clk_Frequency_c,
            SclkFreq_g      => SclkFreq_c,
            MaxTransWidth_g => MaxTransWidth_c,
            CsHighTime_g    => CsHighTime_c,
            SpiCPOL_g       => SpiCPOL_g,
            SpiCPHA_g       => SpiCPHA_g,
            SlaveCnt_g      => SlaveCnt_c,
            LsbFirst_g      => LsbFirst_g,
            MosiIdleState_g => MosiIdleState_c
        )
        port map (
            -- Control Signals
            Clk        => Clk,     
            Rst        => Rst,   
            -- Parallel Interface
            Start      => Start,
            Slave      => Slave,
            Busy       => Busy,
            Done       => Done,
            WrData     => WrData,
            RdData     => RdData,
            TransWidth => TransWidth,
            -- SPI 
            SpiSclk    => SpiSclk,
            SpiMosi    => SpiMosi,
            SpiMiso    => SpiMiso,
            SpiCs_n    => SpiCs_n
        );

    ------------------------------------------------------------
    -- Verification Components
    ------------------------------------------------------------
    vc_slave0 : entity work.olo_test_spi_slave_vc
        generic map (
            instance => slave0
        )
        port map (
            Sclk     => SpiSclk,
            CS_n     => SpiCs_n(0),
            Mosi     => SpiMosi,
            Miso     => SpiMiso
        );

    vc_slave1 : entity work.olo_test_spi_slave_vc
        generic map (
            instance => slave1
        )
        port map (
            Sclk     => SpiSclk,
            CS_n     => SpiCs_n(1),
            Mosi     => SpiMosi,
            Miso     => SpiMiso
        );

end sim;
