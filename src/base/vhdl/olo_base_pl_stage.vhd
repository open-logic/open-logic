------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2023-2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This entity implements a pipelinestage with handshaking (AXI-S Ready/Valild). The
-- pipeline stage ensures all signals are registered in both directions (including
-- Ready). This is important to break long logic chains that can occur in the RDY
-- paths because Rdy is often forwarded asynchronously.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_pl_stage is
    generic (
        Width_g     : positive;
        UseReady_g  : boolean   := true;
        Stages_g    : natural   := 1
    ); 
    port (   
        -- Control Ports
        Clk         : in  std_logic;                              
        Rst         : in  std_logic;    
        -- Input                          
        In_Valid    : in  std_logic := '1';                              
        In_Ready    : out std_logic;                              
        In_Data     : in  std_logic_vector(Width_g-1 downto 0); 
        -- Output
        Out_Valid   : out std_logic;                              
        Out_Ready   : in  std_logic := '1';                       
        Out_Data    : out std_logic_vector(Width_g-1 downto 0)
    );
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_pl_stage is
    -- Single Stage Entity forward-declaration (defined later in this file)
    component olo_base_pl_stage_single is
        generic (
            Width_g     : positive;
            UseReady_g  : boolean   := true
        ); 
        port (   
            Clk         : in  std_logic;                              
            Rst         : in  std_logic;                             
            In_Valid    : in  std_logic;                              
            In_Ready    : out std_logic;                              
            In_Data     : in  std_logic_vector(Width_g-1 downto 0); 
            Out_Valid   : out std_logic;                              
            Out_Ready   : in  std_logic := '1';                       
            Out_Data    : out std_logic_vector(Width_g-1 downto 0)
        );
    end component;
    -- Signals
    type Data_t is array (natural range <>) of std_logic_vector(Width_g - 1 downto 0);
    signal data_s : Data_t(0 to Stages_g);
    signal valid_s  : std_logic_vector(0 to Stages_g);
    signal ready_s  : std_logic_vector(0 to Stages_g);
begin
    -- *** On or more stages required ***
    g_nonzero : if Stages_g > 0 generate
        valid_s(0)  <= In_Valid;
        In_Ready    <= ready_s(0);
        data_s(0)   <= In_Data;

        g_stages : for i in 0 to Stages_g - 1 generate
            i_stg : component olo_base_pl_stage_single
                generic map(
                    Width_g   => Width_g,
                    UseReady_g => UseReady_g
                )
                port map(
                    Clk => Clk,
                    Rst => Rst,
                    In_Valid => valid_s(i),
                    In_Ready => ready_s(i),
                    In_Data => data_s(i),
                    Out_Valid => valid_s(i + 1),
                    Out_Ready => ready_s(i + 1),
                    Out_Data => data_s(i + 1)
                );
        end generate;

        Out_Valid           <= valid_s(Stages_g);
        ready_s(Stages_g)   <= Out_Ready;
        Out_Data            <= data_s(Stages_g);
    end generate;

    -- *** Zero stages ***
    g_zero : if Stages_g = 0 generate
        Out_Valid    <= In_Valid;
        Out_Data    <= In_Data;
        In_Ready <= Out_Ready;
    end generate;

end;

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

------------------------------------------------------------------------------
-- Single Stage Entity
------------------------------------------------------------------------------
entity olo_base_pl_stage_single is
    generic (
        Width_g     : positive;
        UseReady_g  : boolean   := true
    ); 
    port (   
        -- Control Ports
        Clk         : in  std_logic;                              
        Rst         : in  std_logic;    
        -- Input                          
        In_Valid    : in  std_logic;                              
        In_Ready    : out std_logic;                              
        In_Data     : in  std_logic_vector(Width_g-1 downto 0); 
        -- Output
        Out_Valid   : out std_logic;                              
        Out_Ready   : in  std_logic := '1';                       
        Out_Data    : out std_logic_vector(Width_g-1 downto 0)
    );
end entity;

------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_pl_stage_single is
    -- two process method
    type tp_r is record
        DataMain    : std_logic_vector(Width_g - 1 downto 0);
        DataMainVld : std_logic;
        DataShad    : std_logic_vector(Width_g - 1 downto 0);
        DataShadVld : std_logic;
        In_Ready       : std_logic;
    end record;
    signal r, r_next : tp_r;

begin
  
    -- *** Pipeline Stage with RDY ***
    g_rdy : if UseReady_g generate

        p_comb : process(In_Valid, In_Data, Out_Ready, r)
            variable v         : tp_r;
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

        In_Ready <= r.In_Ready;
        Out_Valid <= r.DataMainVld;
        Out_Data <= r.DataMain;

        p_seq : process(Clk)
        begin
            if rising_edge(Clk) then
                r <= r_next;
                if Rst = '1' then
                    r.DataMainVld <= '0';
                    r.DataShadVld <= '0';
                    r.In_Ready       <= '1';
                end if;
            end if;
        end process;
    end generate;

  
    -- *** Pipeline Stage without RDY ***
    g_nrdy : if not UseReady_g generate
        signal VldReg   : std_logic;
        signal DataReg  : std_logic_vector(Width_g-1 downto 0);

        -- Synthesis attributes AMD
        attribute syn_srlstyle : string;
        attribute syn_srlstyle of VldReg : signal is "registers";
        attribute syn_srlstyle of DataReg : signal is "registers";

        attribute shreg_extract : string;
        attribute shreg_extract of VldReg : signal is "no";
        attribute shreg_extract of DataReg : signal is "no";

        -- Synthesis attributes Intel
        attribute dont_merge : boolean;
        attribute dont_merge of VldReg : signal is true;
        attribute dont_merge of DataReg : signal is true;   

        attribute preserve : boolean;
        attribute preserve of VldReg : signal is true;
        attribute preserve of DataReg : signal is true;         
    begin
        
        p_stg : process(Clk)
        begin
            if rising_edge(Clk) then
                DataReg <= In_Data;
                VldReg <= In_Valid;
                if Rst = '1' then
                    VldReg <= '0';
                end if;
            end if;
        end process;

        In_Ready <= '1'; -- Not used!
        Out_Data <= DataReg;
        Out_Valid <= VldReg;

    end generate;

end architecture;
