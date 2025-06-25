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
    use ieee.std_logic_misc.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_wconv_n2m is
    generic (
        InWidth_g  : positive := 16;
        OutWidth_g : positive := 24;
        UseBe_g    : boolean  := false
    );
    port (
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        In_Valid     : in    std_logic                                    := '1';
        In_Ready     : out   std_logic;
        In_Data      : in    std_logic_vector(InWidth_g - 1 downto 0);
        In_Be        : in    std_logic_vector(InWidth_g / 8 - 1 downto 0) := (others => '1');
        In_Last      : in    std_logic                                    := '0';
        Out_Valid    : out   std_logic;
        Out_Ready    : in    std_logic                                    := '1';
        Out_Data     : out   std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Be       : out   std_logic_vector(OutWidth_g / 8 - 1 downto 0);
        Out_Last     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_wconv_n2m is

    -- *** Constants ***
    constant MaxChunkSize_c : positive := greatestCommonFactor(InWidth_g, OutWidth_g);
    constant ChunkSize_c    : positive := choose(UseBe_g, 8, MaxChunkSize_c);
    constant SrWidth_c      : positive := choose(OutWidth_g > InWidth_g, 2*OutWidth_g, OutWidth_g+InWidth_g);
    constant OutChunks_c    : positive := OutWidth_g / ChunkSize_c;
    constant InChunks_c     : positive := InWidth_g / ChunkSize_c;

    -- *** Two Process Method ***
    type TwoProcess_r is record
        ChunkCnt    : integer range 0 to SrWidth_c / ChunkSize_c - 1;
        ShiftReg    : std_logic_vector(SrWidth_c - 1 downto 0);
        LastChunk   : std_logic_vector(SrWidth_c / ChunkSize_c - 1 downto 0);
        LastPending : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -- assertions
    assert (UseBe_g = false) or ((InWidth_g mod 8 = 0) and (OutWidth_g mod 8 = 0))
        report "olo_base_wconv_n2m: Byte Enables are only supported for byte-aligned InWidht_g and OutWidth_g"
        severity failure;

    -- Implement conversion logic only if required
    g_convert : if OutWidth_g /= InWidth_g generate

        p_comb : process (all) is
            variable v            : TwoProcess_r;
            variable Out_Valid_v  : std_logic;
            variable Offset_v     : natural range 0 to SrWidth_c - 1;
            variable IsLastBeat_v : std_logic;
        begin
            -- *** hold variables stable ***
            v := r;

            -- Output transaction
            Out_Valid_v  := '0';
            IsLastBeat_v := or_reduce(r.LastChunk(OutChunks_c - 1 downto 0));
            if (r.ChunkCnt >= OutChunks_c) or (IsLastBeat_v = '1') then
                Out_Valid_v := '1';
            end if;
            if Out_Valid_v = '1' and Out_Ready = '1' then
                -- Clear after last beat
                if IsLastBeat_v = '1' then
                    v.ChunkCnt    := 0;
                    v.ShiftReg    := (others => '0');
                    v.LastChunk   := (others => '0');
                    v.LastPending := '0';
                -- Normal Operation
                else
                    v.ChunkCnt  := r.ChunkCnt - OutChunks_c;
                    v.ShiftReg  := zerosVector(OutWidth_g) & r.ShiftReg(r.ShiftReg'high downto OutWidth_g);
                    v.LastChunk := zerosVector(OutChunks_c) & r.LastChunk(r.LastChunk'high downto OutChunks_c);
                end if;
            end if;
            Out_Valid <= Out_Valid_v;
            Out_Data  <= r.ShiftReg(OutWidth_g - 1 downto 0);
            Out_Last  <= IsLastBeat_v;
            -- Output byte enables
            if UseBe_g = true then
                Out_Be <= (others => '0');

                -- Loop through all byte-enable signals
                for byte in 0 to OutChunks_c-1 loop
                    Out_Be(byte) <= '1';
                    if r.LastChunk(byte) = '1' then
                        exit;
                    end if;
                end loop;

            else
                Out_Be <= (others => '1');
            end if;

            -- Shift in new data if required
            In_Ready <= '0';
            -- On last beat in blockage, do not accept data
            if (v.ChunkCnt < OutChunks_c) and (v.LastPending = '0') then

                In_Ready <= not Rst;
                if In_Valid = '1' then
                    -- Insert dat ainto shift register
                    Offset_v                                             := v.ChunkCnt*ChunkSize_c;
                    v.ShiftReg(Offset_v + InWidth_g - 1 downto Offset_v) := In_Data;

                    -- Select last chunk for byte-enables (based on byte enables)
                    if UseBe_g = true then
                        -- Check correct BE usage
                        assert (In_Last = '1') or (In_Be = onesVector(In_Be'length))
                            report "olo_base_wconv_n2m: Incomplete byte enables are only supported for last beat"
                            severity failure;
                        -- Assert last chunk on correct byte (default)
                        v.LastChunk(v.ChunkCnt + InChunks_c-1) := In_Last;

                        -- Loop through all byte-enables
                        for byte in 0 to InChunks_c-2 loop
                            if In_Be(byte) = '1' and In_Be(byte+1) = '0' then
                                v.LastChunk(v.ChunkCnt + byte)         := In_Last; -- set last chunk
                                v.LastChunk(v.ChunkCnt + InChunks_c-1) := '0'; -- override default
                                exit;
                            end if;
                        end loop;

                    -- Select last chunk with disabled byte-enables
                    else
                        v.LastChunk(v.ChunkCnt + InChunks_c-1) := In_Last;
                    end if;
                    v.ChunkCnt    := v.ChunkCnt + InChunks_c;
                    v.LastPending := In_Last;
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
                    r.ShiftReg    <= (others => '0');
                    r.ChunkCnt    <= 0;
                    r.LastChunk   <= (others => '0');
                    r.LastPending <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- No conversion required
    g_equalwidth : if OutWidth_g = InWidth_g generate
        Out_Valid <= In_Valid;
        Out_Data  <= In_Data;
        Out_Last  <= In_Last;
        In_Ready  <= Out_Ready;

    end generate;

end architecture;
