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
    use olo.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_pkg_math_tb is
    generic (
        runner_cfg     : string
    );
end entity olo_base_pkg_math_tb;

architecture sim of olo_base_pkg_math_tb is

begin

    -------------------------------------------------------------------------
    -- TB Control
    -------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a package TB
    test_runner_watchdog(runner, 1 ms);
    p_control : process
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;
        -- log2
        check_equal(log2(8), 3, "log2(8) wrong");
        check_equal(log2(5), 2, "log2(5) wrong");
        check_equal(log2(2), 1, "log2(2) wrong");
        check_equal(log2(1), 0, "log2(1) wrong");

        -- log2ceil
        check_equal(log2ceil(8), 3, "log2ceil(8) wrong");
        check_equal(log2ceil(5), 3, "log2ceil(5) wrong");
        check_equal(log2ceil(2), 1, "log2ceil(2) wrong");
        check_equal(log2ceil(1), 0, "log2ceil(1) wrong");        
        
        -- islog2
        check_equal(islog2(8), true,  "islog2(8) wrong");
        check_equal(islog2(5), false, "islog2(5) wrong");
        check_equal(islog2(2), true,  "islog2(2) wrong");
        check_equal(islog2(1), true, "islog2(1) wrong");     
        
        -- max (integer)
        check_equal(max(3,4), 4,    "max(3,4) wrong"); 
        check_equal(max(4,3), 4,    "max(3,4) wrong");
        check_equal(max(-4,3), 3,   "max(3,4) wrong");
        check_equal(max(3,-4), 3,   "max(3,4) wrong");

        -- max (real)
        check_equal(max(3.0,4.0), 4.0,    "max(3.0,4.0) wrong");
        check_equal(max(4.0,3.0), 4.0,    "max(4.0,3.0) wrong");
        check_equal(max(-4.0,3.0), 3.0,   "max(-4.0,3.0)wrong");
        check_equal(max(3.0,-4.0), 3.0,   "max(3.0,-4.0) wrong");
        check_equal(max(1.2,1.3), 1.3,    "max(1.2,1.3) wrong");

        -- min (integer)
        check_equal(olo.olo_base_pkg_math.min(3,4), 3,    "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(4,3), 3,    "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(-4,3), -4,  "min(3,4) wrong");
        check_equal(olo.olo_base_pkg_math.min(3,-4), -4,  "min(3,4) wrong");

        -- min (real)
        check_equal(olo.olo_base_pkg_math.min(3.0,4.0), 3.0,    "min(3.0,4.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(4.0,3.0), 3.0,    "min(4.0,3.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(-4.0,3.0), -4.0,  "min(-4.0,3.0)wrong");
        check_equal(olo.olo_base_pkg_math.min(3.0,-4.0), -4.0,  "min(3.0,-4.0) wrong");
        check_equal(olo.olo_base_pkg_math.min(1.2,1.3), 1.2,    "min(1.2,1.3) wrong");
         
        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end sim;
