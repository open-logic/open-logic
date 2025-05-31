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
        Pulse_Up        : out std_logic;
        Pulse_Down      : out std_logic);
    end entity olo_intf_inc_encoder;
