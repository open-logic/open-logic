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
entity olo_fix_from_real_tb is
    generic (
        Value_g      : string := "1.33";
        ResultFmt_g  : string := "(0,1,8)";
        Saturate_g   : string := "Sat_s";
        runner_cfg   : string
    );
end entity;

architecture sim of olo_fix_from_real_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant ResultFmt_c : FixFormat_t                                            := cl_fix_format_from_string(ResultFmt_g);
    constant Saturate_c  : FixSaturate_t                                          := cl_fix_saturate_from_string(Saturate_g);
    constant ValueReal_c : real                                                   := real'value(Value_g);
    constant ValueFix_c  : std_logic_vector(cl_fix_width(ResultFmt_c)-1 downto 0) := cl_fix_from_real(ValueReal_c, ResultFmt_c, Saturate_c);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal In_Value         : real := 0.0;
    signal Out_ValuePort    : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
    signal Out_ValueGeneric : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);
    signal Out_ValueSynth   : std_logic_vector(fixFmtWidthFromString(ResultFmt_g) - 1 downto 0);

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
                check_equal(Out_ValuePort, 0, "Out_ValuePort before");
                -- apply input
                In_Value <= ValueReal_c;
                wait for 1 ns;
                -- check value after input
                check_equal(Out_ValuePort, ValueFix_c, "Out_ValuePort after");
                check_equal(Out_ValueGeneric, ValueFix_c, "Out_ValueGeneric after");
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
    i_dut_port : entity olo.olo_fix_sim_from_real
        generic map (
            ResultFmt_g => ResultFmt_g,
            Saturate_g  => Saturate_g
        )
        port map (
            In_Value  => In_Value,
            Out_Value => Out_ValuePort
        );

    i_dut_generic : entity olo.olo_fix_sim_from_real
        generic map (
            ResultFmt_g => ResultFmt_g,
            Saturate_g  => Saturate_g,
            Value_g     => real'VALUE(Value_g)
        )
        port map (
            Out_Value => Out_ValueGeneric
        );

    i_dut_synth : entity olo.olo_fix_from_real
        generic map (
            ResultFmt_g => ResultFmt_g,
            Saturate_g  => Saturate_g,
            Value_g     => real'VALUE(Value_g)
        )
        port map (
            Out_Value => Out_ValueSynth
        );

end architecture;
