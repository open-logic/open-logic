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
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_inc_encoder.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

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
        AngleWidth_g    : natural := 0;
        PositionWidth_g : natural := 0);
    port(
        Clk              : in  std_logic;
        Rst              : in  std_logic;
        Encoder_A        : in  std_logic;
        Encoder_B        : in  std_logic;
        Encoder_Z        : in  std_logic := '0';
        Position_Value   : out std_logic_vector(work.olo_base_pkg_math.max(PositionWidth_g - 1, 0) downto 0);
        Position_Clear   : in  std_logic := '0';
        Angle_Value      : out std_logic_vector(work.olo_base_pkg_math.max(AngleWidth_g - 1, 0) downto 0);
        Angle_Clear      : in  std_logic := '0';
        Angle_Resolution : in  std_logic_vector(AngleWidth_g downto 0) := (AngleWidth_g => '1', others => '0');
        Event_Up         : out std_logic;
        Event_Down       : out std_logic;
        Event_Index      : out std_logic);
end entity;

architecture rtl of olo_intf_inc_encoder is

    -- The values of the encoder phase signals from the prior clock cycle.
    signal Encoder_A_Prior : std_logic;
    signal Encoder_B_Prior : std_logic;
    signal Encoder_Z_Prior : std_logic;

    -- Port 'Position_Value' as a numeric_std unsigned.
    signal Position_Value_U : unsigned(Position_Value'range);

    -- Port 'Angle_Value' as a numeric_std unsigned.
    signal Angle_Value_U : unsigned(Angle_Value'range);

    -- Heighest value of the angle counter for the given resolution, before a wrap-around.
    signal Angle_Limit : unsigned(Angle_Value'range);

    -- Maximum valid value of 'Angle_Resolution'.
    constant Angle_ResolutionMaximum : unsigned(Angle_Resolution'range) := (Angle_Resolution'high => '1', others => '0');

begin

    proc_always : process (all)
    begin

        -- Verify if the value of 'Angle_Resolution' is valid.
        assert unsigned(Angle_Resolution) <= Angle_ResolutionMaximum report
            "The requested angle resolution cannot be represented by the configured angle width."
            severity error;
        assert Angle_Resolution(1 downto 0) = "00" report
            "For a quadrature encoder the resolution must be divisable by 4."
            severity error;

        -- Convert entity ports to appropriate types.
        Position_Value <= std_logic_vector(Position_Value_U);
        Angle_Value <= std_logic_vector(Angle_Value_U);

        -- Calculate the angle limit.
        Angle_Limit <= resize(unsigned(Angle_Resolution) - 1, Angle_Limit'length);

    end process;

    proc_main : process is
        variable IncrementEventOccurred_v : boolean;
        variable DecrementEventOccurred_v : boolean;
        variable IndexEventOccurred_v     : boolean;
    begin

        -- Wait for an active clock edge.
        wait until rising_edge(Clk);

        -- Check if an increment event has occurred.
        IncrementEventOccurred_v := (Encoder_A_Prior = '0' and Encoder_A = '1' and Encoder_B = '0') or
                                    (Encoder_B_Prior = '0' and Encoder_B = '1' and Encoder_A = '1') or
                                    (Encoder_A_Prior = '1' and Encoder_A = '0' and Encoder_B = '1') or
                                    (Encoder_B_Prior = '1' and Encoder_B = '0' and Encoder_A = '0');

        -- Check if a decrement event has occured.
        DecrementEventOccurred_v := (Encoder_B_Prior = '0' and Encoder_B = '1' and Encoder_A = '0') or
                                    (Encoder_A_Prior = '0' and Encoder_A = '1' and Encoder_B = '1') or
                                    (Encoder_B_Prior = '1' and Encoder_B = '0' and Encoder_A = '1') or
                                    (Encoder_A_Prior = '1' and Encoder_A = '0' and Encoder_B = '0');

        -- Check if an index event has occurred.
        IndexEventOccurred_v := Encoder_Z_Prior = '0' and Encoder_Z = '1';

        -- Update event output signals.
        Event_Up    <= '1' when IncrementEventOccurred_v else '0';
        Event_Down  <= '1' when DecrementEventOccurred_v else '0';
        Event_Index <= '1' when IndexEventOccurred_v     else '0';

        -- Update position and angle counters.

        if IncrementEventOccurred_v and not DecrementEventOccurred_v then
            Position_Value_U <= Position_Value_U + 1;
            Angle_Value_U <= (others => '0') when Angle_Value_U = Angle_Limit else Angle_Value_U + 1;

        elsif DecrementEventOccurred_v and not IncrementEventOccurred_v then
            Position_Value_U <= Position_Value_U - 1;
            Angle_Value_U <= Angle_Limit when Angle_Value_U = unsigned(zerosVector(Angle_Value_U'length)) else Angle_Value_U - 1;

        end if;

        if Position_Clear = '1' then
            Position_Value_U <= (others => '0');
        end if;

        if Angle_Clear = '1' or IndexEventOccurred_v then
            Angle_Value_U <= (others => '0');
        end if;

        -- Update 'prior' values of the encoder phase signals.
        Encoder_A_Prior <= Encoder_A;
        Encoder_B_Prior <= Encoder_B;
        Encoder_Z_Prior <= Encoder_Z;

        -- Overwrite if position counter has been configured not to be used.
        if PositionWidth_g = 0 then
            Position_Value_U <= (others => '0');
        end if;

        -- Overwrite if angle counter has been configured not to be used.
        if AngleWidth_g = 1 then
            Angle_Value_U <= (others => '0');
        end if;

        -- Reset logic.
        if Rst = '1' then
            Position_Value_U <= (others => '0');
            Angle_Value_U    <= (others => '0');
            Event_Up         <= '0';
            Event_Down       <= '0';
            Event_Index      <= '0';
        end if;

    end process;

end architecture;
