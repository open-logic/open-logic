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
    signal Error_1      : std_logic_vector(cl_fix_width(FmtErr_c) - 1 downto 0);
    signal Vld_1        : std_logic;
    signal Ppart_2      : std_logic_vector(cl_fix_width(FmtPpart_c) - 1 downto 0);
    signal I1_2         : std_logic_vector(cl_fix_width(FmtImult_c) - 1 downto 0);
    signal Vld_2        : std_logic;
    signal IPresat_3    : std_logic_vector(cl_fix_width(FmtIadd_c) - 1 downto 0);
    signal Ppart_3      : std_logic_vector(Ppart_2'range);
    signal Vld_3        : std_logic;
    signal Integrator_4 : std_logic_vector(cl_fix_width(FmtI_c) - 1 downto 0);
    signal Ppart_4      : std_logic_vector(Ppart_2'range);
    signal Vld_4        : std_logic;

begin

    p_calc : process (Clk) is
    begin
        if rising_edge(Clk) then

            -- Static Calculations
            ILimNeg <= cl_fix_neg(Cfg_Ilim, FmtIlim_c, FmtIlimNeg_c);

            -- Stg 1
            Error_1 <= cl_fix_sub(In_Target, FmtIn_c, In_Actual, FmtIn_c, FmtErr_c);
            Vld_1   <= In_Valid;

            -- Stg 2
            Ppart_2 <= cl_fix_mult(Error_1, FmtErr_c, Cfg_Kp, FmtKp_c, FmtPpart_c, NonSymPos_s, Sat_s);
            I1_2    <= cl_fix_mult(Error_1, FmtErr_c, Cfg_Ki, FmtKi_c, FmtImult_c);
            Vld_2   <= Vld_1;

            -- Stg 3
            IPresat_3 <= cl_fix_add(Integrator_4, FmtI_c, I1_2, FmtImult_c, FmtIadd_c);
            Ppart_3   <= Ppart_2;
            Vld_3     <= Vld_2;

            -- Stg 4
            if Vld_3 = '1' then
                if cl_fix_compare(">", IPresat_3, FmtIadd_c, Cfg_Ilim, FmtIlim_c) then
                    Integrator_4 <= cl_fix_resize(Cfg_Ilim, FmtIlim_c, FmtI_c);
                elsif cl_fix_compare("<", IPresat_3, FmtIadd_c, ILimNeg, FmtIlimNeg_c) then
                    Integrator_4 <= cl_fix_resize(ILimNeg, FmtIlimNeg_c, FmtI_c);
                else
                    Integrator_4 <= cl_fix_resize(IPresat_3, FmtIadd_c, FmtI_c);
                end if;
            end if;
            Ppart_4 <= Ppart_3;
            Vld_4   <= Vld_3;

            -- Stg 5
            Out_Result <= cl_fix_add(Integrator_4, FmtI_c, Ppart_4, FmtPpart_c, FmtOut_c, NonSymPos_s, Sat_s);
            Out_Valid  <= Vld_4;

            -- Reset
            if Rst = '1' then
                Integrator_4 <= (others => '0');
                Vld_1        <= '0';
                Vld_2        <= '0';
                Vld_3        <= '0';
                Vld_4        <= '0';
                Out_Valid    <= '0';
                Out_Result   <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
