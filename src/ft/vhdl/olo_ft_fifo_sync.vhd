---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected synchronous FIFO using SECDED (Single Error Correction,
-- Double Error Detection) Hamming code. Wraps olo_base_fifo_sync with a wider
-- internal word to store parity bits alongside data. The ECC is transparent
-- to the user: data is encoded on write and decoded/corrected on read.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_fifo_sync.md
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
entity olo_ft_fifo_sync is
    generic (
        Width_g         : positive;
        Depth_g         : positive;
        AlmFullOn_g     : boolean              := false;
        AlmFullLevel_g  : natural              := 0;
        AlmEmptyOn_g    : boolean              := false;
        AlmEmptyLevel_g : natural              := 0;
        RamStyle_g      : string               := "auto";
        RamBehavior_g   : string               := "RBW";
        ReadyRstState_g : std_logic            := '1';
        EccPipeline_g   : natural range 0 to 2 := 0
    );
    port (
        -- Control Ports
        Clk               : in    std_logic;
        Rst               : in    std_logic;
        -- Input Data
        In_Data           : in    std_logic_vector(Width_g - 1 downto 0);
        In_Valid          : in    std_logic                                                := '1';
        In_Ready          : out   std_logic;
        In_Level          : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        -- Output Data
        Out_Data          : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Valid         : out   std_logic;
        Out_Ready         : in    std_logic                                                := '1';
        Out_Level         : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        Out_EccSec        : out   std_logic;
        Out_EccDed        : out   std_logic;
        -- Status
        Full              : out   std_logic;
        AlmFull           : out   std_logic;
        Empty             : out   std_logic;
        AlmEmpty          : out   std_logic;
        -- Error injection (independent of the data handshake)
        In_ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        In_ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_fifo_sync is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -- Encoder -> FIFO interface
    signal EncOut_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal EncOut_Valid    : std_logic;
    signal EncOut_Ready    : std_logic;

    -- FIFO -> decoder interface
    signal FifoOut_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal FifoOut_Valid    : std_logic;
    signal FifoOut_Ready    : std_logic;

begin

    -- Encoder: AXI-S handshake propagates user In_Valid/In_Ready through the codec, latch lives
    -- inside the codec. UseReady_g=true so the FIFO's back-pressure (FIFO.In_Ready) reaches the
    -- user's In_Ready.
    i_enc : entity work.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0,
            UseReady_g => true
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready,
            In_Data        => In_Data,
            Out_Valid      => EncOut_Valid,
            Out_Ready      => EncOut_Ready,
            Out_Codeword   => EncOut_Codeword,
            ErrInj_BitFlip => In_ErrInj_BitFlip,
            ErrInj_Valid   => In_ErrInj_Valid
        );

    -- Base FIFO with codeword-wide word
    i_fifo : entity work.olo_base_fifo_sync
        generic map (
            Width_g         => CodewordWidth_c,
            Depth_g         => Depth_g,
            AlmFullOn_g     => AlmFullOn_g,
            AlmFullLevel_g  => AlmFullLevel_g,
            AlmEmptyOn_g    => AlmEmptyOn_g,
            AlmEmptyLevel_g => AlmEmptyLevel_g,
            RamStyle_g      => RamStyle_g,
            RamBehavior_g   => RamBehavior_g,
            ReadyRstState_g => ReadyRstState_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => EncOut_Codeword,
            In_Valid  => EncOut_Valid,
            In_Ready  => EncOut_Ready,
            In_Level  => In_Level,
            Out_Data  => FifoOut_Codeword,
            Out_Valid => FifoOut_Valid,
            Out_Ready => FifoOut_Ready,
            Out_Level => Out_Level,
            Full      => Full,
            AlmFull   => AlmFull,
            Empty     => Empty,
            AlmEmpty  => AlmEmpty
        );

    -- Decoder: own pipeline stages (EccPipeline_g) and AXI-S handshake propagate FIFO's
    -- Out_Valid/Out_Ready to the user.
    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => EccPipeline_g,
            UseReady_g => true
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => FifoOut_Valid,
            In_Ready       => FifoOut_Ready,
            In_Codeword    => FifoOut_Codeword,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Out_Data       => Out_Data,
            Out_EccSec     => Out_EccSec,
            Out_EccDed     => Out_EccDed,
            ErrInj_BitFlip => (others => '0'),
            ErrInj_Valid   => '0'
        );

end architecture;
