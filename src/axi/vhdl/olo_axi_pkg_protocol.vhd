------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- Package containing axi protocol definitions

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package olo_axi_pkg_protocol is

    subtype Resp_t is std_logic_vector(1 downto 0);
    constant xRESP_OKAY_c   : Resp_t := "00";
    constant xRESP_EXOKAY_c : Resp_t := "01";
    constant xRESP_SLVERR_c : Resp_t := "10";
    constant xRESP_DECERR_c : Resp_t := "11";

    subtype Burst_t is std_logic_vector(1 downto 0);
    constant xBURST_FIXED_c : Burst_t := "00";
    constant xBURST_INCR_c  : Burst_t := "01";
    constant xBURST_WRAP_c  : Burst_t := "10";

    subtype Size_t is std_logic_vector(2 downto 0);
    constant AxSIZE_1_c   : Size_t := "000";
    constant AxSIZE_2_c   : Size_t := "001";
    constant AxSIZE_4_c   : Size_t := "010";
    constant AxSIZE_8_c   : Size_t := "011";
    constant AxSIZE_16_c  : Size_t := "100";
    constant AxSIZE_32_c  : Size_t := "101";
    constant AxSIZE_64_c  : Size_t := "110";
    constant AxSIZE_128_c : Size_t := "111";

end olo_axi_pkg_protocol;

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body olo_axi_pkg_protocol is

end olo_axi_pkg_protocol;

