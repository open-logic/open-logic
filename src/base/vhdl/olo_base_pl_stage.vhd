---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2023-2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a pipelinestage with handshaking (AXI-S Ready/Valild). The
-- pipeline stage ensures all signals are registered in both directions (including
-- Ready). This is important to break long logic chains that can occur in the RDY
-- paths because Rdy is often forwarded asynchronously.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pl_stage.md
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_pl_stage is
    generic (
        Width_g     : positive;
        UseReady_g  : boolean := true;
        Stages_g    : natural := 1
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input
        In_Valid    : in    std_logic := '1';
        In_Ready    : out   std_logic;
        In_Data     : in    std_logic_vector(Width_g-1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic := '1';
        Out_Data    : out   std_logic_vector(Width_g-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_pl_stage is

    -- Single Stage Entity forward-declaration (defined later in this file)
    component olo_private_pl_stage_single is
        generic (
            Width_g     : positive;
            UseReady_g  : boolean   := true
        );
        port (
            Clk         : in    std_logic;
            Rst         : in    std_logic;
            In_Valid    : in    std_logic;
            In_Ready    : out   std_logic;
            In_Data     : in    std_logic_vector(Width_g-1 downto 0);
            Out_Valid   : out   std_logic;
            Out_Ready   : in    std_logic := '1';
            Out_Data    : out   std_logic_vector(Width_g-1 downto 0)
        );
    end component;

    -- Types
    type Data_t is array (natural range <>) of std_logic_vector(Width_g - 1 downto 0);

    -- Signals
    signal Data  : Data_t(0 to Stages_g);
    signal Valid : std_logic_vector(0 to Stages_g);
    signal Ready : std_logic_vector(0 to Stages_g);

begin

    -- *** On or more stages required ***
    g_nonzero : if Stages_g > 0 generate
        Valid(0) <= In_Valid;
        In_Ready <= Ready(0);
        Data(0)  <= In_Data;

        g_stages : for i in 0 to Stages_g - 1 generate

            -- Signle pipeline stage instance
            i_stg : component olo_private_pl_stage_single
                generic map (
                    Width_g    => Width_g,
                    UseReady_g => UseReady_g
                )
                port map (
                    Clk       => Clk,
                    Rst       => Rst,
                    In_Valid  => Valid(i),
                    In_Ready  => Ready(i),
                    In_Data   => Data(i),
                    Out_Valid => Valid(i + 1),
                    Out_Ready => Ready(i + 1),
                    Out_Data  => Data(i + 1)
                );

        end generate;

        Out_Valid       <= Valid(Stages_g);
        Ready(Stages_g) <= Out_Ready;
        Out_Data        <= Data(Stages_g);
    end generate;

    -- *** Zero stages ***
    g_zero : if Stages_g = 0 generate
        Out_Valid <= In_Valid;
        Out_Data  <= In_Data;
        In_Ready  <= Out_Ready;
    end generate;

end architecture;

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_attribute.all;

---------------------------------------------------------------------------------------------------
-- Single Stage Entity
---------------------------------------------------------------------------------------------------
entity olo_private_pl_stage_single is
    generic (
        Width_g     : positive;
        UseReady_g  : boolean := true
    );
    port (
        -- Control Ports
        Clk         : in    std_logic;
        Rst         : in    std_logic;
        -- Input
        In_Valid    : in    std_logic;
        In_Ready    : out   std_logic;
        In_Data     : in    std_logic_vector(Width_g-1 downto 0);
        -- Output
        Out_Valid   : out   std_logic;
        Out_Ready   : in    std_logic := '1';
        Out_Data    : out   std_logic_vector(Width_g-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_private_pl_stage_single is

    -- two process method
    type TwoProcess_r is record
        DataMain    : std_logic_vector(Width_g - 1 downto 0);
        DataMainVld : std_logic;
        DataShad    : std_logic_vector(Width_g - 1 downto 0);
        DataShadVld : std_logic;
        In_Ready    : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

begin

    -- *** Pipeline Stage with RDY ***
    g_rdy : if UseReady_g generate

        p_comb : process (all) is
            variable v         : TwoProcess_r;
            variable IsStuck_v : boolean;
        begin
            -- *** Hold variables stable ***
            v := r;

            -- *** Simplification Variables ***
            IsStuck_v := (r.DataMainVld = '1' and Out_Ready = '0' and (In_Valid = '1' or r.DataShadVld = '1'));

            -- *** Handle output transactions ***
            if r.DataMainVld = '1' and Out_Ready = '1' then
                v.DataMainVld := r.DataShadVld;
                v.DataMain    := r.DataShad;
                v.DataShadVld := '0';
            end if;

            -- *** Latch incoming data ***
            if r.In_Ready = '1' and In_Valid = '1' then
                -- If we are stuck, save data in shadow register because ready is deasserted only after one clock cycle
                if IsStuck_v then
                    v.DataShadVld := '1';
                    v.DataShad    := In_Data;
                -- In normal case, forward data directly to the output registers
                else
                    v.DataMainVld := '1';
                    v.DataMain    := In_Data;
                end if;
            end if;

            -- *** Remove Rdy if stuck ***
            if IsStuck_v then
                v.In_Ready := '0';
            else
                v.In_Ready := '1';
            end if;

            -- *** Assign to signal ***
            r_next <= v;
        end process;

        In_Ready  <= r.In_Ready;
        Out_Valid <= r.DataMainVld;
        Out_Data  <= r.DataMain;

        p_seq : process (Clk) is
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.DataMainVld <= '0';
                    r.DataShadVld <= '0';
                    r.In_Ready    <= '1';
                end if;
            end if;
        end process;

    end generate;

    -- *** Pipeline Stage without RDY ***
    g_nrdy : if not UseReady_g generate
        signal VldReg  : std_logic;
        signal DataReg : std_logic_vector(Width_g-1 downto 0);

        -- Synthesis attributes - suppress shift register extraction
        attribute shreg_extract of VldReg  : signal is ShregExtract_SuppressExtraction_c;
        attribute shreg_extract of DataReg : signal is ShregExtract_SuppressExtraction_c;

        attribute syn_srlstyle of VldReg  : signal is SynSrlstyle_FlipFlops_c;
        attribute syn_srlstyle of DataReg : signal is SynSrlstyle_FlipFlops_c;

        -- Synthesis attributes - preserve registers
        attribute dont_merge of VldReg  : signal is DontMerge_SuppressChanges_c;
        attribute dont_merge of DataReg : signal is DontMerge_SuppressChanges_c;

        attribute preserve of VldReg  : signal is Preserve_SuppressChanges_c;
        attribute preserve of DataReg : signal is Preserve_SuppressChanges_c;

        attribute syn_keep of VldReg  : signal is SynKeep_SuppressChanges_c;
        attribute syn_keep of DataReg : signal is SynKeep_SuppressChanges_c;

        attribute syn_preserve of VldReg  : signal is SynPreserve_SuppressChanges_c;
        attribute syn_preserve of DataReg : signal is SynPreserve_SuppressChanges_c;

    begin

        p_stg : process (Clk) is
        begin
            if rising_edge(Clk) then
                DataReg <= In_Data;
                VldReg  <= In_Valid;
                if Rst = '1' then
                    VldReg <= '0';
                end if;
            end if;
        end process;

        In_Ready  <= '1'; -- Not used!
        Out_Data  <= DataReg;
        Out_Valid <= VldReg;

    end generate;

end architecture;
