---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected single-port RAM with an opportunistic memory scrubber. Wraps olo_ft_ram_sp and
-- olo_ft_private_scrubber. The scrubber acts only on fully idle user cycles, so user accesses are
-- never stalled and user data is always authoritative (any user access aborts an in-flight scrub
-- operation).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ram_sp_scrub.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ram_sp_scrub is
    generic (
        Depth_g        : positive range 2 to positive'high;
        Width_g        : positive;
        RamRdLatency_g : positive             := 1;
        RamStyle_g     : string               := "auto";
        RamBehavior_g  : string               := "RBW";
        EccPipeline_g  : natural range 0 to 2 := 0;
        ScrubClkHz_g   : real                 := 100000000.0;
        ScrubPeriod_g  : real                 := 0.0
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- FT RAM Port
        Addr            : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        WrEna           : in    std_logic;
        WrData          : in    std_logic_vector(Width_g - 1 downto 0);
        RdEna           : in    std_logic;
        RdData          : out   std_logic_vector(Width_g - 1 downto 0);
        RdValid         : out   std_logic;
        RdEccSec        : out   std_logic;
        RdEccDed        : out   std_logic;
        -- Error Injection
        ErrInj_BitFlip  : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid    : in    std_logic                                                := '0';
        -- Scrubber Control
        Scrub_Enable    : in    std_logic                                                := '1';
        -- Scrubber Status
        Scrub_EccSec    : out   std_logic;
        Scrub_EccDed    : out   std_logic;
        Scrub_PassDone  : out   std_logic;
        Scrub_Overrun   : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sp_scrub is

    constant AddrWidth_c : positive := log2ceil(Depth_g);

    -- RAM request signals from the scrubber. It collapses the address onto Ram_Addr (single port),
    -- so this wrapper carries no address mux and leaves Ram_Wr_Addr / Ram_Rd_Addr open.
    signal Ram_Wr_Ena  : std_logic;
    signal Ram_Wr_Data : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_Rd_Ena  : std_logic;
    signal Ram_Addr    : std_logic_vector(AddrWidth_c - 1 downto 0);

    -- RAM read outputs from olo_ft_ram_sp; forwarded to the user and observed by the scrubber, which
    -- masks its own read cycles to produce the user-facing RdValid.
    signal Ram_RdData   : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_RdEccSec : std_logic;
    signal Ram_RdEccDed : std_logic;
    signal Ram_RdValid  : std_logic;

begin

    -- Opportunistic scrubber + arbitration. The single user port feeds both user channels.
    i_scrubber : entity work.olo_ft_private_scrubber
        generic map (
            Depth_g            => Depth_g,
            Width_g            => Width_g,
            TotalReadLatency_g => RamRdLatency_g + EccPipeline_g,
            SinglePortRam_g    => true,
            ScrubClkHz_g       => ScrubClkHz_g,
            ScrubPeriod_g      => ScrubPeriod_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Scrub_Enable    => Scrub_Enable,
            User_Wr_Addr    => Addr,
            User_Wr_Ena     => WrEna,
            User_Wr_Data    => WrData,
            User_Rd_Addr    => Addr,
            User_Rd_Ena     => RdEna,
            Ram_Wr_Addr     => open,
            Ram_Wr_Ena      => Ram_Wr_Ena,
            Ram_Wr_Data     => Ram_Wr_Data,
            Ram_Rd_Addr     => open,
            Ram_Rd_Ena      => Ram_Rd_Ena,
            Ram_Addr        => Ram_Addr,
            Ram_Rd_Data     => Ram_RdData,
            Ram_Rd_EccSec   => Ram_RdEccSec,
            Ram_Rd_EccDed   => Ram_RdEccDed,
            Ram_Rd_Valid    => Ram_RdValid,
            User_Rd_Valid   => RdValid,
            Scrub_EccSec    => Scrub_EccSec,
            Scrub_EccDed    => Scrub_EccDed,
            Scrub_PassDone  => Scrub_PassDone,
            Scrub_Overrun   => Scrub_Overrun
        );

    -- Inner ECC-protected RAM; its single physical address is the scrubber's collapsed Ram_Addr.
    i_ram_sp : entity work.olo_ft_ram_sp
        generic map (
            Depth_g        => Depth_g,
            Width_g        => Width_g,
            RamRdLatency_g => RamRdLatency_g,
            RamStyle_g     => RamStyle_g,
            RamBehavior_g  => RamBehavior_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            Addr           => Ram_Addr,
            WrEna          => Ram_Wr_Ena,
            WrData         => Ram_Wr_Data,
            RdEna          => Ram_Rd_Ena,
            RdData         => Ram_RdData,
            RdValid        => Ram_RdValid,
            RdEccSec       => Ram_RdEccSec,
            RdEccDed       => Ram_RdEccDed,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
        );

    -- Forward decoder outputs (the masked user RdValid comes from the scrubber above).
    RdData   <= Ram_RdData;
    RdEccSec <= Ram_RdEccSec;
    RdEccDed <= Ram_RdEccDed;

end architecture;
