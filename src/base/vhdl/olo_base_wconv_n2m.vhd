---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple data-width conversion between arbitrary input and output
-- widths.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_wconv_n2m.md
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

-- Optimize barrel shifter to use registered chunkcounter
-- Implement Last Handling
-- Implement output byte enables
-- Implement input byte enables (drop incomplete last word)
-- Test both byte enables (incomplete last word only)
-- Implement "arbitrary byte enables? or LSB byte enables?"
-- Test backpressure
-- Constrained random test
-- Test same width
-- Test In > OUt
-- Test OUt > In


---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_wconv_n2m is
    generic (
        InWidth_g  : positive;
        OutWidth_g : positive
    );
    port (
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        In_Valid     : in    std_logic := '1';
        In_Ready     : out   std_logic;
        In_Data      : in    std_logic_vector(InWidth_g - 1 downto 0);
        In_Last      : in    std_logic := '0';
        Out_Valid    : out   std_logic;
        Out_Ready    : in    std_logic := '1';
        Out_Data     : out   std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Last     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_wconv_n2m is

    -- *** Constants ***
    constant ChunkSize_c : positive := greatestCommonFactor(InWidth_g, OutWidth_g);
    constant SrWidth_c   : positive := choose(OutWidth_g > InWidth_g, 2*OutWidth_g, OutWidth_g+InWidth_g);
    constant Period_c    : positive := leastCommonMultiple(InWidth_g, OutWidth_g);
    constant OutChunks_c : positive := OutWidth_g / ChunkSize_c;
    constant InChunks_c  : positive := InWidth_g / ChunkSize_c;

    -- *** Two Process Method ***
    type TwoProcess_r is record
        ChunkCnt    : integer range 0 to SrWidth_c / ChunkSize_c - 1;
        ShiftReg    : std_logic_vector(SrWidth_c - 1 downto 0);
    end record;

    signal r, r_next    : TwoProcess_r;

begin

    -- Implement conversion logic only if required
    g_convert : if OutWidth_g /= InWidth_g generate

        p_comb : process (r, In_Valid, In_Data, Out_Ready, In_Last, Rst) is
            variable v           : TwoProcess_r;
            variable Out_Valid_v : std_logic;
            variable Offset_v    : natural range 0 to SrWidth_c / ChunkSize_C - 1;
        begin
            -- *** hold variables stable ***
            v := r;

            -- Output transaction
            Out_Valid_v := '0';
            if r.ChunkCnt >= OutChunks_c then
                Out_Valid_v := '1';
            end if;
            if Out_Valid_v = '1' and Out_Ready = '1' then
                v.ChunkCnt := r.ChunkCnt - OutChunks_c;
                v.ShiftReg := zerosVector(OutWidth_g) & r.ShiftReg(r.ShiftReg'high downto OutWidth_g);
            end if;
            Out_Valid <= Out_Valid_v;
            Out_Data <= r.ShiftReg(OutWidth_g - 1 downto 0);
            Out_Last <= '0';

            -- Shift in new data if required
            In_Ready <= '0';
            if v.ChunkCnt < OutChunks_c  then
                In_Ready <= not Rst;
                if In_Valid = '1' then
                    Offset_v := v.ChunkCnt*ChunkSize_c;
                    v.ShiftReg(Offset_v + InWidth_g - 1 downto Offset_v) := In_Data;
                    v.ChunkCnt := v.ChunkCnt + InChunks_c;
                end if;
            end if;

            -- *** assign signal ***
            r_next <= v;
        end process;

        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.ShiftReg <= (others => '0');
                    r.ChunkCnt <= 0;
                end if;
            end if;
        end process;

    end generate;

    -- No conversion required
    g_equalwidth : if OutWidth_g = InWidth_g generate
        Out_Valid   <= In_Valid;
        Out_Data    <= In_Data;
        Out_Last    <= In_Last;
        In_Ready    <= Out_Ready;

    end generate;

end architecture;
