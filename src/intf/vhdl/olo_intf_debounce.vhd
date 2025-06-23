---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a debouncer for button and switch inputs. It contains a
-- double stage synchronizer to synchronize those inputs to the clock.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_debounce.md
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
    use work.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------

entity olo_intf_debounce is
    generic (
        ClkFrequency_g  : real;
        DebounceTime_g  : real      := 20.0e-3;
        Width_g         : positive  := 1;
        IdleLevel_g     : std_logic := '0';
        Mode_g          : string    := "LOW_LATENCY"    -- LOW_LATENCY or GLITCH_FILTER
    );
    port (
        -- control signals
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input clock domain
        DataAsync   : in    std_logic_vector(Width_g - 1 downto 0);
        DataOut     : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------

architecture struct of olo_intf_debounce is

    -- Time Constants
    -- Idea is to have a counter in the range 15-31 for each bit
    constant TargetTickFrequency_c : real    := 1.0/(DebounceTime_g/31.0);
    constant TickCycles_c          : real    := ceil(ClkFrequency_g/TargetTickFrequency_c);
    constant ActualTickFrequency_c : real    := ClkFrequency_g/TickCycles_c;
    constant DebounceTicks_c       : integer := integer(ceil(DebounceTime_g*ActualTickFrequency_c));
    constant UseStrobeDiv_c        : boolean := integer(TickCycles_c) >= 2;

    -- Other Constants
    constant Bits_c : integer := DataAsync'length;

    -- Instantiation Signals
    signal DataSync : std_logic_vector(DataAsync'range);
    signal Tick     : std_logic;

    -- Types
    subtype Cnt_t is integer range 0 to DebounceTicks_c;
    type Cnt_a is array (0 to Bits_c-1) of Cnt_t;

    -- Two process record
    type TwoProcess_r is record
        StableCnt : Cnt_a;
        LastState : std_logic_vector(Bits_c-1 downto 0);
        IsStable  : std_logic_vector(Bits_c-1 downto 0);
        DataOut   : std_logic_vector(Bits_c-1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin

    assert Mode_g = "GLITCH_FILTER" or Mode_g = "LOW_LATENCY"
        report "olo_intf_debounce: Illegal Mode_g - " & Mode_g
        severity failure;

    assert DebounceTicks_c >= 10
        report "olo_intf_debounce: DebounceTime too short (must be >= 10 clock cycles) - " &
               "DebounceTime_g=" & real'image(DebounceTime_g) & " ClkFrequency_g=" & real'image(ClkFrequency_g)
        severity failure;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- Hold variables stable
        v := r;

        for i in 0 to DataAsync'length-1 loop

            -- Counter Update & Stablity Detection
            if Tick = '1' then
                if r.StableCnt(i) = DebounceTicks_c then
                    v.IsStable(i) := '1';
                else
                    v.StableCnt(i) := r.Stablecnt(i) + 1;
                end if;
            end if;

            -- Reset counters on state change
            if DataSync(i) /= r.LastState(i) then
                v.StableCnt(i) := 0;
                v.IsStable(i)  := '0';
            end if;

            -- GLITCH_FILTER mode
            if Mode_g = "GLITCH_FILTER" then
                -- Only forward signal once stable
                if r.IsStable(i) = '1' then
                    v.DataOut(i) := r.LastState(i);
                end if;
            end if;

            -- LOW_LATENCY mode
            if Mode_g = "LOW_LATENCY" then
                -- Forward new state whenever signal is stable (including first edge)
                if r.IsStable(i) = '1' then
                    v.DataOut(i) := DataSync(i);
                end if;
            end if;
        end loop;

        -- Update last state
        v.LastState := DataSync;

        -- Outputs
        DataOut <= r.DataOut;

        -- Assign to signal
        r_next <= v;
    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- normal operation
            r <= r_next;
            -- reset
            if Rst = '1' then
                r.StableCnt <= (others => DebounceTicks_c);
                r.LastState <= (others => IdleLevel_g);
                r.IsStable  <= (others => '1');
                r.DataOut   <= (others => IdleLevel_g);
            end if;
        end if;
    end process;

    -- *** Component Instantiations ***
    -- Synchronizer
    i_sync : entity work.olo_intf_sync
        generic map (
            Width_g     => Width_g,
            RstLevel_g  => IdleLevel_g
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => DataAsync,
            DataSync    => DataSync
        );

    -- Tick Generator
    g_use_strobe : if UseStrobeDiv_c generate

        i_tickgen : entity work.olo_base_strobe_gen
            generic map (
                FreqClkHz_g    => ClkFrequency_g,
                FreqStrobeHz_g => ActualTickFrequency_c
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                Out_Valid   => Tick
            );

    end generate;

    g_no_strobe : if not UseStrobeDiv_c generate
        Tick <= '1';
    end generate;

end architecture;
