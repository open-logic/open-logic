---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple data-width conversion. The output width
-- must be an integer multiple of the input width (Wo = n*Wi).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_wconv_n2xn.md
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
entity olo_base_wconv_n2xn is
    generic (
        InWidth_g  : positive;
        OutWidth_g : positive
    );
    port (
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        In_Valid     : in    std_logic := '1';
        In_Ready     : out   std_logic;
        In_Data      : in    std_logic_vector(InWidth_g - 1 downto 0);
        In_Last      : in    std_logic := '0';
        Out_Valid    : out   std_logic;
        Out_Ready    : in    std_logic := '1';
        Out_Data     : out   std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Last     : out   std_logic;
        Out_WordEna  : out   std_logic_vector(OutWidth_g / InWidth_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_wconv_n2xn is

    -- *** Constants ***
    constant RatioReal_c : real    := real(OutWidth_g) / real(InWidth_g);
    constant RatioInt_c  : integer := integer(RatioReal_c);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        DataVld     : std_logic_vector(RatioInt_c - 1 downto 0);
        Data        : std_logic_vector(OutWidth_g - 1 downto 0);
        DataLast    : std_logic;
        Out_Valid   : std_logic;
        Out_Data    : std_logic_vector(OutWidth_g - 1 downto 0);
        Out_Last    : std_logic;
        Out_WordEna : std_logic_vector(RatioInt_c - 1 downto 0);
        Cnt         : integer range 0 to RatioInt_c;
    end record;

    signal r, r_next : TwoProcess_r;

begin

    assert floor(RatioReal_c) = ceil(RatioReal_c)
        report "olo_base_wconv_n2xn: Ratio OutWidth_g/InWidth_g must be an integer number"
        severity error;
    assert OutWidth_g >= InWidth_g
        report "olo_base_wconv_n2xn: OutWidth_g must be bigger or equal than InWidth_g"
        severity error;

    -- Implement conversion logic only if required
    g_convert : if OutWidth_g > InWidth_g generate

        p_comb : process (all) is
            variable v           : TwoProcess_r;
            variable IsStuck_v   : std_logic;
            variable ShiftDone_v : boolean;
        begin
            -- *** hold variables stable ***
            v := r;

            -- Halt detection
            ShiftDone_v := (r.DataVld(r.DataVld'high) = '1') or (r.DataLast = '1');
            if ShiftDone_v and (r.Out_Valid = '1') and (Out_Ready = '0') then
                IsStuck_v := '1';
            else
                IsStuck_v := '0';
            end if;

            -- Reset OutVld when transfer occured
            if (r.Out_Valid = '1') and (Out_Ready = '1') then
                v.Out_Valid := '0';
            end if;

            -- Data Deserialization
            if ShiftDone_v and ((r.Out_Valid = '0') or (Out_Ready = '1')) then
                v.Out_Valid   := '1';
                v.Out_Data    := r.Data;
                v.Out_Last    := r.DataLast;
                v.Out_WordEna := r.DataVld;
                v.DataVld     := (others => '0');
                v.DataLast    := '0';
            end if;
            if In_Valid = '1' and IsStuck_v = '0' then
                v.Data((r.Cnt + 1) * InWidth_g - 1 downto r.Cnt * InWidth_g) := In_Data;
                v.DataVld(r.Cnt)                                             := '1';
                if In_Last = '1' then
                    v.DataLast := '1';
                end if;
                if (r.Cnt = RatioInt_c - 1) or (In_Last = '1') then
                    v.Cnt := 0;
                else
                    v.Cnt := r.Cnt + 1;
                end if;
            end if;

            -- Outputs
            In_Ready    <= not IsStuck_v;
            Out_Valid   <= r.Out_Valid;
            Out_Data    <= r.Out_Data;
            Out_Last    <= r.Out_Last;
            Out_WordEna <= r.Out_WordEna;

            -- *** assign signal ***
            r_next <= v;
        end process;

        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.DataVld   <= (others => '0');
                    r.Out_Valid <= '0';
                    r.Cnt       <= 0;
                    r.DataLast  <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- No conversion required
    g_equalwidth : if OutWidth_g = InWidth_g generate
        Out_Valid   <= In_Valid;
        Out_Data    <= In_Data;
        Out_Last    <= In_Last;
        Out_WordEna <= (others => '1');
        In_Ready    <= Out_Ready;

    end generate;

end architecture;
