---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025-2026 by Oliver Bruendler, Switzerland
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library std;
    use std.textio.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;
    use olo.olo_base_pkg_array.all;

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

    constant DataDir_c : string := output_path(runner_cfg);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Format_v  : FixFormat_t;
        constant Fmt108_c  : FixFormat_t := (1, 0, 8);
        constant Fmt018_c  : FixFormat_t := (0, 1, 8);
        constant Fmt1015_c : FixFormat_t := (1, 0, 15);
        constant Fmt015_c  : FixFormat_t := (0, 1, 5);

        -- File reading tests
        file File_v : text;

        variable RealArr_v : RealArray_t(0 to 1);
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

            elsif run("fixFmtWidthFromStringTolerant") then
                check_equal(fixFmtWidthFromStringTolerant("(1,2,4)"), 7, "fixFmtWidthFromString(1,2,4) wrong");
                check_equal(fixFmtWidthFromStringTolerant("No-Fmt"), 1, "fixFmtWidthFromStringTolerant(No-Fmt) wrong");

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
                check_equal(Format_v.I, 1, "fixFmtFromStringTolerant(NONE) I wrong");
                check_equal(Format_v.F, 0, "fixFmtFromStringTolerant(NONE) F wrong");

                Format_v := fixFmtFromStringTolerant("(0,-1,3");
                check_equal(Format_v.S, 0, "fixFmtFromStringTolerant(0,-1,3 S wrong");
                check_equal(Format_v.I, 1, "fixFmtFromStringTolerant(0,-1,3 I wrong");
                check_equal(Format_v.F, 0, "fixFmtFromStringTolerant(0,-1,3 F wrong");

            elsif run("fixDynShift") then
                -- Shift tests
                check_equal(fixDynShift("000010000", Fmt108_c, 1, -8, 8, Fmt108_c), 2#000100000#, "fixDynShift shift 1 wrong");
                check_equal(fixDynShift("000010000", Fmt108_c, -1, -8, 8, Fmt108_c), 2#000001000#, "fixDynShift shift -1 wrong");
                check_equal(fixDynShift("000010000", Fmt108_c, 2, -8, 8, Fmt108_c), 2#001000000#, "fixDynShift shift 2 wrong");
                check_equal(fixDynShift("000010000", Fmt108_c, -2, -8, 8, Fmt108_c), 2#000000100#, "fixDynShift shift -2 wrong");
                -- Saturation tests
                check_equal(fixDynShift("000010000", Fmt108_c, 4, -8, 8, Fmt108_c, Trunc_s, Sat_s), 2#011111111#, "fixDynShift sat1 wrong");
                check_equal(fixDynShift("000010000", Fmt108_c, 4, -8, 8, Fmt108_c, Trunc_s, None_s), 2#100000000#, "fixDynShift sat2 wrong");
                check_equal(fixDynShift("000010000", Fmt018_c, 4, -8, 8, Fmt018_c, Trunc_s, Sat_s), 2#100000000#, "fixDynShift sat3 wrong");
                check_equal(fixDynShift("000010000", Fmt018_c, 5, -8, 8, Fmt018_c, Trunc_s, None_s), 2#000000000#, "fixDynShift sat4 wrong");
                -- Rounding tests
                check_equal(fixDynShift("000010000", Fmt108_c, -5, -8, 8, Fmt108_c, Trunc_s), 2#000000000#, "fixDynShift rnd1 wrong");
                check_equal(fixDynShift("000010000", Fmt108_c, -5, -8, 8, Fmt108_c, NonSymPos_s), 2#000000001#, "fixDynShift rnd2 wrong");
                -- Sign extension tests
                check_equal(fixDynShift("100000000", Fmt108_c, -2, -8, 8, Fmt108_c), 2#111000000#, "fixDynShift Sign1 wrong");
                check_equal(fixDynShift("100000000", Fmt018_c, -2, -8, 0, Fmt018_c), 2#001000000#, "fixDynShift Sign2 wrong");
                check_equal(fixDynShift("010000000", Fmt108_c, -2, -8, 8, Fmt108_c), 2#000100000#, "fixDynShift Sign3 wrong");
                check_equal(fixDynShift("010000000", Fmt018_c, -2, -8, 0, Fmt018_c), 2#000100000#, "fixDynShift Sign4 wrong");

            elsif run("fixFileCheckHeader") then
                -- Header matching the expected format must pass without error
                file_open(File_v, DataDir_c & "data_1_0_15.fix", read_mode);
                fixFileCheckHeader(File_v, Fmt1015_c);
                -- After the header is consumed, the first sample can be read
                check_equal(fixFileReadSample(File_v, Fmt1015_c), cl_fix_from_real(0.75, Fmt1015_c), "fixFileCheckHeader - sample after header wrong");
                file_close(File_v);

            elsif run("fixFileReadSample") then
                -- Format width is a multiple of 4 (16 bit -> 4 hex digits)
                file_open(File_v, DataDir_c & "data_1_0_15.fix", read_mode);
                fixFileCheckHeader(File_v, Fmt1015_c);
                check_equal(fixFileReadSample(File_v, Fmt1015_c), cl_fix_from_real(0.75, Fmt1015_c), "fixFileReadSample sample 0 wrong");
                check_equal(fixFileReadSample(File_v, Fmt1015_c), cl_fix_from_real(-1.0, Fmt1015_c), "fixFileReadSample sample 1 wrong");
                file_close(File_v);

                -- Format width is not a multiple of 4 (6 bit format -> 2 hex digits -> 6 bit result)
                file_open(File_v, DataDir_c & "data_0_1_5.fix", read_mode);
                fixFileCheckHeader(File_v, Fmt015_c);
                check_equal(fixFileReadSample(File_v, Fmt015_c), cl_fix_from_real(0.5, Fmt015_c), "fixFileReadSample 6-bit sample 0 wrong");
                check_equal(fixFileReadSample(File_v, Fmt015_c), cl_fix_from_real(1.5, Fmt015_c), "fixFileReadSample 6-bit sample 1 wrong");
                file_close(File_v);

            elsif run("fixFileReadReal") then
                RealArr_v := fixFileReadReal(DataDir_c & "data_1_0_15.fix", Fmt1015_c);
                check_equal(RealArr_v'length, 2, "fixFileReadReal length wrong");
                check_equal(RealArr_v(0), 0.75, "fixFileReadReal value 0 wrong");
                check_equal(RealArr_v(1), -1.0, "fixFileReadReal value 1 wrong");

            elsif run("fixFileReadString") then
                -- Different simulators convert real to string differently. The options encountered are covered here.
                if fixFileReadString(DataDir_c & "data_1_0_15.fix", Fmt1015_c) /= "7.5e-1, -1.0" and
                   fixFileReadString(DataDir_c & "data_1_0_15.fix", Fmt1015_c) /= "0.75, -1.0" and
                   fixFileReadString(DataDir_c & "data_1_0_15.fix", Fmt1015_c) /= "0.75, -1" then
                    failure("fixFileReadString wrong: " & fixFileReadString(DataDir_c & "data_1_0_15.fix", Fmt1015_c));
                end if;
            else
                report "Test not found";

            end if;
        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
