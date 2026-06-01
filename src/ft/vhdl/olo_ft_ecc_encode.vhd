---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC encoder entity. Wraps the SECDED encode function from olo_ft_pkg_ecc into
-- a reusable, optionally pipelined entity that is also accessible from Verilog.
-- The entity exposes an AXI4-Stream handshake (In_Valid/In_Ready,
-- Out_Valid/Out_Ready) for the data path and a separate error-injection port
-- group (ErrInj_BitFlip + ErrInj_Valid) that is independent of the data
-- handshake. The injection pattern is latched on ErrInj_Valid and applied to
-- the next accepted data beat (or directly when ErrInj_Valid coincides with
-- a completed In_Valid/In_Ready handshake).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ecc_encode.md
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
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ecc_encode is
    generic (
        Width_g    : positive;
        Pipeline_g : natural range 0 to 1 := 0;
        UseReady_g : boolean              := true
    );
    port (
        -- Clock and Reset
        Clk            : in    std_logic;
        Rst            : in    std_logic;
        -- Input (AXI4-Stream sink)
        In_Valid       : in    std_logic                                                := '1';
        In_Ready       : out   std_logic;
        In_Data        : in    std_logic_vector(Width_g - 1 downto 0);
        -- Output (AXI4-Stream source)
        Out_Valid      : out   std_logic;
        Out_Ready      : in    std_logic                                                := '1';
        Out_Codeword   : out   std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0);
        -- Error injection
        ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ecc_encode is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    signal ErrInj_Pending : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Active  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Injected       : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal In_Ready_i     : std_logic;

begin

    -- Active flip pattern: latched value, with same-cycle ErrInj_BitFlip taking priority when
    -- ErrInj_Valid='1'.
    ErrInj_Active <= ErrInj_BitFlip when ErrInj_Valid = '1' else ErrInj_Pending;

    -- Injection latch: loaded on ErrInj_Valid, cleared on a completed input handshake.
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

    -- Combinational SECDED encode + injection
    Injected <= eccEncode(In_Data) xor ErrInj_Active;

    -- Optional pipeline stage with AXI-S handshake (Stages_g=0 -> pass-through)
    i_pl : entity work.olo_base_pl_stage
        generic map (
            Width_g    => CodewordWidth_c,
            Stages_g   => Pipeline_g,
            UseReady_g => UseReady_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready_i,
            In_Data   => Injected,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready,
            Out_Data  => Out_Codeword
        );

    In_Ready <= In_Ready_i;

end architecture;
