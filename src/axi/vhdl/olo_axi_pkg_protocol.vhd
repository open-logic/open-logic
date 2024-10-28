---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing axi protocol definitions
--
--
-- Documentation:
-- None - This file is not intended to be used directly.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_axi_pkg_protocol is

    subtype Resp_t is std_logic_vector(1 downto 0);
    constant AxiResp_Okay_c   : Resp_t := "00";
    constant AxiResp_ExOkay_c : Resp_t := "01";
    constant AxiResp_SlvErr_c : Resp_t := "10";
    constant AxiResp_DecErr_c : Resp_t := "11";

    subtype Burst_t is std_logic_vector(1 downto 0);
    constant AxiBurst_Fixed_c : Burst_t := "00";
    constant AxiBurst_Incr_c  : Burst_t := "01";
    constant AxiBurst_Wrap_c  : Burst_t := "10";

    subtype Size_t is std_logic_vector(2 downto 0);
    constant AxiSize_1_c   : Size_t := "000";
    constant AxiSize_2_c   : Size_t := "001";
    constant AxiSize_4_c   : Size_t := "010";
    constant AxiSize_8_c   : Size_t := "011";
    constant AxiSize_16_c  : Size_t := "100";
    constant AxiSize_32_c  : Size_t := "101";
    constant AxiSize_64_c  : Size_t := "110";
    constant AxiSize_128_c : Size_t := "111";

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_axi_pkg_protocol is

end package body;

