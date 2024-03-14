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
    use olo.olo_base_pkg_array.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_pkg_math_tb is
    generic (
        runner_cfg     : string
    );
end entity olo_base_pkg_math_tb;

architecture sim of olo_base_pkg_math_tb is

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        variable stdlva, stdlvb : std_logic_vector(2 downto 0);
        variable stra : string(1 to 3) := "bla";
        variable strb : string(1 to 5) := "blubb";
        variable usa, usb : unsigned(2 downto 0);
        variable tra, trb, trc : t_areal(0 to 1);
        variable taint : t_ainteger(0 to 3);
        variable tabool : t_abool(0 to 3);
        variable tra4 : t_areal(0 to 3);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;
        -- log2
        check_equal(log2(8), 3, "log2(8) wrong");
        check_equal(log2(5), 2, "log2(5) wrong");
        check_equal(log2(2), 1, "log2(2) wrong");
        check_equal(log2(1), 0, "log2(1) wrong");

        -- log2ceil
        check_equal(log2ceil(8), 3, "log2ceil(8) wrong");
        check_equal(log2ceil(5), 3, "log2ceil(5) wrong");
        check_equal(log2ceil(2), 1, "log2ceil(2) wrong");
        check_equal(log2ceil(1), 0, "log2ceil(1) wrong");   
        check_equal(log2ceil(0), 0, "log2ceil(1) wrong");    -- special case, returns zero to avoid errors when calculating bits for zero-lenth arrays
        
        -- islog2
        check_equal(islog2(8), true,  "islog2(8) wrong");
        check_equal(islog2(5), false, "islog2(5) wrong");
        check_equal(islog2(2), true,  "islog2(2) wrong");
        check_equal(islog2(1), true, "islog2(1) wrong");     
        
        -- max (integer)
        check_equal(max(3,4), 4,    "max(3,4) wrong"); 
        check_equal(max(4,3), 4,    "max(3,4) wrong");
        check_equal(max(-4,3), 3,   "max(3,4) wrong");
        check_equal(max(3,-4), 3,   "max(3,4) wrong");

        -- max (real)
        check_equal(max(3.0,4.0), 4.0,    "max(3.0,4.0) wrong");
        check_equal(max(4.0,3.0), 4.0,    "max(4.0,3.0) wrong");
        check_equal(max(-4.0,3.0), 3.0,   "max(-4.0,3.0)wrong");
        check_equal(max(3.0,-4.0), 3.0,   "max(3.0,-4.0) wrong");
        check_equal(max(1.2,1.3), 1.3,    "max(1.2,1.3) wrong");

        -- min (integer)
        check_equal(olo.olo_base_pkg_math.min(3,4), 3,    "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(4,3), 3,    "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(-4,3), -4,  "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(3,-4), -4,  "min(3,4) wrong");

        -- min (real)
        check_equal(olo.olo_base_pkg_math.min(3.0,4.0), 3.0,    "min(3.0,4.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(4.0,3.0), 3.0,    "min(4.0,3.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(-4.0,3.0), -4.0,  "min(-4.0,3.0)wrong");
        check_equal(olo.olo_base_pkg_math.min(3.0,-4.0), -4.0,  "min(3.0,-4.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(1.2,1.3), 1.2,    "min(1.2,1.3) wrong");

        -- choose (bool)
        check_equal(choose(true, true, false), true,    "choose(true, true, false)"); 
        check_equal(choose(true, false, true), false,   "choose(true, false, true)"); 
        check_equal(choose(false, true, false), false,  "choose(false, true, false)"); 
        check_equal(choose(false, false, true), true,   "choose(false, false, true)"); 

        -- choose (std_logic)
        check_equal(choose(true, '1', '0'), '1',     "choose(true, '1'', '0')"); 
        check_equal(choose(true, '0', '1'), '0',     "choose(true, '0'', '1')"); 
        check_equal(choose(false, '1', '0'), '0',    "choose(false, '1', '0')"); 
        check_equal(choose(false,  '0', '1'), '1',   "choose(false,  '0', '1')"); 

        -- choose (std_logic_vector)
        stdlva := "000";
        stdlvb := "111";
        check_equal(choose(true, stdlva, stdlvb), stdlva,   "choose(true, 000, 111)"); 
        check_equal(choose(false, stdlva, stdlvb), stdlvb,  "choose(false, 000, 111)"); 

        -- choose (integer)
        check_equal(choose(true, 2, 3), 2,   "choose(true, 2, 3)"); 
        check_equal(choose(false, 2, 3), 3,  "choose(false, 2, 3)"); 

        -- choose (real)
        check_equal(choose(true, 2.0, 3.0), 2.0,   "choose(true, 2.0, 3.0)"); 
        check_equal(choose(false, 2.0, 3.0), 3.0,  "choose(false, 2.0, 3.0)"); 

        -- choose (string)
        check_equal(choose(true, stra, strb), stra,     "choose(true, bla, blubb)"); 
        check_equal(choose(false, stra, strb), strb,    "choose(false, bla, blubb)"); 

        -- choose (unsigned)
        usa := "000";
        usb := "111";
        check_equal(choose(true, usa, usb), usa,    "choose(true, usa, usb)"); 
        check_equal(choose(false, usa, usb), usb,   "choose(false, usa, usb)"); 

        -- choose (t_areal)
        tra := (0.1, 0.2);
        trb := (2.0, 3.0);
        trc := choose(true, tra, trb);
        check_equal(trc(0), tra(0),    "choose(true, tra, trb)"); 
        trc := choose(false, tra, trb);
        check_equal(trc(0), trb(0),   "choose(false, tra, trb)"); 

        -- count (t_ainteger)
        taint := (1, 2, 3, 2);
        check_equal(count(taint, 2), 2,    "count -> 2"); 
        check_equal(count(taint, 3), 1,    "count -> 3"); 

        -- count (t_abool)
        tabool := (true, false, true, true);
        check_equal(count(tabool, true), 3,    "count -> true"); 
        check_equal(count(tabool, false), 1,   "count -> false"); 

        -- count (std_logic_vector)
        stdlva := "010";
        check_equal(count(stdlva, '1'), 1,    "count -> '1''"); 
        check_equal(count(stdlva, '0'), 2,    "count -> '0'"); 

        -- to_uslv
        check_equal(to_uslv(3, 4), std_logic_vector(to_unsigned(3, 4)),    "to_uslv(3, 4)"); 

        -- to_sslv
        check_equal(to_sslv(3, 4), std_logic_vector(to_unsigned(3, 4)),  "to_sslv(3, 4)"); 
        check_equal(to_sslv(-2, 5), std_logic_vector(to_signed(-2, 5)),  "to_sslv(-2, 5)"); 

        -- from_uslv
        stdlva := "010";
        check_equal(from_uslv(stdlva), 2,    "from_uslv(010)"); 

        -- from_sslv
        stdlva := "010";
        check_equal(from_sslv(stdlva), 2,    "from_sslv(010)"); 
        stdlva := "110";
        check_equal(from_sslv(stdlva), -2,   "from_sslv(110)"); 

        -- from_str real
        check_equal(from_str("1.0"), 1.0,           "from_str(1.0)", 0.001e-6);
        check_equal(from_str(" 1.1"), 1.1,          "from_str( 1.1)", 0.001e-6);
        check_equal(from_str("+0.1"), +0.1,         "from_str(+0.1)", 0.001e-6);
        check_equal(from_str("-0.1"), -0.1,         "from_str(-0.1)", 0.001e-6);
        check_equal(from_str("+12.2"), +12.2,       "from_str(+12.2)", 0.001e-6);
        check_equal(from_str("-13.3"), -13.3,       "from_str(-13.3)", 0.001e-6);
        check_equal(from_str("-13.3e2"), -13.3e2,   "from_str(-13.3e2)", 0.001e-6);
        check_equal(from_str("12.2E-3"), 12.2E-3,   "from_str(12.2E-3)", 0.001e-6);

        -- from_str real array
        tra := from_str("0.1, -0.3e-2");
        check_equal(tra(0), 0.1,           "from_str(t_areal) - 0", 0.001e-6);
        check_equal(tra(1), -0.3e-2,       "from_str(t_areal) - 1", 0.001e-6);

        -- max_a (int)
        taint := (1, -3, 4, 2);
        check_equal(max_a(taint), 4, "max_a(taint)");

        -- max_a (real)
        tra4 := (0.1, -0.3, 1.4, 0.2);
        check_equal(max_a(tra4), 1.4, "max_a(tra4)");

        -- min_a (int)
        taint := (1, -3, 4, 2);
        check_equal(min_a(taint), -3, "min_a(taint)");

        -- min_a (real)
        tra4 := (0.1, -0.3, 1.4, 0.2);
        check_equal(min_a(tra4), -0.3, "min_a(tra4)");

    
        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
