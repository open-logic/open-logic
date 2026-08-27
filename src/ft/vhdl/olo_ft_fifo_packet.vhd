---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected synchronous packet FIFO using SECDED (Single Error Correction,
-- Double Error Detection) Hamming code. Wraps olo_base_fifo_packet with a wider
-- internal word to store parity bits alongside data. The ECC is transparent
-- to the user: data is encoded on write and decoded/corrected on read.
-- Note that FeatureSet_g=DROP_ONLY is not supported for fault-tolerance reasons
-- and that the entity is intentionally free of output pipelining
-- (see documentation).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_fifo_packet.md
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
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_fifo_packet is
    generic (
        Width_g            : positive;
        Depth_g            : positive;
        FeatureSet_g       : string                            := "FULL";
        RamStyle_g         : string                            := "auto";
        RamBehavior_g      : string                            := "RBW";
        SmallRamStyle_g    : string                            := "registers";
        SmallRamBehavior_g : string                            := "same";
        MaxPackets_g       : positive range 2 to positive'high := 17
    );
    port (
        -- Control Ports
        Clk               : in    std_logic;
        Rst               : in    std_logic;
        -- Input Data
        In_Valid          : in    std_logic                                                := '1';
        In_Ready          : out   std_logic;
        In_Data           : in    std_logic_vector(Width_g - 1 downto 0);
        In_Last           : in    std_logic                                                := '1';
        In_Drop           : in    std_logic                                                := '0';
        In_IsDropped      : out   std_logic;
        -- Output Data
        Out_Valid         : out   std_logic;
        Out_Ready         : in    std_logic                                                := '1';
        Out_Data          : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Size          : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        Out_Last          : out   std_logic;
        Out_Next          : in    std_logic                                                := '0';
        Out_Repeat        : in    std_logic                                                := '0';
        Out_EccSec        : out   std_logic;
        Out_EccDed        : out   std_logic;
        -- Status
        PacketLevel       : out   std_logic_vector(log2ceil(MaxPackets_g + 1) - 1 downto 0);
        FreeWords         : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        -- Error injection (independent of the data handshake)
        In_ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        In_ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_fifo_packet is

    constant EntityName_c    : string   := "olo_ft_fifo_packet";
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);
    constant SizeWidth_c     : positive := log2ceil(Depth_g + 1);

    -- Encoder -> FIFO
    signal EncOut_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal EncOut_Valid    : std_logic;
    signal EncOut_Ready    : std_logic;

    -- FIFO -> decoder
    signal Fifo_OutData  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Fifo_OutValid : std_logic;
    signal Fifo_OutReady : std_logic;

begin

    -- In DROP_ONLY mode the base FIFO stores the In_Last flag inside the main RAM, where it is
    -- not covered by the ECC parity. Only the feature sets that keep the main RAM a pure ECC
    -- codeword (packet boundaries in the separate small FIFO) are supported.
    assert not compareNoCase(FeatureSet_g, "drop_only")
        report errorMessage(EntityName_c, "FeatureSet_g=DROP_ONLY is not supported " &
               "(In_Last would be stored in RAM outside the ECC codeword). " &
               "Use FULL or DROP_SKIP_ONLY.")
        severity error;

    -- Encoder: codec owns the injection latch. AXI-S handshake propagates user In_Valid/In_Ready
    -- through to the FIFO's In_Valid/In_Ready.
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

    -- Base packet FIFO with wider codeword width
    i_fifo : entity work.olo_base_fifo_packet
        generic map (
            Width_g            => CodewordWidth_c,
            Depth_g            => Depth_g,
            FeatureSet_g       => FeatureSet_g,
            RamStyle_g         => RamStyle_g,
            RamBehavior_g      => RamBehavior_g,
            SmallRamStyle_g    => SmallRamStyle_g,
            SmallRamBehavior_g => SmallRamBehavior_g,
            MaxPackets_g       => MaxPackets_g
        )
        port map (
            Clk          => Clk,
            Rst          => Rst,
            In_Valid     => EncOut_Valid,
            In_Ready     => EncOut_Ready,
            In_Data      => EncOut_Codeword,
            In_Last      => In_Last,
            In_Drop      => In_Drop,
            In_IsDropped => In_IsDropped,
            Out_Valid    => Fifo_OutValid,
            Out_Ready    => Fifo_OutReady,
            Out_Data     => Fifo_OutData,
            Out_Size     => Out_Size,
            Out_Last     => Out_Last,
            Out_Next     => Out_Next,
            Out_Repeat   => Out_Repeat,
            PacketLevel  => PacketLevel,
            FreeWords    => FreeWords
        );

    -- Decoder. Combinational by design so that the read-side control (Out_Next, Out_Repeat) and
    -- the status act on the beat the user actually observes, see documentation.
    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0,
            UseReady_g => true
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => Fifo_OutValid,
            In_Ready       => Fifo_OutReady,
            In_Codeword    => Fifo_OutData,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Out_Data       => Out_Data,
            Out_EccSec     => Out_EccSec,
            Out_EccDed     => Out_EccDed,
            ErrInj_BitFlip => (others => '0'),
            ErrInj_Valid   => '0'
        );

end architecture;
