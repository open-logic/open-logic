library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;    -- Open Logic Library

entity libero_tutorial is
    port (
        -- Control Signals
        Clk             : in    std_logic;
        -- Interfaces
        Switches        : in    std_logic_vector(3 downto 0);
        Led             : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of libero_tutorial is

    signal Switches_Inv  : std_logic_vector(3 downto 0);
    signal Switches_Sync : std_logic_vector(3 downto 0);
    signal Data          : std_logic_vector(3 downto 0);
    signal RisingEdges   : std_logic_vector(2 downto 0);
    signal Events        : std_logic_vector(2 downto 0);
    signal Events_Last   : std_logic_vector(2 downto 0);
    signal Rst           : std_logic;

begin

    -- Assert reset
    i_reset : entity olo.olo_base_reset_gen
        generic map (
            RstInPolarity_g => '0'
        )
        port map (
            Clk         => Clk,
            RstIn       => Switches(3),
            RstOut      => Rst
        );

    -- Debounce Switches
    Switches_Inv <= not Switches; -- Buttons are low-active

    i_switches : entity olo.olo_intf_debounce
        generic map (
            ClkFrequency_g  => 50.0e6,
            DebounceTime_g  => 25.0e-3,
            Width_g         => 4
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => Switches_Inv,
            DataOut     => Switches_Sync
        );

    -- Switch(3) is used for reset
    Events <= Switches_Sync(2 downto 0);

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
            Out_Data      => Led,
            Out_Ready     => RisingEdges(1)
        );

end architecture;
