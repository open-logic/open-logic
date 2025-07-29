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

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

library work;
    use work.fix_formats_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity controller_tb is
end entity;

architecture sim of controller_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c   : real     := 100.0e6; -- 100 MHz
    constant Clk_Period_c      : time     := (1 sec) / Clk_Frequency_c;
    constant SampleFrequency_c : real     := 1.0e6; -- 1 MHz
    constant SamplePeriod_c    : time     := (1 sec) / SampleFrequency_c;
    constant CyclesPerSample_c : positive := integer(Clk_Frequency_c / SampleFrequency_c);

    signal TbRunning : boolean := true;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk        : std_logic := '0';
    signal Rst        : std_logic := '1';
    signal Cfg_Ki     : std_logic_vector(cl_fix_width(FmtKi_c) - 1 downto 0);
    signal Cfg_Kp     : std_logic_vector(cl_fix_width(FmtKp_c) - 1 downto 0);
    signal Cfg_Ilim   : std_logic_vector(cl_fix_width(FmtIlim_c) - 1 downto 0);
    signal In_Valid   : std_logic;
    signal In_Actual  : std_logic_vector(cl_fix_width(FmtIn_c) - 1 downto 0);
    signal In_Target  : std_logic_vector(cl_fix_width(FmtIn_c) - 1 downto 0);
    signal Out_Valid  : std_logic;
    signal Out_Result : std_logic_vector(cl_fix_width(FmtOut_c) - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- TB Defnitions
    -----------------------------------------------------------------------------------------------

    -- *** Constants ***
    constant InFileTarget_c : string := "InputTarget.fix";
    constant InFileActual_c : string := "InputActual.fix";
    constant OutFile_c      : string := "Output.fix";

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    p_control : process is
    begin
        -- Apply Configuration
        Cfg_Kp   <= cl_fix_from_real(20.0, FmtKp_c);
        Cfg_Ki   <= cl_fix_from_real(0.4, FmtKi_c);
        Cfg_Ilim <= cl_fix_from_real(3.5, FmtIlim_c);

        -- Reset
        wait until rising_edge(Clk);
        Rst <= '1';
        wait for 1 us;
        wait until rising_edge(Clk);
        Rst <= '0';
        wait until rising_edge(Clk);

        -- Wait until simulation is finished
        while In_Valid'last_event < 10*SamplePeriod_c loop
            wait for 100*SamplePeriod_c;
        end loop;

        TbRunning <= false;
        wait;

    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5*Clk_Period_c when TbRunning else '0';

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity work.olo_fix_tutorial_controller
        port map (
            Clk         => Clk,
            Rst         => Rst,
            Cfg_Ki      => Cfg_Ki,
            Cfg_Kp      => Cfg_Kp,
            Cfg_Ilim    => Cfg_Ilim,
            In_Valid    => In_Valid,
            In_Actual   => In_Actual,
            In_Target   => In_Target,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli_target : entity olo.olo_fix_sim_stimuli
        generic map (
            FilePath_g         => InFileTarget_c,
            Fmt_g              => to_string(FmtIn_c),
            StallProbability_g => 1.0, -- Always stall to create the desired sample rate
            StallMaxCycles_g   => CyclesPerSample_c-1,
            StallMinCycles_g   => CyclesPerSample_c-1
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Data     => In_Target
        );

    vc_stimuli_actual : entity olo.olo_fix_sim_stimuli
        generic map (
            FilePath_g         => InFileActual_c,
            Fmt_g              => to_string(FmtIn_c),
            IsTimingMaster_g   => false
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Valid    => In_Valid,
            Ready    => In_Valid,
            Data     => In_Actual
        );

    vc_checker : entity olo.olo_fix_sim_checker
        generic map (
            FilePath_g         => OutFile_c,
            Fmt_g              => to_string(FmtOut_c)
        )
        port map (
            Clk      => Clk,
            Valid    => Out_Valid,
            Data     => Out_Result
        );

end architecture;
