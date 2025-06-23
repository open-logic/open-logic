---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an efficient round-robin arbiter.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_arb_rr.md
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
entity olo_base_arb_rr is
    generic (
        Width_g    : positive
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        In_Req      : in    std_logic_vector(Width_g-1 downto 0);
        Out_Grant   : out   std_logic_vector(Width_g-1 downto 0);
        Out_Ready   : in    std_logic;
        Out_Valid   : out   std_logic
    );
end entity;

architecture rtl of olo_base_arb_rr is

    -- Two Process Method
    type TwoProcess_t is record
        Mask : std_logic_vector(In_Req'range);
    end record;

    signal r, r_next : TwoProcess_t;

    -- Component connection signals
    signal RequestMasked : std_logic_vector(In_Req'range);
    signal GrantMasked   : std_logic_vector(Out_Grant'range);
    signal GrantUnmasked : std_logic_vector(Out_Grant'range);

begin

    -- Only generate code for non-zero sized arbiters to avoid illegal range delcarations
    g_non_zero : if Width_g > 0 generate

        -- *** Combinatorial Process ***
        p_comb : process (all) is
            variable v       : TwoProcess_t;
            variable Grant_v : std_logic_vector(Out_Grant'range);
        begin
            -- hold variables stable
            v := r;

            -- Round Robing Logic
            RequestMasked <= In_Req and r.Mask;

            -- Generate Grant
            if unsigned(GrantMasked) = 0 then
                Grant_v := GrantUnmasked;
            else
                Grant_v := GrantMasked;
            end if;

            -- Update mask
            if (unsigned(Grant_v) /= 0) and (Out_Ready = '1') then
                v.Mask := '0' & ppcOr(Grant_v(Grant_v'high downto 1));
            end if;

            -- *** Outputs ***
            if unsigned(Grant_v) /= 0 then
                Out_Valid <= '1';
            else
                Out_Valid <= '0';
            end if;

            Out_Grant <= Grant_v;

            -- Apply to record
            r_next <= v;

        end process;

        -- *** Sequential Process ***
        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.Mask <= (others => '0');
                end if;
            end if;
        end process;

        -- *** Component Instantiations ***
        i_prio_masked : entity work.olo_base_arb_prio
            generic map (
                Width_g   => Width_g,
                Latency_g => 0
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Req      => RequestMasked,
                Out_Grant   => GrantMasked
            );

        i_prio_unmasked : entity work.olo_base_arb_prio
            generic map (
                Width_g   => Width_g,
                Latency_g => 0
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Req      => In_Req,
                Out_Grant   => GrantUnmasked
            );

    end generate;

end architecture;
