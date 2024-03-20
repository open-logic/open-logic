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

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_array.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
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

        while test_suite loop

            if run("log2") then
                check_equal(log2(8), 3, "log2(8) wrong");
                check_equal(log2(5), 2, "log2(5) wrong");
                check_equal(log2(2), 1, "log2(2) wrong");
                check_equal(log2(1), 0, "log2(1) wrong");

            elsif run("log2ceil") then
                check_equal(log2ceil(8), 3, "log2ceil(8) wrong");
                check_equal(log2ceil(5), 3, "log2ceil(5) wrong");
                check_equal(log2ceil(2), 1, "log2ceil(2) wrong");
                check_equal(log2ceil(1), 0, "log2ceil(1) wrong");   
                check_equal(log2ceil(0), 0, "log2ceil(1) wrong");    -- special case, returns zero to avoid errors when calculating bits for zero-lenth arrays
        
            elsif run("isPower2") then
                check_equal(isPower2(8), true,  "islog2(8) wrong");
                check_equal(isPower2(5), false, "islog2(5) wrong");
                check_equal(isPower2(2), true,  "islog2(2) wrong");
                check_equal(isPower2(1), true, "islog2(1) wrong");     
        
            elsif run("max-integer") then
                check_equal(max(3,4), 4,    "max(3,4) wrong"); 
                check_equal(max(4,3), 4,    "max(3,4) wrong");
                check_equal(max(-4,3), 3,   "max(3,4) wrong");
                check_equal(max(3,-4), 3,   "max(3,4) wrong");

            elsif run("max-real") then
                check_equal(max(3.0,4.0), 4.0,    "max(3.0,4.0) wrong");
                check_equal(max(4.0,3.0), 4.0,    "max(4.0,3.0) wrong");
                check_equal(max(-4.0,3.0), 3.0,   "max(-4.0,3.0)wrong");
                check_equal(max(3.0,-4.0), 3.0,   "max(3.0,-4.0) wrong");
                check_equal(max(1.2,1.3), 1.3,    "max(1.2,1.3) wrong");

            elsif run("min-integer") then
                check_equal(olo.olo_base_pkg_math.min(3,4), 3,    "min(3,4) wrong");
                check_equal(olo.olo_base_pkg_math.min(4,3), 3,    "min(3,4) wrong");
                check_equal(olo.olo_base_pkg_math.min(-4,3), -4,  "min(3,4) wrong");
                check_equal(olo.olo_base_pkg_math.min(3,-4), -4,  "min(3,4) wrong");

            elsif run("min-real") then
                check_equal(olo.olo_base_pkg_math.min(3.0,4.0), 3.0,    "min(3.0,4.0) wrong");
                check_equal(olo.olo_base_pkg_math.min(4.0,3.0), 3.0,    "min(4.0,3.0) wrong");
                check_equal(olo.olo_base_pkg_math.min(-4.0,3.0), -4.0,  "min(-4.0,3.0)wrong");
                check_equal(olo.olo_base_pkg_math.min(3.0,-4.0), -4.0,  "min(3.0,-4.0) wrong");
                check_equal(olo.olo_base_pkg_math.min(1.2,1.3), 1.2,    "min(1.2,1.3) wrong");

            elsif run("choose-bool") then
                check_equal(choose(true, true, false), true,    "choose(true, true, false)"); 
                check_equal(choose(true, false, true), false,   "choose(true, false, true)"); 
                check_equal(choose(false, true, false), false,  "choose(false, true, false)"); 
                check_equal(choose(false, false, true), true,   "choose(false, false, true)"); 

            elsif run("choose-std_logic") then
                check_equal(choose(true, '1', '0'), '1',     "choose(true, '1'', '0')"); 
                check_equal(choose(true, '0', '1'), '0',     "choose(true, '0'', '1')"); 
                check_equal(choose(false, '1', '0'), '0',    "choose(false, '1', '0')"); 
                check_equal(choose(false,  '0', '1'), '1',   "choose(false,  '0', '1')"); 

            elsif run("choose-std_logic_vector") then
                stdlva := "000";
                stdlvb := "111";
                check_equal(choose(true, stdlva, stdlvb), stdlva,   "choose(true, 000, 111)"); 
                check_equal(choose(false, stdlva, stdlvb), stdlvb,  "choose(false, 000, 111)"); 

            elsif run("choose-integer") then
                check_equal(choose(true, 2, 3), 2,   "choose(true, 2, 3)"); 
                check_equal(choose(false, 2, 3), 3,  "choose(false, 2, 3)"); 

            elsif run("choose-real") then
                check_equal(choose(true, 2.0, 3.0), 2.0,   "choose(true, 2.0, 3.0)"); 
                check_equal(choose(false, 2.0, 3.0), 3.0,  "choose(false, 2.0, 3.0)"); 

            elsif run("choose-string") then
                check_equal(choose(true, stra, strb), stra,     "choose(true, bla, blubb)"); 
                check_equal(choose(false, stra, strb), strb,    "choose(false, bla, blubb)"); 

            elsif run("choose-unsigned") then
                usa := "000";
                usb := "111";
                check_equal(choose(true, usa, usb), usa,    "choose(true, usa, usb)"); 
                check_equal(choose(false, usa, usb), usb,   "choose(false, usa, usb)"); 

            elsif run("choose-t_areal") then
                tra := (0.1, 0.2);
                trb := (2.0, 3.0);
                trc := choose(true, tra, trb);
                check_equal(trc(0), tra(0),    "choose(true, tra, trb)"); 
                trc := choose(false, tra, trb);
                check_equal(trc(0), trb(0),   "choose(false, tra, trb)"); 

            elsif run("count-t_ainteger") then
                taint := (1, 2, 3, 2);
                check_equal(count(taint, 2), 2,    "count -> 2"); 
                check_equal(count(taint, 3), 1,    "count -> 3"); 

            elsif run("count-t_abool") then
                tabool := (true, false, true, true);
                check_equal(count(tabool, true), 3,    "count -> true"); 
                check_equal(count(tabool, false), 1,   "count -> false"); 

            elsif run("count-std_logic_vector") then
                stdlva := "010";
                check_equal(count(stdlva, '1'), 1,    "count -> '1''"); 
                check_equal(count(stdlva, '0'), 2,    "count -> '0'"); 

            elsif run("toUslv") then
                check_equal(toUslv(3, 4), std_logic_vector(to_unsigned(3, 4)),    "toUslv(3, 4)"); 

            elsif run("toSslv") then
                check_equal(toSslv(3, 4), std_logic_vector(to_unsigned(3, 4)),  "toSslv(3, 4)"); 
                check_equal(toSslv(-2, 5), std_logic_vector(to_signed(-2, 5)),  "toSslv(-2, 5)"); 

            elsif run("toStdl") then
                check_equal(toStdl(1), '1', "toStdl(1)");
                check_equal(toStdl(0), '0', "toStdl(0)");

            elsif run("fromUslv") then
                stdlva := "010";
                check_equal(fromUslv(stdlva), 2,    "fromUslv(010)"); 

            elsif run("fromSslv") then
                stdlva := "010";
                check_equal(fromSslv(stdlva), 2,    "fromSslv(010)"); 
                stdlva := "110";
                check_equal(fromSslv(stdlva), -2,   "fromSslv(110)");
                
            elsif run("fromStdl") then
                check_equal(fromStdl('0'), 0, "fromStdl('0')");
                check_equal(fromStdl('1'), 1, "fromStdl('1')");

            elsif run("fromString-real") then
                check_equal(fromString("2 "), 2.0,            "fromString(2 )", 0.001e-6);
                check_equal(fromString("2"), 2.0,             "fromString(2)", 0.001e-6);
                check_equal(fromString("1.0"), 1.0,           "fromString(1.0)", 0.001e-6);
                check_equal(fromString(" 1.1"), 1.1,          "fromString( 1.1)", 0.001e-6);
                check_equal(fromString("+0.1"), +0.1,         "fromString(+0.1)", 0.001e-6);
                check_equal(fromString("-0.1"), -0.1,         "fromString(-0.1)", 0.001e-6);
                check_equal(fromString("+12.2"), +12.2,       "fromString(+12.2)", 0.001e-6);
                check_equal(fromString("-13.3"), -13.3,       "fromString(-13.3)", 0.001e-6);
                check_equal(fromString("-13.3e2"), -13.3e2,   "fromString(-13.3e2)", 0.001e-6);
                check_equal(fromString("12.2E-3"), 12.2E-3,   "fromString(12.2E-3)", 0.001e-6);

            elsif run("fromString-t_areal") then
                tra := fromString("0.1, -0.3e-2");
                check_equal(tra(0), 0.1,           "fromString(t_areal) - 0", 0.001e-6);
                check_equal(tra(1), -0.3e-2,       "fromString(t_areal) - 1", 0.001e-6);
                tra := fromString("0.1,");
                check_equal(tra(1), 0.0,       "fromString(t_areal) - 2a", 0.001e-6); -- empty last array element is interpreted as zero
                check_equal(tra(0), 0.1,       "fromString(t_areal) - 2b", 0.001e-6); 

            elsif run("maxArray-int") then
                taint := (1, -3, 4, 2);
                check_equal(maxArray(taint), 4, "maxArray(taint)");

            elsif run("maxArray-real") then
                tra4 := (0.1, -0.3, 1.4, 0.2);
                check_equal(maxArray(tra4), 1.4, "maxArray(tra4)");

            elsif run("minArray-int") then
                taint := (1, -3, 4, 2);
                check_equal(minArray(taint), -3, "minArray(taint)");

            elsif run("minArray-real") then
                tra4 := (0.1, -0.3, 1.4, 0.2);
                check_equal(minArray(tra4), -0.3, "minArray(tra4)");

            end if;
        end loop;

    
        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
