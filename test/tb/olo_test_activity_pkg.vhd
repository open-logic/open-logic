------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler, Benoit Stef
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

library olo;
    use olo.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package olo_test_activity_pkg is

	-- Wait for a given time and check if the signal is idle
	procedure CheckNoActivityStdl(  signal Sig : in std_logic;
	                                IdleTime   : in time;
	                                Msg        : in string := "");

	procedure CheckNoActivityStlv(signal Sig : in std_logic_vector;
	                              IdleTime   : in time;
	                              Msg        : in string := "");

	-- Check when a signal had its last activity (without waiting)
	procedure CheckLastActivity(signal Sig : in std_logic;
	                            IdleTime   : in time;
	                            Level      : in integer range -1 to 1 := -1; -- -1 = don't check, 0 = low, 1 = high
	                            Msg        : in string := "");

	-- pulse a signal
	procedure PulseSig( signal Sig  : out std_logic;
	                    signal Clk  : in std_logic;
                        ActiveLevel : in std_logic := '1');

	-- check if stdlv is arrived within a defined period of time
	procedure WaitForValueStdlv(signal Sig		: in std_logic_vector; 		-- Signal to check
								ExpVal			: in std_logic_vector; 		-- expected value
								Timeout	  		: in time;					-- time to wait for
								Msg		  		: in string);   			-- bool out to stop Tb for ex.
							
	-- check if std is arrived within a defined period of time
	procedure WaitForValueStdl(	signal Sig		: in std_logic; 			-- Signal to check
								ExpVal			: in std_logic; 			-- expected value
								Timeout	  		: in time;					-- time to wait for
								Msg		  		: in string);   			-- bool out to stop Tb for ex.						

end olo_test_activity_pkg;

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body olo_test_activity_pkg is

	-- *** CheckNoActivity ***
	procedure CheckNoActivityStdl(  signal Sig : in std_logic;
	                                IdleTime   : in time;
	                                Msg        : in string := "") is
	begin
		wait for IdleTime;
        check(Sig'last_event >= IdleTime, "CheckNoActivityStdl() failed: " & Msg);
	end procedure;

	-- *** CheckNoActivityStlv ***
	procedure CheckNoActivityStlv(signal Sig : in std_logic_vector;
	                              IdleTime   : in time;
	                              Msg        : in string := "") is
	begin
		wait for IdleTime;
        check(Sig'last_event >= IdleTime, "CheckNoActivityStlv() failed: " & Msg);
	end procedure;

    -- *** CheckLastActivity ***
    procedure CheckLastActivity(signal Sig : in std_logic;
                                IdleTime   : in time;
                                Level      : in integer range -1 to 1 := -1; -- -1 = don't check, 0 = low, 1 = high
                                Msg        : in string := "") is
    begin
        check(Sig'last_event >= IdleTime, "CheckLastActivity() - unexpected activity: " & Msg);
		if Level /= -1 then
            check_equal(Sig, choose(Level = 0, '0', '1'), "CheckLastActivity() - wrong level: " & Msg);
		end if;
	end procedure;   

	-- *** PulseSig ***
	procedure PulseSig(signal Sig  : out std_logic;
	                   signal Clk  : in std_logic;
                       ActiveLevel : in std_logic := '1') is
	begin
		wait until rising_edge(Clk);
		Sig <= ActiveLevel;
		wait until rising_edge(Clk);
		Sig <= not ActiveLevel;
	end procedure;

	-- *** Wait for Standard logic vector to happen ***
	procedure WaitForValueStdlv(signal Sig		: in std_logic_vector; 	
                                ExpVal			: in std_logic_vector; 	
                                Timeout	  		: in time;				
                                Msg		  		: in string) is
	begin
        if Sig /= ExpVal then
            wait until ExpVal = Sig for timeout;
            if ExpVal /= Sig then
                error(  "WaitForValueStdlv() failed: " & Msg & 
                        " Target state not reached" &
                        " [Expected " & to_string(ExpVal) & "(0x" & to_hstring(ExpVal) & ")" &
                        ", Received " & to_string(Sig) & "(0x" & to_hstring(Sig) & ")" & "]");
            end if;
        end if;
	end procedure;
	
	-- *** Wait for Standard logic to happen ***
	procedure WaitForValueStdl(	signal Sig		: in std_logic; 	
                                ExpVal			: in std_logic; 		
                                Timeout	  		: in time;		
                                Msg		  		: in string) is
	begin
        if Sig /= ExpVal then
            wait until ExpVal = Sig for timeout;
            if ExpVal /= Sig then
                error(  "WaitForValueStdl() failed: " & Msg & 
                        " Target state not reached" &
                        " [Expected " & to_string(ExpVal) & 
                        ", Received " & to_string(Sig) & "]");
            end if;
		end if;
	end procedure;

end olo_test_activity_pkg;
