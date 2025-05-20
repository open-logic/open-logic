---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
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

library work;
    use work.fix_formats_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;
    use olo.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_tutorial_controller is
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Config
        Cfg_Ki      : in    std_logic_vector(cl_fix_width(FmtKi_c) - 1 downto 0);
        Cfg_Kp      : in    std_logic_vector(cl_fix_width(FmtKp_c) - 1 downto 0);
        Cfg_Ilim    : in    std_logic_vector(cl_fix_width(FmtIlim_c) - 1 downto 0);
        -- Input
        In_Valid    : in    std_logic;
        In_Actual   : in    std_logic_vector(cl_fix_width(FmtIn_c) - 1 downto 0);
        In_Target   : in    std_logic_vector(cl_fix_width(FmtIn_c) - 1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Result  : out   std_logic_vector(cl_fix_width(FmtOut_c) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_tutorial_controller is

    -- Static
    signal ILimNeg : std_logic_vector(cl_fix_width(FmtIlimNeg_c) - 1 downto 0);

    -- Dynamic
    signal Error            : std_logic_vector(cl_fix_width(FmtErr_c) - 1 downto 0);
    signal Error_Valid      : std_logic;
    signal Ppart            : std_logic_vector(cl_fix_width(FmtPpart_c) - 1 downto 0);
    signal Ppart_Valid      : std_logic;
    signal I1               : std_logic_vector(cl_fix_width(FmtImult_c) - 1 downto 0);
    signal I1_Valid         : std_logic;
    signal IPresat          : std_logic_vector(cl_fix_width(FmtIadd_c) - 1 downto 0);
    signal IPresat_Valid    : std_logic;
    signal ILimited         : std_logic_vector(cl_fix_width(FmtI_c) - 1 downto 0);
    signal ILimited_Valid   : std_logic;
    signal Integrator       : std_logic_vector(cl_fix_width(FmtI_c) - 1 downto 0);
    signal Integrator_Valid : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Static Calculations
    -----------------------------------------------------------------------------------------------
    i_ilim_neg : entity olo.olo_fix_neg
        generic map (
            AFmt_g      => to_string(FmtIlim_c),
            ResultFmt_g => to_string(FmtIlimNeg_c)
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_A        => Cfg_Ilim,
            Out_Result  => ILimNeg
        );

    -----------------------------------------------------------------------------------------------
    -- Dynamic Calculations
    -----------------------------------------------------------------------------------------------

    -- Error Calculation
    i_error_sub : entity olo.olo_fix_sub
        generic map (
            AFmt_g      => to_string(FmtIn_c),
            BFmt_g      => to_string(FmtIn_c),
            ResultFmt_g => to_string(FmtErr_c)
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => In_Valid,
            In_A        => In_Target,
            In_B        => In_Actual,
            Out_Valid   => Error_Valid,
            Out_Result  => Error
        );

    -- P Part
    i_p_mult : entity olo.olo_fix_mult
        generic map (
            AFmt_g      => to_string(FmtErr_c),
            BFmt_g      => to_string(FmtKp_c),
            OpRegs_g    => 8,
            ResultFmt_g => to_string(FmtPpart_c),
            Round_g     => FixRound_NonSymPos_c,
            Saturate_g  => FixSaturate_Sat_c
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Error_Valid,
            In_A        => Error,
            In_B        => Cfg_Kp,
            Out_Valid   => Ppart_Valid,
            Out_Result  => Ppart
        );

    -- I Part
    i_i_mult : entity olo.olo_fix_mult
        generic map (
            AFmt_g      => to_string(FmtErr_c),
            BFmt_g      => to_string(FmtKi_c),
            ResultFmt_g => to_string(FmtImult_c)
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => Error_Valid,
            In_A        => Error,
            In_B        => Cfg_Ki,
            Out_Valid   => I1_Valid,
            Out_Result  => I1
        );

    i_i_add : entity olo.olo_fix_add
        generic map (
            AFmt_g      => to_string(FmtI_c),
            BFmt_g      => to_string(FmtImult_c),
            ResultFmt_g => to_string(FmtIadd_c)
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => I1_Valid,
            In_A        => Integrator,
            In_B        => I1,
            Out_Valid   => IPresat_Valid,
            Out_Result  => IPresat
        );

    i_limit : entity olo.olo_fix_limit
        generic map (
            InFmt_g          => to_string(FmtIadd_c),
            LimLoFmt_g       => to_string(FmtIlimNeg_c),
            LimHiFmt_g       => to_string(FmtIlim_c),
            ResultFmt_g      => to_string(FmtI_c)
        )
        port map (
            Clk        => Clk,
            Rst        => Rst,
            In_Valid   => IPresat_Valid,
            In_Data    => IPresat,
            In_LimLo   => ILimNeg,
            In_LimHi   => Cfg_Ilim,
            Out_Valid  => ILimited_Valid,
            Out_Result => ILimited
        );

    p_feedback : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            if ILimited_Valid = '1' then
                Integrator <= ILimited;
            end if;
            Integrator_Valid <= ILimited_Valid;
            -- Reset
            if Rst = '1' then
                Integrator       <= (others => '0');
                Integrator_Valid <= '0';
            end if;
        end if;
    end process;

    -- Output Adder
    i_out_add : entity olo.olo_fix_add
        generic map (
            AFmt_g      => to_string(FmtI_c),
            BFmt_g      => to_string(FmtPpart_c),
            ResultFmt_g => to_string(FmtOut_c),
            Round_g     => FixRound_NonSymPos_c,
            Saturate_g  => FixSaturate_Sat_c
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => ILimited_Valid,
            In_A        => ILimited,
            In_B        => Ppart,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_Result
        );

end architecture;
