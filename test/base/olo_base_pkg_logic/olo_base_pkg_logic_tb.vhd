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
    use olo.olo_base_pkg_logic.all;
    use olo.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_logic_tb is
    generic (
        runner_cfg     : string
    );
end entity olo_base_pkg_logic_tb;

architecture sim of olo_base_pkg_logic_tb is

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        variable stdlv5 : std_logic_vector(4 downto 0);
        variable stdlv3 : std_logic_vector(2 downto 0);
        variable stdlv9 : std_logic_vector(8 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop
    
            if run("zerosVector") then
                check_equal(zerosVector(1), toUslv(0, 1), "zerosVector(1)");
                check_equal(zerosVector(3), toUslv(0, 3), "zerosVector(3)");   
            
            elsif run("onesVector") then
                check_equal(onesVector(1), toSslv(-1, 1), "onesVector(1)");
                check_equal(onesVector(3), toSslv(-1, 3), "onesVector(3)");  

            elsif run("shiftLeft") then
                stdlv5 := "11010";
                check_equal(shiftLeft(stdlv5, 1, '0'), stdlv5(3 downto 0) & '0', "shiftLeft(stdlv5, 1, '0')");
                check_equal(shiftLeft(stdlv5, 2, '1'), stdlv5(2 downto 0) & "11", "shiftLeft(stdlv5, 2, '1')");
                check_equal(shiftLeft(stdlv5, -2, '0'), "00" & stdlv5(4 downto 2), "shiftLeft(stdlv5, -2, '0')");
                check_equal(shiftLeft(stdlv5, -1, '1'), '1' & stdlv5(4 downto 1), "shiftLeft(stdlv5, -1, '1')");

            elsif run("shiftRight") then
                stdlv5 := "11010";
                check_equal(shiftRight(stdlv5, -1, '0'), stdlv5(3 downto 0) & '0', "shiftLeft(stdlv5, -1, '0')");
                check_equal(shiftRight(stdlv5, -2, '1'), stdlv5(2 downto 0) & "11", "shiftLeft(stdlv5, -2, '1')");
                check_equal(shiftRight(stdlv5, 2, '0'), "00" & stdlv5(4 downto 2), "shiftLeft(stdlv5, 2, '0')");
                check_equal(shiftRight(stdlv5, 1, '1'), '1' & stdlv5(4 downto 1), "shiftLeft(stdlv5, 1, '1')");
            
            
            elsif run("binaryToGray") then
                stdlv3 := "000"; check_equal(binaryToGray(stdlv3), 2#000#, "binaryToGray(000)");
                stdlv3 := "001"; check_equal(binaryToGray(stdlv3), 2#001#, "binaryToGray(001)");
                stdlv3 := "010"; check_equal(binaryToGray(stdlv3), 2#011#, "binaryToGray(010)");
                stdlv3 := "011"; check_equal(binaryToGray(stdlv3), 2#010#, "binaryToGray(011)");
                stdlv3 := "100"; check_equal(binaryToGray(stdlv3), 2#110#, "binaryToGray(100)");
                stdlv3 := "101"; check_equal(binaryToGray(stdlv3), 2#111#, "binaryToGray(101)");
                stdlv3 := "110"; check_equal(binaryToGray(stdlv3), 2#101#, "binaryToGray(110)");
                stdlv3 := "111"; check_equal(binaryToGray(stdlv3), 2#100#, "binaryToGray(111)");
          
            elsif run("grayToBinary") then
                stdlv3 := "000"; check_equal(grayToBinary(stdlv3), 2#000#, "grayToBinary(000)");
                stdlv3 := "001"; check_equal(grayToBinary(stdlv3), 2#001#, "grayToBinary(001)");
                stdlv3 := "011"; check_equal(grayToBinary(stdlv3), 2#010#, "grayToBinary(011)");
                stdlv3 := "010"; check_equal(grayToBinary(stdlv3), 2#011#, "grayToBinary(010)");
                stdlv3 := "110"; check_equal(grayToBinary(stdlv3), 2#100#, "grayToBinary(110)");
                stdlv3 := "111"; check_equal(grayToBinary(stdlv3), 2#101#, "grayToBinary(111)");
                stdlv3 := "101"; check_equal(grayToBinary(stdlv3), 2#110#, "grayToBinary(101)");
                stdlv3 := "100"; check_equal(grayToBinary(stdlv3), 2#111#, "grayToBinary(100)");

            elsif run("ppcOr") then
                check_equal(ppcOr("0100"), 2#0111#, "ppcOr(0100)");
                check_equal(ppcOr("0101"), 2#0111#, "ppcOr(0101)");
                check_equal(ppcOr("0011"), 2#0011#, "ppcOr(0011)");
                check_equal(ppcOr("0010"), 2#0011#, "ppcOr(0010)");
            
            elsif run("reduceOr") then
                check_equal(reduceOr("0000"), '0', "reduceOr(0000)");
                check_equal(reduceOr("0001"), '1', "reduceOr(0001)");
                check_equal(reduceOr("0110"), '1', "reduceOr(0110)");
                check_equal(reduceOr("1110"), '1', "reduceOr(1110)");
                check_equal(reduceOr("1111"), '1', "reduceOr(1111)");

            elsif run("reduceAnd") then
                check_equal(reduceAnd("0000"), '0', "reduceAnd(0000)");
                check_equal(reduceAnd("0001"), '0', "reduceAnd(0001)");
                check_equal(reduceAnd("0110"), '0', "reduceAnd(0110)");
                check_equal(reduceAnd("1110"), '0', "reduceAnd(1110)");
                check_equal(reduceAnd("1111"), '1', "reduceAnd(1111)");

            elsif run("reduceXor") then
                check_equal(reduceXor("0000"), '0', "reduceXor(0000)");
                check_equal(reduceXor("0001"), '1', "reduceXor(0001)");
                check_equal(reduceXor("0110"), '0', "reduceXor(0110)");
                check_equal(reduceXor("1110"), '1', "reduceXor(1110)");
                check_equal(reduceXor("1111"), '0', "reduceXor(1111)");

            elsif run("to01X-stdl") then
                check_equal(to01X('0'), '0', "to01X('0')");
                check_equal(to01X('1'), '1', "to01X('1')");
                check_equal(to01X('H'), '1', "to01X('H')");
                check_equal(to01X('L'), '0', "to01X('L')");
                check_equal(to01X('W'), 'X', "to01X('W')");
                check_equal(to01X('-'), 'X', "to01X('-')");
                check_equal(to01X('Z'), 'X', "to01X('Z')");
                check_equal(to01X('U'), 'X', "to01X('U')");
                check_equal(to01X('X'), 'X', "to01X('X')");

            elsif run("to01X-stlv") then    
                stdlv9 := "0101XXXXX";
                check_equal(to01X("01LHW-ZUX"), stdlv9, "to01X(01HLW-ZUX)");

            elsif run("invertBitOrder") then    
            stdlv9 := "110010101";
            check_equal(invertBitOrder("101010011"), stdlv9, "to01X(110010101)");              
            
            end if;



        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
