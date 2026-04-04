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
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_sample_hold_tb is
    generic (
        runner_cfg      : string;
        ResetValid_g    : boolean := true
    );
end entity;

architecture sim of olo_fix_sample_hold_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant FmtStr_c     : string      := "(0,8,0)";
    constant Fmt_c        : FixFormat_t := cl_fix_format_from_string(FmtStr_c);
    constant ResetValue_c : real        := 3.0;

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                          := '0';
    signal Rst       : std_logic                                          := '0';
    signal In_Valid  : std_logic                                          := '0';
    signal In_Data   : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0) := (others => '0');
    signal Out_Valid : std_logic                                          := '0';
    signal Out_Data  : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0) := (others => '0');

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Data_v : std_logic_vector(cl_fix_width(Fmt_c) - 1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- State after Reset
            if run("Reset") then
                check_equal(Out_Data, cl_fix_from_real(ResetValue_c, Fmt_c), msg => "Out_Data after reset");
                check_equal(Out_Valid, choose(ResetValid_g, '1', '0'), msg => "Out_Valid after reset");
            end if;

            if run("ProcessSamples") then

                for i in 1 to 4 loop
                    Data_v := cl_fix_from_real(1.0 * real(i), Fmt_c);

                    wait until rising_edge(Clk);
                    wait for 100 ps;
                    In_Valid <= '1';
                    In_Data  <= Data_v;

                    wait until rising_edge(Clk);
                    wait for 100 ps;
                    In_Valid <= '0';
                    In_Data  <= (others => '0');
                    check_equal(Out_Data, Data_v, msg => "Out_Data sample " & integer'image(i));
                    check_equal(Out_Valid, '1', msg => "Out_Valid sample " & integer'image(i));
                end loop;

            end if;

            if run("BackToBack") then
                wait until rising_edge(Clk);
                wait for 100 ps;
                In_Valid <= '1';
                In_Data  <= cl_fix_from_real(1.0, Fmt_c);

                wait until rising_edge(Clk);
                wait for 100 ps;
                In_Data <= cl_fix_from_real(2.0, Fmt_c);
                check_equal(Out_Data, cl_fix_from_real(1.0, Fmt_c), msg => "Out_Data 0");
                check_equal(Out_Valid, '1', msg => "Out_Valid 0");

                wait until rising_edge(Clk);
                wait for 100 ps;
                In_Data <= cl_fix_from_real(3.0, Fmt_c);
                check_equal(Out_Data, cl_fix_from_real(2.0, Fmt_c), msg => "Out_Data 1");
                check_equal(Out_Valid, '1', msg => "Out_Valid 1");

                wait until rising_edge(Clk);
                wait for 100 ps;
                In_Valid <= '0';
                In_Data  <= (others => '0');
                check_equal(Out_Data, cl_fix_from_real(3.0, Fmt_c), msg => "Out_Data 2");
                check_equal(Out_Valid, '1', msg => "Out_Valid 2");

                wait until rising_edge(Clk);
                wait for 100 ps;
                check_equal(Out_Data, cl_fix_from_real(3.0, Fmt_c), msg => "Out_Data 3");
                check_equal(Out_Valid, '1', msg => "Out_Valid 3");
            end if;

            wait for 1 us;

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_fix_sample_hold
        generic map (
            Fmt_g         => FmtStr_c,
            ResetValue_g  => ResetValue_c,
            ResetValid_g  => ResetValid_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_Data     => In_Data,
            Out_Valid   => Out_Valid,
            Out_Data    => Out_Data
        );

end architecture;
