------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
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
    use olo.olo_base_pkg_array.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_array_tb is
    generic (
        runner_cfg     : string
    );
end entity olo_base_pkg_array_tb;

architecture sim of olo_base_pkg_array_tb is

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
        variable aint : t_ainteger(0 to 2);
        variable areal : t_areal(0 to 2);
        variable abool : t_abool(0 to 2);
        variable stdlv : std_logic_vector(0 to 2);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop
    
            if run("t_ainteger_to_t_areal") then
                aint := (1, -2, 3);
                areal := t_ainteger_to_t_areal(aint);
                check_equal(areal(0), 1.0, "t_ainteger_to_t_areal->0", 0.001);
                check_equal(areal(1), -2.0, "t_ainteger_to_t_areal->1", 0.001);
                check_equal(areal(2), 3.0, "t_ainteger_to_t_areal->2", 0.001);

            elsif run("stdlv_to_t_abool") then
                stdlv := "011";
                abool := stdlv_to_t_abool(stdlv);
                check_equal(abool(0), false, "stdlv_to_t_abool->0");
                check_equal(abool(1), true,  "stdlv_to_t_abool->1");
                check_equal(abool(2), true,  "stdlv_to_t_abool->2");

            elsif run("t_abool_to_stlv") then
                abool := (true, true, false);
                stdlv := t_abool_to_stdlv(abool);
                check_equal(stdlv(0), '1',  "t_abool_to_stlv->0");
                check_equal(stdlv(1), '1',  "t_abool_to_stlv->1");
                check_equal(stdlv(2), '0',  "t_abool_to_stlv->2");

            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
