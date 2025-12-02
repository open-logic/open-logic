---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Author: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This component limits the rate of AXI4-Stream style handshaked interfaces to a specified
-- maximum data rate. It can be used to avoid overloading downstream components. This is especially
-- useful when interfacing to components that have limited processing capabilities and do not
-- support back-pressure (i.e. do not de-assert Ready signals).
--
-- The component has two modes of operation:
-- - BLOCK: Forward short bursts at full speed but limit average rate over fixed periods
-- - SMOOTH: Space samples evenly over time to achieve constant output data rate
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_rate_limit.md
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
    use work.olo_base_pkg_string.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_rate_limit is
    generic (
        Width_g         : positive;
        RegisterReady_g : boolean  := true;
        Mode_g          : string   := "SMOOTH";
        Period_g        : positive;
        MaxSamples_g    : positive := 1;
        RuntimeCfg_g    : boolean  := false
    );
    port (
        -- Control
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Input Data
        In_Data         : in    std_logic_vector(Width_g-1 downto 0);
        In_Valid        : in    std_logic                                           := '1';
        In_Ready        : out   std_logic;
        -- Output Data
        Out_Data        : out   std_logic_vector(Width_g-1 downto 0);
        Out_Valid       : out   std_logic;
        Out_Ready       : in    std_logic                                           := '1';
        -- Configuration Ports (for RuntimeCfg_g = true)
        Cfg_Period      : in    std_logic_vector(log2ceil(Period_g)-1 downto 0)     := toUslv(Period_g-1, log2ceil(Period_g));
        Cfg_MaxSamples  : in    std_logic_vector(log2ceil(MaxSamples_g)-1 downto 0) := toUslv(MaxSamples_g-1, log2ceil(MaxSamples_g))
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_rate_limit is

    -- Constants
    constant ModeUpper_c : string := toUpper(Mode_g);

    -- Signals
    signal Input_Ready : std_logic;
    signal Input_Valid : std_logic;
    signal Input_Data  : std_logic_vector(Width_g-1 downto 0);

begin

    -- *** Assertions ***
    assert MaxSamples_g <= Period_g
        report "olo_base_rate_limit: MaxSamples_g (" & integer'image(MaxSamples_g) &
               ") must be <= Period_g (" & integer'image(Period_g) & ")"
        severity failure;

    assert ModeUpper_c = "SMOOTH" or ModeUpper_c = "BLOCK"
        report "olo_base_rate_limit: Mode_g must be either ""SMOOTH"" or ""BLOCK"", got """ & ModeUpper_c & """"
        severity failure;

    -- *** Add Input Register if Required ***
    -- Ready registered
    g_ready_registered : if RegisterReady_g generate

        i_pl_stage : entity work.olo_base_pl_stage
            generic map (
                Width_g => Width_g
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Data   => In_Data,
                In_Valid  => In_Valid,
                In_Ready  => In_Ready,
                Out_Data  => Input_Data,
                Out_Valid => Input_Valid,
                Out_Ready => Input_Ready
            );

    end generate;

    -- Ready unregistered
    g_ready_unregistered : if not RegisterReady_g generate
        Input_Valid <= In_Valid;
        In_Ready    <= Input_Ready;
        Input_Data  <= In_Data;
    end generate;

    -- *** Generate statement for NO RATE LIMIT ***
    -- Period_g = 1 means that there is no rate limit because every clock cycle a
    -- sample can be transferred.
    g_no_rate_limit : if Period_g = 1 generate
        -- Direct wire-through without any rate limiting
        Out_Valid   <= Input_Valid;
        Input_Ready <= Out_Ready;
        Out_Data    <= Input_Data;
    end generate;

    -- *** Generate statement for ACTIVE RATE LIMIT when Period_g > 1 ***
    g_rate_limit : if Period_g > 1 generate
        -- Two process method signals
        type TwoProcess_r is record
            -- SMOOTH mode signals
            SmoothCounter  : unsigned(log2ceil(Period_g+MaxSamples_g)-1 downto 0);
            -- BLOCK mode signals
            PeriodCounter  : integer range 0 to Period_g-1;
            SamplesCounter : integer range 0 to MaxSamples_g+1;
            -- Runtime configuration signals
            CfgPeriod      : std_logic_vector(Cfg_Period'range);
            CfgMaxSamples  : std_logic_vector(Cfg_MaxSamples'range);
            CfgSmoothLimit : unsigned(Cfg_Period'range);
        end record;

        signal r, r_next : TwoProcess_r;

        -- Internal signals to avoid reading back output ports
        signal Out_Valid_i : std_logic;
        signal In_Ready_i  : std_logic;
        signal AllowSample : std_logic;

    begin

        -- Combinatorial process
        p_comb : process (all) is
            variable v                : TwoProcess_r;
            variable OutputTransfer_v : boolean;
            variable PeriodMin1_v     : natural; -- Period minus 1
            variable MaxSamples_v     : natural;
            variable SmoothLimit_v    : natural;
        begin
            -- Hold variables stable
            v := r;

            -- Register Runtime Configuration signals
            if RuntimeCfg_g then
                v.CfgPeriod     := to01(Cfg_Period);
                v.CfgMaxSamples := to01(Cfg_MaxSamples);
                -- to01 and resize required to workaround simulation issues. Functionally they do not
                -- have impact so this is tolerable.
                v.CfgSmoothLimit := unsigned(to01(Cfg_Period)) - resize(unsigned(to01(Cfg_MaxSamples)), Cfg_Period'length);
                PeriodMin1_v     := to_integer(unsigned(to01(r.CfgPeriod))); -- This is period minus 1 because the definition of the port is like that
                MaxSamples_v     := to_integer(unsigned(to01(r.CfgMaxSamples)))+1;
                SmoothLimit_v    := to_integer(r.CfgSmoothLimit);
                -- synthesis translate_off
                assert MaxSamples_v <= PeriodMin1_v+1
                    report "olo_base_rate_limit: Runtime configured requires Cfg_MaxSamples <= Cfg_Period"
                    severity failure;
                -- synthesis translate_on
            else
                PeriodMin1_v  := Period_g - 1;
                MaxSamples_v  := MaxSamples_g;
                SmoothLimit_v := Period_g - MaxSamples_g; -- off by one correction
            end if;

            -- Detect successful output transfer (rate limiter output to downstream)
            OutputTransfer_v := (Out_Valid_i = '1' and Out_Ready = '1');

            -- SMOOTH Mode Logic
            if ModeUpper_c = "SMOOTH" then

                -- Update counter: either decrement (on transfer) OR increment (building credit)
                if OutputTransfer_v then
                    v.SmoothCounter := r.SmoothCounter - SmoothLimit_v;
                elsif r.SmoothCounter < SmoothLimit_v then
                    v.SmoothCounter := r.SmoothCounter + MaxSamples_v;
                end if;

                -- Allow sample logic
                if r.SmoothCounter >= SmoothLimit_v then
                    AllowSample <= '1';
                else
                    AllowSample <= '0';
                end if;

            -- BLOCK Mode Logic
            else -- Mode_g = "BLOCK"

                -- Samples counting (increment only when actually outputting)
                if OutputTransfer_v then
                    v.SamplesCounter := r.SamplesCounter + 1;
                end if;

                -- Period Handling
                if r.PeriodCounter >= PeriodMin1_v then
                    v.PeriodCounter  := 0;
                    v.SamplesCounter := 0;
                else
                    v.PeriodCounter := r.PeriodCounter + 1;
                end if;

                -- Allow sample logic
                if r.SamplesCounter < MaxSamples_v then
                    AllowSample <= '1';
                else
                    AllowSample <= '0';
                end if;
            end if;

            -- Assign to next state
            r_next <= v;
        end process;

        -- Sequential process
        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.SmoothCounter  <= (others => '0');
                    r.PeriodCounter  <= 0;
                    r.SamplesCounter <= 0;
                    r.CfgPeriod      <= toUslv(Period_g-1, Cfg_Period'length);
                    r.CfgMaxSamples  <= toUslv(MaxSamples_g-1, Cfg_MaxSamples'length);
                    r.CfgSmoothLimit <= to_unsigned(Period_g - MaxSamples_g + 1, Cfg_Period'length);
                end if;
            end if;
        end process;

        -- Gated handshaking signals
        Out_Valid_i <= Input_Valid and AllowSample;
        In_Ready_i  <= Out_Ready and AllowSample;

        -- Output Port Assignment
        Out_Valid   <= Out_Valid_i;
        Input_Ready <= In_Ready_i;
        Out_Data    <= Input_Data;

    end generate;

end architecture;