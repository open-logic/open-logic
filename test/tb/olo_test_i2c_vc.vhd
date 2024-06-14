------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- VC Package
------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

package olo_test_i2c_pkg is

    -- *** Constants ***
    constant I2c_ACK 	: std_logic := '0';
	constant I2c_NACK 	: std_logic := '1';
	
	type I2c_Transaction_t is (I2c_READ, I2c_WRITE);   

    -- *** VUnit instance type ***
    type olo_test_i2c_t is record
        p_actor         : actor_t;
        BusFrequency    : real;
    end record;

    -- *** Master Operations ***

    -- Send start (and switch to master operation mode)
    procedure i2c_push_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;
        msg             : string                := ""
    );

    -- Send repeated start
    procedure i2c_push_repeated_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;  
        msg             : string                := ""
    );

    -- Send stop (and switch to idle operation mode)
    procedure i2c_push_stop (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;  
        msg             : string                := ""
    );

    -- Send address
    procedure i2c_push_addr_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        address 	    : integer;
        isRead		    : boolean;
        addrBits        : natural range 7 to 10 := 7;
        expectedAck     : std_logic             := I2c_ACK;
        delay           : time                  := 0 ns;
        msg             : string                := ""
    );

    -- *** Slave Operations ***
    -- Wait for start (and switch to slave operation mode)
    procedure i2c_expect_start(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        msg             : string                := ""
    );	

    -- Wait for repeated start
    procedure i2c_expect_repeated_start(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        clkStretch      : time              := 0 ns;
        msg             : string                := ""
    );	

    -- Wait for stop (and switch to idle operation mode)
    procedure i2c_expect_stop(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        clkStretch      : time              := 0 ns;
        msg             : string                := ""
    );

    -- Expect address
    procedure i2c_expect_addr (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        address 	    : integer;
        isRead		    : boolean;
        addrBits        : natural range 7 to 10 := 7;
        ackOutput       : std_logic             := I2c_ACK;
        timeout		    : time		            := 1 ms;
        clkStretch      : time                  := 0 ns;
        msg             : string                := ""
    );

    -- *** General Operations ***

    -- Send TX Byte
    procedure i2c_push_tx_byte (
        signal net      : inout network_t;
        I2cMaster       : olo_test_i2c_t;
        data		    : integer range -128 to 255;
        expectedAck     : std_logic                     := I2c_ACK;
        clkStretch      : time                          := 0 ns;  -- only allowed in slave mode
        delay           : time                          := 0 ns; -- only allowed in master mode
        msg             : string                        := ""
    );

    -- Receive RX Byte
    procedure i2c_expect_rx_byte (
        signal net      : inout network_t;
        I2cMaster       : olo_test_i2c_t;
        expData		    : integer range -128 to 255;
        ackOutput       : std_logic                     := I2c_ACK;
        clkStretch      : time                          := 0 ns;  -- only allowed in slave mode
        msg             : string                        := ""
    );

    -- Force I2C VC in slave mode to master operation mode
    procedure i2c_force_master_mode (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        msg             : string                := ""
    );

    -- Force releasing of the bus
    procedure i2c_force_bus_release (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        msg             : string                := ""
    );

    -- *** VUnit Operations ***

    -- Message Types
    constant I2cPushStartMsg          : msg_type_t := new_msg_type("I2C Push Start");
    constant I2cPushRepeatedStartMsg  : msg_type_t := new_msg_type("I2C Push Repeated Start");
    constant I2cPushStopMsg           : msg_type_t := new_msg_type("I2C Push Stop");
    constant I2cPushAddrMsg      : msg_type_t := new_msg_type("I2C Push Address Start");
    constant I2cExpectStartMsg        : msg_type_t := new_msg_type("I2C Expect Start");
    constant I2cExpectRepeatedStartMsg: msg_type_t := new_msg_type("I2C Expect Repeated Start");
    constant I2cExpectStopMsg         : msg_type_t := new_msg_type("I2C Expect Stop");
    constant I2cExpectAddrMsg         : msg_type_t := new_msg_type("I2C Expect Address");
    constant I2cPushTxByteMsg         : msg_type_t := new_msg_type("I2C Push TX Byte");
    constant I2cExpectRxByteMsg       : msg_type_t := new_msg_type("I2C Expect RX Byte");
    constant I2cForceMasterModeMsg    : msg_type_t := new_msg_type("I2C Force Master Mode");
    constant I2cForceBusReleaseMsg    : msg_type_t := new_msg_type("I2C Force Bus Release");

    -- Constructor
    impure function new_olo_test_i2c( busFrequency : real    := 100.0e3) return olo_test_i2c_t;

    -- Casts
    impure function as_sync(instance : olo_test_i2c_t) return sync_handle_t;

    -- I2c Pullup
    procedure I2cPullup(signal Scl : inout std_logic;
                        signal Sda : inout std_logic);

end package;

package body olo_test_i2c_pkg is 
  
    -- *** Master Operations ***

    -- Send start (and switch to master operation mode)
    procedure i2c_push_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;
        msg             : string                := ""  
    ) is
        variable Msg_v : msg_t := new_msg(I2cPushStartMsg);
    begin
        push(Msg_v, delay);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Send repeated start (and switch to master operation mode)
    procedure i2c_push_repeated_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;
        msg             : string                := "" 
    ) is
        variable Msg_v : msg_t := new_msg(I2cPushRepeatedStartMsg);
    begin
        push(Msg_v, delay);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Send stop (and switch to idle operation mode)
    procedure i2c_push_stop (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        delay           : time                  := 0 ns;
        msg             : string                := "" 
    ) is
        variable Msg_v : msg_t := new_msg(I2cPushStopMsg);
    begin
        push(Msg_v, delay);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Send address
    procedure i2c_push_addr_start (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        address 	    : integer;
        isRead		    : boolean;
        addrBits        : natural range 7 to 10 := 7;
        expectedAck     : std_logic             := I2c_ACK;
        delay           : time                  := 0 ns;
        msg             : string                := "" 
    ) is
        variable Msg_v : msg_t := new_msg(I2cPushAddrMsg);
    begin
        push(Msg_v, address);
        push(Msg_v, isRead);
        push(Msg_v, addrBits);
        push(Msg_v, expectedAck);
        push(Msg_v, delay);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;


    -- *** Slave Operations ***

    -- Wait for start (and switch to slave operation mode)
    procedure i2c_expect_start(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cExpectStartMsg);
    begin
        push(Msg_v, timeout);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Wait for repeated start
    procedure i2c_expect_repeated_start(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        clkStretch      : time              := 0 ns;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cExpectRepeatedStartMsg);
    begin
        push(Msg_v, timeout);
        push(Msg_v, clkStretch);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Wait for stop (and switch to idle operation mode)
    procedure i2c_expect_stop(	
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;        
        timeout		    : time		        := 1 ms;
        clkStretch      : time              := 0 ns;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cExpectStopMsg);
    begin
        push(Msg_v, timeout);
        push(Msg_v, clkStretch);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Expect address
    procedure i2c_expect_addr (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        address 	    : integer;
        isRead		    : boolean;
        addrBits        : natural range 7 to 10 := 7;
        ackOutput       : std_logic             := I2c_ACK;
        timeout		    : time		            := 1 ms;
        clkStretch      : time                  := 0 ns;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cExpectAddrMsg);
    begin
        push(Msg_v, address);
        push(Msg_v, isRead);
        push(Msg_v, addrBits);
        push(Msg_v, ackOutput);
        push(Msg_v, timeout);
        push(Msg_v, clkStretch);
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- *** General Operations ***

    -- Send TX Byte
    procedure i2c_push_tx_byte (
        signal net      : inout network_t;
        I2cMaster       : olo_test_i2c_t;
        data		    : integer range -128 to 255;
        expectedAck     : std_logic                     := I2c_ACK;
        clkStretch      : time                          := 0 ns;  -- only allowed in slave mode
        delay           : time                          := 0 ns; -- only allowed in master mode
        msg             : string                        := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cPushTxByteMsg);
    begin
        push(Msg_v, data);
        push(Msg_v, expectedAck);
        push(Msg_v, clkStretch);
        push(Msg_v, delay);
        push_string(Msg_v, msg);
        send(net, I2cMaster.p_actor, Msg_v);
    end procedure;

    -- Receive RX Byte
    procedure i2c_expect_rx_byte (
        signal net      : inout network_t;
        I2cMaster       : olo_test_i2c_t;
        expData		    : integer range -128 to 255;
        ackOutput       : std_logic                     := I2c_ACK;
        clkStretch      : time                          := 0 ns;  -- only allowed in slave mode
        msg             : string                        := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cExpectRxByteMsg);
    begin
        push(Msg_v, expData);
        push(Msg_v, ackOutput);
        push(Msg_v, clkStretch);
        push_string(Msg_v, msg);
        send(net, I2cMaster.p_actor, Msg_v);
    end procedure;

    -- Force I2C VC in slave mode to master operation mode
    procedure i2c_force_master_mode (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cForceMasterModeMsg);
    begin
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;

    -- Force releasing of the bus
    procedure i2c_force_bus_release (
        signal net      : inout network_t;
        i2c             : olo_test_i2c_t;
        msg             : string                := ""
    ) is
        variable Msg_v : msg_t := new_msg(I2cForceBusReleaseMsg);
    begin
        push_string(Msg_v, msg);
        send(net, i2c.p_actor, Msg_v);
    end procedure;


    -- *** Infrastructure ***  

    -- Pull Up
	procedure I2cPullup(signal Scl : inout std_logic;
						signal Sda : inout std_logic) is
	begin
		Scl <= 'H';
		Sda <= 'H';
	end procedure;

    -- Constructor
    impure function new_olo_test_i2c( 
        busFrequency : real    := 100.0e3) return olo_test_i2c_t is
    begin
        return (p_actor => new_actor, 
                BusFrequency => busFrequency);
    end;
        
    -- Casts
    impure function as_sync(instance : olo_test_i2c_t) return sync_handle_t is
    begin
        return instance.p_actor;
    end;

end;

------------------------------------------------------------------------------------------------------------------------
-- Component Implementation
------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.stream_master_pkg.all;
    use vunit_lib.sync_pkg.all;

library work;
    use work.olo_test_i2c_pkg.all;
    use work.olo_test_activity_pkg.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_test_i2c_vc is
    generic (
        instance                 : olo_test_i2c_t
    );
    port (
        Clk          : in       std_logic;
        Rst          : in       std_logic;
        Scl          : inout    std_logic;
        Sda          : inout    std_logic
    );
end entity;

architecture rtl of olo_test_i2c_vc is
    -- **** Local procedures and functions ***
	procedure LevelCheck(	signal Sig	: std_logic;
                            Expected	: std_logic;
							Msg			: string) is
        variable Sig_v : std_logic;
	begin
        Sig_v := to01X(Sig);
        check_equal(Sig_v, Expected, Msg);
    end procedure;

    procedure LevelWait(	signal Sig	: std_logic;
                            Expected	: std_logic;
                            Msg			: string;
                            Timeout		: time      := 1 ms) is
        variable Correct_v : boolean;
    begin
        if Expected = '0' then
            if Sig /= '0' then
                wait until Sig = '0' for Timeout;
            end if;
            Correct_v := (Sig = '0');
        else
            if Sig /= '1' and Sig /= 'H' then
                wait until ((Sig = '1') or (Sig = 'H')) for Timeout;
            end if;
            Correct_v := ((Sig = '1') or (Sig = 'H'));
        end if;
        check_true(Correct_v, Msg);
    end procedure;

	-- *** Time Calculations ***
	impure function ClkPeriod return time is
    begin
        return (1 sec) / instance.BusFrequency;
    end function;
    
    impure function ClkHalfPeriod return time is
    begin
        return (0.5 sec) / instance.BusFrequency;
    end function;	
    
    impure function ClkQuartPeriod return time is
    begin
        return (0.25 sec) / instance.BusFrequency;
    end function;	

    -- *** Bit Transfers ***
	procedure SendBitInclClock(	Data		: in	std_logic;
								signal Scl	: inout std_logic;
								signal Sda	: inout std_logic;
								Msg         : in    string;
                                Timeout		: in	time    := 1 ms) is
	begin
		-- Initial Check
		LevelCheck(Scl, '0', Msg & " - SCL is HIGH but was expected LOW here [SendBitInclClock]");
		
		-- Assert Data		
		if Data = '0' then
			Sda <= '0';
		else
			Sda <= 'Z';
		end if;
		wait for ClkQuartPeriod;
		
		-- Send Clk Pulse
		Scl <= 'Z';
		LevelWait(Scl, '1', Msg & " - SCL held low by other device [SendBitInclClock]", Timeout);
		wait for ClkHalfPeriod;
		CheckLastActivity(Scl, ClkHalfPeriod*0.9, -1, Msg & " - SCL high period too short [SendBitInclClock]");
		LevelCheck(Sda, Data, Msg & " - SDA readback does not match SDA transmit value during SCL pulse [SendBitInclClock]");
		CheckLastActivity(Sda, ClkHalfPeriod, -1, Msg & " - SDA not stable during SCL pulse [SendBitInclClock]");
		Scl <= '0';
		wait for ClkQuartPeriod;	
	end procedure;

	procedure ReceiveBitInclClock(	variable Data	: out	std_logic;
									signal Scl		: inout std_logic;
									signal Sda		: inout std_logic;
									Msg             : in    string;
                                    Timeout			: in	time        := 1 ms) is	
	begin
		-- Initial Check
		LevelCheck(Scl, '0', Msg & " - SCL is HIGH but was expected LOW here [ReceiveBitInclClock]");
		
		-- Wait for assertion
		wait for ClkQuartPeriod;
		
		-- Send Clk Pulse
		Scl <= 'Z';
		LevelWait(Scl, '1', Msg & " - SCL held low by other device [ReceiveBitInclClock]", Timeout);
		wait for ClkHalfPeriod;
        CheckLastActivity(Scl, ClkHalfPeriod*0.9, -1, Msg & " - SCL high period too short [ReceiveBitInclClock]");
		CheckLastActivity(Sda, ClkHalfPeriod, -1, Msg & " - SDA not stable during SCL pulse [ReceiveBitInclClock]");
        Data := to01X(Sda);
		Scl <= '0';
		wait for ClkQuartPeriod;	
	end procedure;	

	procedure SendBitExclClock(		Data			: in	std_logic;
									signal Scl		: inout std_logic;
									signal Sda		: inout std_logic;
                                    Msg             : in    string;
									Timeout			: in	time        := 1 ms;
									ClkStretch	    : in	time        := 0 ns) is	
		variable Stretched_v : boolean := false;
	begin
		-- Initial Check
		LevelCheck(Scl, '0', Msg & " - SCL is HIGH but was expected LOW here [ReceiveBitInclClock]");
		
		-- Clock stretching
		if ClkStretch > 0 ns then
			Scl <= '0';
			wait for ClkStretch;
			Stretched_v := true;
		end if;
		
		-- Assert Data		
		if Data = '0' then
			Sda <= '0';
		else
			Sda <= 'Z';
		end if;	
		if Stretched_v then
			wait for ClkQuartPeriod;
			Scl <= 'Z';
		end if;
		
		-- Wait clock rising edge
		LevelWait(Scl, '1', Msg & " - SCL did not go high [ReceiveBitInclClock]", Timeout);
		
		-- wait clock falling edge
        LevelWait(Scl, '0', Msg & " - SCL did not go low [ReceiveBitInclClock]", Timeout);
        LevelCheck(Sda, Data, Msg & " - SDA readback does not match SDA transmit value during SCL pulse [ReceiveBitInclClock]");
		CheckLastActivity(Sda, ClkHalfPeriod, -1, Msg & " - SDA not stable during SCL pulse [ReceiveBitInclClock]");
		
		-- wait until center of low
		wait for ClkQuartPeriod;
	end procedure;	

	procedure ReceiveBitExclClock(	Data			: out	std_logic;
									signal Scl		: inout std_logic;
									signal Sda		: inout std_logic;
                                    Msg             : in    string;
									Timeout			: in	time        := 1 ms;
                                    ClkStretch	    : in	time        := 0 ns) is
	begin
		-- Initial Check
		LevelCheck(Scl, '0', Msg & " - SCL is HIGH but was expected LOW here [ReceiveBitExclClock]");
		
		-- Clock stretching
		if ClkStretch > 0 ns then
			Scl <= '0';
			wait for ClkStretch;
			Scl <= 'Z';
		end if;		

		-- Wait clock rising edge
		LevelWait(Scl, '1', Msg & " - SCL did not go high [ReceiveBitExclClock]", Timeout);
		
		-- wait clock falling edge
        LevelWait(Scl, '0', Msg & " - SCL did not go low [ReceiveBitExclClock]", Timeout);
        CheckLastActivity(Sda, ClkHalfPeriod, -1, Msg & " - SDA not stable during SCL pulse [ReceiveBitExclClock]");
        Data := to01X(Sda);
		
		-- wait until center of low
		wait for ClkQuartPeriod;
	end procedure;

	-- *** Byte Transfers ***	
	procedure SendByteInclClock(	Data 		: in	std_logic_vector(7 downto 0);
									signal Scl	: inout std_logic;
									signal Sda	: inout std_logic;
									Msg			: in 	string) is
	begin
		-- Do bits
		for i in 7 downto 0 loop
            SendBitInclClock(Data(i), Scl, Sda, Msg & " - Bit " & integer'image(7-i));	
		end loop;
	end procedure;

    procedure SendByteExclClock(	Data 		: in	std_logic_vector(7 downto 0);
                                    signal Scl	: inout std_logic;
                                    signal Sda	: inout std_logic;
                                    Msg			: in 	string;
                                    ClkStretch	: in	time    := 0 ns) is
    begin
        -- Do bits
        for i in 7 downto 0 loop
            SendBitExclClock(Data(i), Scl, Sda, Msg & " - Bit " & integer'image(7-i), ClkStretch => ClkStretch);	
        end loop;
    end procedure;

    procedure ExpectByteInclClock(	ExpData 	: in	std_logic_vector(7 downto 0);
                                    signal Scl	: inout std_logic;
                                    signal Sda	: inout std_logic;
                                    Msg			: in 	string) is
        variable RxByte_v : std_logic_vector(7 downto 0) := (others => 'X');
    begin
        -- Do bits
        for i in 7 downto 0 loop
            ReceiveBitInclClock(RxByte_v(i), Scl, Sda, Msg & " - Bit " & integer'image(7-i));	
        end loop;
        check_equal(RxByte_v, ExpData, Msg & " - Received wrong byte");
    end procedure;

	procedure ExpectByteExclClock(	ExpData 	: in	std_logic_vector(7 downto 0);
									signal Scl	: inout std_logic;
									signal Sda	: inout std_logic;
									Msg			: in 	string;
									ClkStretch	: in	time    := 0 ns) is
        variable RxByte_v : std_logic_vector(7 downto 0) := (others => 'X');
	begin
		-- Do bits
		for i in 7 downto 0 loop
            ReceiveBitExclClock(RxByte_v(i), Scl, Sda, Msg & " - Bit " & integer'image(7-i), ClkStretch => ClkStretch);	
		end loop;
        check_equal(RxByte_v, ExpData, Msg & " - Received wrong byte");
	end procedure;

    -- *** Utilities ***
    -- Calculate adddress
 	function I2cGetAddr( Addr 	: in integer;
						 IsRead : in boolean) return integer is
	begin
		return Addr*2+choose(IsRead, 1, 0);
	end function;
	
    -- Free Bus
	procedure I2cBusFree(	signal Scl : inout std_logic;
							signal Sda : inout std_logic) is
	begin
		Scl <= 'Z';
		Sda <= 'Z';
	end procedure;	   

begin

    -- PullUp
    I2cPullup(Scl, Sda);

    -- Main Process
    main : process
        -- Messaging
        variable request_msg    : msg_t;
        variable reply_msg      : msg_t;
        variable msg_type       : msg_type_t;
        variable delay          : time;
        variable timeout        : time;
        variable clkStretch     : time;
        variable address        : integer;
        variable isRead         : boolean;
        variable addrBits       : natural;
        variable expectedAck    : std_logic;
        variable ackOutput      : std_logic;
        variable data           : integer;
        variable msg_p          : string_ptr_t;

        -- Operation Mode
        type I2c_OperationMode_t is (I2c_IDLE, I2c_MASTER, I2c_SLAVE);
        variable opmode         : I2c_OperationMode_t := I2c_IDLE;

        -- Variables
        variable Ack_v         : std_logic;
        variable Data_v        : std_logic_vector(7 downto 0);
    begin
        -- Initialization
        I2cBusFree(Scl, Sda);

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Master Messages ***
            if msg_type = I2cPushStartMsg then
                -- Push Start
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = I2c_IDLE, to_string(msg_p) & " - I2C must be idle before I2C-START can be sent [I2cPushStart]");
                opmode := I2c_MASTER;
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 before I2C-START can be sent [I2cPushStart]");
                LevelCheck(Scl, '1', to_string(msg_p) & " - SDA must be 1 before I2C-START can be sent [I2cPushStart]");
                
                -- Do start condition
                wait for ClkQuartPeriod;
                Sda <= '0';
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cPushStart]");
                wait for ClkQuartPeriod;
                
                -- Go to center of clk low period
                Scl <= '0';
                wait for ClkQuartPeriod;      
                
                
            elsif msg_type = I2cPushRepeatedStartMsg then
                -- Push Repeated Start
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = I2c_MASTER, to_string(msg_p) & " - I2C must be in master mode before I2C-REPEATED-START can be sent [I2cPushRepeatedStart]");
                if to01X(Scl) = '1' then
                    LevelCheck(Sda, '1', to_string(msg_p) & " - SDA must be 1 before procedure is called if SCL = 1 [I2cPushRepeatedStart]");
                end if;
            
                -- Do repeated start
                if Scl = '0' then
                    Sda <= 'Z';
                    wait for ClkQuartPeriod;
                    LevelCheck(Sda, '1', to_string(msg_p) & " - SDA held low by other device [I2cPushRepeatedStart]");
                    Scl <= 'Z';
                    wait for ClkQuartPeriod;
                    LevelCheck(Scl, '1', to_string(msg_p) & " - SCL held low by other device [I2cPushRepeatedStart]");
                end if;
                wait for ClkQuartPeriod;
                Sda <= '0';
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cPushRepeatedStart]");
                wait for ClkQuartPeriod;

                -- Go to center of clk low period
                Scl <= '0';
                wait for ClkQuartPeriod;

            elsif msg_type = I2cPushStopMsg then
                -- Push Stop
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = I2c_MASTER, to_string(msg_p) & " - I2C must be in master mode before I2C-STOP can be sent [I2cPushStop]");
                if to01X(Scl) = '1' then
                    LevelCheck(Sda, '0', to_string(msg_p) & " - SDA must be 0 before procedure is called if SCL = 1 [I2cPushStop]");
                end if;
                
                -- Do stop
                if Scl = '0' then
                    Sda <= '0';
                    wait for ClkQuartPeriod;
                    Scl <= 'Z';
                    wait for ClkQuartPeriod;
                    LevelCheck(Scl, '1', to_string(msg_p) & " - SCL held low by other device [I2cPushStop]");
                else
                    wait for ClkQuartPeriod;		
                end if;
                Sda <= 'Z';
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA rising edge [I2cPushStop]");
                
                -- Go to center of clk high period
                wait for ClkQuartPeriod;
                opmode := I2c_IDLE; 
                
            elsif msg_type = I2cPushAddrMsg then
                -- Push Address
                address := pop(request_msg);
                isRead := pop(request_msg);
                addrBits := pop(request_msg);
                expectedAck := pop(request_msg);
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- delay
                wait for delay;

                -- Initial check
                check(opmode = I2c_MASTER, to_string(msg_p) & " - I2C must be in master mode before I2C-ADDRESS can be sent [I2cPushAddr]");

                -- 7 Bit addressing
                if AddrBits = 7 then
                    SendByteInclClock(toUslv(Address, 7) & choose(isRead, '1', '0'), Scl, Sda, to_string(msg_p) & " - 7bit Address Transmission [I2cPushAddr]");
                    Sda <= 'Z';
                    ReceiveBitInclClock(Ack_v, Scl, Sda, to_string(msg_p) & " - 7bit Addres ACK reception [I2cPushAddr]");
                    check_equal(Ack_v, ExpectedAck, to_string(msg_p) & " - 7bit Address ACK [I2cPushAddr]");
                -- 10 Bit addressing
                elsif AddrBits = 10 then
                    -- First beat
                    SendByteInclClock("11110" & toUslv(Address, 10)(9 downto 8) & choose(isRead, '1', '0'), Scl, Sda, to_string(msg_p) & " - 10bit Address Transmission, first beat [I2cPushAddr]");
                    Sda <= 'Z';
                    ReceiveBitInclClock(Ack_v, Scl, Sda, to_string(msg_p) & " - 7bit Addres ACK reception for first address beat [I2cPushAddr]");
                    check_equal(Ack_v, ExpectedAck, to_string(msg_p) & " - 10bit Address ACK for first address beat [I2cPushAddr]");
                    -- Second beat
                    SendByteInclClock(toUslv(Address, 10)(7 downto 0) , Scl, Sda, to_string(msg_p) & " - 10bit Address Transmission, second beat [I2cPushAddr]");
                    Sda <= 'Z';
                    ReceiveBitInclClock(Ack_v, Scl, Sda, to_string(msg_p) & " - 7bit Addres ACK reception for second address beat [I2cPushAddr]");
                    check_equal(Ack_v, ExpectedAck, to_string(msg_p) & " - 10bit Address ACK for first second beat [I2cPushAddr]");
                else
                    error(to_string(msg_p) & " - I2cMasterSendAddr - Illegal addrBits (must be 7 or 10)");
                end if;

            -- *** Handle Slave Messages ***
            elsif msg_type = I2cExpectStartMsg then
                -- Expect Start
                timeout := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_IDLE, to_string(msg_p) & " - I2C must be idle before I2C-START can be expected [I2cExpectStart]");
                opmode := I2c_SLAVE;
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 before I2C-START can be received [I2cExpectStart]");
                LevelCheck(Sda, '1', to_string(msg_p) & " - SDA must be 1 before I2C-START can be received [I2cExpectStart]");
                
                -- Do start checking
                LevelWait(Sda, '0', to_string(msg_p) & " - SDA did not go low [I2cExpectStart]", timeout);
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cExpectStart]");
                LevelWait(Scl, '0', to_string(msg_p) & " - SCL did not go low [I2cExpectStart]", timeout);
                LevelCheck(Sda, '0', to_string(msg_p) & " - SDA must be 0 during SCL falling edge [I2cExpectStart]");	

                -- Wait for center of SCL low
		        wait for ClkQuartPeriod;

            elsif msg_type = I2cExpectRepeatedStartMsg then
                -- Expect Repeated Start
                timeout := pop(request_msg);
                clkStretch := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in slave mode before I2C-REPEATED-START can be expected [I2cExpectRepeatedStart]");
                if to01X(Scl) = '1' then
                    LevelCheck(Sda, '1', to_string(msg_p) & " - SDA must be 1 if SCL = 1 when waiting for a I2C-REPEATED-START [I2cExpectRepeatedStart]");
                end if;
            
                -- Do Check
                if to01X(Scl) = '0' then
                    -- Clock stretching
                    if clkStretch > 0 ns then
                        Scl <= '0';
                        wait for clkStretch;
                        Scl <= 'Z';
                    end if;	
                    LevelWait(Scl, '1', to_string(msg_p) & " - SCL did not go high [I2cExpectRepeatedStart]", timeout);
                    LevelCheck(Sda, '1', to_string(msg_p) & " - SDA must be 1 before SCL goes high [I2cExpectRepeatedStart]");
                end if;
                LevelWait(Sda, '0', to_string(msg_p) & " - SDA did not go low [I2cExpectRepeatedStart]", timeout);
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA falling edge [I2cExpectRepeatedStart]");
                LevelWait(Scl, '0', to_string(msg_p) & " - SCL did not go low [I2cExpectRepeatedStart]", timeout);
                LevelCheck(Sda, '0', to_string(msg_p) & " - SDA must be 0 during SCL falling edge [I2cExpectRepeatedStart]");		
                
                -- Wait for center of SCL low
                wait for ClkQuartPeriod;

            elsif msg_type = I2cExpectStopMsg then
                -- Expect Stop
                timeout := pop(request_msg);
                clkStretch := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in slave mode before I2C-STOP can be expected [I2cExpectStop]");
                if to01X(Scl) = '1' then
                    LevelCheck(Sda, '0', to_string(msg_p) & " - SDA must be 0 if SCL = 1 when waiting for a I2C-STOP [I2cExpectStop]");
                end if;
                
                -- Do Check
                if to01X(Scl) = '0' then
                    -- Clock stretching
                    if clkStretch > 0 ns then
                        Scl <= '0';
                        wait for clkStretch;
                        Scl <= 'Z';
                    end if;	
                    LevelWait(Scl, '1', to_string(msg_p) & " - SCL did not go high [I2cExpectStop]", timeout);
                    LevelCheck(Sda, '0', to_string(msg_p) & " - SDA must be 0 before SCL goes high [I2cExpectStop]");
                end if;
                LevelWait(Sda, '1', to_string(msg_p) & " - SDA did not go high [I2cExpectStop]", timeout);
                LevelCheck(Scl, '1', to_string(msg_p) & " - SCL must be 1 during SDA rising edge [I2cExpectStop]");
                
                -- Go to center of clk high period
                wait for ClkQuartPeriod;
                opmode := I2c_IDLE;

            elsif msg_type = I2cExpectAddrMsg then
                -- Expect Address
                address := pop(request_msg);
                isRead := pop(request_msg);
                addrBits := pop(request_msg);
                ackOutput := pop(request_msg);
                timeout := pop(request_msg);
                clkStretch := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in slave mode before I2C-ADDRESS can be expected [I2cExpectAddr]");

                -- 7 Bit addressing
                if AddrBits = 7 then
                    ExpectByteExclClock(toUslv(Address, 7) & choose(isRead, '1', '0'), Scl, Sda, to_string(msg_p) & " - 7bit Address Reception [I2cExpectAddr]", ClkStretch => clkStretch);
                    SendBitExclClock(ackOutput, Scl, Sda, to_string(msg_p) & " - 7bit Address ACK Transmission [I2cExpectAddr]", clkStretch => clkStretch);
                -- 10 Bit addressing
                elsif AddrBits = 10 then
                    -- First beat
                    ExpectByteExclClock("11110" & toUslv(Address, 10)(9 downto 8) & choose(isRead, '1', '0'), Scl, Sda, to_string(msg_p) & " - 10bit Address Reception, first beat [I2cExpectAddr]", clkStretch);
                    SendBitExclClock(ackOutput, Scl, Sda, to_string(msg_p) & " - 10bit Address ACK Transmission, first beat [I2cExpectAddr]", ClkStretch => clkStretch);
                    -- Second beat
                    ExpectByteExclClock(toUslv(Address, 10)(7 downto 0), Scl, Sda, to_string(msg_p) & " - 10bit Address Reception, second beat [I2cExpectAddr]", ClkStretch => clkStretch);
                    SendBitExclClock(ackOutput, Scl, Sda, to_string(msg_p) & " - 10bit Address ACK Transmission, second beat [I2cExpectAddr]", ClkStretch => clkStretch);
                else
                    error(to_string(msg_p) & " - I2cExpectAddr - Illegal addrBits (must be 7 or 10)");
                end if;

            -- *** Handle General Messages ***
            elsif msg_type = I2cPushTxByteMsg then
                -- Push TX Byte
                data := pop(request_msg);
                expectedAck := pop(request_msg);
                clkStretch := pop(request_msg);
                delay := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_MASTER or opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in master or slave mode before I2C-TX-BYTE can be sent [I2cPushTxByte]");
                check(opmode = I2c_SLAVE or clkStretch = 0 ns, to_string(msg_p) & " - Clock stretching is only allowed in slave mode [I2cPushTxByte]");
                check(opmode = I2c_MASTER or delay = 0 ns, to_string(msg_p) & " - Delay is only allowed in master mode [I2cPushTxByte]");

                -- Do data
                if Data < 0 then
                    Data_v := toSslv(data, 8);
                else
                    Data_v := toUslv(data, 8);
                end if;
                if opmode = I2c_MASTER then
                    wait for delay;
                    SendByteInclClock(Data_v, Scl, Sda, to_string(msg_p) & " - Send byte in master mode [I2cPushTxByte]");
                    Sda <= 'Z';
                    ReceiveBitInclClock(Ack_v, Scl, Sda, to_string(msg_p) & " - data ACK in master mode [I2cPushTxByte]");
                else
                    SendByteExclClock(Data_v, Scl, Sda, to_string(msg_p) & " - Send byte in slave mode [I2cPushTxByte]", ClkStretch => clkStretch);
                    I2cBusFree(Scl, Sda);
                    ReceiveBitExclClock(Ack_v, Scl, Sda, to_string(msg_p) & " - data ACK in slave mode [I2cPushTxByte]", ClkStretch => clkStretch);
                end if;
                check_equal(Ack_v, expectedAck, to_string(msg_p) & " - data ACK [I2cPushTxByte]");

            elsif msg_type = I2cExpectRxByteMsg then
                -- Expect RX Byte
                data := pop(request_msg);
                ackOutput := pop(request_msg);
                clkStretch := pop(request_msg);
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Initial check
                check(opmode = I2c_MASTER or opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in master or slave mode before I2C-RX-BYTE can be expected [I2cExpectRxByte]");
                check(opmode = I2c_SLAVE or clkStretch = 0 ns, to_string(msg_p) & " - Clock stretching is only allowed in slave mode [I2cExpectRxByte]");

                -- Do data
                if Data < 0 then
                    Data_v := toSslv(Data, 8);
                else
                    Data_v := toUslv(Data, 8);
                end if;
                if opmode = I2c_MASTER then
                    Sda <= 'Z';
                    ExpectByteInclClock(Data_v, Scl, Sda, to_string(msg_p) & " - Receive byte in master mode [I2cExpectRxByte]");
                    SendBitInclClock(ackOutput, Scl, Sda, to_string(msg_p) & " - ACK in master mode [I2cExpectRxByte]");
                else
                    ExpectByteExclClock(Data_v, Scl, Sda, to_string(msg_p) & " - Receive byte in slave mode [I2cExpectRxByte]", ClkStretch => clkStretch);           
                    SendBitExclClock(ackOutput, Scl, Sda, to_string(msg_p) & " - ACK in slave mode [I2cExpectRxByte]", ClkStretch => clkStretch);
                    I2cBusFree(Scl, Sda);
                end if;

            elsif msg_type = I2cForceMasterModeMsg then
                -- Pop message
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Force Master Mode
                check(opmode = I2c_SLAVE, to_string(msg_p) & " - I2C must be in slave mode before I2C-MASTER-MODE can be forced [I2cForceMasterMode]");
                opmode := I2c_MASTER;

            elsif msg_type = I2cForceBusReleaseMsg then
                -- Pop message
                msg_p := new_string_ptr(pop_string(request_msg));

                -- Force Bus Release
                I2cBusFree(Scl, Sda);
                opmode := I2c_IDLE;
	

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;                
        end loop;
    end process;

end;