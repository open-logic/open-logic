---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler, Switzerland
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
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_to_real_tb is
    generic (
        Value_g      : string := "1.33";
        AFmt_g       : string := "(0,1,8)";
        runner_cfg   : string
    );
end entity;

architecture sim of olo_fix_to_real_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant AFmt_c         : FixFormat_t                                       := cl_fix_format_from_string(AFmt_g);
    constant ValueReal_c    : real                                              := real'value(Value_g);
    constant ValueFix_c     : std_logic_vector(cl_fix_width(AFmt_c)-1 downto 0) := cl_fix_from_real(ValueReal_c, AFmt_c, Sat_s);
    constant ValueRealRnd_c : real                                              := cl_fix_to_real(ValueFix_c, AFmt_c);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_A      : std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0) := (others => '0');
    signal Out_Value : real;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    -- TB is not very vunit-ish because it is a ported legacy TB
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- *** First Run ***
            if run("CheckValue") then
                -- check value before input
                wait for 1 ns;
                check_equal(Out_Value, 0.0, "Out_Value before");
                -- apply input
                In_A <= ValueFix_c;
                wait for 1 ns;
                -- check value after input
                check_equal(Out_Value, ValueRealRnd_c, "Out_Value after");
            end if;

            -- *** Wait until done ***
            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_to_real
        generic map (
            AFmt_g => AFmt_g
        )
        port map (
            In_A      => In_A,
            Out_Value => Out_Value
        );

end architecture;
