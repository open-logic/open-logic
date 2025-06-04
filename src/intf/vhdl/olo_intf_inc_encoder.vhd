---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Milorad Petrovic
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an interface to an incremental encoder.
--
-- Documentation:
-- TODO

---------------------------------------------------------------------------------------------------
-- Package for Interface Simplification
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

entity olo_intf_inc_encoder is
    generic(
        DefaultAngleResolution_g : positive;
        PositionWidth_g   : positive := 32);
    port(
        Clk             : in  std_logic;
        Rst             : in  std_logic;
        Phase_A         : in  std_logic;
        Phase_B         : in  std_logic;
        Phase_Z         : in  std_logic := '0';
        Position        : out std_logic_vector(PositionWidth_g - 1 downto 0);
        Clear_Position  : in  std_logic := '0';
        Angle           : out std_logic_vector(PositionWidth_g - 1 downto 0);
        Clear_Angle     : in  std_logic := '0';
        AngleResolution : in  std_logic_vector(PositionWidth_g - 1 downto 0) := toUslv(DefaultAngleResolution_g, PositionWidth_g);
        Event_Up        : out std_logic;
        Event_Down      : out std_logic;
        Event_Index     : out std_logic);
end entity olo_intf_inc_encoder;

architecture rtl of olo_intf_inc_encoder is
    
    -- The values of the encoder phase signals from the prior clock cycle.
    signal Phase_A_Prior : std_logic;
    signal Phase_B_Prior : std_logic;
    signal Phase_Z_Prior : std_logic;

    -- Encoder position value as a numeric_std.unsigned.
    signal Position_U : unsigned(Position'range);

    -- Encoder angle value as a numeric_std.unsigned.
    signal Angle_U : unsigned(Angle'range);

begin

    Position <= std_logic_vector(Position_U);
    Angle <= std_logic_vector(Angle_U);
    
    proc_main : process is
        variable IncrementEventOccurred : boolean;
        variable DecrementEventOccurred : boolean;
        variable IndexEventOccurred     : boolean;
    begin

        -- Wait for an active clock edge.
        wait until rising_edge(Clk);

        -- Check if an increment event has occurred.
        IncrementEventOccurred :=
            (Phase_A_Prior = '0' and Phase_A = '1' and Phase_B = '0') or
            (Phase_B_Prior = '0' and Phase_B = '1' and Phase_A = '1') or
            (Phase_A_Prior = '1' and Phase_A = '0' and Phase_B = '1') or
            (Phase_B_Prior = '1' and Phase_B = '0' and Phase_A = '0');

        -- Check if a decrement event has occured.
        DecrementEventOccurred :=
            (Phase_B_Prior = '0' and Phase_B = '1' and Phase_A = '0') or
            (Phase_A_Prior = '0' and Phase_A = '1' and Phase_B = '1') or
            (Phase_B_Prior = '1' and Phase_B = '0' and Phase_A = '1') or
            (Phase_A_Prior = '1' and Phase_A = '0' and Phase_B = '0');

        -- Check if an index event has occurred.
        IndexEventOccurred := Phase_Z_Prior = '0' and Phase_Z = '1';

        -- Update event output signals.
        Event_Up    <= '1' when IncrementEventOccurred else '0';
        Event_Down  <= '1' when DecrementEventOccurred else '0';
        Event_Index <= '1' when IndexEventOccurred     else '0';

        -- Update position counter.
        if Clear_Position = '1' then
            Position_U <= (others => '0');

        elsif IncrementEventOccurred and DecrementEventOccurred then
            Position_U <= Position_U;

        elsif IncrementEventOccurred then
            Position_U <= Position_U + 1;

        elsif DecrementEventOccurred then
            Position_U <= Position_U - 1;

        end if;

        -- Update angle counter.
        if Clear_Angle = '1' then
            Angle_U <= (others => '0');

        elsif IndexEventOccurred then
            Angle_U <= (others => '0');

        elsif IncrementEventOccurred and DecrementEventOccurred then
            Angle_U <= Angle_U;

        elsif IncrementEventOccurred then
            Angle_U <=
                (others => '0') when Angle_U = unsigned(AngleResolution)
                else Angle_U + 1 ;

        elsif DecrementEventOccurred then
            Angle_U <=
                unsigned(AngleResolution) when Angle_U = unsigned(zerosVector(Angle_U'length))
                else Angle_U - 1;

        end if;

        -- Update prior samples of the encoder phase signals.
        Phase_A_Prior <= Phase_A;
        Phase_B_Prior <= Phase_B;
        Phase_Z_Prior <= Phase_Z;

        -- Reset logic.
        if Rst = '1' then
            Position_U  <= (others => '0');
            Angle_U     <= (others => '0');
            Event_Up    <= '0';
            Event_Down  <= '0';
            Event_Index <= '0';
        end if;

    end process proc_main;

end architecture rtl;

