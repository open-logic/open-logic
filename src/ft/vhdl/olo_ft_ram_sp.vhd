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
        RamRdLatency_g : positive             := 1;
        RamStyle_g     : string               := "auto";
        RamBehavior_g  : string               := "RBW";
        EccPipeline_g  : natural range 0 to 2 := 0
    );
    port (
        Clk            : in    std_logic;
        Rst            : in    std_logic                                                := '0';
        Addr           : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        WrEna          : in    std_logic                                                := '1';
        WrData         : in    std_logic_vector(Width_g - 1 downto 0);
        ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid   : in    std_logic                                                := '0';
        RdData         : out   std_logic_vector(Width_g - 1 downto 0);
        RdValid        : out   std_logic;
        RdEccSec       : out   std_logic;
        RdEccDed       : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sp is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    signal Wr_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal Rd_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);

    -- Read-enable pipeline aligned with the wrapped RAM's read latency. The encode entity
    -- accepts WrEna as its handshake; the decode entity's In_Valid then needs to track when a
    -- fresh codeword (i.e. a read, not a write) is appearing at the RAM read port. We delay
    -- (not WrEna) by exactly RamRdLatency_g cycles to align with that read result. The decode
    -- entity contributes the remaining EccPipeline_g cycles via its own Out_Valid.
    signal RdEnaPipe : std_logic_vector(1 to RamRdLatency_g) := (others => '0');

begin

    -- Encode write data with the new AXI-S codec entity. The codec owns the injection latch.
    -- We never backpressure (Out_Ready always '1') and we don't need shadow registers
    -- internally, so UseReady_g=false.
    i_enc : entity work.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0,
            UseReady_g => false
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => WrEna,
            In_Ready       => open,
            In_Data        => WrData,
            Out_Valid      => open,
            Out_Ready      => '1',
            Out_Codeword   => Wr_Codeword,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
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

    -- Delay (not WrEna) by RamRdLatency_g to drive decode.In_Valid in lockstep with the
    -- codeword that just came out of the RAM.
    p_rd_ena_pipe : process (Clk) is
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                RdEnaPipe <= (others => '0');
            else
                RdEnaPipe(1) <= not WrEna;

                for i in 2 to RamRdLatency_g loop
                    RdEnaPipe(i) <= RdEnaPipe(i - 1);
                end loop;

            end if;
        end if;
    end process;

    -- Decode read data (with optional pipeline). Out_Valid is the user-facing RdValid.
    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => EccPipeline_g,
            UseReady_g => false
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => RdEnaPipe(RamRdLatency_g),
            In_Ready       => open,
            In_Codeword    => Rd_Codeword,
            Out_Valid      => RdValid,
            Out_Ready      => '1',
            Out_Data       => RdData,
            Out_EccSec     => RdEccSec,
            Out_EccDed     => RdEccDed,
            ErrInj_BitFlip => (others => '0'),
            ErrInj_Valid   => '0'
        );

end architecture;
