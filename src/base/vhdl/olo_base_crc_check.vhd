---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description:
---------------------------------------------------------------------------------------------------
-- Check the CRC appended to AXI4-Stream packets and drop packets with errors.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_crc_check.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_misc.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_logic.all;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_crc_check is
    generic (
        DataWidth_g        : positive;
        FifoDepth_g        : positive         := 1024;
        FifoRamStyle_g     : string           := "auto";
        FifoRamBehavior_g  : string           := "RBW";
        Mode_g             : string           := "DROP";
        CrcPolynomial_g    : std_logic_vector;                -- See olo_base_crc
        CrcInitialValue_g  : std_logic_vector := "0";         -- See olo_base_crc
        CrcBitOrder_g      : string           := "MSB_FIRST"; -- See olo_base_crc
        CrcByteOrder_g     : string           := "NONE";      -- See olo_base_crc
        CrcBitflipOutput_g : boolean          := false;       -- See olo_base_crc
        CrcXorOutput_g     : std_logic_vector := "0"          -- See olo_base_crc
    );
    port (
        -- Control Ports
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Input
        In_Data          : in    std_logic_vector(DataWidth_g-1 downto 0);
        In_Valid         : in    std_logic := '1';
        In_Ready         : out   std_logic;
        In_Last          : in    std_logic;
        -- Output
        Out_Data         : out   std_logic_vector(DataWidth_g-1 downto 0);
        Out_Valid        : out   std_logic;
        Out_Ready        : in    std_logic := '1';
        Out_Last         : out   std_logic;
        Out_CrcErr       : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc_check is

    -- *** constants ***
    constant Mode_c : string := toLower(Mode_g);

    -- *** Types ***
    type Fsm_t is (First_s, Others_s);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        Data : std_logic_vector(DataWidth_g-1 downto 0);
        Fsm  : Fsm_t;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal Crc_Crc   : std_logic_vector(CrcPolynomial_g'length-1 downto 0);
    signal Pl_Valid  : std_logic;
    signal Pl_Ready  : std_logic;
    signal Pl_CrcErr : std_logic;
    signal In_Beat   : std_logic;

begin

    -- *** Assertions ***
    assert CrcPolynomial_g'length <= DataWidth_g
        report "###ERROR###: olo_base_crc_check - Polynomial_g must be smaller or equal width than DataWidth_g"
        severity error;
    assert Mode_c = "drop" or Mode_c = "flag"
        report "###ERROR###: olo_base_crc_check - Mode_g must be FLAG or DROP"
        severity error;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** Hold Variables Stable ***
        v := r;

        -- *** FSM ***
        Pl_CrcErr <= '0';
        In_Ready  <= '0';
        Pl_Valid  <= '0';

        case r.Fsm is
            when First_s =>
                -- This data is not forwarded but only stored
                In_Ready <= '1';
                Pl_Valid <= '0';
                -- Upon first data, change state
                if In_Valid = '1' and In_Last = '0' then -- Ignore single beat packets with CRC only
                    v.Fsm  := Others_s;
                    v.Data := In_Data;
                end if;

            when Others_s =>
                -- Handshaking betwen output part (PL or FIFO) and input directly
                In_Ready <= Pl_Ready;
                Pl_Valid <= In_Valid;

                -- Handle data and check CRC
                if Pl_Ready = '1' and In_Valid = '1' then
                    v.Data := In_Data;
                    if In_Last = '1' then
                        v.Fsm := First_s;
                        if In_Data(Crc_Crc'range) /= Crc_Crc then
                            Pl_CrcErr <= '1';
                        end if;
                    end if;
                end if;

            -- coverage off
            when others => null; -- unreachable code
            -- coverage on
        end case;

        -- *** Detect Data Beats ***
        In_Beat <= In_Ready and In_Valid;

        -- *** Assign Signal ***
        r_next <= v;

    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;

            -- Reset
            if Rst = '1' then
                r.Fsm <= First_s;
            end if;
        end if;
    end process;

    -- *** Instantiations ***
    i_crc : entity work.olo_base_crc
        generic map (
            DataWidth_g     => DataWidth_g,
            Polynomial_g    => CrcPolynomial_g,
            InitialValue_g  => CrcInitialValue_g,
            BitOrder_g      => CrcBitOrder_g,
            ByteOrder_g     => CrcByteOrder_g,
            BitflipOutput_g => CrcBitflipOutput_g,
            XorOutput_g     => CrcXorOutput_g
        )
        port map (
            Clk              => Clk,
            Rst              => Rst,
            In_Data          => In_Data,
            In_Valid         => In_Beat,
            In_Last          => In_Last,
            Out_Crc          => Crc_Crc
        );

    -- For DROP a packet FIFO is required
    g_drop : if Mode_c = "drop" generate

        i_fifo : entity work.olo_base_fifo_packet
            generic map (
                Width_g             => DataWidth_g,
                Depth_g             => FifoDepth_g,
                FeatureSet_g        => "DROP_ONLY",
                RamStyle_g          => FifoRamStyle_g,
                RamBehavior_g       => FifoRamBehavior_g
            )
            port map (
                Clk           => Clk,
                Rst           => Rst,
                -- Input Data
                In_Valid      => Pl_Valid,
                In_Ready      => Pl_Ready,
                In_Data       => r.Data,
                In_Last       => In_Last,
                In_Drop       => Pl_CrcErr,
                Out_Valid     => Out_Valid,
                Out_Ready     => Out_Ready,
                Out_Data      => Out_Data,
                Out_Last      => Out_Last
            );

        Out_CrcErr <= Pl_CrcErr;
    end generate;

    g_flag : if Mode_c = "flag" generate
        signal InData  : std_logic_vector(DataWidth_g+1 downto 0);
        signal OutData : std_logic_vector(DataWidth_g+1 downto 0);
    begin
        -- Input Assembly
        InData <= Pl_CrcErr & In_Last & r.Data;

        -- Instantiation
        i_pl : entity work.olo_base_pl_stage
            generic map (
                Width_g     => DataWidth_g+2
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => Pl_Valid,
                In_Ready    => Pl_Ready,
                In_Data     => InData,
                Out_Valid   => Out_Valid,
                Out_Ready   => Out_Ready,
                Out_Data    => OutData
            );

        -- Output Disassembly
        Out_CrcErr <= OutData(OutData'high);
        Out_Last   <= OutData(OutData'high-1);
        Out_Data   <= OutData(DataWidth_g-1 downto 0);
    end generate;

end architecture;
