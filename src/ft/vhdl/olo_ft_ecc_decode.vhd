---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC decoder entity. Wraps the SECDED decode functions from olo_ft_pkg_ecc
-- (eccSyndromeAndParity, eccCorrectData, eccSecError, eccDedError) into a
-- reusable, optionally pipelined entity that is also accessible from Verilog.
-- Single-bit errors are corrected; double-bit errors are detected. The entity
-- exposes an AXI4-Stream handshake (In_Valid/In_Ready,
-- Out_Valid/Out_Ready) for the data path and a separate error-injection port
-- group (ErrInj_BitFlip + ErrInj_Valid) that is independent of the data
-- handshake. The injection pattern is XORed into the codeword before decode.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ecc_decode.md
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
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ecc_decode is
    generic (
        Width_g    : positive;
        Pipeline_g : natural range 0 to 2 := 0;
        UseReady_g : boolean              := true
    );
    port (
        -- Clock and Reset
        Clk            : in    std_logic;
        Rst            : in    std_logic;
        -- Input (AXI4-Stream sink)
        In_Valid       : in    std_logic                                                := '1';
        In_Ready       : out   std_logic;
        In_Codeword    : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0);
        -- Output (AXI4-Stream source)
        Out_Valid      : out   std_logic;
        Out_Ready      : in    std_logic                                                := '1';
        Out_Data       : out   std_logic_vector(Width_g - 1 downto 0);
        Out_EccSec     : out   std_logic;
        Out_EccDed     : out   std_logic;
        -- Error injection
        ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ecc_decode is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);
    constant ParityBits_c    : positive := eccParityBits(Width_g);
    constant SynParWidth_c   : positive := ParityBits_c + 1; -- includes overall parity bit
    constant PayloadWidth_c  : positive := Width_g + 2;      -- {Data, Sec, Ded}
    constant Stage1Width_c   : positive := CodewordWidth_c + SynParWidth_c;

    -- Distribute Pipeline_g across the two pl_stage instances. Stages2 (the output register)
    -- is preferred first because a single output register already breaks the codec-to-downstream
    -- path; Stages1 (between syndrome and correction) is added only at Pipeline_g=2 to split
    -- the SECDED logic into syndrome and correction halves for very tight timing.
    --   Pipeline_g=0 -> (Stages1=0, Stages2=0)   pure combinational
    --   Pipeline_g=1 -> (Stages1=0, Stages2=1)   single register at the output
    --   Pipeline_g=2 -> (Stages1=1, Stages2=1)   register between syndrome and correction, plus output
    constant Stages1_c : natural := choose(Pipeline_g >= 2, 1, 0);
    constant Stages2_c : natural := choose(Pipeline_g >= 1, 1, 0);

    signal ErrInj_Pending : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Active  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Injected       : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal In_Ready_i     : std_logic;

    signal SynPar     : std_logic_vector(SynParWidth_c - 1 downto 0);
    signal Stage1_In  : std_logic_vector(Stage1Width_c - 1 downto 0);
    signal Stage1_Out : std_logic_vector(Stage1Width_c - 1 downto 0);
    signal Stage1_Cw  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Stage1_Sp  : std_logic_vector(SynParWidth_c - 1 downto 0);
    signal Mid_Valid  : std_logic;
    signal Mid_Ready  : std_logic;
    signal Stage2_In  : std_logic_vector(PayloadWidth_c - 1 downto 0);
    signal Stage2_Out : std_logic_vector(PayloadWidth_c - 1 downto 0);

begin

    -- Injection latch identical to olo_ft_ecc_encode
    ErrInj_Active <= ErrInj_BitFlip when ErrInj_Valid = '1' else ErrInj_Pending;

    p_latch : process (Clk) is
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                ErrInj_Pending <= (others => '0');
            elsif In_Valid = '1' and In_Ready_i = '1' then
                ErrInj_Pending <= (others => '0');
            elsif ErrInj_Valid = '1' then
                ErrInj_Pending <= ErrInj_BitFlip;
            end if;
        end if;
    end process;

    -- XOR injection into the codeword before decode (simulates in-transit corruption)
    Injected <= In_Codeword xor ErrInj_Active;

    -- Stage 1: combinational syndrome+parity, optionally register {codeword, synpar}.
    SynPar    <= eccSyndromeAndParity(Injected, Width_g);
    Stage1_In <= Injected & SynPar;

    i_pl1 : entity work.olo_base_pl_stage
        generic map (
            Width_g    => Stage1Width_c,
            Stages_g   => Stages1_c,
            UseReady_g => UseReady_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready_i,
            In_Data   => Stage1_In,
            Out_Valid => Mid_Valid,
            Out_Ready => Mid_Ready,
            Out_Data  => Stage1_Out
        );

    Stage1_Cw <= Stage1_Out(Stage1Width_c - 1 downto SynParWidth_c);
    Stage1_Sp <= Stage1_Out(SynParWidth_c - 1 downto 0);

    -- Stage 2: combinational correction + SEC/DED, optionally register the output.
    Stage2_In <= eccCorrectData(Stage1_Cw, Stage1_Sp, Width_g) &
                 eccSecError(Stage1_Sp) &
                 eccDedError(Stage1_Sp);

    i_pl2 : entity work.olo_base_pl_stage
        generic map (
            Width_g    => PayloadWidth_c,
            Stages_g   => Stages2_c,
            UseReady_g => UseReady_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => Mid_Valid,
            In_Ready  => Mid_Ready,
            In_Data   => Stage2_In,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready,
            Out_Data  => Stage2_Out
        );

    Out_Data   <= Stage2_Out(PayloadWidth_c - 1 downto 2);
    Out_EccSec <= Stage2_Out(1);
    Out_EccDed <= Stage2_Out(0);

    In_Ready <= In_Ready_i;

end architecture;
