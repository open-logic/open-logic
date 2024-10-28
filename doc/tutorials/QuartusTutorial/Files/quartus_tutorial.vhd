library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library olo;    -- Open Logic Library

entity quartus_tutorial is
    port (
        -- Control Signals
        Clk             : in    std_logic;
        -- Interfaces
        Buttons         : in    std_logic_vector(1 downto 0);
        Switches        : in    std_logic_vector(3 downto 0);
        Led             : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of quartus_tutorial is

    signal Buttons_Sync  : std_logic_vector(1 downto 0);
    signal Switches_Sync : std_logic_vector(3 downto 0);
    signal RisingEdges   : std_logic_vector(1 downto 0);
    signal Buttons_Last  : std_logic_vector(1 downto 0);
    signal Rst           : std_logic := '1';
    signal LedSig        : std_logic_vector(3 downto 0);

begin

    -- Assert reset after power up
    i_reset : entity olo.olo_base_reset_gen
        port map (
            Clk         => Clk,
            RstOut      => Rst
        );

    -- Debounce Buttons
    i_buttons : entity olo.olo_intf_debounce
        generic map (
            ClkFrequency_g  => 50.0e6,
            DebounceTime_g  => 25.0e-3,
            Width_g         => 2
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => Buttons,
            DataOut     => Buttons_Sync
        );

    -- Debounce Switches
    i_switches : entity olo.olo_intf_debounce
        generic map (
            ClkFrequency_g  => 50.0e6,
            DebounceTime_g  => 25.0e-3,
            Width_g         => 4
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            DataAsync   => Switches,
            DataOut     => Switches_Sync
        );

    -- Edge Detection
    p_edge_detection : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Normal Operation
            RisingEdges  <= Buttons_Sync and (not Buttons_Last);
            Buttons_Last <= Buttons_Sync;

            -- Reset
            if Rst = '1' then
                RisingEdges  <= (others => '0');
                Buttons_Last <= (others => '0');
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
            In_Data       => Switches_Sync,
            In_Valid      => RisingEdges(0),
            Out_Data      => LedSig,
            Out_Ready     => RisingEdges(1)
        );

    Led <= LedSig;

end architecture;
