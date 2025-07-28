---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a pure VHDL and vendor indpendent simple dual port RAM with
-- optional byte enables.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_ram_sdp.md
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
entity olo_base_ram_sdp is
    generic (
        Depth_g         : positive;
        Width_g         : positive;
        IsAsync_g       : boolean  := false;
        RdLatency_g     : positive := 1;
        RamStyle_g      : string   := "auto";
        RamBehavior_g   : string   := "RBW";
        UseByteEnable_g : boolean  := false;
        InitString_g    : string   := "";
        InitFormat_g    : string   := "NONE"
    );
    port (
        Clk         : in    std_logic;
        Wr_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena      : in    std_logic                                  := '1';
        Wr_Be       : in    std_logic_vector(Width_g / 8 - 1 downto 0) := (others => '1');
        Wr_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Rd_Clk      : in    std_logic                                  := '0';
        Rd_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Rd_Ena      : in    std_logic                                  := '1';
        Rd_Data     : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_ram_sdp is

    -- constants
    constant BeCount_c : integer := Width_g / 8;

    -- components
    component olo_private_ram_sdp_nobe is
        generic (
            Depth_g         : positive;
            Width_g         : positive;
            IsAsync_g       : boolean  := false;
            RdLatency_g     : positive := 1;
            RamStyle_g      : string   := "auto";
            RamBehavior_g   : string   := "RBW";
            InitString_g    : string   := "";
            InitFormat_g    : string   := "NONE";
            InitWidth_g     : positive;
            InitShift_g     : natural  := 0
        );
        port (
            Clk         : in    std_logic;
            Wr_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
            Wr_Ena      : in    std_logic                                  := '1';
            Wr_Data     : in    std_logic_vector(Width_g - 1 downto 0);
            Rd_Clk      : in    std_logic                                  := '0';
            Rd_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
            Rd_Ena      : in    std_logic                                  := '1';
            Rd_Data     : out   std_logic_vector(Width_g - 1 downto 0)
        );
    end component;

begin

    -- Assertions
    assert (Width_g mod 8 = 0) or (not UseByteEnable_g)
        report "olo_base_ram_sdp: Width_g must be a multiple of 8, otherwise byte-enables must be disabled"
        severity error;

    -- No BE Implementation
    g_nobe : if not UseByteEnable_g generate

        i_ram : component olo_private_ram_sdp_nobe
            generic map (
                Depth_g         => Depth_g,
                Width_g         => Width_g,
                IsAsync_g       => IsAsync_g,
                RdLatency_g     => RdLatency_g,
                RamStyle_g      => RamStyle_g,
                RamBehavior_g   => RamBehavior_g,
                InitString_g    => InitString_g,
                InitFormat_g    => InitFormat_g,
                InitWidth_g     => Width_g
            )
            port map (
                Clk         => Clk,
                Wr_Addr     => Wr_Addr,
                Wr_Ena      => Wr_Ena,
                Wr_Data     => Wr_Data,
                Rd_Clk      => Rd_Clk,
                Rd_Addr     => Rd_Addr,
                Rd_Ena      => Rd_Ena,
                Rd_Data     => Rd_Data
            );

    end generate;

    -- BE Implementation
    g_be : if UseByteEnable_g generate

        g_byte : for byte in 0 to BeCount_c-1 generate
            signal Wr_Ena_Byte : std_logic;
        begin
            Wr_Ena_Byte <= Wr_Ena and Wr_Be(byte);

            i_ram : component olo_private_ram_sdp_nobe
                generic map (
                    Depth_g         => Depth_g,
                    Width_g         => 8,
                    IsAsync_g       => IsAsync_g,
                    RdLatency_g     => RdLatency_g,
                    RamStyle_g      => RamStyle_g,
                    RamBehavior_g   => RamBehavior_g,
                    InitString_g    => InitString_g,
                    InitFormat_g    => InitFormat_g,
                    InitWidth_g     => Width_g,
                    InitShift_g     => byte*8
                )
                port map (
                    Clk         => Clk,
                    Wr_Addr     => Wr_Addr,
                    Wr_Ena      => Wr_Ena_Byte,
                    Wr_Data     => Wr_Data(byte*8+7 downto byte*8),
                    Rd_Clk      => Rd_Clk,
                    Rd_Addr     => Rd_Addr,
                    Rd_Ena      => Rd_Ena,
                    Rd_Data     => Rd_Data(byte*8+7 downto byte*8)
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
entity olo_private_ram_sdp_nobe is
    generic (
        Depth_g         : positive;
        Width_g         : positive;
        IsAsync_g       : boolean  := false;
        RdLatency_g     : positive := 1;
        RamStyle_g      : string   := "auto";
        RamBehavior_g   : string   := "RBW";
        InitString_g    : string   := "";
        InitFormat_g    : string   := "NONE";
        InitWidth_g     : positive;
        InitShift_g     : natural  := 0
    );
    port (
        Clk         : in    std_logic;
        Wr_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena      : in    std_logic := '1';
        Wr_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Rd_Clk      : in    std_logic := '0';
        Rd_Addr     : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Rd_Ena      : in    std_logic := '1';
        Rd_Data     : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_private_ram_sdp_nobe is

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

    -- Synthesis attributes - suppress shift register extraction
    attribute shreg_extract of RdPipe : signal is ShregExtract_SuppressExtraction_c;

    -- Synthesis attributes - control RAM style
    attribute ram_style of Mem_v    : variable is RamStyle_g;
    attribute ramstyle of Mem_v     : variable is RamStyle_g;
    attribute syn_ramstyle of Mem_v : variable is RamStyle_g;

begin

    -- Assertions
    assert InitFormat_g = "NONE" or InitFormat_g = "HEX"
        report "olo_base_ram_sdp: InitFormat_g must be NONE or HEX. Got: " & InitFormat_g
        severity error;
    assert RamBehavior_g = "RBW" or RamBehavior_g = "WBR"
        report "olo_base_ram_sdp: RamBehavior_g must Be RBW or WBR. Got: " & RamBehavior_g
        severity error;

    -- Synchronous Implementation
    g_sync : if not IsAsync_g generate

        p_ram : process (Clk) is
        begin
            if rising_edge(Clk) then
                if RamBehavior_g = "RBW" then
                    if Rd_Ena = '1' then
                        RdPipe(1) <= Mem_v(to_integer(unsigned(Rd_Addr)));
                    end if;
                end if;
                if Wr_Ena = '1' then
                    Mem_v(to_integer(unsigned(Wr_Addr))) := Wr_Data;
                end if;
                if RamBehavior_g = "WBR" then
                    if Rd_Ena = '1' then
                        RdPipe(1) <= Mem_v(to_integer(unsigned(Rd_Addr)));
                    end if;
                end if;

                -- Read-data pipeline registers
                RdPipe(2 to RdLatency_g) <= RdPipe(1 to RdLatency_g-1);
            end if;
        end process;

    end generate;

    -- Asynchronous implementation
    g_async : if IsAsync_g generate

        -- Write side
        p_write : process (Clk) is
        begin
            if rising_edge(Clk) then
                if Wr_Ena = '1' then
                    Mem_v(to_integer(unsigned(Wr_Addr))) := Wr_Data;
                end if;
            end if;
        end process;

        -- Read side
        p_read : process (Rd_Clk) is
        begin
            if rising_edge(Rd_Clk) then
                if Rd_Ena = '1' then
                    RdPipe(1) <= Mem_v(to_integer(unsigned(Rd_Addr)));
                end if;

                -- Read-data pipeline registers
                RdPipe(2 to RdLatency_g) <= RdPipe(1 to RdLatency_g-1);
            end if;
        end process;

    end generate;

    -- Output
    Rd_Data <= RdPipe(RdLatency_g);

end architecture;

