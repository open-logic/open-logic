---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_logic_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_base_pkg_logic_tb is

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Stdlv5_v : std_logic_vector(4 downto 0);
        variable Stdlv3_v : std_logic_vector(2 downto 0);
        variable Stdlv9_v : std_logic_vector(8 downto 0);
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
                Stdlv5_v := "11010";
                check_equal(shiftLeft(Stdlv5_v, 1, '0'), Stdlv5_v(3 downto 0) & '0', "shiftLeft(Stdlv5_v, 1, '0')");
                check_equal(shiftLeft(Stdlv5_v, 2, '1'), Stdlv5_v(2 downto 0) & "11", "shiftLeft(Stdlv5_v, 2, '1')");
                check_equal(shiftLeft(Stdlv5_v, -2, '0'), "00" & Stdlv5_v(4 downto 2), "shiftLeft(Stdlv5_v, -2, '0')");
                check_equal(shiftLeft(Stdlv5_v, -1, '1'), '1' & Stdlv5_v(4 downto 1), "shiftLeft(Stdlv5_v, -1, '1')");

            elsif run("shiftRight") then
                Stdlv5_v := "11010";
                check_equal(shiftRight(Stdlv5_v, -1, '0'), Stdlv5_v(3 downto 0) & '0', "shiftLeft(Stdlv5_v, -1, '0')");
                check_equal(shiftRight(Stdlv5_v, -2, '1'), Stdlv5_v(2 downto 0) & "11", "shiftLeft(Stdlv5_v, -2, '1')");
                check_equal(shiftRight(Stdlv5_v, 2, '0'), "00" & Stdlv5_v(4 downto 2), "shiftLeft(Stdlv5_v, 2, '0')");
                check_equal(shiftRight(Stdlv5_v, 1, '1'), '1' & Stdlv5_v(4 downto 1), "shiftLeft(Stdlv5_v, 1, '1')");

            elsif run("binaryToGray") then
                Stdlv3_v := "000"; check_equal(binaryToGray(Stdlv3_v), 2#000#, "binaryToGray(000)");
                Stdlv3_v := "001"; check_equal(binaryToGray(Stdlv3_v), 2#001#, "binaryToGray(001)");
                Stdlv3_v := "010"; check_equal(binaryToGray(Stdlv3_v), 2#011#, "binaryToGray(010)");
                Stdlv3_v := "011"; check_equal(binaryToGray(Stdlv3_v), 2#010#, "binaryToGray(011)");
                Stdlv3_v := "100"; check_equal(binaryToGray(Stdlv3_v), 2#110#, "binaryToGray(100)");
                Stdlv3_v := "101"; check_equal(binaryToGray(Stdlv3_v), 2#111#, "binaryToGray(101)");
                Stdlv3_v := "110"; check_equal(binaryToGray(Stdlv3_v), 2#101#, "binaryToGray(110)");
                Stdlv3_v := "111"; check_equal(binaryToGray(Stdlv3_v), 2#100#, "binaryToGray(111)");

            elsif run("grayToBinary") then
                Stdlv3_v := "000"; check_equal(grayToBinary(Stdlv3_v), 2#000#, "grayToBinary(000)");
                Stdlv3_v := "001"; check_equal(grayToBinary(Stdlv3_v), 2#001#, "grayToBinary(001)");
                Stdlv3_v := "011"; check_equal(grayToBinary(Stdlv3_v), 2#010#, "grayToBinary(011)");
                Stdlv3_v := "010"; check_equal(grayToBinary(Stdlv3_v), 2#011#, "grayToBinary(010)");
                Stdlv3_v := "110"; check_equal(grayToBinary(Stdlv3_v), 2#100#, "grayToBinary(110)");
                Stdlv3_v := "111"; check_equal(grayToBinary(Stdlv3_v), 2#101#, "grayToBinary(111)");
                Stdlv3_v := "101"; check_equal(grayToBinary(Stdlv3_v), 2#110#, "grayToBinary(101)");
                Stdlv3_v := "100"; check_equal(grayToBinary(Stdlv3_v), 2#111#, "grayToBinary(100)");

            elsif run("ppcOr") then
                check_equal(ppcOr("0100"), 2#0111#, "ppcOr(0100)");
                check_equal(ppcOr("0101"), 2#0111#, "ppcOr(0101)");
                check_equal(ppcOr("0011"), 2#0011#, "ppcOr(0011)");
                check_equal(ppcOr("0010"), 2#0011#, "ppcOr(0010)");

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
                Stdlv9_v := "0101XXXXX";
                check_equal(to01X("01LHW-ZUX"), Stdlv9_v, "to01X(01HLW-ZUX)");

            elsif run("to01-stdl") then
                check_equal(to01('0'), '0', "to01('0')");
                check_equal(to01('1'), '1', "to01('1')");
                check_equal(to01('H'), '1', "to01('H')");
                check_equal(to01('L'), '0', "to01('L')");
                check_equal(to01('W'), '0', "to01('W')");
                check_equal(to01('-'), '0', "to01('-')");
                check_equal(to01('Z'), '0', "to01('Z')");
                check_equal(to01('U'), '0', "to01('U')");
                check_equal(to01('X'), '0', "to01('X')");

            elsif run("to01-stlv") then
                Stdlv9_v := "010100000";
                check_equal(to01("01LHW-ZUX"), Stdlv9_v, "to01(01HLW-ZUX)");

            elsif run("invertBitOrder") then
                Stdlv9_v := "110010101";
                check_equal(invertBitOrder("101010011"), Stdlv9_v, "invertBitOrder(110010101)");

            elsif run("invertByteOrder") then
                check_equal(invertByteOrder(X"12"), 16#12#, "invertByteOrder(0x12)");
                check_equal(invertByteOrder(X"1234"), 16#3412#, "invertByteOrder(0x1234)");
                check_equal(invertByteOrder(X"123456"), 16#563412#, "invertByteOrder(0x123456)");

            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
