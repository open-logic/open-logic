------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This entity implements a pipelined first bit decoder. It finds out which
-- is the lowest index of a bit set in the input vecotr.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity olo_base_decode_firstbit is
    generic (
        InWidth_g       : positive;
        InReg_g         : boolean   := true;
        OutReg_g        : boolean   := true;
        Stages_g        : natural   := 2
    );
    port (   
        -- Clock and Reset
        Clk             : in  std_logic;                             
        Rst             : in  std_logic;        

        -- Input
        In_Data         : in  std_logic_vector(InWidth_g-1 downto 0);     
        In_Valid        : in  std_logic                                  := '1';
        
        -- Output
        Out_FirstBit    : out std_logic_vector(log2ceil(InWidth_g)-1 downto 0);
        Out_OneFound    : out std_logic;
        Out_Valid       : out std_logic
    );
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of olo_base_decode_firstbit is

    -- *** Constants ***
    constant BinBits_c          : natural := log2ceil(InWidth_g);
    constant AddrBitsStageN_c   : natural := BinBits_c/Stages_g;
    constant AddrBitsStage1_c   : natural := BinBits_c - AddrBitsStageN_c*(Stages_g-1);
    constant ParallelStage1_c   : natural := InWidth_g/2**AddrBitsStage1_c;

    -- *** Types ***
    type BinStage_t is array (0 to ParallelStage1_c-1) of std_logic_vector(BinBits_c-1 downto 0);
    type BinAll_t is array(0 to Stages_g-1) of BinStage_t;


    -- *** Two Process Method ***
    type two_process_r is record
        -- Input Registers
        DataIn                  : std_logic_vector(InWidth_g-1 downto 0);
        ValidIn                 : std_logic;                 
        -- Pipeline Registers
        Addr                    : BinAll_t
        Valid                   : std_logic_vector(Stages_g-1 downto 0);
        -- Output Registers
        FirstBit                : log2ceil(log2ceil(InWidth_g)-1 downto 0);
        OneFound                : std_logic;
        ValidOut                : std_logic;
    end record;
    signal r, r_next : two_process_r;

begin

    --------------------------------------------------------------------------
    -- Assertions
    -------------------------------------------------------------------------- 
    assert PipelineReg_g <= BinBits_c/4
        report "olo_base_decode_firstbit - PipelineReg_g must be smaller or equal to ceil(log2(InWidth_g))/4"
        severity error;

    --------------------------------------------------------------------------
    -- Combinatorial Process
    -------------------------------------------------------------------------- 
    p_comb : process
        variable v  : two_process_r;
        variable DataIn_v           : std_logic_vector(2**BinBits_c-1 downto 0);
        variable InValid_v          : std_logic;
        variable AddrBits_v         : natural;
        variable AddrBitsDone_v     : natural;
        variable AddrBitsRemain_v   : natural;
        variable Parallelism_v      : natural;
    begin
        -- *** Hold Variables Stble ***
        v := r;

        -- *** Optional Input Register ***
        DataIn_v := (others => '0');
        if InReg_g then
            v.DataIn    := In_Data;
            v.ValidIn   := In_Valid;
            InValid_v   := r.ValidIn;
            DataIn_v(InWidth_g-1 downto 0) := r.DataIn;
        else
            DataIn_v(InWidth_g-1 downto 0) := In_Data;
            InValid_v := In_Valid;
        end if;

        -- *** Calculate Address ***
        AddrBitsRemain_v := BinBits_c;
        for stg in 0 to Stages_g-1 loop
            -- Calculate Parallelism
            if stg = 0 then
                AddrBits_v := AddrBitsStage1_c;
            else
                AddrBits_v := AddrBitsStageN_c;
            end if;
            AddrBitsRemain_v := AddrBitsRemain_v - AddrBits_v;
            AddrBitsDone_v := BinBits_c - AddrBitsRemain_v;
            Parallelism_v := 2**(AddrBitsRemain_v);

            -- Calculate address
            for i in 0 to Parallelism_v-1 loop
                -- Find first bit only for first stage

            end loop;




        end loop;

        -- *** Assign to signal ***
        r_next <= v;
    end process;


end architecture;
