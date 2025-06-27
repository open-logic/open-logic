---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple data-width conversion. The input width
-- must be an integer multiple of the output width (Wi = n*Wo)
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_wconv_xn2n.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_wconv_xn2n is
    generic (
        InWidth_g  : positive;
        OutWidth_g : positive
    );
    port (
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        In_Valid    : in    std_logic;
        In_Ready    : out   std_logic;
        In_Data     : in    std_logic_vector(InWidth_g - 1 downto 0);
        In_Last     : in    std_logic                                             := '0';
        In_WordEna  : in    std_logic_vector(InWidth_g / OutWidth_g - 1 downto 0) := (others => '1');
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic                                             := '1';
        Out_Data    : out   std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Last    : out   std_logic
    );
end entity;

architecture rtl of olo_base_wconv_xn2n is

    -- *** Constants ***
    constant RatioReal_c : real    := real(InWidth_g) / real(OutWidth_g);
    constant RatioInt_c  : integer := integer(RatioReal_c);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        Data     : std_logic_vector(InWidth_g - 1 downto 0);
        DataVld  : std_logic_vector(RatioInt_c - 1 downto 0);
        DataLast : std_logic_vector(RatioInt_c - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

begin

    assert floor(RatioReal_c) = ceil(RatioReal_c)
        report "olo_base_wconv_xn2n: Ratio OutWidth_g/InWidth_g must be an integer number"
        severity error;
    assert OutWidth_g < InWidth_g
        report "olo_base_wconv_n2xn: OutWidth_g must be smaller than InWidth_g"
        severity error;

    p_comb : process (all) is
        variable v         : TwoProcess_r;
        variable IsReady_v : std_logic;
    begin
        -- *** hold variables stable ***
        v := r;

        -- Halt detection
        IsReady_v := '1';
        if unsigned(r.DataVld(r.DataVld'high downto 1)) /= 0 then
            IsReady_v := '0';
        elsif r.DataVld(0) = '1' and Out_Ready = '0' then
            IsReady_v := '0';
        end if;

        -- Get new data
        if IsReady_v = '1' and In_Valid = '1' then
            v.Data    := In_Data;
            v.DataVld := In_WordEna;
            -- Assert last to the correct data-word
            v.DataLast := (others => '0');

            -- Loop over all input sub-words and assert last to the correct output word
            for i in RatioInt_c-1 downto 0 loop
                if In_WordEna(i) = '1' and In_Last = '1' then
                    v.DataLast(i) := '1';
                    exit;
                end if;
            end loop;

        elsif (Out_Ready = '1') and (unsigned(r.DataVld) /= 0) then
            v.Data     := zerosVector(OutWidth_g) & r.Data(r.Data'left downto OutWidth_g);
            v.DataVld  := '0' & r.DataVld(r.DataVld'left downto 1);
            v.DataLast := '0' & r.DataLast(r.DataLast'left downto 1);
        end if;

        -- Outputs
        Out_Data  <= r.Data(OutWidth_g - 1 downto 0);
        In_Ready  <= IsReady_v;
        Out_Valid <= r.DataVld(0);
        Out_Last  <= r.DataLast(0);

        -- *** assign signal ***
        r_next <= v;
    end process;

    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.DataVld <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
