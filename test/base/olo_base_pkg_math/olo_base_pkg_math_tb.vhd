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
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_math_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_base_pkg_math_tb is

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable StdlvA_v, StdlvB_v                 : std_logic_vector(2 downto 0);
        variable StrA_v                             : string(1 to 3) := "bla";
        variable StrB_v                             : string(1 to 5) := "blubb";
        variable UnsA_v, UnsB_v                     : unsigned(2 downto 0);
        variable RealArrA_v, RealArrB_v, RealArrC_v : RealArray_t(0 to 1);
        variable IntArr_v                           : IntegerArray_t(0 to 3);
        variable BoolArr_v                          : BoolArray_t(0 to 3);
        variable RealArr4_v                         : RealArray_t(0 to 3);
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

            elsif run("greatestCommonFactor") then
                check_equal(greatestCommonFactor(9, 3), 3, "greatestCommonFactor(9, 3) wrong");
                check_equal(greatestCommonFactor(3, 9), 3, "greatestCommonFactor(3, 9) wrong");
                check_equal(greatestCommonFactor(8, 12), 4, "greatestCommonFactor(8, 12) wrong");
                check_equal(greatestCommonFactor(12, 8), 4, "greatestCommonFactor(12, 8) wrong");
                check_equal(greatestCommonFactor(3, 5), 1, "greatestCommonFactor(3, 5) wrong");
                check_equal(greatestCommonFactor(1, 5), 1, "greatestCommonFactor(0, 5) wrong");
                check_equal(greatestCommonFactor(5, 1), 1, "greatestCommonFactor(5, 0) wrong");

            elsif run("leastCommonMultiple") then
                check_equal(leastCommonMultiple(9, 3), 9, "leastCommonMultiple(9, 3) wrong");
                check_equal(leastCommonMultiple(3, 9), 9, "leastCommonMultiple(3, 9) wrong");
                check_equal(leastCommonMultiple(8, 12), 24, "leastCommonMultiple(8, 12) wrong");
                check_equal(leastCommonMultiple(7, 5), 35, "leastCommonMultiple(7, 5) wrong");
                check_equal(leastCommonMultiple(3, 5), 15, "leastCommonMultiple(3, 5) wrong");
                check_equal(leastCommonMultiple(1, 5), 5, "leastCommonMultiple(0, 5) wrong");
                check_equal(leastCommonMultiple(5, 1), 5, "leastCommonMultiple(5, 0) wrong");

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
                StdlvA_v := "000";
                StdlvB_v := "111";
                check_equal(choose(true, StdlvA_v, StdlvB_v), StdlvA_v,   "choose(true, 000, 111)");
                check_equal(choose(false, StdlvA_v, StdlvB_v), StdlvB_v,  "choose(false, 000, 111)");

            elsif run("choose-integer") then
                check_equal(choose(true, 2, 3), 2,   "choose(true, 2, 3)");
                check_equal(choose(false, 2, 3), 3,  "choose(false, 2, 3)");

            elsif run("choose-real") then
                check_equal(choose(true, 2.0, 3.0), 2.0,   "choose(true, 2.0, 3.0)");
                check_equal(choose(false, 2.0, 3.0), 3.0,  "choose(false, 2.0, 3.0)");

            elsif run("choose-string") then
                check_equal(choose(true, StrA_v, StrB_v), StrA_v,     "choose(true, bla, blubb)");
                check_equal(choose(false, StrA_v, StrB_v), StrB_v,    "choose(false, bla, blubb)");

            elsif run("choose-unsigned") then
                UnsA_v := "000";
                UnsB_v := "111";
                check_equal(choose(true, UnsA_v, UnsB_v), UnsA_v,    "choose(true, UnsA_v, UnsB_v)");
                check_equal(choose(false, UnsA_v, UnsB_v), UnsB_v,   "choose(false, UnsA_v, UnsB_v)");

            elsif run("choose-RealArray_t") then
                RealArrA_v := (0.1,
                               0.2);
                RealArrB_v := (2.0,
                               3.0);
                RealArrC_v := choose(true, RealArrA_v, RealArrB_v);
                check_equal(RealArrC_v(0), RealArrA_v(0),    "choose(true, RealArrA_v, RealArrB_v)");
                RealArrC_v := choose(false, RealArrA_v, RealArrB_v);
                check_equal(RealArrC_v(0), RealArrB_v(0),   "choose(false, RealArrA_v, RealArrB_v)");

            elsif run("count-IntegerArray_t") then
                IntArr_v := (1,
                             2,
                             3,
                             2);
                check_equal(count(IntArr_v, 2), 2,    "count -> 2");
                check_equal(count(IntArr_v, 3), 1,    "count -> 3");

            elsif run("count-BoolArray_t") then
                BoolArr_v := (true,
                              false,
                              true,
                              true);
                check_equal(count(BoolArr_v, true), 3,    "count -> true");
                check_equal(count(BoolArr_v, false), 1,   "count -> false");

            elsif run("count-std_logic_vector") then
                StdlvA_v := "010";
                check_equal(count(StdlvA_v, '1'), 1,    "count -> '1''");
                check_equal(count(StdlvA_v, '0'), 2,    "count -> '0'");

            elsif run("toUslv") then
                check_equal(toUslv(3, 4), std_logic_vector(to_unsigned(3, 4)),    "toUslv(3, 4)");

            elsif run("toSslv") then
                check_equal(toSslv(3, 4), std_logic_vector(to_unsigned(3, 4)),  "toSslv(3, 4)");
                check_equal(toSslv(-2, 5), std_logic_vector(to_signed(-2, 5)),  "toSslv(-2, 5)");

            elsif run("toStdl") then
                check_equal(toStdl(1), '1', "toStdl(1)");
                check_equal(toStdl(0), '0', "toStdl(0)");

            elsif run("fromUslv") then
                StdlvA_v := "010";
                check_equal(fromUslv(StdlvA_v), 2,    "fromUslv(010)");

            elsif run("fromSslv") then
                StdlvA_v := "010";
                check_equal(fromSslv(StdlvA_v), 2,    "fromSslv(010)");
                StdlvA_v := "110";
                check_equal(fromSslv(StdlvA_v), -2,   "fromSslv(110)");

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

            elsif run("fromString-RealArray_t") then
                RealArrA_v := fromString("0.1, -0.3e-2");
                check_equal(RealArrA_v(0), 0.1,           "fromString(RealArray_t) - 0", 0.001e-6);
                check_equal(RealArrA_v(1), -0.3e-2,       "fromString(RealArray_t) - 1", 0.001e-6);
                RealArrA_v := fromString("0.1,");
                check_equal(RealArrA_v(1), 0.0,       "fromString(RealArray_t) - 2a", 0.001e-6); -- empty last array element is interpreted as zero
                check_equal(RealArrA_v(0), 0.1,       "fromString(RealArray_t) - 2b", 0.001e-6);

            elsif run("maxArray-int") then
                IntArr_v := (1,
                             -3,
                             4,
                             2);
                check_equal(maxArray(IntArr_v), 4, "maxArray(IntArr_v)");

            elsif run("maxArray-real") then
                RealArr4_v := (0.1,
                               -0.3,
                               1.4,
                               0.2);
                check_equal(maxArray(RealArr4_v), 1.4, "maxArray(RealArr4_v)");

            elsif run("minArray-int") then
                IntArr_v := (1,
                             -3,
                             4,
                             2);
                check_equal(minArray(IntArr_v), -3, "minArray(IntArr_v)");

            elsif run("minArray-real") then
                RealArr4_v := (0.1,
                               -0.3,
                               1.4,
                               0.2);
                check_equal(minArray(RealArr4_v), -0.3, "minArray(RealArr4_v)");

            end if;
        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
