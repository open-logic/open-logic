---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC encoder entity. Wraps the SECDED encode function from olo_ft_pkg_ecc into
-- a reusable, optionally pipelined entity that is also accessible from Verilog.
-- Includes an optional codeword-wide bit-flip injection input for BIST/testing.
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
    use work.olo_base_pkg_attribute.all;
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ecc_encode is
    generic (
        Width_g    : positive;
        Pipeline_g : natural := 0
    );
    port (
        Clk          : in    std_logic                                                  := '0';
        In_Data      : in    std_logic_vector(Width_g - 1 downto 0);
        In_BitFlip   : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0)   := (others => '0');
        Out_Codeword : out   std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ecc_encode is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    signal Encoded  : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Injected : std_logic_vector(CodewordWidth_c - 1 downto 0);

begin

    -- Combinational SECDED encode + injection
    Encoded  <= eccEncode(In_Data);
    Injected <= Encoded xor In_BitFlip;

    -- No pipeline: combinational output
    g_no_pipe : if Pipeline_g = 0 generate
        Out_Codeword <= Injected;
    end generate;

    -- Pipeline: register stages after encode/injection
    g_pipe : if Pipeline_g > 0 generate
        type Pipe_t is array (natural range <>) of std_logic_vector(CodewordWidth_c - 1 downto 0);
        signal Pipe : Pipe_t(1 to Pipeline_g);
        attribute shreg_extract of Pipe : signal is ShregExtract_SuppressExtraction_c;
    begin
        p_pipe : process (Clk) is
        begin
            if rising_edge(Clk) then
                Pipe(1) <= Injected;
                Pipe(2 to Pipeline_g) <= Pipe(1 to Pipeline_g - 1);
            end if;
        end process;
        Out_Codeword <= Pipe(Pipeline_g);
    end generate;

end architecture;
