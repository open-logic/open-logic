---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bruendler
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
    use work.olo_base_pkg_array.all;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_arb_wrr is
    generic (
        GrantWidth_g  : positive;
        WeightWidth_g : positive;
        Latency_g     : natural range 0 to 1 := 0
    );
    port (
        -- Control
        Clk        : in    std_logic;
        Rst        : in    std_logic;

        -- Static Configuration
        Weights    : in    std_logic_vector(WeightWidth_g*GrantWidth_g-1 downto 0);

        -- Request Interface
        In_Valid   : in    std_logic;
        In_Req     : in    std_logic_vector(GrantWidth_g-1 downto 0);

        -- Grant Interface
        Out_Valid  : out   std_logic;
        Out_Grant  : out   std_logic_vector(GrantWidth_g-1 downto 0)
    );
end entity;

architecture rtl of olo_base_arb_wrr is

    -- Functions
    -- Generates a mask for the input request vector.
    -- Each bit is set to '1' if the corresponding weight is not zero, otherwise it is '0'.
    -- Effectively masks out requests with zero weight.
    function generateRequestWeightsMask (
        WeightsParam     : std_logic_vector;
        WeightWidthParam : positive;
        GrantWidthParam  : positive) return std_logic_vector is
        -- Variables
        variable RequestWeightsMask_v : std_logic_vector(GrantWidthParam-1 downto 0);
    begin

        for i in (GrantWidthParam-1) downto 0 loop
            if (unsigned(WeightsParam((i+1)*WeightWidthParam-1 downto i*WeightWidthParam)) /= 0) then
                RequestWeightsMask_v(i) := '1';
            else
                RequestWeightsMask_v(i) := '0';
            end if;
        end loop;

        return RequestWeightsMask_v;
    end function;

    -- Two Process Method
    type TwoProcess_t is record
        Valid      : std_logic;
        WeightCnt  : unsigned(WeightWidth_g - 1 downto 0);
        Weights    : std_logic_vector(WeightWidth_g * GrantWidth_g - 1 downto 0);
        Grant      : std_logic_vector(Out_Grant'range);
        GrantIdx   : natural range 0 to GrantWidth_g - 1;
        Switchover : std_logic;
    end record;

    signal r      : TwoProcess_t;
    signal r_next : TwoProcess_t;

    -- Component connection signals
    signal RrReq        : std_logic_vector(In_Req'range);
    signal RrGrant      : std_logic_vector(Out_Grant'range);
    signal RrGrantReady : std_logic;

begin

    RrReq <= In_Req and generateRequestWeightsMask(Weights, WeightWidth_g, GrantWidth_g);

    -- *** Component Instantiations ***
    i_arb_rr : entity work.olo_base_arb_rr
        generic map (
            Width_g => GrantWidth_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Req    => RrReq,
            Out_Ready => RrGrantReady,
            Out_Grant => RrGrant
        );

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v                   : TwoProcess_t;
        variable WeightCurrent_v     : unsigned(WeightWidth_g - 1 downto 0);
        variable WeighsUnflattened_v : StlvArray_t(0 to GrantWidth_g - 1)(WeightWidth_g - 1 downto 0);
    begin
        -- Hold variables stable
        v := r;

        -- Valid pipeline
        v.Valid := In_Valid;

        -- Detect switchover to new requester
        if In_Valid = '1' then
            v.Weights := Weights;
        end if;

        -- Switchover detection
        WeighsUnflattened_v := unflattenStlvArray(r.Weights, WeightWidth_g);
        WeightCurrent_v     := unsigned(WeighsUnflattened_v(r.GrantIdx));
        if ((r.WeightCnt >= WeightCurrent_v) and r.Valid = '1') or unsigned(r.Grant and In_Req) = 0 then
            v.Switchover := '1';
        end if;

        -- Switchover Execution
        RrGrantReady <= '0';
        if (v.Switchover = '1') and (In_Valid = '1') then
            v.Switchover := '0';
            RrGrantReady <= '1';
            if unsigned(RrGrant) = 0 then
                v.GrantIdx := 0;
            else
                v.GrantIdx := getLeadingSetBitIndex(RrGrant);
            end if;
            v.Grant     := RrGrant;
            v.WeightCnt := to_unsigned(1, WeightWidth_g);
        elsif r.Valid = '1' then
            v.WeightCnt := v.WeightCnt + 1;
        end if;

        -- Write to signal
        r_next <= v;
    end process;

    -- *** Output Assignment ***
    g_latency : if (Latency_g = 1) generate
        Out_Valid <= r.Valid;
        Out_Grant <= r.Grant;
    end generate;

    g_no_latency : if (Latency_g = 0) generate
        Out_Valid <= r_next.Valid;
        Out_Grant <= r_next.Grant;
    end generate;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Valid      <= '0';
                r.GrantIdx   <= 0;
                r.WeightCnt  <= (others => '0');
                r.Weights    <= (others => '0');
                r.Switchover <= '1';
            end if;
        end if;
    end process;

end architecture;

