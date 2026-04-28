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
    use work.olo_base_pkg_attribute.all;
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ram_sp is
    generic (
        Depth_g       : positive;
        Width_g       : positive;
        RdLatency_g   : positive := 1;
        RamStyle_g    : string   := "auto";
        RamBehavior_g : string   := "RBW";
        EccPipeline_g : natural  := 0
    );
    port (
        Clk          : in    std_logic;
        Addr         : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        WrEna        : in    std_logic                               := '1';
        WrData       : in    std_logic_vector(Width_g - 1 downto 0);
        WrEccBitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        RdData       : out   std_logic_vector(Width_g - 1 downto 0);
        RdEccSec     : out   std_logic;
        RdEccDed     : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sp is

    -- ECC constants
    constant ParityBits_c    : positive := eccParityBits(Width_g);
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -- Write-side signals
    signal Wr_Encoded  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Wr_Injected : std_logic_vector(CodewordWidth_c - 1 downto 0);

    -- Read-side signals
    signal Rd_Encoded  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Rd_SynPar   : std_logic_vector(ParityBits_c downto 0);
    signal Rd_DataCorr : std_logic_vector(Width_g - 1 downto 0);
    signal Rd_EccSecI  : std_logic;
    signal Rd_EccDedI  : std_logic;

begin

    -- Encode write data
    Wr_Encoded <= eccEncode(WrData);

    -- Error injection (XOR full bit-flip pattern into the encoded codeword for testing / BIST)
    Wr_Injected <= Wr_Encoded xor WrEccBitFlip;

    -- Internal RAM with wider codeword width
    i_ram : entity work.olo_base_ram_sp
        generic map (
            Depth_g       => Depth_g,
            Width_g       => CodewordWidth_c,
            RdLatency_g   => RdLatency_g,
            RamStyle_g    => RamStyle_g,
            RamBehavior_g => RamBehavior_g
        )
        port map (
            Clk    => Clk,
            Addr   => Addr,
            WrEna  => WrEna,
            WrData => Wr_Injected,
            RdData => Rd_Encoded
        );

    -- Decode read data (combinational)
    Rd_SynPar  <= eccSyndromeAndParity(Rd_Encoded, Width_g);
    Rd_DataCorr <= eccCorrectData(Rd_Encoded, Rd_SynPar, Width_g);
    Rd_EccSecI <= eccSecError(Rd_SynPar);
    Rd_EccDedI <= eccDedError(Rd_SynPar);

    -- No ECC pipeline: direct output
    g_no_ecc_pipe : if EccPipeline_g = 0 generate
        RdData   <= Rd_DataCorr;
        RdEccSec <= Rd_EccSecI;
        RdEccDed <= Rd_EccDedI;
    end generate;

    -- ECC pipeline: register stages after decode
    g_ecc_pipe : if EccPipeline_g > 0 generate
        type Data_t is array (natural range <>) of std_logic_vector(Width_g - 1 downto 0);
        signal DataPipe   : Data_t(1 to EccPipeline_g);
        signal EccSecPipe : std_logic_vector(1 to EccPipeline_g);
        signal EccDedPipe : std_logic_vector(1 to EccPipeline_g);
        attribute shreg_extract of DataPipe   : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of EccSecPipe : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of EccDedPipe : signal is ShregExtract_SuppressExtraction_c;
    begin
        p_ecc_pipe : process (Clk) is
        begin
            if rising_edge(Clk) then
                DataPipe(1)   <= Rd_DataCorr;
                EccSecPipe(1) <= Rd_EccSecI;
                EccDedPipe(1) <= Rd_EccDedI;
                DataPipe(2 to EccPipeline_g)   <= DataPipe(1 to EccPipeline_g - 1);
                EccSecPipe(2 to EccPipeline_g) <= EccSecPipe(1 to EccPipeline_g - 1);
                EccDedPipe(2 to EccPipeline_g) <= EccDedPipe(1 to EccPipeline_g - 1);
            end if;
        end process;
        RdData   <= DataPipe(EccPipeline_g);
        RdEccSec <= EccSecPipe(EccPipeline_g);
        RdEccDed <= EccDedPipe(EccPipeline_g);
    end generate;

end architecture;
