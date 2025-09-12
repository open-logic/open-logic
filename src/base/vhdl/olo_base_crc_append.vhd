---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description:
---------------------------------------------------------------------------------------------------
-- Append a CRC to AXI4-Stream packets.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_crc_append.md
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_crc_append is
    generic (
        DataWidth_g        : positive;
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
        Out_Last         : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc_append is

    -- *** Types ***
    type State_t is (Data_s, Crc_s);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        State : State_t;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal Crc_Valid : std_logic;
    signal Crc_Ready : std_logic;
    signal Crc_Crc   : std_logic_vector(CrcPolynomial_g'length-1 downto 0);
    signal Pl_Valid  : std_logic;
    signal Pl_Data   : std_logic_vector(DataWidth_g-1 downto 0);
    signal Pl_Last   : std_logic;
    signal Pl_Ready  : std_logic;
    signal In_Beat   : std_logic;

begin

    -- *** Assertions ***
    assert CrcPolynomial_g'length <= DataWidth_g
        report "###ERROR###: olo_base_crc_append - Polynomial_g must be smaller or equal width than DataWidth_g"
        severity error;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** Hold Variables Stable ***
        v := r;

        -- *** FSM ***
        In_Ready  <= '0';
        Crc_Ready <= '0';
        Pl_Data   <= (others => 'X');
        Pl_Valid  <= '0';
        Pl_Last   <= '0';
        In_Beat   <= '0';

        case r.State is
            when Data_s =>
                Pl_Data  <= In_Data;
                Pl_Valid <= In_Valid;
                In_Ready <= Pl_Ready;
                In_Beat  <= In_Valid and Pl_Ready;

                if In_Valid = '1' and Pl_Ready = '1' and In_Last = '1' then
                    v.State := Crc_s;
                end if;

            when Crc_s =>
                Pl_Data                <= (others => '0');
                Pl_Data(Crc_Crc'range) <= Crc_Crc;
                Pl_Valid               <= Crc_Valid;
                Pl_Last                <= '1';
                Crc_Ready              <= Pl_Ready;

                if Crc_Valid = '1' and Pl_Ready = '1' then
                    v.State := Data_s;
                end if;

            -- coverage off
            when others => null; -- unreachable code
            -- coverage on
        end case;

        -- *** Assign Signal ***
        r_next <= v;

    end process;

    -- *** Sequential PRocess ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;

            -- Reset
            if Rst = '1' then
                r.State <= Data_s;
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
            Out_Crc          => Crc_Crc,
            Out_Valid        => Crc_Valid,
            Out_Ready        => Crc_Ready
        );

    b_pl : block is
        signal PlInData  : std_logic_vector(DataWidth_g downto 0);
        signal PlOutData : std_logic_vector(DataWidth_g downto 0);
    begin
        -- Input Assembly
        PlInData <= Pl_Last & Pl_Data;

        -- Instance
        i_pl_out : entity work.olo_base_pl_stage
            generic map (
                Width_g     => DataWidth_g+1,
                UseReady_g  => true,
                Stages_g    => 1
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Valid  => Pl_Valid,
                In_Ready  => Pl_Ready,
                In_Data   => PlInData,
                Out_Valid => Out_Valid,
                Out_Ready => Out_Ready,
                Out_Data  => PlOutData
            );

        -- Output Assembly
        Out_Last <= PlOutData(DataWidth_g);
        Out_Data <= PlOutData(DataWidth_g-1 downto 0);

    end block;

end architecture;
