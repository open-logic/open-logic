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
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
    use vunit_lib.queue_pkg.all;
    use vunit_lib.sync_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

library work;
    use work.olo_test_fix_stimuli_pkg.all;
    use work.olo_test_fix_checker_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_fix_madd_tb is
    generic (
        PreAdd_g      : boolean := false;
        Operation_g   : string  := "Add";
        MultRegs_g    : natural := 1;
        InBIsCoef_g   : boolean := false;
        runner_cfg    : string
    );
end entity;

architecture sim of olo_fix_madd_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6; -- 100 MHz
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    constant AFmt_c        : FixFormat_t := (1, 7, 0);
    constant CFmt_c        : FixFormat_t := (1, 8, 0);
    constant BFmt_c        : FixFormat_t := (1, 6, 0);
    constant AddChainFmt_c : FixFormat_t := (1, 24, 0);

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic                                                  := '0';
    signal Rst        : std_logic                                                  := '0';
    signal InA_Data   : std_logic_vector(cl_fix_width(AFmt_c) - 1 downto 0)        := (others => '0');
    signal InB_Data   : std_logic_vector(cl_fix_width(BFmt_c) - 1 downto 0)        := (others => '0');
    signal InC_Data   : std_logic_vector(cl_fix_width(CFmt_c) - 1 downto 0)        := (others => '0');
    signal MaccIn     : std_logic_vector(cl_fix_width(AddChainFmt_c) - 1 downto 0) := (others => '0');
    signal InAC_Valid : std_logic                                                  := '0';
    signal InB_Valid  : std_logic                                                  := '0';
    signal Out_Valid  : std_logic;
    signal Out_Data   : std_logic_vector(cl_fix_width(AddChainFmt_c) - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable A_v, B_v, C_v, Macc_v, Result_v, AC_v       : real;
        variable A2_v, B2_v, C2_v, Macc2_v, Result2_v, AC2_v : real;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';

            -- *** Reset State ***
            if run("ResetState") then
                check_equal(Out_Valid, '0', "Out_Valid should be '0' after reset");
                check_equal(Out_Data, 0, "Out_Data should be '0' after reset");
            end if;

            -- *** Spaced Samples ***
            if run("SpacedSamples") then

                for i in 0 to 1 loop
                    -- Calculate Testcase
                    A_v    := 1.0 + real(i*10);
                    B_v    := 2.0 + real(i*10);
                    C_v    := 3.0 + real(i*10);
                    Macc_v := 4.0;
                    if PreAdd_g then
                        AC_v := A_v + C_v;
                    else
                        AC_v := A_v;
                    end if;
                    if Operation_g = "Add" then
                        Result_v := Macc_v + AC_v * B_v;
                    else
                        Result_v := Macc_v - AC_v * B_v;
                    end if;

                    -- Execute
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    InA_Data   <= cl_fix_from_real(A_v, AFmt_c);
                    InB_Data   <= cl_fix_from_real(B_v, BFmt_c);
                    InC_Data   <= cl_fix_from_real(C_v, CFmt_c);
                    MaccIn     <= (others => 'X');
                    InAC_Valid <= '1';
                    InB_Valid  <= '1';
                    -- In reg
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    InAC_Valid <= '0';
                    InB_Valid  <= '0';
                    InA_Data   <= (others => 'X');
                    InB_Data   <= (others => 'X');
                    InC_Data   <= (others => 'X');
                    -- adder
                    if PreAdd_g then
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    end if;
                    -- Mult Regs

                    for i in 0 to MultRegs_g - 1 loop
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    end loop;

                    MaccIn <= cl_fix_from_real(Macc_v, AddChainFmt_c);
                    -- Output Reg
                    wait until falling_edge(Clk);
                    MaccIn <= (others => 'X');
                    check_equal(Out_Valid, '1', "Out_Valid should be '1' for valid output sample");
                    check_equal(Out_Data, cl_fix_from_real(Result_v, AddChainFmt_c), "Output data mismatch");
                    -- Wait a bit
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    wait until falling_edge(Clk);
                    wait until falling_edge(Clk);
                end loop;

            end if;

            -- *** Back to back samples ***
            if run("BackToBackSamples") then
                -- Calculate Testcase 0
                A_v    := 1.0;
                B_v    := 2.0;
                C_v    := 3.0;
                Macc_v := 4.0;
                if PreAdd_g then
                    AC_v := A_v + C_v;
                else
                    AC_v := A_v;
                end if;
                if Operation_g = "Add" then
                    Result_v := Macc_v + AC_v * B_v;
                else
                    Result_v := Macc_v - AC_v * B_v;
                end if;

                -- Calculate Testcase 1
                A2_v    := 11.0;
                B2_v    := 12.0;
                C2_v    := 13.0;
                Macc2_v := 14.0;
                if PreAdd_g then
                    AC2_v := A2_v + C2_v;
                else
                    AC2_v := A2_v;
                end if;
                if Operation_g = "Add" then
                    Result2_v := Macc2_v + AC2_v * B2_v;
                else
                    Result2_v := Macc2_v - AC2_v * B2_v;
                end if;

                -- Execute / -
                wait until falling_edge(Clk);
                check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                InA_Data   <= cl_fix_from_real(A_v, AFmt_c);
                InB_Data   <= cl_fix_from_real(B_v, BFmt_c);
                InC_Data   <= cl_fix_from_real(C_v, CFmt_c);
                MaccIn     <= (others => 'X');
                InAC_Valid <= '1';
                InB_Valid  <= '1';

                -- In reg
                wait until falling_edge(Clk);
                InA_Data <= cl_fix_from_real(A2_v, AFmt_c);
                InB_Data <= cl_fix_from_real(B2_v, BFmt_c);
                InC_Data <= cl_fix_from_real(C2_v, CFmt_c);
                check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                -- adder
                if PreAdd_g then
                    wait until falling_edge(Clk);
                    InAC_Valid <= '0';
                    InB_Valid  <= '0';
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                end if;
                -- Mult Regs

                for i in 0 to MultRegs_g - 1 loop
                    wait until falling_edge(Clk);
                    InAC_Valid <= '0';
                    InB_Valid  <= '0';
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                end loop;

                MaccIn <= cl_fix_from_real(Macc_v, AddChainFmt_c);
                -- Output Reg 0
                wait until falling_edge(Clk);
                MaccIn <= cl_fix_from_real(Macc2_v, AddChainFmt_c);
                check_equal(Out_Valid, '1', "Out_Valid should be '1' for valid output sample");
                check_equal(Out_Data, cl_fix_from_real(Result_v, AddChainFmt_c), "Output data mismatch");
                -- Output Reg 1
                wait until falling_edge(Clk);
                MaccIn <= (others => 'X');
                check_equal(Out_Valid, '1', "Out_Valid should be '1' for valid output sample");
                check_equal(Out_Data, cl_fix_from_real(Result2_v, AddChainFmt_c), "Output data mismatch");
                -- Wait a bit
                wait until falling_edge(Clk);
                check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                wait until falling_edge(Clk);
                wait until falling_edge(Clk);
            end if;

            -- *** Coef Latching ***
            if run("CoefLatching") then
                -- Skip case if coefficient is not static
                if InBIsCoef_g then
                    -- Calculate Testcase
                    A_v    := 1.0;
                    B_v    := 2.0;
                    C_v    := 3.0;
                    Macc_v := 4.0;
                    if PreAdd_g then
                        AC_v := A_v + C_v;
                    else
                        AC_v := A_v;
                    end if;
                    if Operation_g = "Add" then
                        Result_v := Macc_v + AC_v * B_v;
                    else
                        Result_v := Macc_v - AC_v * B_v;
                    end if;

                    -- Latch coefficient and check not output valid
                    wait until falling_edge(Clk);
                    InB_Data  <= cl_fix_from_real(B_v, BFmt_c);
                    InB_Valid <= '1';
                    wait until falling_edge(Clk);
                    InB_Valid <= '0';
                    InB_Data  <= (others => 'X');

                    for i in 0 to 10 loop
                        check_equal(Out_Valid, '0', "Unexpected Out_Valid while latching coefficient");
                        wait until falling_edge(Clk);
                    end loop;

                    -- Execute
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    InA_Data   <= cl_fix_from_real(A_v, AFmt_c);
                    InC_Data   <= cl_fix_from_real(C_v, CFmt_c);
                    MaccIn     <= cl_fix_from_real(Macc_v, AddChainFmt_c);
                    InAC_Valid <= '1';
                    -- In reg
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    InAC_Valid <= '0';
                    InA_Data   <= (others => 'X');
                    InC_Data   <= (others => 'X');
                    -- adder
                    if PreAdd_g then
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    end if;
                    -- Mult Regs

                    for i in 0 to MultRegs_g - 1 loop
                        wait until falling_edge(Clk);
                        check_equal(Out_Valid, '0', "Unexpected Out_Valid");
                    end loop;

                    -- Output Reg
                    wait until falling_edge(Clk);
                    check_equal(Out_Valid, '1', "Out_Valid should be '1' for valid output sample");
                    check_equal(Out_Data, cl_fix_from_real(Result_v, AddChainFmt_c), "Output data mismatch");
                end if;
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
    i_dut : entity olo.olo_fix_madd
        generic map (
            PreAdd_g      => PreAdd_g,
            Operation_g   => Operation_g,
            InBIsCoef_g   => InBIsCoef_g,
            AFmt_g        => to_string(AFmt_c),
            BFmt_g        => to_string(BFmt_c),
            CFmt_g        => to_string(CFmt_c),
            AddChainFmt_g => to_string(AddChainFmt_c),
            MultRegs_g    => MultRegs_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            InA_Data    => InA_Data,
            InB_Data    => InB_Data,
            InC_Data    => InC_Data,
            InAC_Valid  => InAC_Valid,
            InB_Valid   => InB_Valid,
            MaccIn      => MaccIn,
            Out_Valid   => Out_Valid,
            Out_Data    => Out_Data
        );

end architecture;
