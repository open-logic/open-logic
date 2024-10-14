---------------------------------------------------------------------------------------------------
-- Copyright (c) 2017 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package to simplify the usage of AXI interfaces in testbenches.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_test_pkg_axi is

    type axi_ms_t is record
        -- Read address channel
        ar_id     : std_logic_vector;
        ar_addr   : std_logic_vector;
        ar_len    : std_logic_vector(7 downto 0);
        ar_size   : std_logic_vector(2 downto 0);
        ar_burst  : std_logic_vector(1 downto 0);
        ar_lock   : std_logic;
        ar_cache  : std_logic_vector(3 downto 0);
        ar_prot   : std_logic_vector(2 downto 0);
        ar_qos    : std_logic_vector(3 downto 0);
        ar_region : std_logic_vector(3 downto 0);
        ar_user   : std_logic_vector;
        ar_valid  : std_logic;
        -- Read data channel
        r_ready   : std_logic;
        -- Write address channel
        aw_id     : std_logic_vector;
        aw_addr   : std_logic_vector;
        aw_len    : std_logic_vector(7 downto 0);
        aw_size   : std_logic_vector(2 downto 0);
        aw_burst  : std_logic_vector(1 downto 0);
        aw_lock   : std_logic;
        aw_cache  : std_logic_vector(3 downto 0);
        aw_prot   : std_logic_vector(2 downto 0);
        aw_qos    : std_logic_vector(3 downto 0);
        aw_region : std_logic_vector(3 downto 0);
        aw_user   : std_logic_vector;
        aw_valid  : std_logic;
        -- Write data channel
        w_data    : std_logic_vector;
        w_strb    : std_logic_vector;
        w_last    : std_logic;
        w_user    : std_logic_vector;
        w_valid   : std_logic;
        -- Write response channel
        b_ready   : std_logic;
    end record;

    type axi_sm_t is record
        -- Read address channel
        ar_ready : std_logic;
        -- Read data channel
        r_id     : std_logic_vector;
        r_data   : std_logic_vector;
        r_resp   : std_logic_vector(1 downto 0);
        r_last   : std_logic;
        r_user   : std_logic_vector;
        r_valid  : std_logic;
        -- Write address channel
        aw_ready : std_logic;
        -- Write data channel
        w_ready  : std_logic;
        -- Write response channel
        b_id     : std_logic_vector;
        b_resp   : std_logic_vector(1 downto 0);
        b_user   : std_logic_vector;
        b_valid  : std_logic;
    end record;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_test_pkg_axi is

end package body;

