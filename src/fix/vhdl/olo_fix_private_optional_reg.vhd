---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an optional register. It is meant for internal use only and hence not
-- documented in detail.
-- Using olo_base_pl_stage was considered but avoided because this entity contains synthesis
-- attributes that prevent retiming.
--
-- Documentation:
-- None
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
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------

entity olo_fix_private_optional_reg is
    generic (
        Width_g     : natural;
        Stages_g    : natural := 1
    );
    port (
        -- Control Ports
        Clk         : in    std_logic := '0';
        Rst         : in    std_logic := '0';
        -- Input
        In_Valid    : in    std_logic := '1';
        In_Data     : in    std_logic_vector(Width_g-1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Data    : out   std_logic_vector(Width_g-1 downto 0)
    );
end entity;

architecture rtl of olo_fix_private_optional_reg is

    -- Types
    type Data_t is array (0 to Stages_g-1) of std_logic_vector(In_Data'range);

    -- Signals
    signal Data  : Data_t;
    signal Valid : std_logic_vector(0 to Stages_g-1);

begin

    -- ** No reg **
    g_noreg : if Stages_g = 0 generate
        Out_Valid <= In_Valid;
        Out_Data  <= In_Data;
    end generate;

    -- ** Registers ***
    g_reg : if Stages_g > 0 generate

        p_reg : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- First stage
                Data(0)  <= In_Data;
                Valid(0) <= In_Valid;

                -- Other stages
                for stg in 1 to Stages_g-1 loop
                    Data(stg)  <= Data(stg-1);
                    Valid(stg) <= Valid(stg-1);
                end loop;

                -- Reset
                if Rst = '1' then
                    Valid <= (others => '0');
                end if;
            end if;
        end process;

        Out_Valid <= Valid(Stages_g-1);
        Out_Data  <= Data(Stages_g-1);
    end generate;

end architecture;
