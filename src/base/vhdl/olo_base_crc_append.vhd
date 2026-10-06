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
    use work.olo_base_pkg_string.all;

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
        In_Ready         : out   std_logic;
        In_Valid         : in    std_logic := '1';
        In_Last          : in    std_logic;
        In_Be            : in    std_logic_vector(DataWidth_g/8-1 downto 0) := (others => '1');
        In_Data          : in    std_logic_vector(DataWidth_g-1 downto 0);
        -- Output
        Out_Ready        : in    std_logic := '1';
        Out_Valid        : out   std_logic;
        Out_Last         : out   std_logic;
        Out_Be           : out   std_logic_vector(DataWidth_g/8 - 1 downto 0);
        Out_Data         : out   std_logic_vector(DataWidth_g-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc_append is

    -- *** Constants ***
    constant EntityName_c : string := "olo_base_crc_append";

    constant CrcBytes_c : natural := CrcPolynomial_g'length/8;
    constant BeWidth_c  : natural := DataWidth_g/8;
    -- data + be + last
    constant ConcatWidth_c : natural := DataWidth_g + BeWidth_c + 1;

    -- *** Types ***
    type State_t is (Data_s, Crc_s);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        CrcByteCnt : natural;
        State      : State_t;
    end record;

    signal r      : TwoProcess_r;
    signal r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal In_Concat : std_logic_vector(ConcatWidth_c-1 downto 0);

    signal Crc_Valid : std_logic;
    signal Crc_Ready : std_logic;
    signal Crc_Crc   : std_logic_vector(CrcPolynomial_g'length-1 downto 0);

    signal PlIn_Ready  : std_logic;
    signal PlIn_Valid  : std_logic;
    signal PlIn_Last   : std_logic;
    signal PlIn_Be     : std_logic_vector(BeWidth_c-1 downto 0);
    signal PlIn_Data   : std_logic_vector(DataWidth_g-1 downto 0);
    signal PlIn_Concat : std_logic_vector(ConcatWidth_c-1 downto 0);

    signal Fsm_Ready  : std_logic;
    signal Fsm_Valid  : std_logic;
    signal Fsm_Last   : std_logic;
    signal Fsm_Be     : std_logic_vector(BeWidth_c-1 downto 0);
    signal Fsm_Data   : std_logic_vector(DataWidth_g-1 downto 0);
    signal Fsm_Concat : std_logic_vector(ConcatWidth_c-1 downto 0);

    signal PlOut_Valid  : std_logic;
    signal PlOut_Last   : std_logic;
    signal PlOut_Be     : std_logic_vector(BeWidth_c-1 downto 0);
    signal PlOut_Data   : std_logic_vector(DataWidth_g-1 downto 0);
    signal PlOut_Concat : std_logic_vector(ConcatWidth_c-1 downto 0);

    -- Internal connection signals
    signal Conn_PlIn_Ready : std_logic;
    signal Conn_Crc_Ready  : std_logic;

begin

    -- *** Assertions ***
    -- TODO: Think about edge cases. What if CRC width is not multiple of 8 bits?

    --  assert CrcPolynomial_g'length <= DataWidth_g
    --      report errorMessage(EntityName_c, "Polynomial_g must be smaller or equal width than DataWidth_g")
    --      severity error;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;

        -- Helper Variables
        variable NumBe_v             : natural;
        variable NumBeWithCrc_v      : natural;
        variable CrcBytesRemaining_v : natural;
    begin
        -- *** Hold Variables Stable ***
        v := r;

        -- *** FSM ***
        Fsm_Valid <= '0';
        Fsm_Last  <= 'U';
        Fsm_Be    <= (others => 'U');
        Fsm_Data  <= (others => 'U');

        Crc_Ready <= '0';

        PlIn_Ready <= '0';

        case r.State is
            --------------------------------------------------------------------
            when Data_s =>
                -- Reset CRC byte counter.
                -- Normally, this counter is reset when the complete CRC has been 
                -- appended to the stream. 
                -- This redundant reset is kept as a safeguard in case the counter 
                -- was not reset at the expected point.
                v.CrcByteCnt := 0;

                if (PlIn_Valid = '1' and Fsm_Ready = '1') then

                    PlIn_Ready <= '1';

                    -- Possible cases:
                    --  1) Not the last data-beat
                    --  2) Last data-beat

                    -- 1) Not the last data-beat
                    if (PlIn_Last = '0') then

                        Fsm_Valid <= '1';
                        Fsm_Last  <= '0';
                        Fsm_Be    <= PlIn_Be;
                        Fsm_Data  <= PlIn_Data;

                    -- 2) Last data-beat
                    elsif (PlIn_Last = '1') then
                        
                        -- Possible cases:
                        -- 2.1) Last data-beat is fully filled with data
                        -- 2.2) Last data-beat is paritally filled with data

                        -- 2.1) Last data-beat is fully filled with data
                        if (PlIn_Be = onesVector(BeWidth_c)) then
                            
                            Fsm_Valid <= '1';
                            Fsm_Last  <= '0';
                            Fsm_Be    <= PlIn_Be;
                            Fsm_Data  <= PlIn_Data;

                            v.State := Crc_s;

                        -- 2.2) Last data-beat is paritally filled with data
                        else

                            -- Possible cases:
                            -- 2.2.1) Entire CRC fits in the remaining space of the last data beat
                            -- 2.2.2) CRC does not fit in the remaining space of the last data beat.
                            --        Part of the CRC is combined with DATA in this beat,
                            --        and the remaining CRC will be appended in subsequent data-beats

                            -- Helper variables
                            NumBe_v        := count(PlIn_Be, '1');
                            NumBeWithCrc_v := count(PlIn_Be, '1') + CrcBytes_c;

                            -- 2.2.1) Entire CRC fits in the remaining space of the last data beat
                            if (CrcBytes_c <= count(PlIn_Be, '0')) then

                                Fsm_Valid <= '1';
                                Fsm_Last  <= '1';
                                Fsm_Be    <= 
                                    zerosVector(BeWidth_c - NumBeWithCrc_v) &
                                    onesVector(NumBeWithCrc_v);
                                Fsm_Data  <=
                                    zerosVector((BeWidth_c - NumBeWithCrc_v)*8) &
                                    Crc_Crc &
                                    PlIn_Data(NumBe_v*8-1 downto 0);

                                -- Reset CRC byte counter after the complete 
                                -- CRC has been appended to the stream.
                                v.CrcByteCnt := 0;

                                -- Ready to calculate the CRC for the next packet.
                                Crc_Ready <= '1';

                            -- 2.2.2) CRC does not fit in the remaining space of the last data beat.
                            --        Part of the CRC is combined with DATA in this beat,
                            --        and the remaining CRC will be appended in subsequent data-beats
                            else

                                Fsm_Valid <= '1';
                                Fsm_Last  <= '0';
                                Fsm_Be    <= (others => '1');
                                Fsm_Data  <= 
                                    Crc_Crc(count(PlIn_Be, '0')*8-1 downto 0)&
                                    PlIn_Data(NumBe_v*8-1 downto 0);

                                v.CrcByteCnt := count(PlIn_Be, '0');
                                v.State      := Crc_s;

                            end if;
                        end if;
                    end if;
                end if;

            --------------------------------------------------------------------
            when Crc_s =>

                Fsm_Valid <= '1';

                -- Helper Variable
                CrcBytesRemaining_v := CrcBytes_c - r.CrcByteCnt;

                if (Fsm_Valid = '1' and Fsm_Ready = '1') then

                    -- Possible cases:
                    --   1) Not the last data beat. CRC bytes are not yet fully appended on the stream
                    --   2) Last data beat. All CRC bytes are fully appended on the stream
                        
                    --   1) Not the last data beat. CRC bytes are not yet fully appended on the stream
                    if (r.CrcByteCnt + BeWidth_c < CrcBytes_c) then

                        Fsm_Last <= '0';
                        Fsm_Be   <= (others => '1');
                        Fsm_Data <= Crc_Crc((r.CrcByteCnt+BeWidth_c)*8-1 downto r.CrcByteCnt*8);

                        v.CrcByteCnt := r.CrcByteCnt + BeWidth_c;

                    --   2) Last data beat. All CRC bytes are fully appended on the stream
                    else

                        Fsm_Last <= '1';
                        Fsm_Be   <=
                            zerosVector(BeWidth_c - CrcBytesRemaining_v) &
                            onesVector(CrcBytesRemaining_v);
                        Fsm_Data <=
                            zerosVector((BeWidth_c - CrcBytesRemaining_v)*8) &
                            Crc_Crc(CrcBytes_c*8-1 downto r.CrcByteCnt*8);

                        -- Reset CRC byte counter after the complete 
                        -- CRC has been appended to the stream.
                        v.CrcByteCnt := 0;

                        -- Ready to calculate the CRC for the next packet.
                        Crc_Ready <= '1';

                        v.State := Data_s;

                    end if;
                end if;

            --------------------------------------------------------------------
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
                r.CrcByteCnt <= 0;
                r.State      <= Data_s;
            end if;
        end if;
    end process;

    -- *** Instantiations ***

    ----------------------------------------------------------------------------
    -- CRC
    ----------------------------------------------------------------------------

    In_Ready <= Conn_PlIn_Ready and Conn_Crc_Ready;

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
            Clk       => Clk,
            Rst       => Rst,

            In_Ready  => Conn_Crc_Ready,
            In_Valid  => In_Valid and In_Ready,
            In_Last   => In_Last,
            In_Be     => In_Be,
            In_Data   => In_Data,

            Out_Ready => Crc_Ready,
            Out_Valid => Crc_Valid,
            Out_Crc   => Crc_Crc
        );

    ----------------------------------------------------------------------------
    -- Input Pipeline Stage
    --     Required to delay the stream by one clock cycle to allow 
    --     the CRC component sufficient time to calculate the CRC.
    ----------------------------------------------------------------------------
    -- Input Assembly
    In_Concat <= In_Last & In_Be & In_Data;

    -- Instance
    i_pl_in : entity work.olo_base_pl_stage
        generic map (
            Width_g     => ConcatWidth_c,
            UseReady_g  => true,
            Stages_g    => 1
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,

            In_Ready  => Conn_PlIn_Ready,
            In_Valid  => In_Valid and Conn_Crc_Ready,
            In_Data   => In_Concat,

            Out_Ready => PlIn_Ready,
            Out_Valid => PlIn_Valid,
            Out_Data  => PlIn_Concat
        );

    -- Output Assembly
    PlIn_Last <= PlIn_Concat(ConcatWidth_c-1);
    PlIn_Be   <= PlIn_Concat(ConcatWidth_c-2 downto DataWidth_g);
    PlIn_Data <= PlIn_Concat(DataWidth_g-1 downto 0);

    ----------------------------------------------------------------------------
    -- Output Pipeline Stage
    ----------------------------------------------------------------------------
    -- Input Assembly
    Fsm_Concat <= Fsm_Last & Fsm_Be & Fsm_Data;

    -- Instance
    i_pl_out : entity work.olo_base_pl_stage
        generic map (
            Width_g     => ConcatWidth_c,
            UseReady_g  => true,
            Stages_g    => 1
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,

            In_Ready  => Fsm_Ready,
            In_Valid  => Fsm_Valid,
            In_Data   => Fsm_Concat,

            Out_Ready => Out_Ready,
            Out_Valid => Out_Valid,
            Out_Data  => PlOut_Concat
        );

    -- Output Assembly
    Out_Last <= PlOut_Concat(ConcatWidth_c-1);
    Out_Be   <= PlOut_Concat(ConcatWidth_c-2 downto DataWidth_g);
    Out_Data <= PlOut_Concat(DataWidth_g-1 downto 0);

end architecture;
