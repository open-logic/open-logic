---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Switzerland
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
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_pkg_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_fix_pkg_tb is

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Format_v : FixFormat_t;
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop

            if run("fixFmtWidthFromString") then
                check_equal(fixFmtWidthFromString("(1,1,3)"), 5, "fixFmtWidthFromString(1,1,3) wrong");
                check_equal(fixFmtWidthFromString("(1,1,4)"), 6, "fixFmtWidthFromString(1,1,4) wrong");
                check_equal(fixFmtWidthFromString("(1,2,4)"), 7, "fixFmtWidthFromString(1,2,4) wrong");
                check_equal(fixFmtWidthFromString("(0,2,4)"), 6, "fixFmtWidthFromString(0,2,4) wrong");
                check_equal(fixFmtWidthFromString("(0, 2, 4)"), 6, "fixFmtWidthFromString(0, 2, 4) wrong");
                check_equal(fixFmtWidthFromString("(0 ,2 ,4)"), 6, "fixFmtWidthFromString(0 ,2 ,4) wrong");
                check_equal(fixFmtWidthFromString(" (0,2,4) "), 6, "fixFmtWidthFromString (0,2,4)  wrong");

            elsif run("fixImplementReg") then
                check_equal(fixImplementReg(false, "AUTO"), false, "fixImplementReg(false, AUTO) wrong");
                check_equal(fixImplementReg(true,  "AUTO"), true,  "fixImplementReg(true,  AUTO) wrong");
                check_equal(fixImplementReg(false, "YES"),  true,  "fixImplementReg(false, YES) wrong");
                check_equal(fixImplementReg(true,  "YES"),  true,  "fixImplementReg(true,  YES) wrong");
                check_equal(fixImplementReg(false, "NO"),   false, "fixImplementReg(false, NO) wrong");
                check_equal(fixImplementReg(true,  "NO"),   false, "fixImplementReg(true,  NO) wrong");

            elsif run("fixFmtFromStringTolerant") then
                Format_v := fixFmtFromStringTolerant("(1,1,3)");
                check_equal(Format_v.S, 1, "fixFmtFromStringTolerant(1,1,3) S wrong");
                check_equal(Format_v.I, 1, "fixFmtFromStringTolerant(1,1,3) I wrong");
                check_equal(Format_v.F, 3, "fixFmtFromStringTolerant(1,1,3) F wrong");

                Format_v := fixFmtFromStringTolerant(" (1, 1 ,3) ");
                check_equal(Format_v.S, 1, "fixFmtFromStringTolerant(1,1,3) S wrong");
                check_equal(Format_v.I, 1, "fixFmtFromStringTolerant(1,1,3) I wrong");
                check_equal(Format_v.F, 3, "fixFmtFromStringTolerant(1,1,3) F wrong");

                Format_v := fixFmtFromStringTolerant("(0,-1,3)");
                check_equal(Format_v.S, 0, "fixFmtFromStringTolerant(0,-1,3) S wrong");
                check_equal(Format_v.I, -1, "fixFmtFromStringTolerant(0,-1,3) I wrong");
                check_equal(Format_v.F, 3, "fixFmtFromStringTolerant(0,-1,3) F wrong");

                Format_v := fixFmtFromStringTolerant("NONE");
                check_equal(Format_v.S, 0, "fixFmtFromStringTolerant(NONE) S wrong");
                check_equal(Format_v.I, 0, "fixFmtFromStringTolerant(NONE) I wrong");
                check_equal(Format_v.F, 0, "fixFmtFromStringTolerant(NONE) F wrong");

                Format_v := fixFmtFromStringTolerant("(0,-1,3");
                check_equal(Format_v.S, 0, "fixFmtFromStringTolerant(0,-1,3 S wrong");
                check_equal(Format_v.I, 0, "fixFmtFromStringTolerant(0,-1,3 I wrong");
                check_equal(Format_v.F, 0, "fixFmtFromStringTolerant(0,-1,3 F wrong");

            else
                report "Test not found";

            end if;
        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
