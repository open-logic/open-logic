---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an efficient priority arbiter. The highest index of
-- the input has priority.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_arb_prio.md
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
entity olo_base_arb_prio is
    generic (
        Width_g    : positive;
        Latency_g  : natural := 1
    );
    port (
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        In_Req     : in    std_logic_vector(Width_g-1 downto 0);
        Out_Grant  : out   std_logic_vector(Width_g-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_arb_prio is

    -- Types
    type Data_t is array (natural range<>) of std_logic_vector(Out_Grant'range);

    -- Signals
    signal Grant_I : std_logic_vector(Out_Grant'range);
    signal RdPipe  : Data_t(1 to Latency_g);

begin

    -- Only generate code for non-zero sized arbiters to avoid illegal range delcarations
    g_non_zero : if Width_g > 0 generate

        p_comb : process (all) is
            variable OredRequest_v : std_logic_vector(In_Req'range);
        begin
            -- Or request vector
            OredRequest_v := ppcOr(In_Req);

            -- Calculate Grant with Edge Detection
            Grant_I <= OredRequest_v and not ('0' & OredRequest_v(OredRequest_v'high downto 1));
        end process;

        -- Registered Output
        g_reg : if Latency_g > 0 generate

            p_outreg : process (Clk) is
            begin
                if rising_edge(Clk) then
                    if Rst = '1' then
                        RdPipe <= (others => (others => '0'));
                    else
                        RdPipe(1)              <= Grant_I;
                        RdPipe(2 to Latency_g) <= RdPipe(1 to Latency_g-1);
                    end if;
                end if;
            end process;

            Out_Grant <= RdPipe(Latency_g);
        end generate;

        -- Combinatorial Output
        g_nreg : if Latency_g = 0 generate
            Out_Grant <= Grant_I;
        end generate;

    end generate;

end architecture;
