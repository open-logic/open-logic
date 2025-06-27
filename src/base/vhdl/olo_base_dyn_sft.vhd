---------------------------------------------------------------------------------------------------
-- Copyright (c) 2020 by Oliver Bruendler
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a dynamic shift implemented in multiple stages in
-- order to achieve good timing.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_dyn_sft.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_dyn_sft is
    generic (
        Direction_g         : string;
        SelBitsPerStage_g   : positive := 4;
        MaxShift_g          : positive;
        Width_g             : positive;
        SignExtend_g        : boolean  := false
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        In_Valid    : in    std_logic := '1';
        In_Shift    : in    std_logic_vector(log2ceil(MaxShift_g+1)- 1 downto 0);
        In_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Out_Valid   : out   std_logic;
        Out_Data    : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_dyn_sft is

    -- Constants
    constant Stages_c                 : integer := integer(ceil(real(In_Shift'length) / real(SelBitsPerStage_g)));
    constant SelBitsPerStageLimited_c : integer := work.olo_base_pkg_math.min(SelBitsPerStage_g, In_Shift'length);

    -- Types
    type Data_t is array (natural range <>) of std_logic_vector(In_Data'range);
    type Shift_t is array (natural range <>) of std_logic_vector(In_Shift'range);

    -- Two Process Method
    type TwoProcess_t is record
        Vld   : std_logic_vector(0 to Stages_c);
        Data  : Data_t(0 to Stages_c);
        Shift : Shift_t(0 to Stages_c);
    end record;

    signal r, r_next : TwoProcess_t;

begin

    -- *** Assertions ***
    assert Direction_g = "LEFT" or Direction_g = "RIGHT"
        report "###ERROR###: olo_base_dyn_sft - Direction_g must be LEFT or RIGHT"
        severity error;
    assert MaxShift_g <= Width_g
        report "###ERROR###: olo_base_dyn_sft - MaxShift_g must be smaller or equal to Width_g"
        severity error;

    -- *** Cobinatorial Process ***
    p_comb : process (all) is
        variable v          : TwoProcess_t;
        variable StepSize_v : natural;
        variable Select_v   : natural range 0 to 2**SelBitsPerStage_g - 1;
        variable TempData_v : std_logic_vector(Width_g * 2 - 1 downto 0);
    begin
        -- hold variables stable
        v := r;

        -- Input stages
        v.Data(0)  := In_Data;
        v.Shift(0) := In_Shift;
        v.Vld(0)   := In_Valid;

        -- Shift stages
        for stg in 0 to Stages_c - 1 loop
            -- Stage constants calculation
            StepSize_v := 2**(stg * SelBitsPerStageLimited_c);

            -- Shift implementation
            Select_v := to_integer(unsigned(r.Shift(stg)(SelBitsPerStageLimited_c - 1 downto 0)));
            if Direction_g = "RIGHT" then
                if SignExtend_g then
                    TempData_v := (others => r.Data(stg)(Width_g - 1));
                else
                    TempData_v := (others => '0');
                end if;
                TempData_v(2 * Width_g - 1 - Select_v * StepSize_v downto Width_g - Select_v * StepSize_v) := r.Data(stg);
                v.Data(stg + 1)                                                                            := TempData_v(2 * Width_g - 1 downto Width_g);
            elsif Direction_g = "LEFT" then
                TempData_v                                                                   := (others => '0');
                TempData_v(Select_v * StepSize_v + Width_g - 1 downto Select_v * StepSize_v) := r.Data(stg);
                v.Data(stg + 1)                                                              := TempData_v(Width_g - 1 downto 0);
            -- Excluded from coverage because this line can't be reached in valid configurations
            -- coverage off
            else
                report "###ERROR###: olo_base_dyn_sft - Direction_g must be LEFT or RIGHT, is '" & Direction_g & "'" severity error;
            -- coverage on
            end if;
            v.Shift(stg + 1) := shiftRight(r.Shift(stg), SelBitsPerStageLimited_c, '0');
            v.Vld(stg + 1)   := r.Vld(stg);
        end loop;

        -- Outputs
        Out_Data  <= r.Data(Stages_c);
        Out_Valid <= r.Vld(Stages_c);

        -- Apply to record
        r_next <= v;

    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Vld <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
