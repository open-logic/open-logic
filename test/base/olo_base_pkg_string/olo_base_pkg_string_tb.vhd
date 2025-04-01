---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Br�ndler, Switzerland
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
    use olo.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_string_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_base_pkg_string_tb is

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Stlv16_v : std_logic_vector(15 downto 0);
        variable Stlv14_v : std_logic_vector(13 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop

            if run("toUpper") then
                check_equal(toUpper("Hello"), "HELLO", "toUpper 1");
                check_equal(toUpper("hello"), "HELLO", "toUpper 2");
                check_equal(toUpper("hElLo"), "HELLO", "toUpper 3");
                check_equal(toUpper("HELLO"), "HELLO", "toUpper 4");
                check_equal(toUpper("123 &- abCD"), "123 &- ABCD", "toUpper 5");
            end if;

            if run("toLower") then
                check_equal(toLower("Hello"), "hello", "toLower 1");
                check_equal(toLower("hello"), "hello", "toLower 2");
                check_equal(toLower("hElLo"), "hello", "toLower 3");
                check_equal(toLower("HELLO"), "hello", "toLower 4");
                check_equal(toLower("123 &- abCD"), "123 &- abcd", "toLower 5");
            end if;

            if run("trim") then
                check_equal(trim("Hello"), "Hello", "trim 1");
                check_equal(trim(" Hello"), "Hello", "trim 2");
                check_equal(trim("Hello "), "Hello", "trim 3");
                check_equal(trim(" Hello "), "Hello", "trim 4");
                check_equal(trim("  Hello  "), "Hello", "trim 5");
                check_equal(trim("  Hello  World  "), "Hello  World", "trim 6");
                check_equal(trim("    "), "", "trim 7");
            end if;

            if run("hex2StdLogicVector") then
                -- Test upsizing
                -- Test downsizing

                -- Simple Conversion
                Stlv16_v := x"1234";
                check_equal(hex2StdLogicVector("1234", 16), Stlv16_v, "hex2StdLogicVector 1");
                -- Prefix
                check_equal(hex2StdLogicVector("0x1234", 16, hasPrefix => true), Stlv16_v, "hex2StdLogicVector 2");
                -- Spaces before/after
                check_equal(hex2StdLogicVector("  1234", 16), Stlv16_v, "hex2StdLogicVector 3");
                check_equal(hex2StdLogicVector("1234  ", 16), Stlv16_v, "hex2StdLogicVector 4");
                check_equal(hex2StdLogicVector(" 1234 ", 16), Stlv16_v, "hex2StdLogicVector 5");
                check_equal(hex2StdLogicVector("  0x1234 ", 16, hasPrefix => true), Stlv16_v, "hex2StdLogicVector 6");
                check_equal(hex2StdLogicVector("0x1234  ", 16, hasPrefix => true), Stlv16_v, "hex2StdLogicVector 7");
                check_equal(hex2StdLogicVector(" 0x1234 ", 16, hasPrefix => true), Stlv16_v, "hex2StdLogicVector 8");
                -- Test upsizing/downsizing
                check_equal(hex2StdLogicVector("001234", 16), Stlv16_v, "hex2StdLogicVector 9");
                Stlv16_v := x"0034";
                check_equal(hex2StdLogicVector("34", 16), Stlv16_v, "hex2StdLogicVector 10");
                Stlv14_v := "01" & x"034";
                check_equal(hex2StdLogicVector("1034", 14), Stlv14_v, "hex2StdLogicVector 11");
                check_equal(hex2StdLogicVector("01034", 14), Stlv14_v, "hex2StdLogicVector 12");
                -- Convert empty string
                Stlv16_v := x"0000";
                check_equal(hex2StdLogicVector("", 16), Stlv16_v, "hex2StdLogicVector 13");
                -- Cover all nibble values
                Stlv16_v := x"0123";
                check_equal(hex2StdLogicVector("0123", 16), Stlv16_v, "hex2StdLogicVector 14");
                Stlv16_v := x"4567";
                check_equal(hex2StdLogicVector("4567", 16), Stlv16_v, "hex2StdLogicVector 15");
                Stlv16_v := x"89AB";
                check_equal(hex2StdLogicVector("89AB", 16), Stlv16_v, "hex2StdLogicVector 14");
                Stlv16_v := x"CDEF";
                check_equal(hex2StdLogicVector("CDEF", 16), Stlv16_v, "hex2StdLogicVector 14");
            end if;

            if run("countOccurence") then
                check_equal(countOccurence("Hello", 'l'), 2, "countOccurence 1");
                check_equal(countOccurence("Hello", 'H'), 1, "countOccurence 2");
                check_equal(countOccurence("Hello", 'f'), 0, "countOccurence 3");
            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
