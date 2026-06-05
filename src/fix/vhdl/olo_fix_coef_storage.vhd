---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a fixed-point coefficient storage. The storage can be ROM or RAM and if
-- it is a RAM, it can be written and read from outside (to update coefficients at runtime).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_coef_storage.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_array.all;
    use work.olo_base_pkg_attribute.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_coef_storage is
    generic (
        -- Functionality
        Depth_g       : positive;
        Fmt_g         : string;
        Init_g        : string   := "0.0";
        StorageType_g : string   := "ROM";
        RamReadback_g : boolean  := false;
        RamBehavior_g : string   := "RBW";
        RdLatency_g   : positive := 1;
        MemStyle_g    : string   := "auto"
    );
    port (
        -- Control Ports
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        -- Config Port
        Cfg_Addr     : in    std_logic_vector(log2Ceil(Depth_g) - 1 downto 0)            := (others => '0');
        Cfg_WrEna    : in    std_logic                                                   := '0';
        Cfg_WrData   : in    std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0) := (others => '0');
        Cfg_RdEna    : in    std_logic                                                   := '0';
        Cfg_RdData   : out   std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
        Cfg_RdValid  : out   std_logic;
        -- Coefficient Port
        Coef_Addr    : in    std_logic_vector(log2Ceil(Depth_g) - 1 downto 0)            := (others => '0');
        Coef_RdEna   : in    std_logic                                                   := '0';
        Coef_RdData  : out   std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
        Coef_RdValid : out   std_logic
    );
end entity;

architecture rtl of olo_fix_coef_storage is

    -- *** Formats ***
    constant Fmt_c : FixFormat_t := cl_fix_format_from_string(Fmt_g);

    -- *** Types ***
    subtype Data_t is std_logic_vector(fixFmtWidthFromString(Fmt_g) - 1 downto 0);
    type DataArray_t is array (natural range <>) of Data_t;

    -- *** Functions ***
    function initData return DataArray_t is
        constant InitReal_c : RealArray_t                   := fromString(Init_g);
        variable Data_v     : DataArray_t(0 to Depth_g - 1) := (others => (others => '0'));
    begin

        -- Initialize elements that have an initializer
        for i in 0 to InitReal_c'high loop
            Data_v(i) := cl_fix_from_real(InitReal_c(i), Fmt_c);
        end loop;

        return Data_v;
    end function;

    -- *** Constants ***
    constant EntityName_c : string := "olo_fix_coef_storage";

    -- *** Signals ***
    signal CoefPipe      : DataArray_t(1 to RdLatency_g);
    signal CoefValidPipe : std_logic_vector(1 to RdLatency_g);
    attribute shreg_extract of CoefPipe      : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of CoefValidPipe : signal is ShregExtract_SuppressExtraction_c;

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert compareNoCase(StorageType_g, "RAM") or compareNoCase(StorageType_g, "ROM")
        report errorMessage(EntityName_c, "Invalid StorageType_g. Allowed values are 'RAM' and 'ROM'.")
        severity error;
    assert compareNoCase(RamBehavior_g, "RBW") or compareNoCase(RamBehavior_g, "WBR")
        report errorMessage(EntityName_c, "Invalid RamBehavior_g. Allowed values are 'RBW' and 'WBR'.")
        severity error;
    -- synthesis translate_on

    -- *** ROM Implementation ***
    g_rom : if compareNoCase(StorageType_g, "ROM") generate
        -- Implemented as shared variable becaus attributes do not apply properly to constants
        shared variable Rom_v : DataArray_t(0 to Depth_g - 1) := initData;

        -- Synthesis attributes - control ROM style
        attribute rom_style of Rom_v    : variable is MemStyle_g;
        attribute romstyle of Rom_v     : variable is MemStyle_g;
        attribute syn_romstyle of Rom_v : variable is MemStyle_g;

    begin

        p_rom : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Default VAlues
                CoefValidPipe(1) <= Coef_RdEna;

                -- Read ROM
                if Coef_RdEna = '1' then
                    CoefPipe(1) <= Rom_v(fromUslv(Coef_Addr));
                end if;

                -- Read-data pipeline registers
                CoefPipe(2 to RdLatency_g)      <= CoefPipe(1 to RdLatency_g-1);
                CoefValidPipe(2 to RdLatency_g) <= CoefValidPipe(1 to RdLatency_g-1);

                -- Reset
                if Rst = '1' then
                    CoefValidPipe <= (others => '0');
                end if;
            end if;
        end process;

        -- Assign outputs
        Coef_RdData  <= CoefPipe(RdLatency_g);
        Coef_RdValid <= CoefValidPipe(RdLatency_g);
        Cfg_RdData   <= (others => '0');
        Cfg_RdValid  <= '0';
    end generate;

    -- *** RAM Implementation ***
    g_ram : if compareNoCase(StorageType_g, "RAM") generate
        -- Memory Array
        shared variable Ram_v : DataArray_t(0 to Depth_g - 1) := initData;

        -- Synthesis attributes - control RAM style
        attribute ram_style of Ram_v    : variable is MemStyle_g;
        attribute ramstyle of Ram_v     : variable is MemStyle_g;
        attribute syn_ramstyle of Ram_v : variable is MemStyle_g;

        -- Signals
        signal RdPipe      : DataArray_t(1 to RdLatency_g);
        signal RdValidPipe : std_logic_vector(1 to RdLatency_g);
        attribute shreg_extract of RdValidPipe : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of RdPipe      : signal is ShregExtract_SuppressExtraction_c;

    begin

        -- Valid signal pipelines
        p_valid : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Default Values
                CoefValidPipe(1) <= Coef_RdEna;
                if RamReadback_g then
                    RdValidPipe(1) <= Cfg_RdEna;
                else
                    RdValidPipe(1) <= '0';
                end if;

                -- Pipeline registers
                CoefValidPipe(2 to RdLatency_g) <= CoefValidPipe(1 to RdLatency_g-1);
                RdValidPipe(2 to RdLatency_g)   <= RdValidPipe(1 to RdLatency_g-1);

                -- Reset
                if Rst = '1' then
                    CoefValidPipe <= (others => '0');
                    RdValidPipe   <= (others => '0');
                end if;
            end if;
        end process;

        -- RAM implementation
        -- Code optimized to be mapped efficiently by all vendors
        g_wbr : if compareNoCase(RamBehavior_g, "WBR") generate

            p_ram : process (Clk) is
            begin
                if rising_edge(Clk) then
                    -- RAM
                    if Cfg_WrEna = '1' then
                        Ram_v(fromUslv(Cfg_Addr)) := Cfg_WrData;
                    end if;
                    RdPipe(1)   <= Ram_v(fromUslv(Cfg_Addr));
                    CoefPipe(1) <= Ram_v(fromUslv(Coef_Addr));

                    -- Read-data pipeline registers
                    RdPipe(2 to RdLatency_g)   <= RdPipe(1 to RdLatency_g-1);
                    CoefPipe(2 to RdLatency_g) <= CoefPipe(1 to RdLatency_g-1);
                end if;
            end process;

        end generate;

        g_rbw : if compareNoCase(RamBehavior_g, "RBW") generate

            p_ram : process (Clk) is
            begin
                if rising_edge(Clk) then
                    -- RAM
                    RdPipe(1)   <= Ram_v(fromUslv(Cfg_Addr));
                    CoefPipe(1) <= Ram_v(fromUslv(Coef_Addr));
                    if Cfg_WrEna = '1' then
                        Ram_v(fromUslv(Cfg_Addr)) := Cfg_WrData;
                    end if;

                    -- Read-data pipeline registers
                    RdPipe(2 to RdLatency_g)   <= RdPipe(1 to RdLatency_g-1);
                    CoefPipe(2 to RdLatency_g) <= CoefPipe(1 to RdLatency_g-1);
                end if;
            end process;

        end generate;

        -- Assign outputs
        Cfg_RdData   <= RdPipe(RdLatency_g) when RamReadback_g else (others => '0');
        Cfg_RdValid  <= RdValidPipe(RdLatency_g) when RamReadback_g else '0';
        Coef_RdData  <= CoefPipe(RdLatency_g);
        Coef_RdValid <= CoefValidPipe(RdLatency_g);

    end generate;

end architecture;
