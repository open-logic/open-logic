---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected synchronous FIFO using SECDED (Single Error Correction,
-- Double Error Detection) Hamming code. Wraps olo_base_fifo_sync with a wider
-- internal word to store parity bits alongside data. The ECC is transparent
-- to the user: data is encoded on write and decoded/corrected on read.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_fifo_sync.md
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
entity olo_ft_fifo_sync is
    generic (
        Width_g         : positive;
        Depth_g         : positive;
        AlmFullOn_g     : boolean              := false;
        AlmFullLevel_g  : natural              := 0;
        AlmEmptyOn_g    : boolean              := false;
        AlmEmptyLevel_g : natural              := 0;
        RamStyle_g      : string               := "auto";
        RamBehavior_g   : string               := "RBW";
        ReadyRstState_g : std_logic            := '1';
        EccPipeline_g   : natural range 0 to 2 := 0
    );
    port (
        -- Control Ports
        Clk               : in    std_logic;
        Rst               : in    std_logic;
        -- Input Data
        In_Data           : in    std_logic_vector(Width_g - 1 downto 0);
        In_Valid          : in    std_logic                                                := '1';
        In_Ready          : out   std_logic;
        In_Level          : out   std_logic_vector(log2ceil(Depth_g + 1) - 1 downto 0);
        -- Output Data
        Out_Data          : out   std_logic_vector(Width_g - 1 downto 0);
        Out_Valid         : out   std_logic;
        Out_Ready         : in    std_logic                                                := '1';
        Out_Level         : out   std_logic_vector(log2ceil(Depth_g + 2 * EccPipeline_g + 1) - 1 downto 0);
        Out_EccSec        : out   std_logic;
        Out_EccDed        : out   std_logic;
        -- Status
        Full              : out   std_logic;
        AlmFull           : out   std_logic;
        Empty             : out   std_logic;
        AlmEmpty          : out   std_logic;
        -- Error injection (independent of the data handshake)
        In_ErrInj_BitFlip : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        In_ErrInj_Valid   : in    std_logic                                                := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_fifo_sync is

    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    -- Beats buffered in the ECC decoder (two per pipeline stage)
    constant DecCapacity_c : natural := 2 * EccPipeline_g;

    -- Encoder -> FIFO interface
    signal EncOut_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal EncOut_Valid    : std_logic;
    signal EncOut_Ready    : std_logic;

    -- FIFO -> decoder interface
    signal FifoOut_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);
    signal FifoOut_Valid    : std_logic;
    signal FifoOut_Ready    : std_logic;

    -- Status entity forward-declaration (defined later in this file)
    component olo_private_ft_fifo_status is
        generic (
            Depth_g         : positive;
            ExtraBeats_g    : natural;
            AlmEmptyOn_g    : boolean;
            AlmEmptyLevel_g : natural
        );
        port (
            Clk       : in    std_logic;
            Rst       : in    std_logic;
            In_Valid  : in    std_logic;
            In_Ready  : in    std_logic;
            Out_Valid : in    std_logic;
            Out_Ready : in    std_logic;
            Level     : out   std_logic_vector(log2ceil(Depth_g + ExtraBeats_g + 1) - 1 downto 0);
            Empty     : out   std_logic;
            AlmEmpty  : out   std_logic
        );
    end component;

    signal In_Ready_i  : std_logic;
    signal Out_Valid_i : std_logic;

begin

    In_Ready  <= In_Ready_i;
    Out_Valid <= Out_Valid_i;

    i_enc : entity work.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => 0,
            UseReady_g => true
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready_i,
            In_Data        => In_Data,
            Out_Valid      => EncOut_Valid,
            Out_Ready      => EncOut_Ready,
            Out_Codeword   => EncOut_Codeword,
            ErrInj_BitFlip => In_ErrInj_BitFlip,
            ErrInj_Valid   => In_ErrInj_Valid
        );

    i_fifo : entity work.olo_base_fifo_sync
        generic map (
            Width_g         => CodewordWidth_c,
            Depth_g         => Depth_g,
            AlmFullOn_g     => AlmFullOn_g,
            AlmFullLevel_g  => AlmFullLevel_g,
            -- Read-side status is produced by i_status instead
            AlmEmptyOn_g    => false,
            AlmEmptyLevel_g => 0,
            RamStyle_g      => RamStyle_g,
            RamBehavior_g   => RamBehavior_g,
            ReadyRstState_g => ReadyRstState_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => EncOut_Codeword,
            In_Valid  => EncOut_Valid,
            In_Ready  => EncOut_Ready,
            In_Level  => In_Level,
            Out_Data  => FifoOut_Codeword,
            Out_Valid => FifoOut_Valid,
            Out_Ready => FifoOut_Ready,
            Out_Level => open,
            Full      => Full,
            AlmFull   => AlmFull,
            Empty     => open,
            AlmEmpty  => open
        );

    i_dec : entity work.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => EccPipeline_g,
            UseReady_g => true
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => FifoOut_Valid,
            In_Ready       => FifoOut_Ready,
            In_Codeword    => FifoOut_Codeword,
            Out_Valid      => Out_Valid_i,
            Out_Ready      => Out_Ready,
            Out_Data       => Out_Data,
            Out_EccSec     => Out_EccSec,
            Out_EccDed     => Out_EccDed,
            ErrInj_BitFlip => (others => '0'),
            ErrInj_Valid   => '0'
        );

    -- Read-side status covers the FIFO and the ECC decoder, see documentation
    i_status : component olo_private_ft_fifo_status
        generic map (
            Depth_g         => Depth_g,
            ExtraBeats_g    => DecCapacity_c,
            AlmEmptyOn_g    => AlmEmptyOn_g,
            AlmEmptyLevel_g => AlmEmptyLevel_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready_i,
            Out_Valid => Out_Valid_i,
            Out_Ready => Out_Ready,
            Level     => Out_Level,
            Empty     => Empty,
            AlmEmpty  => AlmEmpty
        );

end architecture;

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Read-Side Status Entity
---------------------------------------------------------------------------------------------------
-- Counts the beats a FIFO and the ExtraBeats_g stages behind it still have to deliver.
---------------------------------------------------------------------------------------------------
entity olo_private_ft_fifo_status is
    generic (
        Depth_g         : positive;
        ExtraBeats_g    : natural;
        AlmEmptyOn_g    : boolean;
        AlmEmptyLevel_g : natural
    );
    port (
        -- Control Ports
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Handshakes
        In_Valid  : in    std_logic;
        In_Ready  : in    std_logic;
        Out_Valid : in    std_logic;
        Out_Ready : in    std_logic;
        -- Status
        Level     : out   std_logic_vector(log2ceil(Depth_g + ExtraBeats_g + 1) - 1 downto 0);
        Empty     : out   std_logic;
        AlmEmpty  : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_private_ft_fifo_status is

    constant MaxLevel_c : natural := Depth_g + ExtraBeats_g;

    type TwoProcess_r is record
        Level : natural range 0 to MaxLevel_c;
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v        : TwoProcess_r;
        variable Enters_v : boolean;
        variable Leaves_v : boolean;
    begin
        -- hold variables stable
        v := r;

        -- Level update
        Enters_v := (In_Valid = '1') and (In_Ready = '1');
        Leaves_v := (Out_Valid = '1') and (Out_Ready = '1');

        if Enters_v and not Leaves_v and r.Level /= MaxLevel_c then
            v.Level := r.Level + 1;
        elsif Leaves_v and not Enters_v and r.Level /= 0 then
            v.Level := r.Level - 1;
        end if;

        -- Status outputs
        Level <= toUslv(r.Level, Level'length);

        if r.Level = 0 then
            Empty <= '1';
        else
            Empty <= '0';
        end if;

        if AlmEmptyOn_g and (r.Level <= AlmEmptyLevel_g) then
            AlmEmpty <= '1';
        else
            AlmEmpty <= '0';
        end if;

        -- Assign signal
        r_next <= v;
    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Level <= 0;
            end if;
        end if;
    end process;

end architecture;
