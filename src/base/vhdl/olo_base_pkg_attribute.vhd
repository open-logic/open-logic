---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler, Benoit Stef
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing attribute definitions that work for all target vendors. The package is meant
-- for Open Logic internal use and hence not deocumented in detail.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_pkg_attribute.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_base_pkg_attribute is

    -- *** Allow/Suppress Shift Register Extraction ***

    -- Tools:
    -- - Vivado (AMD)
    attribute shreg_extract : string;
    constant ShregExtract_SuppressExtraction_c : string := "no";
    constant ShregExtract_AllowExtraction_c    : string := "yes";

    -- *** Control Shift Register Resources ***

    -- Tools:
    -- - Vivado (AMD)
    attribute srl_style : string;
    constant SrlStyle_FlipFlops_c : string := "registers";
    constant SrlStyle_Srl_c       : string := "srl"; -- Use LUT as shift register

    -- Tools:
    -- - Efinity (Efinix)
    -- - GowinEDA (Gowin)
    attribute syn_srlstyle : string;
    constant SynSrlstyle_FlipFlops_c : string := "registers";

    -- *** Optimize Synchronizer Registers ***

    -- Tools:
    -- - Vivado (AMD)
    -- - Efinity (Efinix)
    attribute async_reg : boolean;
    constant AsyncReg_TreatAsync_c : boolean := true;

    -- *** Allow/Suprress Synthesis to change a Signal ***

    -- Tools:
    -- - Quartus (Altera)
    attribute dont_merge : boolean;
    constant DontMerge_SuppressChanges_c : boolean := true;

    -- Tools:
    -- - Quartus (Altera)
    attribute preserve : boolean;
    constant Preserve_SuppressChanges_c : boolean := true;

    -- Tools:
    -- - Synplify (Lattice/Mircochip)
    -- - Efinity (Efinix)
    -- - GowinEDA (Gowin)
    -- Note: integer is also confirmed to work for Synopsys/Efinity although documentation only states boolean. Chose
    --       integer because Gowin only accepts integer.
    attribute syn_keep : integer;
    constant SynKeep_SuppressChanges_c : integer := 1;

    -- Tools:
    -- - Synplify (Lattice/Mircochip)
    -- - Efinity (Efinix)
    -- - GowinEDA (Gowin)
    -- Note: integer is also confirmed to work for Synopsys/Efinity although documentation only states boolean. Chose
    --       integer because Gowin only accepts integer.
    attribute syn_preserve : integer;
    constant SynPreserve_SuppressChanges_c : integer := 1;

    -- Tools:
    -- - Vivado (AMD)
    attribute dont_touch : boolean;
    constant DontTouch_SuppressChanges_c : boolean := true;

    -- Tools:
    -- - Vivado (AMD)
    attribute keep : string;
    constant Keep_SuppressChanges_c : string := "yes";

    -- *** RAM Style ***
    -- Those attributes do not come with values. They are controlled by strings entered by the user directly.

    -- Tools:
    -- - Vivado (AMD)
    attribute ram_style : string;

    -- Tools:
    -- - Quartus (Altera)
    attribute ramstyle : string;

    -- Tools:
    -- - Efinity (Efinix)
    -- - Synplify (Lattice/Mircochip)
    -- - GowinEDA (Gowin)
    attribute syn_ramstyle : string;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_base_pkg_attribute is

end package body;
