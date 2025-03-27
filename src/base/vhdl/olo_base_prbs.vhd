---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Rafael Basso, Oliver Bründler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description:
---------------------------------------------------------------------------------------------------
-- A generic pseudo random binary sequence based on a linear-feedback shifter
-- register.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_prbs.md
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
entity olo_base_prbs is
    generic (
        Polynomial_g    : std_logic_vector;
        Seed_g          : std_logic_vector;
        BitsPerSymbol_g : positive := 1
    );
    port (
        -- Control Ports
        Clk              : in    std_logic;
        Rst              : in    std_logic;
        -- Output
        Out_Data         : out   std_logic_vector(BitsPerSymbol_g-1 downto 0);
        Out_Ready        : in    std_logic                                        := '1';
        Out_Valid        : out   std_logic;
        -- State
        State_Current    : out   std_logic_vector(Polynomial_g'length-1 downto 0);
        State_New        : in    std_logic_vector(Polynomial_g'length-1 downto 0) := (others => '0');
        State_Set        : in    std_logic                                        := '0'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------

architecture rtl of olo_base_prbs is

    -- Functions
    function lfsrRegLength (constant PL_c : natural; constant BPS_c : natural) return natural is
    begin
        if BPS_c > PL_c then
            return BPS_c;
        else
            return PL_c;
        end if;
    end function;

    -- Signals
    signal LfsrReg : std_logic_vector(lfsrRegLength(Polynomial_g'length, BitsPerSymbol_g)-1 downto 0);

begin

    assert Polynomial_g'length >= 2
        report "###ERROR###: olo_base_prbs - Polynomial_g width must be at least 2"
        severity error;
    assert Seed_g'length = Polynomial_g'length
        report "###ERROR###: olo_base_prbs - Seed_g width must match Polynomial_g width"
        severity error;
    assert fromUslv(Seed_g) /= 0
        report "###ERROR###: olo_base_prbs - Seed_g MUST NOT be zero"
        severity error;
    assert BitsPerSymbol_g >= 1
        report "###ERROR###: olo_base_prbs - BitsPerSymbol_g width must be larger or equal to 1"
        severity error;

    Out_Valid     <= '1';
    Out_Data      <= invertBitOrder(LfsrReg(LfsrReg'high downto LfsrReg'length-BitsPerSymbol_g));
    State_Current <= LfsrReg(State_Current'high downto 0);

    p_lfsr : process (Clk) is
        variable NextBit_v    : std_logic;
        variable Lfsr_v       : std_logic_vector(LfsrReg'range);
        variable LfsrMasked_v : std_logic_vector(Polynomial_g'length-1 downto 0);
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            if Out_Ready = '1' then
                Lfsr_v := LfsrReg;

                -- Loop over all bits in symbol
                for bit in 0 to BitsPerSymbol_g-1 loop
                    LfsrMasked_v := Lfsr_v(Polynomial_g'length-1 downto 0) and Polynomial_g;
                    NextBit_v    := xor_reduce(LfsrMasked_v);
                    Lfsr_v       := Lfsr_v(Lfsr_v'high-1 downto 0) & NextBit_v;
                end loop;

                LfsrReg <= Lfsr_v;
            end if;

            -- Load state
            if State_Set = '1' then
                LfsrReg                                 <= (others => '0');
                LfsrReg(Polynomial_g'length-1 downto 0) <= State_New;
            end if;

            -- Reset
            if Rst = '1' then
                LfsrReg                                 <= (others => '0');
                LfsrReg(Polynomial_g'length-1 downto 0) <= Seed_g;
            end if;

        end if;

    end process;

end architecture;
