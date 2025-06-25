---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Benoit Stef, Oliver Bründler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic strobe generator. It produces pulses with a duration
-- of one clock cycle at a given frequency.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_strobe_gen.md
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

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_strobe_gen is
    generic (
        FreqClkHz_g      : real;
        FreqStrobeHz_g   : real;
        FractionalMode_g : boolean := false
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        In_Sync     : in    std_logic := '0';
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic := '1'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_strobe_gen is

    -- Counter Period
    constant PeriodCountsFractional_c : integer := integer(work.olo_base_pkg_math.min(round(FreqClkHz_g / FreqStrobeHz_g * 100.0), real(integer'high)));
    constant PeriodCountsInteger_c    : integer := integer(round(FreqClkHz_g / FreqStrobeHz_g));
    constant PeriodCounts_c           : integer := choose(FractionalMode_g, PeriodCountsFractional_c, PeriodCountsInteger_c);

    -- Fractional mode increments by 100 every cycle
    constant Increment_c  : integer := choose(FractionalMode_g, 100, 1);
    constant WrapBorder_c : integer := PeriodCounts_c - Increment_c;

    -- Signal Declarations
    signal Count    : integer range 0 to PeriodCounts_c-1;
    signal SyncLast : std_logic;

begin

    -- Fractional mode is only lsupported for a factor < 1'000'000 between FreqClkHz_g and FreqStrobeHz_g
    assert not (FractionalMode_g and (FreqClkHz_g / FreqStrobeHz_g >= 1.0e6))
        report "olo_base_strobe_gen - Fractional mode is only supported for FreqClkHz_g < 1'000'000 x FreqStrobeHz_g"
        severity failure;

    -- Ratio between FreqClkHz_g and FreqStrobeHz_g must be <= 2'147'483'000
    assert (FreqClkHz_g / FreqStrobeHz_g <= 214748000.0)
        report "olo_base_strobe_gen - FreqClkHz_g / FreqStrobeHz_g must be <= 2'147'483'000"
        severity failure;

    p_strobe : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Sync
            if (In_Sync = '1') and (SyncLast = '0') then
                Count     <= 0;
                Out_Valid <= '1';
            -- Wraparound
            elsif Count >= WrapBorder_c then
                Out_Valid <= '1';
                if FractionalMode_g then
                    Count <= Count - WrapBorder_c;
                else
                    Count <= 0;
                end if;
            -- Increment
            else
                -- Keep Out_Valid asserted until Out_Ready is asserted as well
                if Out_Ready = '1' then
                    Out_Valid <= '0';
                end if;
                Count <= Count + Increment_c;
            end if;
            SyncLast <= In_Sync;

            -- Reset
            if Rst = '1' then
                Count     <= 0;
                Out_Valid <= '0';
                SyncLast  <= '0';
            end if;
        end if;
    end process;

end architecture;
