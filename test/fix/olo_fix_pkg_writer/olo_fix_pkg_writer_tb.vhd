---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler, Switzerland
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

library olo_tb;
    use olo_tb.pkg_writer_test_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_pkg_writer_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_fix_pkg_writer_tb is

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

            -- Code is generated through <root>/sim/codegen.py, which is executed before VUnit detects files.
            -- The tests here check the generated code.

            if run("nativeConstants") then
                check_equal(ConstInt_c, 42, "constInt wrong");
                check_equal(ConstFloat_c, 3.14, "constFloat wrong");
                check_equal(ConstString_c, "Hello", "constString wrong");

                -- Fix Format Variable Assignment triggers false positives
                -- vsg_off
                Format_v := (1, 8, 8);
                -- vsg_on
                check_equal(ConstFixFormat_c.S, Format_v.S, "constFixFormat S wrong");
                check_equal(ConstFixFormat_c.I, Format_v.I, "constFixFormat I wrong");
                check_equal(ConstFixFormat_c.F, Format_v.F, "constFixFormat F wrong");

            elsif run("nativeVectors") then
                check_equal(VectorInt_c'length, 3, "vectorInt length wrong");
                check_equal(VectorInt_c(0), 1, "vectorInt(0) wrong");
                check_equal(VectorInt_c(1), 2, "vectorInt(1) wrong");
                check_equal(VectorInt_c(2), 3, "vectorInt(2) wrong");

                check_equal(VectorFloat_c'length, 3, "vectorFloat length wrong");
                check_equal(VectorFloat_c(0), 1.0, "vectorFloat(0) wrong");
                check_equal(VectorFloat_c(1), 2.0, "vectorFloat(1) wrong");
                check_equal(VectorFloat_c(2), 3.0, "vectorFloat(2) wrong");

                check_equal(VectorFixFormat_c'length, 2, "vectorFixFormat length wrong");
                -- Fix Format Variable Assignment triggers false positives
                -- vsg_off
                Format_v := (1, 8, 8);
                -- vsg_on
                check_equal(VectorFixFormat_c(0).S, Format_v.S, "vectorFixFormat(0) S wrong");
                check_equal(VectorFixFormat_c(0).I, Format_v.I, "vectorFixFormat(0) I wrong");
                check_equal(VectorFixFormat_c(0).F, Format_v.F, "vectorFixFormat(0) F wrong");
                -- Fix Format Variable Assignment triggers false positives
                -- vsg_off
                Format_v := (1, 16, 16);
                -- vsg_on
                check_equal(VectorFixFormat_c(1).S, Format_v.S, "vectorFixFormat(1) S wrong");
                check_equal(VectorFixFormat_c(1).I, Format_v.I, "vectorFixFormat(1) I wrong");
                check_equal(VectorFixFormat_c(1).F, Format_v.F, "vectorFixFormat(1) F wrong");

            elsif run("stringConstants") then
                check_equal(ConstIntAsString_c, "42", "constIntAsString wrong");
                check_equal(ConstFloatAsString_c, "3.14", "constFloatAsString wrong");
                check_equal(ConstFixFormatAsString_c, "(1, 8, 8)", "constFixFormatAsString wrong");

            elsif run("stringVectors") then
                check_equal(VectorIntAsString_c, "1, 2, 3", "vectorIntAsString wrong");
                check_equal(VectorFloatAsString_c, "1.0, 2.0, 3.0", "vectorFloatAsString wrong");
                check_equal(VectorFixFormatAsString_c, "(1, 8, 8), (1, 16, 16)", "vectorFixFormatAsString wrong");

            else
                report "Test not found";

            end if;
        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
