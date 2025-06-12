---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler, Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an efficient weighted round-robin arbiter.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_arb_wrr.md
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
entity olo_base_arb_wrr is
    generic (
        GrantWidth_g  : positive;
        WeightWidth_g : positive
    );
    port (
        Clk        : in  std_logic;
        Rst        : in  std_logic;
        In_Weights : in  std_logic_vector(WeightWidth_g*GrantWidth_g-1 downto 0);
        In_Req     : in  std_logic_vector(GrantWidth_g-1 downto 0);
        Out_Grant  : out std_logic_vector(GrantWidth_g-1 downto 0);
        Out_Ready  : in  std_logic;
        Out_Valid  : out std_logic
    );
end entity;

architecture rtl of olo_base_arb_wrr is

    ----------------------------------------------------------------------------
    -- Functions
    ----------------------------------------------------------------------------
    -- Returns the index of the first high ('1') bit in the vector
    function getFirstHighBitIndex(vec : std_logic_vector) return integer is
    begin
        for i in vec'range loop
            if vec(i) = '1' then
                return i;
            end if;
        end loop;
        -- Return 0 if no high bit is found
        return 0;
    end function;

    -- Generates a mask for the input request vector.
    -- Each bit is set to '1' if the corresponding weight is non-zero; otherwise, '0'.
    -- Effectively masks out requests with zero weight.
    function generateRequestWeightsMask(
            weights      : std_logic_vector;
            weight_width : positive;
            grant_width  : positive
        ) return std_logic_vector is
        variable requestWeightsMask : std_logic_vector(grant_width-1 downto 0);
    begin
        for i in (grant_width-1) downto 0 loop
            if (unsigned(weights((i+1)*weight_width-1 downto i*weight_width)) /= 0) then
                requestWeightsMask(i) := '1';
            else
                requestWeightsMask(i) := '0';
            end if;
        end loop;

        return requestWeightsMask;
    end function;

    -- Two Process Method
    type TwoProcess_t is record
        RoundRobingMask : std_logic_vector(In_Req'range);
        WeightCnt       : unsigned(WeightWidth_g-1 downto 0);
        WeightActive    : unsigned(WeightWidth_g-1 downto 0);
        GrantIdx        : natural;
    end record;

    signal r      : TwoProcess_t;
    signal r_next : TwoProcess_t;

    -- Component connection signals
    Signal RequestWeightsMasked     : std_logic_vector(In_Req'range);
    signal RequestRoundRobingMasked : std_logic_vector(In_Req'range);
    signal GrantRoundRobingMasked   : std_logic_vector(Out_Grant'range);
    signal GrantRoundRobingUnmasked : std_logic_vector(Out_Grant'range);

begin

    -- Only generate code for non-zero sized arbiters to avoid illegal range delcarations
    g_non_zero : if GrantWidth_g > 0 generate

        -- *** Combinatorial Process ***
        p_comb : process (r, In_Req, Out_Ready, In_Weights, GrantRoundRobingMasked, GrantRoundRobingUnmasked, RequestWeightsMasked) is
            variable v       : TwoProcess_t;
            variable Grant_v : std_logic_vector(Out_Grant'range);
        begin
            -- hold variables stable
            v := r;

            -- Mask Requests with a weight of zero
            RequestWeightsMasked <= In_Req and generateRequestWeightsMask(In_Weights, WeightWidth_g, GrantWidth_g);

            -- Round Robing Logic
            RequestRoundRobingMasked <= RequestWeightsMasked and r.RoundRobingMask;

            -- Generate Grant
            if unsigned(GrantRoundRobingMasked) = 0 then
                Grant_v := GrantRoundRobingUnmasked;
            else
                Grant_v := GrantRoundRobingMasked;
            end if;

            -- Get Weight of a currently active Grant
            if (unsigned(Grant_v) /= 0) then
                v.GrantIdx     := getFirstHighBitIndex(Grant_v);
                v.WeightActive := unsigned(In_Weights((v.GrantIdx + 1) * WeightWidth_g - 1 downto v.GrantIdx * WeightWidth_g));
            else
                v.WeightActive := (others => '0');
            end if;

            -- Update RoundRobingMask
            if (unsigned(Grant_v) /= 0) and (Out_Ready = '1') then
                v.WeightCnt := r.WeightCnt + 1;

                if not (r.WeightCnt < v.WeightActive - 1) then
                    v.RoundRobingMask := '0' & ppcOr(Grant_v(Grant_v'high downto 1));
                    v.WeightCnt       := (others => '0');
                end if;
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
                    r.RoundRobingMask <= (others => '0');
                    r.WeightCnt       <= (others => '0');
                    r.GrantIdx        <= 0;
                    r.WeightActive    <= (others => '0');
                end if;
            end if;
        end process;

        -- *** Component Instantiations ***
        i_prio_masked : entity work.olo_base_arb_prio
            generic map (
                Width_g   => GrantWidth_g,
                Latency_g => 0
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Req    => RequestRoundRobingMasked,
                Out_Grant => GrantRoundRobingMasked
            );

        i_prio_unmasked : entity work.olo_base_arb_prio
            generic map (
                Width_g   => GrantWidth_g,
                Latency_g => 0
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Req    => RequestWeightsMasked,
                Out_Grant => GrantRoundRobingUnmasked
            );

    end generate;

end architecture;
