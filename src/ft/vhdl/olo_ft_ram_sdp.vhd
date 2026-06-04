---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected simple dual-port RAM using SECDED (Single Error Correction,
-- Double Error Detection) Hamming code. Wraps olo_base_ram_sdp with a wider
-- internal word to store parity bits alongside data. The ECC is transparent
-- to the user: data is encoded on write and decoded/corrected on read.
--
-- For an opportunistic background memory scrubber, use olo_ft_ram_sdp_scrub
-- (separate entity, sync-only).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ram_sdp.md
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
entity olo_ft_ram_sdp is
    generic (
        Depth_g        : positive;
        Width_g        : positive;
        IsAsync_g      : boolean              := false;
        RamRdLatency_g : positive             := 1;
        RamStyle_g     : string               := "auto";
        RamBehavior_g  : string               := "RBW";
        EccPipeline_g  : natural range 0 to 2 := 0
    );
    port (
        -- Clock and Reset
        Clk            : in    std_logic;
        Rst            : in    std_logic                                                := '0';
        Rd_Clk         : in    std_logic                                                := '0';
        Rd_Rst         : in    std_logic                                                := '0';
        -- Write Port
        Wr_Addr        : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena         : in    std_logic                                                := '1';
        Wr_Data        : in    std_logic_vector(Width_g - 1 downto 0);
        -- Read Port
        Rd_Addr        : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Rd_Ena         : in    std_logic                                                := '1';
        Rd_Data        : out   std_logic_vector(Width_g - 1 downto 0);
        Rd_Valid       : out   std_logic;
        Rd_EccSec      : out   std_logic;
        Rd_EccDed      : out   std_logic;
        -- Error Injection
        ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sdp is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -- Read-clock muxing: in async mode use the user-supplied Rd_Clk / Rd_Rst, otherwise share
    -- the write clock + reset.
    signal RdClk : std_logic;
    signal RdRst : std_logic;

    -- Codec / RAM datapath
    signal Wr_Codeword  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Rd_Codeword  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Ram_Rd_Valid : std_logic;

begin

    -- Read clock / reset selection
    g_async : if IsAsync_g generate
        RdClk <= Rd_Clk;
        RdRst <= Rd_Rst;
    end generate;

    g_sync : if not IsAsync_g generate
        RdClk <= Clk;
        RdRst <= Rst;
    end generate;

    -- Encode write data. UseReady_g=false because the RAM never backpressures the encoder.
    i_enc : entity work.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0,
            UseReady_g => false
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => Wr_Ena,
            In_Ready       => open,
            In_Data        => Wr_Data,
            Out_Valid      => open,
            Out_Ready      => '1',
            Out_Codeword   => Wr_Codeword,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
        );

    -- Internal RAM with codeword-wide word.
    i_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g       => Depth_g,
            Width_g       => CodewordWidth_c,
            IsAsync_g     => IsAsync_g,
            RdLatency_g   => RamRdLatency_g,
            RamStyle_g    => RamStyle_g,
            RamBehavior_g => RamBehavior_g
        )
        port map (
            Clk      => Clk,
            Rst      => Rst,
            Wr_Addr  => Wr_Addr,
            Wr_Ena   => Wr_Ena,
            Wr_Data  => Wr_Codeword,
            Rd_Clk   => Rd_Clk,
            Rd_Rst   => Rd_Rst,
            Rd_Addr  => Rd_Addr,
            Rd_Ena   => Rd_Ena,
            Rd_Data  => Rd_Codeword,
            Rd_Valid => Ram_Rd_Valid
        );

    -- Decode read data (with optional pipeline).
    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => EccPipeline_g,
            UseReady_g => false
        )
        port map (
            Clk            => RdClk,
            Rst            => RdRst,
            In_Valid       => Ram_Rd_Valid,
            In_Ready       => open,
            In_Codeword    => Rd_Codeword,
            Out_Valid      => Rd_Valid,
            Out_Ready      => '1',
            Out_Data       => Rd_Data,
            Out_EccSec     => Rd_EccSec,
            Out_EccDed     => Rd_EccDed,
            ErrInj_BitFlip => (others => '0'),
            ErrInj_Valid   => '0'
        );

end architecture;
