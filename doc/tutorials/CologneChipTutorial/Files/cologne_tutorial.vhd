library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;    -- Open Logic Library

entity cologne_tutorial is
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst_n           : in    std_logic;

        -- Interfaces
        Switches        : in    std_logic_vector(2 downto 0);
        Led             : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of cologne_tutorial is

    signal Switches_Sync : std_logic_vector(2 downto 0);
    signal Data          : std_logic_vector(3 downto 0);
    signal RisingEdges   : std_logic_vector(2 downto 0);
    signal Events        : std_logic_vector(2 downto 0);
    signal Events_Last   : std_logic_vector(2 downto 0);
    signal Rst           : std_logic;
    signal Led_Int       : std_logic_vector(3 downto 0);

begin

    -- Assert reset
    i_reset : entity olo.olo_base_reset_gen
        port map (
            Clk         => Clk,
            RstOut      => Rst
        );

    -- Debounce Switches
    i_switches : entity olo.olo_intf_debounce
        generic map (
            ClkFrequency_g  => 10.0e6,
            DebounceTime_g  => 25.0e-3,
            Width_g         => 3
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => Switches,
            DataOut     => Switches_Sync
        );

    -- Switch(3) is used for reset
    Events <= Switches_Sync;

    -- Edge Detection
    p_edge_detection : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            RisingEdges <= Events and (not Events_Last);
            Events_Last <= Events;

            -- Reset
            if Rst = '1' then
                RisingEdges <= (others => '0');
                Events_Last <= (others => '0');
            end if;
        end if;
    end process;

    -- Data is emulate through a counter incremented by button press on switch(2)
    -- .. because of lack of available switches/buttons
    p_count : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Counting
            if RisingEdges(2) = '1' then
                Data <= std_logic_vector(unsigned(Data) + 1);
            end if;

            -- Reset
            if Rst = '1' then
                Data <= (others => '0');
            end if;
        end if;
    end process;

    -- FIFO
    i_fifo : entity olo.olo_base_fifo_sync
        generic map (
            Width_g         => 4,
            Depth_g         => 4096
        )
        port map (
            Clk           => Clk,
            Rst           => Rst,
            In_Data       => Data,
            In_Valid      => RisingEdges(0),
            Out_Data      => Led_Int,
            Out_Ready     => RisingEdges(1)
        );

    Led <= not Led_Int; -- Leds are low-active

end architecture;
