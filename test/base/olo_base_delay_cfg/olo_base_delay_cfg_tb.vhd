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
entity olo_base_delay_cfg_tb is
    generic (
        runner_cfg      : string;
        SupportZero_g   : boolean := false;
        RamBehavior_g   : string   := "RBW";  
        RandomStall_g   : boolean   := false
    );
end entity olo_base_delay_cfg_tb;

architecture sim of olo_base_delay_cfg_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant DataWidth_c   : integer := 16;
    constant MaxDelay_c    : integer := 20;

    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    constant Clk_Frequency_c   : real    := 100.0e6;
    constant Clk_Period_c      : time    := (1 sec) / Clk_Frequency_c;
    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    shared variable InDelay     : time := 0 ns;
    signal CheckFrom            : integer;

    -- *** Verification Compnents ***
	constant axisMaster : axi_stream_master_t := new_axi_stream_master (
		data_length => DataWidth_c,
		stall_config => new_stall_config(choose(RandomStall_g, 0.5, 0.0), 0, 10)
	);

    -- *** Procedures ***
    procedure PushN(signal net : inout network_t;
                    start : integer;
                    count : integer ) is
    begin
        for i in start to start+count-1 loop
            wait for InDelay;
            push_axi_stream(net, axisMaster, toUslv(i, DataWidth_c));
        end loop;
    end procedure;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk         : std_logic                                              := '0';                              
    signal Rst         : std_logic                                              := '0';    
    signal Delay       : std_logic_vector(log2ceil(MaxDelay_c+1)-1 downto 0)    := (others => '0'); 
    signal In_Valid    : std_logic                                              := '0';                                                        
    signal In_Data     : std_logic_vector(DataWidth_c - 1 downto 0)             := (others => '0');                                               
    signal Out_Data    : std_logic_vector(DataWidth_c - 1 downto 0)             := (others => '0'); 

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

            InDelay := 100 ns;
            CheckFrom <= 0;

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("FixDelay0") then
                -- Skip if zero is not supported
                if SupportZero_g then
                    CheckFrom <= 5;
                    Delay <= toUslv(0, Delay'length);
                    PushN(net, 0, 20);
                end if;
            end if;

            if run("FixDelay1") then
                CheckFrom <= 5;
                Delay <= toUslv(1, Delay'length);
                PushN(net, 0, 20);
            end if;   
            
            if run("FixDelay2") then
                CheckFrom <= 5;
                Delay <= toUslv(2, Delay'length);
                PushN(net, 0, 20);
            end if;    
            
            if run("FixDelay3") then
                CheckFrom <= 5;
                Delay <= toUslv(3, Delay'length);
                PushN(net, 0, 20);
            end if;      

            if run("FixDelay5") then
                CheckFrom <= 5;
                Delay <= toUslv(5, Delay'length);
                PushN(net, 0, 20);
            end if;

            if run("FixDelayMax") then
                CheckFrom <= MaxDelay_c;
                Delay <= toUslv(MaxDelay_c, Delay'length);
                PushN(net, 0, 40);
            end if;
            
            if run("IncreaseDelay") then
                CheckFrom <= 5;
                Delay <= toUslv(5, Delay'length);
                PushN(net, 0, 40);   
                wait_until_idle(net, as_sync(axisMaster));
                CheckFrom <= 40+5;
                Delay <= toUslv(7, Delay'length);
                PushN(net, 40, 40);                        
            end if;

            if run("DecreaseDelay") then
                CheckFrom <= 7;
                Delay <= toUslv(7, Delay'length);
                PushN(net, 0, 40);   
                wait_until_idle(net, as_sync(axisMaster));
                CheckFrom <= 40+5;
                Delay <= toUslv(2, Delay'length);
                PushN(net, 40, 10);     
                wait_until_idle(net, as_sync(axisMaster));  
                CheckFrom <= 50+5;
                Delay <= toUslv(1, Delay'length);
                PushN(net, 50, 10);  
            end if;
            
            wait_until_idle(net, as_sync(axisMaster));
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
    i_dut : entity olo.olo_base_delay_cfg
        generic map (
            Width_g         => DataWidth_c,
            MaxDelay_g      => MaxDelay_c,
            SupportZero_g   => SupportZero_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map (
            Clk         => Clk,     
            Rst         => Rst,    
            Delay       => Delay,
            In_Valid    => In_Valid,                               
            In_Data     => In_Data,                        
            Out_Data    => Out_Data
        ); 

	------------------------------------------------------------
	-- Verification Components
	------------------------------------------------------------
	vc_stimuli : entity vunit_lib.axi_stream_master
	generic map (
	    master => axisMaster
	)
	port map (
	    aclk   => Clk,
	    tvalid => In_Valid,
        tready => '1',
	    tdata  => In_Data
	);

 	------------------------------------------------------------
	-- Custom Processes
	------------------------------------------------------------   
    p_checkout : process(Clk)
    begin
        if rising_edge(Clk) then
            if In_Valid = '1' then
                -- Normal operation
                if unsigned(In_Data) >= CheckFrom then
                    check_equal(Out_Data, fromUslv(In_Data)-fromUslv(Delay), "Wrong Value");
                end if;
            end if;
        end if;
    end process;

end sim;
