---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a pure VHDL and vendor indpendent true single-port RAM with
-- optional byte-enables.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_ram_sp.md
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
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_ram_sp is
    generic (
        Depth_g         : positive;
        Width_g         : positive;
        RdLatency_g     : positive := 1;
        RamStyle_g      : string   := "auto";
        RamBehavior_g   : string   := "RBW";
        UseByteEnable_g : boolean  := false;
        InitString_g    : string   := "";
        InitFormat_g    : string   := "NONE"
    );
    port (
        Clk             : in    std_logic;
        Addr            : in    std_logic_vector(log2ceil(Depth_g)-1 downto 0);
        Be              : in    std_logic_vector(Width_g / 8 - 1 downto 0) := (others => '1');
        WrEna           : in    std_logic                                  := '1';
        WrData          : in    std_logic_vector(Width_g - 1 downto 0);
        RdData          : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_ram_sp is

    -- Constants
    constant BeCount_c : integer := Width_g / 8;

    -- components
    component olo_private_ram_sp_nobe is
        generic (
            Depth_g         : positive;
            Width_g         : positive;
            RdLatency_g     : positive := 1;
            RamStyle_g      : string   := "auto";
            RamBehavior_g   : string   := "RBW";
            InitString_g    : string   := "";
            InitFormat_g    : string   := "NONE";
            InitWidth_g     : positive;
            InitShift_g     : natural  := 0
        );
        port (
            Clk             : in    std_logic;
            Addr            : in    std_logic_vector(log2ceil(Depth_g)-1 downto 0);
            WrEna           : in    std_logic := '1';
            WrData          : in    std_logic_vector(Width_g - 1 downto 0);
            RdData          : out   std_logic_vector(Width_g - 1 downto 0)
        );
    end component;

begin

    -- Assertions
    assert (Width_g mod 8 = 0) or (not UseByteEnable_g)
        report "olo_base_ram_sp: Width_g must be a multiple of 8, otherwise byte-enables must be disabled"
        severity error;

    -- No BE Implementation
    g_nobe : if not UseByteEnable_g generate

        i_ram : component olo_private_ram_sp_nobe
            generic map (
                Depth_g         => Depth_g,
                Width_g         => Width_g,
                RdLatency_g     => RdLatency_g,
                RamStyle_g      => RamStyle_g,
                RamBehavior_g   => RamBehavior_g,
                InitString_g    => InitString_g,
                InitFormat_g    => InitFormat_g,
                InitWidth_g     => Width_g
            )
            port map (
                Clk             => Clk,
                Addr            => Addr,
                WrEna           => WrEna,
                WrData          => WrData,
                RdData          => RdData
            );

    end generate;

    -- BE Implementation
    g_be : if UseByteEnable_g generate

        g_byte : for byte in 0 to BeCount_c-1 generate
            signal WrEna_Byte : std_logic;
        begin
            WrEna_Byte <= WrEna and Be(byte);

            i_ram : component olo_private_ram_sp_nobe
                generic map (
                    Depth_g         => Depth_g,
                    Width_g         => 8,
                    RdLatency_g     => RdLatency_g,
                    RamStyle_g      => RamStyle_g,
                    RamBehavior_g   => RamBehavior_g,
                    InitString_g    => InitString_g,
                    InitFormat_g    => InitFormat_g,
                    InitWidth_g     => Width_g,
                    InitShift_g     => byte*8
                )
                port map (
                    Clk             => Clk,
                    Addr            => Addr,
                    WrEna           => WrEna_Byte,
                    WrData          => WrData(byte*8+7 downto byte*8),
                    RdData          => RdData(byte*8+7 downto byte*8)
                );

        end generate;

    end generate;

end architecture;

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_attribute.all;
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_private_ram_sp_nobe is
    generic (
        Depth_g         : positive;
        Width_g         : positive;
        RdLatency_g     : positive := 1;
        RamStyle_g      : string   := "auto";
        RamBehavior_g   : string   := "RBW";
        InitString_g    : string   := "";
        InitFormat_g    : string   := "NONE";
        InitWidth_g     : positive;
        InitShift_g     : natural  := 0
    );
    port (
        Clk             : in    std_logic;
        Addr            : in    std_logic_vector(log2ceil(Depth_g)-1 downto 0);
        WrEna           : in    std_logic := '1';
        WrData          : in    std_logic_vector(Width_g - 1 downto 0);
        RdData          : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_private_ram_sp_nobe is

    -- Memory  Type
    type Data_t is array (natural range<>) of std_logic_vector(Width_g - 1 downto 0);

    -- Memory Initialization
    -- ... Cannot be moved to a package because VHDL93 (supported by all tools) does not allow
    -- ... unconstrainted arrays as return types.
    function getInitContent return Data_t is
        variable Data_v         : Data_t(Depth_g - 1 downto 0)               := (others => (others => '0'));
        constant InitElements_c : natural                                    := countOccurence(InitString_g, ',')+1;
        variable StartIdx_v     : natural                                    := InitString_g'left;
        variable EndIdx_v       : natural;
        variable FullInitVal_v  : std_logic_vector(InitWidth_g - 1 downto 0) := (others => '0');
    begin
        if InitFormat_g /= "NONE" then

            -- Loop through elements
            for i in 0 to InitElements_c - 1 loop
                EndIdx_v := StartIdx_v;

                -- Find end of element
                loop
                    if InitString_g(EndIdx_v) = ',' then
                        EndIdx_v := EndIdx_v - 1;
                        exit;
                    end if;
                    if EndIdx_v = InitString_g'right then
                        exit;
                    end if;
                    EndIdx_v := EndIdx_v + 1;
                end loop;

                FullInitVal_v := hex2StdLogicVector(InitString_g(StartIdx_v to EndIdx_v), InitWidth_g, hasPrefix => true);
                Data_v(i)     := FullInitVal_v(InitShift_g + Width_g - 1 downto InitShift_g);
                StartIdx_v    := EndIdx_v + 2;

            end loop;

        end if;
        return Data_v;
    end function;

    -- Memory array
    shared variable Mem_v : Data_t(Depth_g - 1 downto 0) := getInitContent;

    -- Read registers
    signal RdPipe : Data_t(1 to RdLatency_g);

    -- Synthesis attributes - Suppress shift register extraction
    attribute shreg_extract of RdPipe : signal is ShregExtract_SuppressExtraction_c;

    -- Synthesis attributes - RAM style
    attribute ram_style of Mem_v    : variable is RamStyle_g;
    attribute ramstyle of Mem_v     : variable is RamStyle_g;
    attribute syn_ramstyle of Mem_v : variable is RamStyle_g;

begin

    -- Assertionsa
    assert InitFormat_g = "NONE" or InitFormat_g = "HEX"
        report "olo_base_ram_sp: InitFormat_g must be NONE or HEX. Got: " & InitFormat_g
        severity error;
    assert RamBehavior_g = "RBW" or RamBehavior_g = "WBR"
        report "olo_base_ram_sp: RamBehavior_g must Be RBW or WBR. Got: " & RamBehavior_g
        severity error;

    -- RAM process
    p_ram : process (Clk) is
    begin
        if rising_edge(Clk) then
            if RamBehavior_g = "RBW" then
                RdPipe(1) <= Mem_v(to_integer(unsigned(Addr)));
            end if;
            if WrEna = '1' then
                Mem_v(to_integer(unsigned(Addr))) := WrData;
            end if;
            if RamBehavior_g = "WBR" then
                RdPipe(1) <= Mem_v(to_integer(unsigned(Addr)));
            end if;

            -- Read-data pipeline registers
            RdPipe(2 to RdLatency_g) <= RdPipe(1 to RdLatency_g-1);
        end if;
    end process;

    -- Output
    RdData <= RdPipe(RdLatency_g);

end architecture;

