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
    use olo.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_array_tb is
    generic (
        runner_cfg     : string
    );
end entity;

architecture sim of olo_base_pkg_array_tb is

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable IntArr_v  : IntegerArray_t(0 to 2);
        variable RealArr_v : RealArray_t(0 to 2);
        variable BoolArr_v : BoolArray_t(0 to 2);
        variable Stdlv_v   : std_logic_vector(0 to 2);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop

            if run("arrayInteger2Real") then
                IntArr_v  := (1,
                              -2,
                              3);
                RealArr_v := arrayInteger2Real(IntArr_v);
                check_equal(RealArr_v(0), 1.0, "arrayInteger2Real->0", 0.001);
                check_equal(RealArr_v(1), -2.0, "arrayInteger2Real->1", 0.001);
                check_equal(RealArr_v(2), 3.0, "arrayInteger2Real->2", 0.001);

            elsif run("arrayStdl2Bool") then
                Stdlv_v   := "011";
                BoolArr_v := arrayStdl2Bool(Stdlv_v);
                check_equal(BoolArr_v(0), false, "arrayStdl2Bool->0");
                check_equal(BoolArr_v(1), true,  "arrayStdl2Bool->1");
                check_equal(BoolArr_v(2), true,  "arrayStdl2Bool->2");

            elsif run("arrayBool2Stdl") then
                BoolArr_v := (true,
                              true,
                              false);
                Stdlv_v   := arrayBool2Stdl(BoolArr_v);
                check_equal(Stdlv_v(0), '1',  "arrayBool2Stdl->0");
                check_equal(Stdlv_v(1), '1',  "arrayBool2Stdl->1");
                check_equal(Stdlv_v(2), '0',  "arrayBool2Stdl->2");

            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
