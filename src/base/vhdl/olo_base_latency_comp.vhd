---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This module implements a latency compensation for signals that bypass some processing logic.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_latency_comp.md
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
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_base_latency_comp is
    generic (
        Width_g          : positive;
        Mode_g           : string                            := "DYNAMIC";
        Latency_g        : positive range 2 to positive'high := 30;
        AssertsDisable_g : boolean                           := false;
        AssertsName_g    : string                            := "No Name";
        RamBehavior_g    : string                            := "RBW";
        RamStyle_g       : string                            := "auto";
        Resource_g       : string                            := "AUTO"
    );
    port (
        -- Control Ports
        Clk          : in    std_logic;
        Rst          : in    std_logic;
        -- Input Data
        In_Data      : in    std_logic_vector(Width_g-1 downto 0);
        In_Valid     : in    std_logic := '1';
        In_Ready     : in    std_logic := '1';
        -- Output Data
        Out_Data     : out   std_logic_vector(Width_g-1 downto 0);
        Out_Valid    : in    std_logic := '1';
        Out_Ready    : in    std_logic := '1';
        -- Status
        Err_Overrun  : out   std_logic;
        Err_Underrun : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_base_latency_comp is

    -- String upping
    constant ModeUpper_c        : string := toUpper(Mode_g);
    constant RamBehaviorUpper_c : string := toUpper(RamBehavior_g);

    -- Entity wide signals
    signal In_Beat  : std_logic;
    signal Out_Beat : std_logic;

begin

    -- *** Assertions ***
    assert ModeUpper_c = "DYNAMIC" or ModeUpper_c = "FIXED_CYCLES"
        report "###ERROR###: olo_base_latency_comp[" & AssertsName_g & "]: Unknown Mode_g - " & Mode_g
        severity error;

    -- *** Entity Wide Signals ***
    In_Beat  <= In_Valid and In_Ready;
    Out_Beat <= Out_Valid and Out_Ready;

    -- *** DYNAMIC Mode ***
    g_dynamic : if ModeUpper_c = "DYNAMIC" generate
        signal In_Rdy  : std_logic;
        signal Out_Vld : std_logic;
    begin

        -- FIFO
        i_fifo : entity work.olo_base_fifo_sync
            generic map (
                Width_g         => Width_g,
                Depth_g         => Latency_g+2,
                AlmFullOn_g     => false,
                AlmEmptyOn_g    => false,
                RamBehavior_g   => RamBehaviorUpper_c,
                RamStyle_g      => RamStyle_g,
                ReadyRstState_g => '1'
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Data   => In_Data,
                In_Valid  => In_Beat,
                In_Ready  => In_Rdy,
                Out_Data  => Out_Data,
                Out_Valid => Out_Vld,
                Out_Ready => Out_Beat
            );

        -- Error Detection
        p_errors : process (Clk) is
        begin
            if rising_edge(Clk) then

                -- Overrun
                if In_Beat = '1' and In_Rdy = '0' and Out_Beat = '0' then
                    Err_Overrun <= '1';
                    if not AssertsDisable_g then
                        -- synthesis translate_off
                        report "###WARNING###: olo_base_latency_comp[" & AssertsName_g & "]: Overrun detected in DYNAMIC mode."
                            severity warning;
                        -- synthesis translate_on
                    end if;
                end if;

                -- Underrun
                if Out_Beat = '1' and Out_Vld = '0' then
                    Err_Underrun <= '1';
                    if not AssertsDisable_g then
                        -- synthesis translate_off
                        report "###WARNING###: olo_base_latency_comp[" & AssertsName_g & "]: Underrun detected in DYNAMIC mode."
                            severity warning;
                        -- synthesis translate_on
                    end if;
                end if;

                -- Reset
                if Rst = '1' then
                    Err_Overrun  <= '0';
                    Err_Underrun <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- *** FIXED_CYCLES Mode ***
    g_fixed_cycles : if ModeUpper_c = "FIXED_CYCLES" generate
        signal Delay_Data   : std_logic_vector(Width_g-1 downto 0);
        signal Delay_Beat   : std_logic;
        signal Data_Latched : std_logic;
        signal InData       : std_logic_vector(Width_g downto 0);
        signal OutData      : std_logic_vector(Width_g downto 0);
    begin

        -- Input assembly
        InData(Width_g-1 downto 0) <= In_Data;
        InData(Width_g)            <= In_Beat;

        -- Delay Line
        i_delay : entity work.olo_base_delay
            generic map (
                Width_g       => Width_g+1,
                Delay_g       => Latency_g-1,
                RstState_g    => true,
                RamBehavior_g => RamBehaviorUpper_c,
                Resource_g    => Resource_g,
                RamStyle_g    => RamStyle_g
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                In_Data  => InData,
                In_Valid => '1',
                Out_Data => OutData
            );

        -- Output disassembly
        Delay_Data <= OutData(Width_g-1 downto 0);
        Delay_Beat <= OutData(Width_g);

        -- Logic to allow output side handshaking
        -- ... Keep output data valid as long as no new sample arrives
        p_handshake : process (Clk) is
        begin
            if rising_edge(Clk) then

                -- Overrun Detection
                if Data_Latched = '1' and Delay_Beat = '1' and Out_Beat = '0' then
                    Err_Overrun <= '1';
                    if not AssertsDisable_g then
                        -- synthesis translate_off
                        report "###WARNING###: olo_base_latency_comp[" & AssertsName_g & "]: Overrun detected in FIXED_CYCLES mode."
                            severity warning;
                        -- synthesis translate_on
                    end if;
                end if;

                -- Underrun Detection
                if Data_Latched = '0' and Out_Beat = '1' then
                    Err_Underrun <= '1';
                    if not AssertsDisable_g then
                        -- synthesis translate_off
                        report "###WARNING###: olo_base_latency_comp[" & AssertsName_g & "]: Underrun detected in FIXED_CYCLES mode."
                            severity warning;
                        -- synthesis translate_on
                    end if;
                end if;

                -- Data Latched Update
                if Delay_Beat = '1' then
                    Data_Latched <= '1';
                    Out_Data     <= Delay_Data;
                elsif Out_Beat = '1' then
                    Data_Latched <= '0';
                end if;

                -- Reset
                if Rst = '1' then
                    Data_Latched <= '0';
                    Err_Overrun  <= '0';
                    Err_Underrun <= '0';
                end if;
            end if;
        end process;

    end generate;

end architecture;

