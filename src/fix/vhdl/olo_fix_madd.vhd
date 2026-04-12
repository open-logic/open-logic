---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a multiply-add operation as used to build FIR filters for example.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_madd.md
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
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_madd is
    generic (
        -- Functionality
        PreAdd_g      : boolean := false;
        InBIsCoef_g   : boolean := false;
        Operation_g   : string  := "Add";
        -- Formats / Round / Saturate
        AFmt_g        : string;
        BFmt_g        : string;
        CFmt_g        : string  := "(0,0,0)";
        AddChainFmt_g : string;
        -- Registers
        MultRegs_g    : natural := 1
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input
        InAC_Valid  : in    std_logic                                                           := '1';
        InA_Data    : in    std_logic_vector(fixFmtWidthFromString(AFmt_g) - 1 downto 0);
        InC_Data    : in    std_logic_vector(fixFmtWidthFromString(CFmt_g) - 1 downto 0)        := (others => '0');
        InB_Valid   : in    std_logic                                                           := '1';
        InB_Data    : in    std_logic_vector(fixFmtWidthFromString(BFmt_g) - 1 downto 0);
        -- Adder Chain
        MaccIn      : in    std_logic_vector(fixFmtWidthFromString(AddChainFmt_g) - 1 downto 0) := (others => '0');
        -- Output
        Out_Valid   : out   std_logic;
        Out_Data    : out   std_logic_vector(fixFmtWidthFromString(AddChainFmt_g) - 1 downto 0)
    );
end entity;

architecture rtl of olo_fix_madd is

    -- *** Fomrats ***
    constant AFmt_c        : FixFormat_t := cl_fix_format_from_string(AFmt_g);
    constant BFmt_c        : FixFormat_t := cl_fix_format_from_string(BFmt_g);
    constant CFmt_c        : FixFormat_t := cl_fix_format_from_string(CFmt_g);
    constant AddChainFmt_c : FixFormat_t := cl_fix_format_from_string(AddChainFmt_g);
    constant PreAddFmt_c   : FixFormat_t := cl_fix_add_fmt(AFmt_c, CFmt_c);
    constant MultInFmt_c   : FixFormat_t := choose(PreAdd_g, PreAddFmt_c, AFmt_c);
    constant MultOutFmt_c  : FixFormat_t := cl_fix_mult_fmt(MultInFmt_c, BFmt_c);

    -- *** Types ***
    type MulReg_t is array (0 to MultRegs_g - 1) of std_logic_vector(cl_fix_width(MultOutFmt_c) - 1 downto 0);

    -- *** Signals ***
    signal MulReg   : MulReg_t;
    signal MulInAC  : std_logic_vector(cl_fix_width(MultInFmt_c) - 1 downto 0);
    signal MulInB   : std_logic_vector(cl_fix_width(BFmt_c) - 1 downto 0);
    signal MulInVld : std_logic;
    signal MulVld   : std_logic_vector(0 to MultRegs_g);

begin

    -- *** Assertions ***
    -- synthesis translate_off
    assert compareNoCase(Operation_g, "Add") or compareNoCase(Operation_g, "Sub")
        report "olo_fix_madd - Invalid Operation_g. Allowed values are 'Add' and 'Sub'."
        severity error;
    -- synthesis translate_on

    -- *** Input side ***
    -- Pre-adder
    g_preadd : if PreAdd_g generate
        signal A_0   : std_logic_vector(cl_fix_width(AFmt_c) - 1 downto 0);
        signal C_0   : std_logic_vector(cl_fix_width(CFmt_c) - 1 downto 0);
        signal B_0   : std_logic_vector(cl_fix_width(BFmt_c) - 1 downto 0);
        signal Vld_0 : std_logic;
    begin

        p_in : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Stage 0 (input registers)
                if InAC_Valid = '1' then
                    A_0 <= InA_Data;
                    C_0 <= InC_Data;
                end if;
                if InB_Valid = '1' then
                    B_0 <= InB_Data;
                end if;

                -- Valid handling - do not produce output sample for static coefficient update
                if InBIsCoef_g then
                    Vld_0 <= InAC_Valid;
                else
                    Vld_0 <= InAC_Valid or InB_Valid;
                end if;

                -- Stage 1 - pre add
                MulInAC  <= cl_fix_add(A_0, AFmt_c, C_0, CFmt_c, PreAddFmt_c);
                MulInB   <= B_0;
                MulInVld <= Vld_0;

                -- Reset
                if Rst = '1' then
                    MulInVld <= '0';
                    Vld_0    <= '0';
                end if;

            end if;
        end process;

    end generate;

    -- No pre-adder
    g_no_preadd : if not PreAdd_g generate
    begin

        p_in : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Input Registers
                if InAC_Valid = '1' then
                    MulInAC <= InA_Data;
                end if;
                if InB_Valid = '1' then
                    MulInB <= InB_Data;
                end if;

                -- Valid handling - do not produce output sample for static coefficient update
                if InBIsCoef_g then
                    MulInVld <= InAC_Valid;
                else
                    MulInVld <= InAC_Valid or InB_Valid;
                end if;

                -- Reset
                if Rst = '1' then
                    MulInVld <= '0';
                end if;

            end if;
        end process;

    end generate;

    -- *** Multiply / AddSub ***
    p_madd : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Multiply
            MulReg(0) <= cl_fix_mult(MulInAC, MultInFmt_c, MulInB, BFmt_c, MultOutFmt_c);

            for i in 1 to MultRegs_g - 1 loop
                MulReg(i) <= MulReg(i-1);
            end loop;

            -- Add/Sub
            if compareNoCase(Operation_g, "Add") then
                Out_Data <= cl_fix_add(MaccIn, AddChainFmt_c, MulReg(MultRegs_g - 1), MultOutFmt_c, AddChainFmt_c);
            else
                Out_Data <= cl_fix_sub(MaccIn, AddChainFmt_c, MulReg(MultRegs_g - 1), MultOutFmt_c, AddChainFmt_c);
            end if;

            -- Valid Handling
            MulVld(0)               <= MulInVld;
            MulVld(1 to MultRegs_g) <= MulVld(0 to MultRegs_g - 1);

            -- Reset
            if Rst = '1' then
                MulVld   <= (others => '0');
                Out_Data <= (others => '0');
            end if;
        end if;
    end process;

    Out_Valid <= MulVld(MultRegs_g);

end architecture;
