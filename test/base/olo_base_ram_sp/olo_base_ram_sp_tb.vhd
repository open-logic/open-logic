------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
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

library olo;
    use olo.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_ram_sp_tb is
    generic (
        runner_cfg      : string;
        Width_g         : positive range 5 to 128  := 32; 
        RamBehavior_g   : string    := "RBW";
        UseByteEnable_g : boolean   := false
    );
end entity olo_base_ram_sp_tb;

architecture sim of olo_base_ram_sp_tb is

    -------------------------------------------------------------------------
    -- Constants
    -------------------------------------------------------------------------	
    constant BeWidth_c      : integer := Width_g/8;
    constant BeSigWidth_c   : integer := maximum(BeWidth_c, 2); -- Must be at least 2 bits to avoid compile errors with GHDL.
                                                                -- .. GHDL checks ranges also on code in a not executed if-clause.
    constant ClkPeriod_c    : time    := 10 ns;


    -------------------------------------------------------------------------
    -- TB Defnitions
    -------------------------------------------------------------------------
    procedure Write(    address : natural;
                        data    : natural;
                        signal Clk  : in std_logic;
                        signal Addr : out std_logic_vector;
                        signal WrData : out std_logic_vector;
                        signal WrEna : out std_logic) is
    begin
        wait until rising_edge(Clk);
        Addr <= to_uslv(address, Addr'length);
        WrData <= to_uslv(data, WrData'length);
        WrEna <= '1';
        wait until rising_edge(Clk);
        WrEna <= '0';
        Addr <= to_uslv(0, Addr'length);
        WrData <= to_uslv(0, WrData'length);
    end procedure;

    procedure Check(    address : natural;
                        data    : natural;
                        signal Clk  : in std_logic;
                        signal Addr : out std_logic_vector;
                        signal RdData : in std_logic_vector;
                        message : string) is
    begin
        wait until rising_edge(Clk);
        Addr <= to_uslv(address, Addr'length);
        wait until rising_edge(Clk); -- Address sampled
        wait until rising_edge(Clk); 
        check_equal(RdData, to_uslv(data, RdData'length), message);
    end procedure;

    -------------------------------------------------------------------------
    -- Interface Signals
    -------------------------------------------------------------------------
    signal Clk        : std_logic                                  := '0';
    signal Addr       : std_logic_vector(7 downto 0)               := (others => '0');
    signal Be         : std_logic_vector(BeSigWidth_c-1 downto 0)     := (others => '0');
    signal WrEna      : std_logic                                  := '0';
    signal WrData     : std_logic_vector(Width_g-1 downto 0);
    signal RdData     : std_logic_vector(Width_g-1 downto 0);

begin

    -------------------------------------------------------------------------
    -- DUT
    -------------------------------------------------------------------------
    i_dut : entity olo.olo_base_ram_sp
        generic map (
            Depth_g         => 200,                                      
            Width_g         => Width_g,                                                   
            RamBehavior_g   => RamBehavior_g,
            UseByteEnable_g => UseByteEnable_g
        )
        port map (   
            Clk        => Clk,
            Addr       => Addr,
            Be         => Be(BeWidth_c-1 downto 0), -- Extract only used bits of minimally sized vector to avoid GHDL issues
            WrEna      => WrEna,
            WrData     => WrData,
            RdData     => RdData
        ); 

    -------------------------------------------------------------------------
    -- Clock
    -------------------------------------------------------------------------
    Clk  <= not Clk after 0.5 * ClkPeriod_c;

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
    begin
        test_runner_setup(runner, runner_cfg);

        -- Wait for some time
        wait for 1 us;
        wait until rising_edge(Clk);

        -- Write 3 Values, Read back
        if UseByteEnable_g then
            Be <= (others => '1'); -- BE not checked -> all ones
        end if;
        Write(1, 5, Clk, Addr, WrData, WrEna);
        Write(2, 6, Clk, Addr, WrData, WrEna);
        Write(3, 7, Clk, Addr, WrData, WrEna);
        Check(1, 5, Clk, Addr, RdData, "3vrb: 1=5");
        Check(2, 6, Clk, Addr, RdData, "3vrb: 2=6");
        Check(3, 7, Clk, Addr, RdData, "3vrb: 3=7");
        Check(1, 5, Clk, Addr, RdData, "3vrb: re-read 1=5");
        Be <= (others => '0');

        -- Check byte enables
        if UseByteEnable_g and (Width_g mod 8 = 0) and (Width_g > 8) then
            -- Byte 0 test
            Be <= (others => '1'); 
            Write(1, 0, Clk, Addr, WrData, WrEna);
            Be <= (others => '0'); 
            Be(0) <= '1';
            Write(1, 16#ABCD#, Clk, Addr, WrData, WrEna);
            Check(1, 16#00CD#, Clk, Addr, RdData, "BE[0]");
            -- Byte 1 test
            Be <= (others => '0'); 
            Be(1) <= '1';
            Write(1, 16#1234#, Clk, Addr, WrData, WrEna);
            Check(1, 16#12CD#, Clk, Addr, RdData, "BE[1]");
        end if;

        -- Read while write
        -- Initialize
        Be <= (others => '1'); 
        Write(1, 5, Clk, Addr, WrData, WrEna);
        Write(2, 6, Clk, Addr, WrData, WrEna);
        Write(3, 7, Clk, Addr, WrData, WrEna);
        wait until rising_edge(Clk);
        WrEna <= '1';
        Addr <= to_uslv(1, Addr'length);
        WrData <= to_uslv(1, WrData'length);
        wait until rising_edge(Clk);
        Addr <= to_uslv(2, Addr'length);
        WrData <= to_uslv(2, WrData'length);       
        wait until rising_edge(Clk);
        if RamBehavior_g = "RBW" then
            check_equal(RdData, 5, "rw: 1=5");
        else
            check_equal(RdData, 1, "rw: 1=1 wbr");    
        end if;
        Addr <= to_uslv(3, Addr'length);
        WrData <= to_uslv(3, WrData'length);    
        wait until rising_edge(Clk);
        if RamBehavior_g = "RBW" then
            check_equal(RdData, 6, "rw: 2=6");
        else
            check_equal(RdData, 2, "rw: 2=2 wbr");
        end if;    
        Addr <= to_uslv(4, Addr'length);
        WrData <= to_uslv(4, WrData'length);  
        wait until rising_edge(Clk);
        if RamBehavior_g = "RBW" then
            check_equal(RdData, 7, "rw: 3=7");
        else
            check_equal(RdData, 3, "rw: 3=3 wbr");
        end if;
        Addr <= to_uslv(5, Addr'length);
        WrData <= to_uslv(5, WrData'length);  
        wait until rising_edge(Clk);
        WrEna <= '0';
        Check(1, 1, Clk, Addr, RdData, "rw: 1=1");
        Check(2, 2, Clk, Addr, RdData, "rw: 2=2");
        Check(3, 3, Clk, Addr, RdData, "rw: 3=3");

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
