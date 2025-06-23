---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a delay element. It is either emplemented in BRAM or SRL. The output
-- is always a fabric register for improved timing.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_delay.md
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

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_delay is
    generic (
        Width_g         : positive;
        Delay_g         : natural;
        Resource_g      : string                            := "AUTO";
        BramThreshold_g : positive range 3 to positive'high := 128;
        RstState_g      : boolean                           := True;
        RamBehavior_g   : string                            := "RBW"
    );
    port (
        -- Control Ports
        Clk      : in    std_logic;
        Rst      : in    std_logic;
        -- Data
        In_Data  : in    std_logic_vector(Width_g-1 downto 0);
        In_Valid : in    std_logic := '1';
        Out_Data : out   std_logic_vector(Width_g-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_delay is

    signal MemOut      : std_logic_vector(Width_g - 1 downto 0);
    constant MemTaps_c : natural := work.olo_base_pkg_math.max(Delay_g - 1, 0);

begin

    -- *** Assertions ***
    assert Resource_g = "AUTO" or Resource_g = "SRL" or Resource_g = "BRAM"
        report "###ERROR###: olo_base_delay: Unknown Resource_g - " & Resource_g
        severity error;
    assert Resource_g /= "BRAM" or Delay_g >= 3
        report "###ERROR###: olo_base_delay: Delay_g >= 3 required for Resource_g=BRAM"
        severity error;
    assert BramThreshold_g > 3
        report "###ERROR###: olo_base_delay: BramThreshold_g must be > 3"
        severity error;

    -- *** SRL ***
    g_srl : if (Delay_g > 1) and ((Resource_g = "SRL") or ((Resource_g = "AUTO") and (Delay_g < BramThreshold_g))) generate
        -- local types
        type Srl_t is array (0 to MemTaps_c - 1) of std_logic_vector(Width_g - 1 downto 0);

        -- local signals
        signal SrlSig : Srl_t := (others => (others => '0'));

        -- Synthesis attributes
        attribute shreg_extract of SrlSig : signal is ShregExtract_AllowExtraction_c;
        attribute srl_style of SrlSig     : signal is SrlStyle_Srl_c;
    begin

        p_srl : process (Clk) is
        begin
            if rising_edge(Clk) then
                if In_Valid = '1' then
                    SrlSig(0)                <= In_Data;
                    SrlSig(1 to SrlSig'high) <= SrlSig(0 to SrlSig'high - 1);
                end if;
            end if;
        end process;

        MemOut <= SrlSig(SrlSig'high);
    end generate;

    -- *** BRAM ***
    g_bram : if (Delay_g > 1) and ((Resource_g = "BRAM") or ((Resource_g = "AUTO") and (Delay_g >= BramThreshold_g))) generate
        signal RdAddr, WrAddr : std_logic_vector(log2ceil(MemTaps_c) - 1 downto 0) := (others => '0');
    begin

        -- address control process
        p_bram : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- normal Operation
                if In_Valid = '1' then
                    -- write address
                    if unsigned(WrAddr) = MemTaps_c - 1 then
                        WrAddr <= (others => '0');
                    else
                        WrAddr <= std_logic_vector(unsigned(WrAddr) + 1);
                    end if;
                    -- read address
                    if unsigned(RdAddr) = MemTaps_c - 1 then
                        RdAddr <= (others => '0');
                    else
                        RdAddr <= std_logic_vector(unsigned(RdAddr) + 1);
                    end if;
                end if;

                -- Reset
                if Rst = '1' then
                    WrAddr <= std_logic_vector(to_unsigned(MemTaps_c - 1, WrAddr'length));
                    RdAddr <= (others => '0');
                end if;
            end if;
        end process;

        -- memory instantiation
        i_bram : entity work.olo_base_ram_sdp
            generic map (
                Depth_g         => MemTaps_c,
                Width_g         => Width_g,
                RamBehavior_g   => RamBehavior_g
            )
            port map (
                Clk     => Clk,
                Wr_Addr => WrAddr,
                Wr_Ena  => In_Valid,
                Wr_Data => In_Data,
                Rd_Addr => RdAddr,
                Rd_Ena  => In_Valid,
                Rd_Data => MemOut
            );

    end generate;

    -- *** Single Stage ***
    g_single : if Delay_g = 1 generate
        MemOut <= In_Data;
    end generate;

    -- *** Output register ***
    g_zero : if Delay_g = 0 generate
        Out_Data <= In_Data;
    end generate;

    g_nonzero : if Delay_g > 0 generate
        signal RstStateCnt : integer range 0 to Delay_g - 1;
    begin

        p_outreg : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Normal operation
                if In_Valid = '1' then
                    if RstState_g = false or RstStateCnt = Delay_g - 1 then
                        Out_Data <= MemOut;
                    else
                        Out_Data    <= (others => '0');
                        RstStateCnt <= RstStateCnt + 1;
                    end if;
                end if;

                -- Reset
                if Rst = '1' then
                    Out_Data    <= (others => '0');
                    RstStateCnt <= 0;
                end if;
            end if;
        end process;

    end generate;

end architecture;

