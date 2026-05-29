---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a pure VHDL and vendor indpendent true dual port RAM with optional
-- byte enables.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_ram_tdp.md
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
-- Test synthesis: Try odd widths without BE, try 3 bits (<8) without BE
entity olo_base_ram_tdp is
    generic (
        Depth_g         : positive;
        Width_g         : positive;
        RdLatency_g     : positive := 1;
        RamStyle_g      : string   := "auto";
        RamBehavior_g   : string   := "RBW";
        UseByteEnable_g : boolean  := false;
        InitString_g    : string   := "";
        InitFormat_g    : string   := "NONE"
    );                                                      -- "RBW" = read-before-write, "WBR" = write-before-read
    port (
        A_Clk     : in    std_logic;
        A_Rst     : in    std_logic                                  := '0';
        A_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        A_Be      : in    std_logic_vector(Width_g / 8 - 1 downto 0) := (others => '1');
        A_WrEna   : in    std_logic                                  := '0';
        A_WrData  : in    std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
        A_RdEna   : in    std_logic                                  := '1';
        A_RdData  : out   std_logic_vector(Width_g - 1 downto 0);
        A_RdValid : out   std_logic;
        B_Clk     : in    std_logic;
        B_Rst     : in    std_logic                                  := '0';
        B_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        B_Be      : in    std_logic_vector(Width_g / 8 - 1 downto 0) := (others => '1');
        B_WrEna   : in    std_logic                                  := '0';
        B_WrData  : in    std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
        B_RdEna   : in    std_logic                                  := '1';
        B_RdData  : out   std_logic_vector(Width_g - 1 downto 0);
        B_RdValid : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_ram_tdp is

    -- constants
    constant EntityName_c : string  := "olo_base_ram_tdp";
    constant BeCount_c    : integer := Width_g / 8;

    -- Read Valid pipelines
    signal A_RdValidPipe : std_logic_vector(1 to RdLatency_g);
    signal B_RdValidPipe : std_logic_vector(1 to RdLatency_g);

    -- Synthesis attributes - Suppress shift register extraction
    attribute shreg_extract of A_RdValidPipe : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of B_RdValidPipe : signal is ShregExtract_SuppressExtraction_c;

    -- components
    component olo_private_ram_tdp_nobe is
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
            A_Clk     : in    std_logic;
            A_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
            A_WrEna   : in    std_logic                                  := '0';
            A_WrData  : in    std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
            A_RdEna   : in    std_logic                                  := '1';
            A_RdData  : out   std_logic_vector(Width_g - 1 downto 0);
            B_Clk     : in    std_logic;
            B_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
            B_WrEna   : in    std_logic                                  := '0';
            B_WrData  : in    std_logic_vector(Width_g - 1 downto 0)     := (others => '0');
            B_RdEna   : in    std_logic                                  := '1';
            B_RdData  : out   std_logic_vector(Width_g - 1 downto 0)
        );
    end component;

begin

    -- Assertions
    assert (Width_g mod 8 = 0) or (not UseByteEnable_g)
        report errorMessage(EntityName_c, "Width_g must be a multiple of 8, otherwise byte-enables must be disabled")
        severity error;

    -- No BE Implementation
    g_nobe : if not UseByteEnable_g generate

        i_ram : component olo_private_ram_tdp_nobe
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
                A_Clk     => A_Clk,
                A_Addr    => A_Addr,
                A_WrEna   => A_WrEna,
                A_WrData  => A_WrData,
                A_RdEna   => A_RdEna,
                A_RdData  => A_RdData,
                B_Clk     => B_Clk,
                B_Addr    => B_Addr,
                B_WrEna   => B_WrEna,
                B_WrData  => B_WrData,
                B_RdEna   => B_RdEna,
                B_RdData  => B_RdData
            );

    end generate;

    -- BE Implementation
    g_be : if UseByteEnable_g generate

        g_byte : for byte in 0 to BeCount_c-1 generate
            signal A_WrEna_Byte : std_logic;
            signal B_WrEna_Byte : std_logic;
        begin
            A_WrEna_Byte <= A_WrEna and A_Be(byte);
            B_WrEna_Byte <= B_WrEna and B_Be(byte);

            i_ram : component olo_private_ram_tdp_nobe
                generic map (
                    Depth_g         => Depth_g,
                    Width_g         => 8,
                    RdLatency_g     => RdLatency_g,
                    RamStyle_g      => RamStyle_g,
                    RamBehavior_g   => RamBehavior_g,
                    InitString_g    => InitString_g,
                    InitFormat_g    => InitFormat_g,
                    InitWidth_g     => Width_g,
                    InitShift_g     => 8*byte
                )
                port map (
                    A_Clk     => A_Clk,
                    A_Addr    => A_Addr,
                    A_WrEna   => A_WrEna_Byte,
                    A_WrData  => A_WrData(8*(byte+1)-1 downto 8*byte),
                    A_RdEna   => A_RdEna,
                    A_RdData  => A_RdData(8*(byte+1)-1 downto 8*byte),
                    B_Clk     => B_Clk,
                    B_Addr    => B_Addr,
                    B_WrEna   => B_WrEna_Byte,
                    B_WrData  => B_WrData(8*(byte+1)-1 downto 8*byte),
                    B_RdEna   => B_RdEna,
                    B_RdData  => B_RdData(8*(byte+1)-1 downto 8*byte)
                );

        end generate;

    end generate;

    -- RdValid pipeline - Port A
    p_rdvalid_a : process (A_Clk) is
    begin
        if rising_edge(A_Clk) then
            A_RdValidPipe(1)                <= A_RdEna;
            A_RdValidPipe(2 to RdLatency_g) <= A_RdValidPipe(1 to RdLatency_g-1);

            -- Reset
            if A_Rst = '1' then
                A_RdValidPipe <= (others => '0');
            end if;
        end if;
    end process;

    -- RdValid pipeline - Port B
    p_rdvalid_b : process (B_Clk) is
    begin
        if rising_edge(B_Clk) then
            B_RdValidPipe(1)                <= B_RdEna;
            B_RdValidPipe(2 to RdLatency_g) <= B_RdValidPipe(1 to RdLatency_g-1);

            -- Reset
            if B_Rst = '1' then
                B_RdValidPipe <= (others => '0');
            end if;
        end if;
    end process;

    A_RdValid <= A_RdValidPipe(RdLatency_g);
    B_RdValid <= B_RdValidPipe(RdLatency_g);

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
-- Test synthesis: Try odd widths without BE, try 3 bits (<8) without BE
entity olo_private_ram_tdp_nobe is
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
        A_Clk     : in    std_logic;
        A_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        A_WrEna   : in    std_logic                              := '0';
        A_WrData  : in    std_logic_vector(Width_g - 1 downto 0) := (others => '0');
        A_RdEna   : in    std_logic                              := '1';
        A_RdData  : out   std_logic_vector(Width_g - 1 downto 0);
        B_Clk     : in    std_logic;
        B_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        B_WrEna   : in    std_logic                              := '0';
        B_WrData  : in    std_logic_vector(Width_g - 1 downto 0) := (others => '0');
        B_RdEna   : in    std_logic                              := '1';
        B_RdData  : out   std_logic_vector(Width_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_private_ram_tdp_nobe is

    -- Constants
    constant EntityName_c : string := "olo_base_ram_tdp_nobe";

    -- Memory Type
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

    -- Read data pipelines
    signal RdPipeA : Data_t(1 to RdLatency_g);
    signal RdPipeB : Data_t(1 to RdLatency_g);

    -- Synthesis attributes - Suppress shift register extraction
    attribute shreg_extract of RdPipeA : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of RdPipeB : signal is ShregExtract_SuppressExtraction_c;

    -- Synthesis attributes - RAM style
    attribute ram_style of Mem_v    : variable is RamStyle_g;
    attribute ramstyle of Mem_v     : variable is RamStyle_g;
    attribute syn_ramstyle of Mem_v : variable is RamStyle_g;

begin

    -- Assertions
    assert compareNoCase(InitFormat_g, "NONE") or compareNoCase(InitFormat_g, "HEX")
        report errorMessage(EntityName_c, "InitFormat_g must be NONE or HEX. Got: " & InitFormat_g)
        severity error;
    assert compareNoCase(RamBehavior_g, "RBW") or compareNoCase(RamBehavior_g, "WBR")
        report errorMessage(EntityName_c, "RamBehavior_g must Be RBW or WBR. Got: " & RamBehavior_g)
        severity error;

    g_wbr : if compareNoCase(RamBehavior_g, "WBR") generate

        -- Port A
        p_porta : process (A_Clk) is
        begin
            if rising_edge(A_Clk) then
                -- RAM
                if A_WrEna = '1' then
                    Mem_v(to_integer(unsigned(A_Addr))) := A_WrData;
                end if;
                if A_RdEna = '1' then
                    RdPipeA(1) <= Mem_v(to_integer(unsigned(A_Addr)));
                end if;

                -- Read-data pipeline registers
                RdPipeA(2 to RdLatency_g) <= RdPipeA(1 to RdLatency_g-1);
            end if;
        end process;

        -- Port B
        p_portb : process (B_Clk) is
        begin
            if rising_edge(B_Clk) then
                -- RAM
                if B_WrEna = '1' then
                    Mem_v(to_integer(unsigned(B_Addr))) := B_WrData;
                end if;
                if B_RdEna = '1' then
                    RdPipeB(1) <= Mem_v(to_integer(unsigned(B_Addr)));
                end if;

                -- Read-data pipeline registers
                RdPipeB(2 to RdLatency_g) <= RdPipeB(1 to RdLatency_g-1);
            end if;
        end process;

    end generate;

    g_rbw : if compareNoCase(RamBehavior_g, "RBW") generate

        -- Port A
        p_porta : process (A_Clk) is
        begin
            if rising_edge(A_Clk) then
                -- RAM
                if A_RdEna = '1' then
                    RdPipeA(1) <= Mem_v(to_integer(unsigned(A_Addr)));
                end if;
                if A_WrEna = '1' then
                    Mem_v(to_integer(unsigned(A_Addr))) := A_WrData;
                end if;

                -- Read-data pipeline registers
                RdPipeA(2 to RdLatency_g) <= RdPipeA(1 to RdLatency_g-1);
            end if;
        end process;

        -- Port B
        p_portb : process (B_Clk) is
        begin
            if rising_edge(B_Clk) then
                -- RAM
                if B_RdEna = '1' then
                    RdPipeB(1) <= Mem_v(to_integer(unsigned(B_Addr)));
                end if;
                if B_WrEna = '1' then
                    Mem_v(to_integer(unsigned(B_Addr))) := B_WrData;
                end if;

                -- Read-data pipeline registers
                RdPipeB(2 to RdLatency_g) <= RdPipeB(1 to RdLatency_g-1);
            end if;
        end process;

    end generate;

    -- Output
    A_RdData <= RdPipeA(RdLatency_g);
    B_RdData <= RdPipeB(RdLatency_g);

end architecture;
