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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_flowctrl_handler_tb is
    generic (
        runner_cfg      : string
    );
end entity olo_base_flowctrl_handler_tb;

architecture sim of olo_base_flowctrl_handler_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant Width_c        : integer := 16;
    constant Delay_c        : integer := 7;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk           : std_logic                                    := '0';
    signal Rst           : std_logic                                    := '1';
    signal In_Data       : std_logic_vector(Width_c - 1 downto 0);
    signal In_Valid      : std_logic := '0';
    signal In_Ready      : std_logic;
    signal Out_Data      : std_logic_vector(Width_c - 1 downto 0);
    signal Out_Valid     : std_logic;
    signal Out_Ready     : std_logic := '0';
    signal ToProc_Data   : std_logic_vector(Width_c - 1 downto 0);
    signal ToProc_Valid  : std_logic;
    signal FromProc_Data : std_logic_vector(Width_c - 1 downto 0);
    signal FromProc_Valid: std_logic;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    signal InputStart    : std_logic    := '0';
    signal InputSize     : integer      := 0;
    signal InPauses      : integer      := 0;
    signal InPausesBurst : integer      := 1; -- Assert pause only after N samples

    procedure CheckOutput(  OutputSize  : integer;
                            OutPauses   : integer;
                            signal Out_Ready : out std_logic;
                            OutPausesBurst : integer := 1) is
    begin
        for i in 0 to OutputSize-1 loop
            Out_Ready <= '1';
            wait until rising_edge(Clk) and Out_Valid = '1';
            check_equal(Out_Data, toUslv(i, Width_c), "Output data mismatch");
            if(OutPauses > 0) and (i mod OutPausesBurst) = 0 then
                Out_Ready <= '0';
                for i in 0 to OutPauses-1 loop
                    wait until rising_edge(Clk);
                end loop;
            end if;
        end loop;
    end CheckOutput;

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);
            InputStart <= '0';
            InPauses <= 0;
            InPausesBurst <= 1;

            if run("FullThrottle") then
                InputStart <= '1';
                InputSize <= 30;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 0, Out_Ready);
            end if;

            if run("InputLimited") then
                InputStart <= '1';
                InputSize <= 30;
                InPauses <= 3;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 0, Out_Ready);               
            end if;

            if run("OutputLimitedSlow") then
                InputStart <= '1';
                InputSize <= 30;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 20, Out_Ready);      
            end if;

            if run("OutputLimitedFast") then
                InputStart <= '1';
                InputSize <= 30;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 3, Out_Ready);      
            end if;

            if run("InputOutputLimited") then
                InputStart <= '1';
                InputSize <= 30;
                InPauses <= 3;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 3, Out_Ready);      
            end if;

            if run("InPausesBurst") then
                InputStart <= '1';
                InputSize <= 30;
                InPauses <= Delay_c;
                InPausesBurst <= Delay_c;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, 0, Out_Ready);      
            end if;

            if run("OutPausesBurst") then
                InputStart <= '1';
                InputSize <= 30;
                wait until rising_edge(Clk);
                InputStart <= '0';
                CheckOutput(30, Delay_c, Out_Ready, Delay_c);      
            end if;
            
            -- Wait between cases;
            wait for 1 us;

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
    -- Instantiate the olo_base_flowctrl_handler entity
    i_dut : entity olo.olo_base_flowctrl_handler
        generic map (
            Width_g             => Width_c,
            SamplesToAbsorb_g   => Delay_c
        )
        port map (
            Clk           => Clk,
            Rst           => Rst,
            In_Data       => In_Data,
            In_Valid      => In_Valid,
            In_Ready      => In_Ready,
            Out_Data      => Out_Data,
            Out_Valid     => Out_Valid,
            Out_Ready     => Out_Ready,
            ToProc_Data   => ToProc_Data,
            ToProc_Valid  => ToProc_Valid,
            FromProc_Data => FromProc_Data,
            FromProc_Valid=> FromProc_Valid
        );

    -------------------------------------------------------------------------
    -- Processing Emulation
    -------------------------------------------------------------------------
    i_proc : entity olo.olo_base_delay
        generic map (
            Width_g         => Width_c+1,
            Delay_g         => Delay_c,
            RstState_g      => True
        )
        port map (
            Clk                             => Clk,     
            Rst                             => Rst,    
            In_Valid                        => '1',  
            In_Data(Width_c-1 downto 0)     => ToProc_Data,
            In_Data(Width_c)                => ToProc_Valid,                                            
            Out_Data(Width_c-1 downto 0)    => FromProc_Data,
            Out_Data(Width_c)               => FromProc_Valid
        ); 

 	------------------------------------------------------------
	-- Custom Processes
	------------------------------------------------------------   
    p_send_counter : process
    begin
        wait until InputStart = '1' and rising_edge(Clk);
        for i in 0 to InputSize-1 loop
            In_Data <= toUslv(i, Width_c);
            In_Valid <= '1';
            wait until rising_edge(Clk) and In_Ready = '1';
            if InPauses > 0 and (i mod InPausesBurst = 0)then
                In_Valid <= '0';
                for i in 0 to InPauses-1 loop
                    wait until rising_edge(Clk);
                end loop;
            end if;
        end loop;
        In_Valid <= '0';
    end process;

end sim;
