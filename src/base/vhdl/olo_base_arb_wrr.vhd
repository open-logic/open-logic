---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bruendler
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

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_arb_wrr is
    generic (
        GrantWidth_g  : positive;
        WeightWidth_g : positive;
        Latency_g     : natural range 0 to 1
    );
    port (
        Clk        : in    std_logic;
        Rst        : in    std_logic;
        In_Weights : in    std_logic_vector(WeightWidth_g*GrantWidth_g-1 downto 0);
        In_Req     : in    std_logic_vector(GrantWidth_g-1 downto 0);
        Out_Grant  : out   std_logic_vector(GrantWidth_g-1 downto 0);
        Out_Ready  : in    std_logic;
        Out_Valid  : out   std_logic
    );
end entity;

architecture rtl of olo_base_arb_wrr is

    -- Functions
    -- Generates a mask for the input request vector.
    -- Each bit is set to '1' if the corresponding weight is non-zero; otherwise, '0'.
    -- Effectively masks out requests with zero weight.
    function generateRequestWeightsMask (
        Weights     : std_logic_vector;
        WeightWidth : positive;
        GrantWidth  : positive) return std_logic_vector is
        -- Variables
        variable RequestWeightsMask_v : std_logic_vector(GrantWidth-1 downto 0);
    begin

        for i in (GrantWidth-1) downto 0 loop
            if (unsigned(Weights((i+1)*WeightWidth-1 downto i*WeightWidth)) /= 0) then
                RequestWeightsMask_v(i) := '1';
            else
                RequestWeightsMask_v(i) := '0';
            end if;
        end loop;

        return RequestWeightsMask_v;
    end function;

    -- state record
    type State_t is (GetRrGrant_s, SendGrant_s);

    type TwoProcess_t is record
        -- Round Robin
        RrGrantReady : std_logic;
        -- Weighted Round Robin Grant Interface
        Grant        : std_logic_vector(Out_Grant'range);
        GrantValid   : std_logic;
        -- Support signals
        Weight       : unsigned(WeightWidth_g - 1 downto 0);
        WeightCnt    : unsigned(WeightWidth_g - 1 downto 0);
        --
        State        : State_t;
    end record;

    signal r      : TwoProcess_t;
    signal r_next : TwoProcess_t;

    -- Component connection signals
    signal ReqMasked    : std_logic_vector(In_Req'range);
    signal RrGrant      : std_logic_vector(Out_Grant'range);
    signal RrGrantValid : std_logic;
    signal RrGrantReady : std_logic;

begin

    -- Mask Requests with a weight of zero
    ReqMasked <= In_Req and generateRequestWeightsMask(In_Weights, WeightWidth_g, GrantWidth_g);

    -- *** Component Instantiations ***
    i_arb_rr : entity work.olo_base_arb_rr
        generic map (
            Width_g => GrantWidth_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Req    => ReqMasked,
            Out_Valid => RrGrantValid,
            Out_Ready => RrGrantReady,
            Out_Grant => RrGrant
        );

    -- *** Combinatorial Process ***

    g_latency : if (Latency_g /= 0) generate

        p_comb : process (all) is
            variable v          : TwoProcess_t;
            variable GrantIdx_v : integer := GrantWidth_g - 1;
        begin

            -- hold variables stable
            v := r;

            -- FSM
            case r.State is
                --------------------------------------------------------------------
                when GetRrGrant_s =>
                    v.RrGrantReady := '1';

                    if (RrGrantValid = '1' and r.RrGrantReady = '1') then
                        v.RrGrantReady := '0';
                        v.Grant        := RrGrant;

                        if (unsigned(RrGrant) /= 0) then
                            GrantIdx_v := getLeadingSetBitIndex(RrGrant);
                            v.Weight   := unsigned(In_Weights((GrantIdx_v + 1) * WeightWidth_g - 1 downto GrantIdx_v * WeightWidth_g));
                            v.State    := SendGrant_s;
                        end if;
                    end if;

                --------------------------------------------------------------------
                when SendGrant_s =>
                    -- Check if grant can still be sent
                    if (ReqMasked(GrantIdx_v) = '1' and r.WeightCnt <= r.Weight - 1) then

                        v.GrantValid := '1';
                        if (r.GrantValid = '1' and Out_Ready = '1') then
                            v.WeightCnt := r.WeightCnt + 1;
                            if (r.WeightCnt >= r.Weight - 1) then
                                v.GrantValid := '0';
                            end if;

                        end if;
                    else
                        v.GrantValid := '0';
                        v.WeightCnt  := (others => '0');
                        v.State      := GetRrGrant_s;
                    end if;

                --------------------------------------------------------------------
                -- coverage off
                -- unreachable code
                when others => null;
                -- coverage on

            end case;

            -- Apply to record
            r_next <= v;
        end process;

        -- Assign outputs
        Out_Grant    <= r.Grant;
        Out_Valid    <= r.GrantValid;
        RrGrantReady <= r.RrGrantReady;

    end generate;

    g_no_latency : if (Latency_g = 0) generate

        p_comb : process (all) is
            variable v          : TwoProcess_t;
            variable GrantIdx_v : integer := GrantWidth_g - 1;
        begin
            -- hold variables stable
            v := r;

            v.RrGrantReady := '0';

            -- Get the Weight value for the currently active Grant
            if (RrGrantValid = '1') then
                GrantIdx_v := getLeadingSetBitIndex(RrGrant);
                -- Extract the corresponding weight using the GrantIdx_v
                v.Weight := unsigned(In_Weights((GrantIdx_v + 1) * WeightWidth_g - 1 downto GrantIdx_v * WeightWidth_g));
            end if;

            if (v.GrantValid = '1' and Out_Ready = '1') then
                -- Increment the weight counter on each successful AXI handshake
                v.WeightCnt := r.WeightCnt + 1;

                -- If the same grant has been used for 'Weight' handshakes,
                -- assert RrGrantReady to request the next grant and reset the counter
                if (v.WeightCnt >= v.Weight) then
                    v.RrGrantReady := '1';
                    v.WeightCnt    := (others => '0');
                end if;
            end if;

            -- Deassert GrantValid when there are no active requests with non-zero weights.
            if unsigned(ReqMasked) = 0 then
                v.GrantValid := '0';
            else
                v.GrantValid := '1';
            end if;

            -- Apply to record
            r_next <= v;
        end process;

        -- Assign outputs
        Out_Grant    <= RrGrant;
        Out_Valid    <= r_next.GrantValid;
        RrGrantReady <= r_next.RrGrantReady;

    end generate;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.RrGrantReady <= '0';
                r.GrantValid   <= '0';
                r.WeightCnt    <= (others => '0');
                r.State        <= GetRrGrant_s;
            end if;
        end if;
    end process;

end architecture;
