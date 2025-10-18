---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bruendler, Switzerland
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
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable IntArr_v       : IntegerArray_t(0 to 2);
        variable RealArr_v      : RealArray_t(0 to 2);
        variable BoolArr_v      : BoolArray_t(0 to 2);
        variable Stdlv_v        : std_logic_vector(0 to 2);
        variable StlvArr_v      : StlvArray_t(0 to 2)(3 downto 0);
        variable StrlvArrFlat_v : std_logic_vector(11 downto 0);
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

            elsif run("flattenStlvArray") then

                StlvArr_v := (0 => ("0000"),
                              1 => ("1111"),
                              2 => ("1010"));

                StrlvArrFlat_v := flattenStlvArray(StlvArr_v);
                check_equal(StrlvArrFlat_v(3 downto 0), 2#0000#, "flattenStlvArray->0");
                check_equal(StrlvArrFlat_v(7 downto 4), 2#1111#, "flattenStlvArray->1");
                check_equal(StrlvArrFlat_v(11 downto 8), 2#1010#, "flattenStlvArray->2");

            elsif run("unflattenStlvArray") then
                StrlvArrFlat_v := "000011110101";
                StlvArr_v      := unflattenStlvArray(StrlvArrFlat_v, 4);
                check_equal(StlvArr_v(2), 2#0000#, "unflattenStlvArray->2");
                check_equal(StlvArr_v(1), 2#1111#, "unflattenStlvArray->1");
                check_equal(StlvArr_v(0), 2#0101#, "unflattenStlvArray->0");
            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
