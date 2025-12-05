---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler, Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description:
---------------------------------------------------------------------------------------------------
-- A CRC generator based on a linear-feedback shifter register. Can be used to generate CRCs to add
-- on TX side or to calculate CRCs to compare to received CRC on RX side.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_crc.md
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
entity olo_base_crc is
    generic (
        DataWidth_g     : positive;
        Polynomial_g    : std_logic_vector;  -- according to https://crccalc.com/?crc=01&method=CRC-8&datatype=hex&outtype=bin
        InitialValue_g  : std_logic_vector := "0";
        BitOrder_g      : string           := "MSB_FIRST"; -- "MSB_FIRST" or "LSB_FIRST"
        ByteOrder_g     : string           := "NONE";      -- "NONE", "MSB_FIRST" or "LSB_FIRST"
        BitflipOutput_g : boolean          := false;
        XorOutput_g     : std_logic_vector := "0"
    );
    port (
        -- Control Ports
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Input
        In_Data          : in    std_logic_vector(DataWidth_g-1 downto 0);
        In_Valid         : in    std_logic                                  := '1';
        In_Ready         : out   std_logic;
        In_Last          : in    std_logic                                  := '0';
        In_First         : in    std_logic                                  := '0';
        In_Be            : in    std_logic_vector(DataWidth_g/8-1 downto 0) := (others => '1');
        -- Output
        Out_Crc          : out   std_logic_vector(Polynomial_g'range);
        Out_Valid        : out   std_logic;
        Out_Ready        : in    std_logic                                  := '1'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_crc is

    -- Constants
    constant CrcWidth_c            : natural                                 := Polynomial_g'length;
    constant BeMode_c              : boolean                                 := choose(DataWidth_g mod 8 = 0, true, false);
    constant ZeroPoly_c            : std_logic_vector(CrcWidth_c-1 downto 0) := (others => '0');
    -- Resized constants - required because modelsim does not compile choose() if inputs have different size, even if
    -- .. the input in question is not selected
    constant InitialValueResized_c : std_logic_vector(CrcWidth_c-1 downto 0) := std_logic_vector(resize(signed(InitialValue_g), CrcWidth_c));
    constant XorValueResized_c     : std_logic_vector(CrcWidth_c-1 downto 0) := std_logic_vector(resize(signed(XorOutput_g), CrcWidth_c));
    constant InitialValue_c        : std_logic_vector(CrcWidth_c-1 downto 0) := choose(InitialValue_g = "0", ZeroPoly_c, InitialValueResized_c);
    constant XorOutput_c           : std_logic_vector(CrcWidth_c-1 downto 0) := choose(XorOutput_g = "0", ZeroPoly_c, XorValueResized_c);
    constant BitOrder_c            : string                                  := toUpper(BitOrder_g);
    constant ByteOrder_c           : string                                  := toUpper(ByteOrder_g);

    -- Signals
    signal LfsrReg     : std_logic_vector(CrcWidth_c-1 downto 0);
    signal Out_Valid_I : std_logic;
    signal In_Ready_I  : std_logic;

begin

    assert BitOrder_c = "MSB_FIRST" or BitOrder_c = "LSB_FIRST"
        report "###ERROR###: olo_base_crc - Illegal value for BitOrder_g"
        severity error;
    assert ByteOrder_c = "NONE" or ByteOrder_c = "LSB_FIRST" or ByteOrder_c = "MSB_FIRST"
        report "###ERROR###: olo_base_crc - Illegal value for ByteOrder_g"
        severity error;
    assert ByteOrder_c = "NONE" or DataWidth_g mod 8 = 0
        report "###ERROR###: olo_base_crc - For DataWidth_g not being a multiple of 8, only ByteOrder_g=NONE is allowed"
        severity error;
    assert InitialValue_c'length = CrcWidth_c
        report "###ERROR###: olo_base_crc - InitialValue_g must have the same length as Polynomial_g"
        severity error;
    assert XorOutput_c'length = CrcWidth_c
        report "###ERROR###: olo_base_crc - XorOutput_g must have the same length as Polynomial_g"
        severity error;

    p_lfsr : process (Clk) is
        variable Input_v     : std_logic_vector(In_Data'range);
        variable Lfsr_v      : std_logic_vector(LfsrReg'range);
        variable InBit_v     : std_logic;
        variable Out_v       : std_logic_vector(CrcWidth_c-1 downto 0);
        variable InputHigh_v : natural;
        variable BePlus_v    : std_logic_vector(In_Be'range);
    begin
        if rising_edge(Clk) then

            if (BeMode_c and In_Last = '1') then
                BePlus_v := std_logic_vector(unsigned(In_Be) + 1);
                -- synthesis translate_off
                assert (In_Be and BePlus_v) = zerosVector(In_Be'length)
                    report "olo_base_crc: In_Be must have LSB asserted and all asserted bits must be contiguous. Trailing-Only Byte-Enable convention violated."
                    severity error;
                -- synthesis translate_on

                InputHigh_v := count(In_Be, '1') * 8 - 1;

                -- Yosys cannot synthesize slices that use variable index ranges, for example:
                --   Input_v(InputHigh_v downto 0) := In_Data(InputHigh_v downto 0)
                -- Workaround: copy the data byte-by-byte inside a fixed-range loop
                for i in 0 to In_Be'length - 1 loop
                    if (i * 8 <= InputHigh_v) then
                        Input_v((i + 1) * 8 - 1 downto i * 8) := In_Data((i + 1) * 8 - 1 downto i * 8);
                    end if;
                end loop;

            else
                Input_v     := In_Data;
                InputHigh_v := In_Data'high;
            end if;

            -- Handle Input permutation (LFSR always processes MSB first)
            if BitOrder_c = "MSB_FIRST" then
                if ByteOrder_c = "LSB_FIRST" then
                    Input_v(InputHigh_v downto 0) := invertByteOrder(Input_v(InputHigh_v downto 0));
                end if;
            else
                if ByteOrder_c = "MSB_FIRST" then
                    Input_v(InputHigh_v downto 0) := invertByteOrder(Input_v(InputHigh_v downto 0));
                end if;
                Input_v(InputHigh_v downto 0) := invertBitOrder(Input_v(InputHigh_v downto 0));
            end if;

            -- Reset valid after output transmitted
            if Out_Valid_I = '1' and Out_Ready = '1' then
                Out_Valid_I <= '0';
            end if;

            -- Normal Operation
            if In_Valid = '1' and In_Ready_I = '1' then

                -- Report a warning when In_Be is used improperly
                if (BeMode_c and In_Last = '0') then
                    -- synthesis translate_off
                    assert In_Be = onesVector(In_Be'length)
                        report "olo_base_crc: In_Be is de-asserted while In_Last='0'. Trailing-Only Byte-Enable convention violated."
                        severity warning;
                    -- synthesis translate_on

                elsif (not(BeMode_c)) then
                    -- synthesis translate_off
                    assert In_Be = onesVector(In_Be'length)
                        report "olo_base_crc: In_Be is ignored when DataWidth_g is not a multiple of 8."
                        severity warning;
                    -- synthesis translate_on
                end if;

                -- First Handling
                if In_First = '1' then
                    Lfsr_v := InitialValue_c;
                else
                    Lfsr_v := LfsrReg;
                end if;

                -- Iterate over all bits of In_Data, including those disabled by In_Be
                -- The loop bounds must be static, as variable ranges are not synthesizable
                for bit in In_Data'high downto 0 loop

                    -- Only execute for the valid bits in input.
                    if bit <= InputHigh_v then

                        -- Input Handling
                        InBit_v := Input_v(bit) xor Lfsr_v(Lfsr_v'high);

                        -- XOR handling
                        Lfsr_v := Lfsr_v(Lfsr_v'high-1 downto 0) & '0';
                        if InBit_v = '1' then
                            Lfsr_v := Lfsr_v xor Polynomial_g;
                        end if;

                    end if;

                end loop;

                -- Output Data
                Out_v := Lfsr_v;
                if BitflipOutput_g then
                    Out_v := invertBitOrder(Out_v);
                end if;
                Out_Crc <= Out_v xor XorOutput_c;

                -- Last Handling
                if In_Last = '1' then
                    Lfsr_v      := InitialValue_c;
                    Out_Valid_I <= '1';
                end if;
                LfsrReg <= Lfsr_v;
            end if;

            -- Reset
            if Rst = '1' then
                LfsrReg     <= InitialValue_c;
                Out_Crc     <= (others => '0');
                Out_Valid_I <= '0';
            end if;

        end if;
    end process;

    -- Combinatorial handling
    In_Ready_I <= Out_Ready or not Out_Valid_I;

    -- Forward internal signal to outputs
    Out_Valid <= Out_Valid_I;
    In_Ready  <= In_Ready_I;

end architecture;
