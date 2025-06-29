---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a pipelined first bit decoder. It finds out which
-- is the lowest index of a bit set in the input vecotr.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_decode_firstbit.md
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
entity olo_base_decode_firstbit is
    generic (
        InWidth_g       : positive;
        InReg_g         : boolean := true;
        OutReg_g        : boolean := true;
        PlRegs_g        : natural := 1
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic;

        -- Input
        In_Data         : in    std_logic_vector(InWidth_g-1 downto 0);
        In_Valid        : in    std_logic := '1';

        -- Output
        Out_FirstBit    : out   std_logic_vector(log2ceil(InWidth_g)-1 downto 0);
        Out_Found       : out   std_logic;
        Out_Valid       : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_decode_firstbit is

    -- *** Constants ***
    constant Stages_c         : natural := PlRegs_g+1;
    constant BinBits_c        : natural := log2ceil(InWidth_g);
    constant InWidthPow2_c    : natural := 2**BinBits_c;
    constant AddrBitsStageN_c : natural := BinBits_c/Stages_c;
    constant AddrBitsStage1_c : natural := BinBits_c - AddrBitsStageN_c*(Stages_c-1);
    constant ParallelStage1_c : natural := InWidthPow2_c/2**AddrBitsStage1_c;

    -- *** Types ***
    type BinStage_t is array (0 to ParallelStage1_c-1) of std_logic_vector(BinBits_c-1 downto 0);
    type BinAll_t is array(0 to Stages_c-1) of BinStage_t;
    type Found_t is array(0 to Stages_c-1) of std_logic_vector(ParallelStage1_c-1 downto 0);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        -- Input Registers
        DataIn   : std_logic_vector(In_Data'range);
        ValidIn  : std_logic;
        -- Pipeline Registers
        Addr     : BinAll_t;
        Found    : Found_t;
        Valid    : std_logic_vector(Stages_c-1 downto 0);
        -- Output Registers
        FirstBit : std_logic_vector(Out_FirstBit'range);
        FoundOut : std_logic;
        ValidOut : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert PlRegs_g < BinBits_c/2
        report "olo_base_decode_firstbit - PlRegs_g must be smaller than ceil(log2(InWidth_g))/2"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Process
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v                : TwoProcess_r;
        variable DataIn_v         : std_logic_vector(2**BinBits_c-1 downto 0);
        variable InValid_v        : std_logic;
        variable AddrBits_v       : natural;
        variable AddrLowIdx_v     : natural;
        variable AddrHighIdx_v    : natural;
        variable Parallelism_v    : natural;
        variable AddrBitsRemain_v : natural;
        variable StartIdx_v       : natural;
        variable InBitsPerInst_v  : natural;
    begin
        -- *** Hold Variables Stble ***
        v := r;

        -- *** Optional Input Register ***
        DataIn_v := (others => '0');
        if InReg_g then
            v.DataIn                       := In_Data;
            v.ValidIn                      := In_Valid;
            InValid_v                      := r.ValidIn;
            DataIn_v(InWidth_g-1 downto 0) := r.DataIn;
        else
            DataIn_v(InWidth_g-1 downto 0) := In_Data;
            InValid_v                      := In_Valid;
        end if;

        -- *** Calculate Address ***
        AddrLowIdx_v     := 0;
        AddrBitsRemain_v := BinBits_c;

        -- loop over all stages
        for stg in 0 to Stages_c-1 loop
            -- Valid handling
            if stg = 0 then
                v.Valid(stg) := InValid_v;
            else
                v.Valid(stg) := r.Valid(stg-1);
            end if;

            -- Calculate Parallelism & Index
            if stg = 0 then
                AddrBits_v := AddrBitsStage1_c;
            else
                AddrBits_v := AddrBitsStageN_c;
            end if;
            AddrHighIdx_v    := AddrLowIdx_v + AddrBits_v - 1;
            AddrBitsRemain_v := AddrBitsRemain_v - AddrBits_v;
            Parallelism_v    := 2**AddrBitsRemain_v;

            -- Calculate Address
            InBitsPerInst_v := 2**AddrBits_v;
            StartIdx_v      := 0;

            -- First stage does only detect the lowerst bit set
            if stg = 0 then

                -- loop over all parallel instances
                for inst in 0 to Parallelism_v-1 loop
                    -- First bit detection
                    v.Found(0)(inst) := '0';

                    -- loop over bits
                    for bit in 0 to InBitsPerInst_v-1 loop
                        if DataIn_v(StartIdx_v+bit) = '1' then
                            v.Addr(0)(inst)  := toUslv(bit, BinBits_c);
                            v.Found(0)(inst) := '1';
                            exit;
                        end if;
                    end loop;

                    StartIdx_v := StartIdx_v + InBitsPerInst_v;
                end loop;

            -- All other stages detect lowest found index, select the corresponding address anad extend it
            else

                -- loop over all parallel instances
                for inst in 0 to Parallelism_v-1 loop
                    -- First bit detection
                    v.Found(stg)(inst) := '0';

                    -- loop over bits
                    for bit in 0 to InBitsPerInst_v-1 loop
                        if r.Found(stg-1)(StartIdx_v+bit) = '1' then
                            v.Addr(stg)(inst)                                    := r.Addr(stg-1)(StartIdx_v+bit);
                            v.Addr(stg)(inst)(AddrHighIdx_v downto AddrLowIdx_v) := toUslv(bit, AddrBits_v);
                            v.Found(stg)(inst)                                   := '1';
                            exit;
                        end if;
                    end loop;

                    StartIdx_v := StartIdx_v + InBitsPerInst_v;
                end loop;

            end if;

            -- Increment Addre Index
            AddrLowIdx_v := AddrLowIdx_v + AddrBits_v;

        end loop;

        -- Optional Output Register
        v.FoundOut := r.Found(Stages_c-1)(0);
        if v.FoundOUt = '1' then
            v.FirstBit := r.Addr(Stages_c-1)(0);
        else
            v.FirstBit := (others => '0'); -- Output zero if not found, simplifies testing in many cases
        end if;
        v.ValidOut := r.Valid(Stages_c-1);
        if OutReg_g then
            Out_FirstBit <= r.FirstBit;
            Out_Found    <= r.FoundOut;
            Out_Valid    <= r.ValidOut;
        else
            Out_FirstBit <= v.FirstBit;
            Out_Found    <= v.FoundOut;
            Out_Valid    <= v.ValidOut;
        end if;

        -- *** Assign to signal ***
        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.ValidIn  <= '0';
                r.Valid    <= (others => '0');
                r.ValidOut <= '0';
            end if;
        end if;
    end process;

end architecture;