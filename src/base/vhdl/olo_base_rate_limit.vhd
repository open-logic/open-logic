---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This component limits the rate of AXI4-Stream style handshaked interfaces to a specified 
-- maximum data rate. It can be used to avoid overloading downstream components. This is especially 
-- useful when interfacing to components that have limited processing capabilities and do not 
-- support back-pressure (i.e. do not de-assert Ready signals).
--
-- The component has two modes of operation:
-- - BLOCK: Forward short bursts at full speed but limit average rate over fixed periods
-- - SMOOTH: Space samples evenly over time to achieve constant output data rate
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_rate_limit.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_rate_limit is
    generic (
        Width_g         : positive;                     -- Width of In_Data and Out_Data
        RegisterReady_g : boolean   := true;            -- If true, In_Ready is registered to improve timing
        Mode_g          : string    := "SMOOTH";        -- Rate limiting mode, either "BLOCK" or "SMOOTH"
        Period_g        : positive;                     -- Time period for rate limiting in clock cycles
        MaxSamples_g    : positive  := 1                -- Maximum number of samples allowed per Period_g
    );
    port (
        -- Control
        Clk             : in    std_logic;              -- Clock
        Rst             : in    std_logic;              -- Reset input (high-active, synchronous to Clk)
        -- Input Data
        In_Data         : in    std_logic_vector(Width_g-1 downto 0);   -- Input data
        In_Valid        : in    std_logic := '1';       -- AXI4-Stream handshaking signal for In_Data
        In_Ready        : out   std_logic;              -- AXI4-Stream handshaking signal for In_Data
        -- Output Data
        Out_Data        : out   std_logic_vector(Width_g-1 downto 0);   -- Output data
        Out_Valid       : out   std_logic;              -- AXI4-Stream handshaking signal for Out_Data
        Out_Ready       : in    std_logic := '1'        -- AXI4-Stream handshaking signal for Out_Data
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_rate_limit is

    -- Two process method signals
    type TwoProcess_r is record
        -- SMOOTH mode signals
        SmoothCounter   : unsigned(log2ceil(Period_g+MaxSamples_g)-1 downto 0);
        -- BLOCK mode signals
        PeriodCounter   : integer range 0 to Period_g-1;
        SamplesCounter  : integer range 0 to MaxSamples_g;
    end record;

    signal r, r_next : TwoProcess_r;
    
    -- Internal signals to avoid reading back output ports
    signal Out_Valid_i : std_logic;
    signal In_Ready_i  : std_logic;
    signal AllowSample : std_logic;

begin

    -- Assertions
    assert MaxSamples_g <= Period_g
        report "olo_base_rate_limit: MaxSamples_g (" & integer'image(MaxSamples_g) & 
               ") must be <= Period_g (" & integer'image(Period_g) & ")"
        severity failure;

    assert Mode_g = "SMOOTH" or Mode_g = "BLOCK"
        report "olo_base_rate_limit: Mode_g must be either ""SMOOTH"" or ""BLOCK"", got """ & Mode_g & """"
        severity failure;

    ---------------------------------------------------------------------------------------------------
    -- Rate Limiting Logic (RegisterReady_g = false case only for now)
    ---------------------------------------------------------------------------------------------------
    
    -- Combinatorial process
    p_comb : process (all) is
        variable v : TwoProcess_r;
        variable OutputTransfer_v : boolean;
    begin
        -- Hold variables stable
        v := r;
        
        -- Detect successful output transfer (rate limiter output to downstream)
        OutputTransfer_v := (Out_Valid_i = '1' and Out_Ready = '1');

        ---------------------------------------------------------------------------------------------------
        -- SMOOTH Mode Logic
        ---------------------------------------------------------------------------------------------------
        if Mode_g = "SMOOTH" then

            -- Update counter: either decrement (on transfer) OR increment (building credit)
            if OutputTransfer_v then
                v.SmoothCounter := r.SmoothCounter - Period_g;
            elsif r.SmoothCounter < Period_g then
                v.SmoothCounter := r.SmoothCounter + MaxSamples_g;
            end if;

            -- Allow sample logic
            if r.SmoothCounter >= Period_g then
                AllowSample <= '1';
            else
                AllowSample <= '0';
            end if;
            
        ---------------------------------------------------------------------------------------------------
        -- BLOCK Mode Logic  
        ---------------------------------------------------------------------------------------------------
        else -- Mode_g = "BLOCK"

            -- Samples counting (increment only when actually outputting)
            if OutputTransfer_v then
                v.SamplesCounter := r.SamplesCounter + 1;
            end if;

            -- Period Handling
            if r.PeriodCounter = Period_g - 1 then
                v.PeriodCounter := 0;
                v.SamplesCounter := 0; 
            else
                v.PeriodCounter := r.PeriodCounter + 1;
            end if;

            -- Allow sample logic
            if r.SamplesCounter < MaxSamples_g - 1 then
                AllowSample <= '1';
            else
                AllowSample <= '0';
            end if;
        end if;

        -- Assign to next state
        r_next <= v;
    end process;

    -- Sequential process  
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.SmoothCounter  <= (others => '0');
                r.PeriodCounter  <= 0; 
                r.SamplesCounter <= 0;
            end if;
        end if;
    end process;


    ---------------------------------------------------------------------------------------------------
    -- Internal Signal Assignment
    ---------------------------------------------------------------------------------------------------
    -- Only allow output when rate limiter permits and input is valid
    Out_Valid_i <= In_Valid and AllowSample;
    -- Only assert ready when downstream is ready and rate limiter allows
    In_Ready_i  <= Out_Ready and AllowSample;

    ---------------------------------------------------------------------------------------------------
    -- Output Port Assignment
    ---------------------------------------------------------------------------------------------------
    Out_Valid <= Out_Valid_i;
    In_Ready  <= In_Ready_i;
    Out_Data  <= In_Data;

end architecture;