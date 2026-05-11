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
-- Single-bit errors are corrected; double-bit errors are detected. The Out_*
-- signals are time-aligned.
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
    use work.olo_base_pkg_attribute.all;
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ecc_decode is
    generic (
        Width_g    : positive;
        Pipeline_g : natural := 0
    );
    port (
        Clk         : in    std_logic                                                  := '0';
        In_Codeword : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0);
        Out_Data    : out   std_logic_vector(Width_g - 1 downto 0);
        Out_EccSec  : out   std_logic;
        Out_EccDed  : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ecc_decode is

    constant ParityBits_c : positive := eccParityBits(Width_g);

    signal SynPar   : std_logic_vector(ParityBits_c downto 0);
    signal DataCorr : std_logic_vector(Width_g - 1 downto 0);
    signal EccSecI  : std_logic;
    signal EccDedI  : std_logic;

begin

    -- Combinational SECDED decode
    SynPar   <= eccSyndromeAndParity(In_Codeword, Width_g);
    DataCorr <= eccCorrectData(In_Codeword, SynPar, Width_g);
    EccSecI  <= eccSecError(SynPar);
    EccDedI  <= eccDedError(SynPar);

    -- No pipeline: combinational output
    g_no_pipe : if Pipeline_g = 0 generate
        Out_Data   <= DataCorr;
        Out_EccSec <= EccSecI;
        Out_EccDed <= EccDedI;
    end generate;

    -- Pipeline: register stages after decode
    g_pipe : if Pipeline_g > 0 generate
        type Data_t is array (natural range <>) of std_logic_vector(Width_g - 1 downto 0);
        signal DataPipe : Data_t(1 to Pipeline_g);
        signal SecPipe  : std_logic_vector(1 to Pipeline_g);
        signal DedPipe  : std_logic_vector(1 to Pipeline_g);
        attribute shreg_extract of DataPipe : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of SecPipe  : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of DedPipe  : signal is ShregExtract_SuppressExtraction_c;
    begin
        p_pipe : process (Clk) is
        begin
            if rising_edge(Clk) then
                DataPipe(1) <= DataCorr;
                SecPipe(1)  <= EccSecI;
                DedPipe(1)  <= EccDedI;
                DataPipe(2 to Pipeline_g) <= DataPipe(1 to Pipeline_g - 1);
                SecPipe(2 to Pipeline_g)  <= SecPipe(1 to Pipeline_g - 1);
                DedPipe(2 to Pipeline_g)  <= DedPipe(1 to Pipeline_g - 1);
            end if;
        end process;
        Out_Data   <= DataPipe(Pipeline_g);
        Out_EccSec <= SecPipe(Pipeline_g);
        Out_EccDed <= DedPipe(Pipeline_g);
    end generate;

end architecture;
