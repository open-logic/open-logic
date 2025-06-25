---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Benoit Stef & Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a delay element. It is either implemented in BRAM & SRL. The output
-- is always a fabric register for improved timing.
-- The delay is settable by a input and not fixed as the olo_base_delay.
-- Changes in delay value are present at the output within less than 5 samlpes.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_delay_cfg.md
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

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_delay_cfg is
    generic (
        Width_g         : positive;
        MaxDelay_g      : positive := 256;
        SupportZero_g   : boolean  := false;
        RamBehavior_g   : string   := "RBW"
    );
    port (
        -- Control Ports
        Clk      : in    std_logic;
        Rst      : in    std_logic;
        Delay    : in    std_logic_vector(log2ceil(MaxDelay_g+1)-1 downto 0);
        -- Data
        In_Data  : in    std_logic_vector(Width_g - 1 downto 0);
        In_Valid : in    std_logic;
        Out_Data : out   std_logic_vector((Width_g - 1) downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_delay_cfg is

    -- types
    type Srl_t is array (0 to 1) of std_logic_vector(Width_g - 1 downto 0);

    -- signals
    signal SrlSig     : Srl_t                                  := (others => (others => '0'));
    signal OutNonzero : std_logic_vector(Width_g - 1 downto 0);
    signal MemOut     : std_logic_vector(Width_g - 1 downto 0) := (others => '0');

begin

    -- *** Ram is used for delays > 3 ***
    g_ram : if MaxDelay_g > 3 generate
        signal RdAddr, WrAddr : std_logic_vector(log2ceil(MaxDelay_g) - 1 downto 0) := (others => '0');
    begin

        -- *** address control process ***
        p_bram : process (Clk) is
            variable RdAddr_v : std_logic_vector(Delay'range);
        begin
            if rising_edge(Clk) then
                -- Normal Operation
                if In_Valid = '1' then
                    -- address mngt
                    WrAddr <= std_logic_vector(unsigned(WrAddr) + 1);
                    -- In corner cases "Delay" has 1 bit more than the addresses. Example: MaxDelay_g=256.
                    -- ... this is the case for all powers of 2 (which are often used values for digital
                    -- designers))
                    RdAddr_v := std_logic_vector(unsigned(WrAddr) - unsigned(Delay) + 3);
                    RdAddr   <= RdAddr_v(RdAddr'range);
                end if;

                -- Reset
                if Rst = '1' then
                    WrAddr <= (others => '0');
                    RdAddr <= (others => '0');
                end if;
            end if;
        end process;

        -- *** memory instantiation ***
        i_bram : entity work.olo_base_ram_sdp
            generic map (
                Depth_g         => 2**log2ceil(MaxDelay_g),
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

    -- *** Shift Register for delays <= 3 ***
    p_srl : process (Clk) is
    begin
        if rising_edge(Clk) then
            if In_Valid = '1' then
                SrlSig(0) <= In_Data;
                SrlSig(1) <= SrlSig(0);
            end if;
        end if;
    end process;

    -- *** Output register ***
    p_outreg : process (Clk) is
        variable DelayInt_v : natural range 0 to MaxDelay_g;
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            DelayInt_v := fromUslv(Delay);
            if In_Valid = '1' then

                case DelayInt_v is
                    when 1 =>  OutNonzero <= In_Data;
                    when 2 =>  OutNonzero <= SrlSig(0);
                    when 3 =>  OutNonzero <= SrlSig(1);
                    when others => OutNonzero <= MemOut;
                end case;

            end if;

            -- Reset
            if Rst = '1' then
                OutNonzero <= (others => '0');
            end if;
        end if;
    end process;

    g_supportzero : if SupportZero_g generate
        Out_Data <= OutNonzero when fromUslv(Delay) /= 0 else In_Data;
    end generate;

    g_nozero : if not SupportZero_g generate
        Out_Data <= OutNonzero;
    end generate;

end architecture;
