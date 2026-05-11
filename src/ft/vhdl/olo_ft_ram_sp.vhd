---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected single port RAM using SECDED (Single Error Correction,
-- Double Error Detection) Hamming code. Wraps olo_base_ram_sp with a wider
-- internal word to store parity bits alongside data. The ECC is transparent
-- to the user: data is encoded on write and decoded/corrected on read.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ram_sp.md
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
entity olo_ft_ram_sp is
    generic (
        Depth_g        : positive;
        Width_g        : positive;
        RamRdLatency_g : positive := 1;
        RamStyle_g     : string   := "auto";
        RamBehavior_g  : string   := "RBW";
        EccPipeline_g  : natural  := 0
    );
    port (
        Clk          : in    std_logic;
        Addr         : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        WrEna        : in    std_logic                               := '1';
        WrData       : in    std_logic_vector(Width_g - 1 downto 0);
        WrEccBitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        RdData       : out   std_logic_vector(Width_g - 1 downto 0);
        RdValid      : out   std_logic;
        RdEccSec     : out   std_logic;
        RdEccDed     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sp is

    constant CodewordWidth_c    : positive := eccCodewordWidth(Width_g);
    constant TotalReadLatency_c : positive := RamRdLatency_g + EccPipeline_g;

    signal Wr_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Rd_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);

    signal RdValidPipe : std_logic_vector(1 to TotalReadLatency_c) := (others => '0');

begin

    -- Encode write data (combinational + injection)
    i_enc : entity work.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0
        )
        port map (
            Clk          => Clk,
            In_Data      => WrData,
            In_BitFlip   => WrEccBitFlip,
            Out_Codeword => Wr_Codeword
        );

    -- Internal RAM with codeword-wide word
    i_ram : entity work.olo_base_ram_sp
        generic map (
            Depth_g       => Depth_g,
            Width_g       => CodewordWidth_c,
            RdLatency_g   => RamRdLatency_g,
            RamStyle_g    => RamStyle_g,
            RamBehavior_g => RamBehavior_g
        )
        port map (
            Clk    => Clk,
            Addr   => Addr,
            WrEna  => WrEna,
            WrData => Wr_Codeword,
            RdData => Rd_Codeword
        );

    -- Decode read data (with optional pipeline)
    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => EccPipeline_g
        )
        port map (
            Clk         => Clk,
            In_Codeword => Rd_Codeword,
            Out_Data    => RdData,
            Out_EccSec  => RdEccSec,
            Out_EccDed  => RdEccDed
        );

    -- Read-valid pipeline: a read happens whenever WrEna='0'. Delay matches data path.
    p_rd_valid : process (Clk) is
    begin
        if rising_edge(Clk) then
            RdValidPipe(1) <= not WrEna;
            for i in 2 to TotalReadLatency_c loop
                RdValidPipe(i) <= RdValidPipe(i - 1);
            end loop;
        end if;
    end process;

    RdValid <= RdValidPipe(TotalReadLatency_c);

end architecture;
