----------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Rafael Basso, Oliver Bründler
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Description: 
----------------------------------------------------------------------------------
-- A generic pseudo random binary sequence based on a linear-feedback shifter
-- register.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_prbs is
    generic (
        LfsrWidth_g     : positive range 2 to natural'high;
        Polynomial_g    : std_logic_vector;
        Seed_g          : std_logic_vector;
        BitsPerSymbol_g : positive                          := 1
    );
    port (
        -- Control Ports   
        Clk              : in  std_logic; 
        Rst              : in  std_logic;
        -- Output
        Out_Data         : out std_logic_vector(BitsPerSymbol_g-1 downto 0);
        Out_Ready        : in  std_logic                                     := '1';
        Out_Valid        : out std_logic;
        -- State
        State_Current    : out std_logic_vector(LfsrWidth_g-1 downto 0);
        State_New        : in  std_logic_vector(LfsrWidth_g-1 downto 0)     := (others => '0');
        State_Set        : in  std_logic                                    := '0'
    );
        
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------

architecture behav of olo_base_prbs is
    -- Signals
    signal LfsrReg  : std_logic_vector(LfsrWidth_g-1 downto 0); 
begin

    assert Polynomial_g'length = LfsrWidth_g report "###ERROR###: olo_base_prbs - Polynomial_g width must match LfsrWidth_g" severity error;
    assert Seed_g'length = LfsrWidth_g report "###ERROR###: olo_base_prbs - Seed_g width must match LfsrWidth_g" severity error;
    assert unsigned(Seed_g) /= 0 report "###ERROR###: olo_base_prbs - Seed_g MUST NOT be zero" severity error;
    assert BitsPerSymbol_g <= LfsrWidth_g report "###ERROR###: olo_base_prbs - BitsPerSymbol_g width must  be smaller or equal to LfsrWidth_g" severity error;

    Out_Valid   <= '1';
    Out_Data    <= invertBitOrder(LfsrReg(LfsrReg'high downto LfsrReg'length-BitsPerSymbol_g));
    State_Current <= LfsrReg;


    p_lfsr : process(Clk)
        variable NextBit_v      : std_logic;
        variable Lfsr_v         : std_logic_vector(LfsrReg'range);
        variable LfsrMasked_v   : std_logic_vector(LfsrReg'range);
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            if Out_Ready = '1' then
                Lfsr_v := LfsrReg;
                for bit in 0 to BitsPerSymbol_g-1 loop
                    LfsrMasked_v := Lfsr_v and Polynomial_g;
                    NextBit_v := reduceXor(LfsrMasked_v);
                    Lfsr_v := Lfsr_v(LfsrWidth_g-2 downto 0) & NextBit_v;
                end loop;
                LfsrReg <= Lfsr_v;
            end if;

            -- Load state
            if State_Set = '1' then
                LfsrReg <= State_New;
            end if;

            -- Reset
            if Rst = '1' then
                LfsrReg <= Seed_g;
            end if;

        end if;
    end process;

end architecture;
