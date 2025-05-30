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
        PulsesPerPhasePerTurn : positive;
        UpCountingDirection : string := "B trails A");
    port(
        Clk             : in  std_logic;
        Rst             : in  std_logic;
        Phase_A         : in  std_logic;
        Phase_B         : in  std_logic;
        Strobe          : in  std_logic := '0';
        Position_tdata  : out std_logic_vector(log2ceil(PulsesPerPhasePerTurn * 4) - 1 downto 0);
        Position_tvalid : out std_logic;
        Position_tready : in  std_logic := '0';
        Clear           : in  std_logic := '0';
        Pulse           : out std_logic;
        Direction       : out std_logic;
        Position        : out std_logic_vector(log2ceil(PulsesPerPhasePerTurn * 4) - 1 downto 0));
    end entity olo_intf_inc_encoder;
