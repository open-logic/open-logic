---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected simple dual-port RAM with an opportunistic memory scrubber. Wraps `olo_ft_ram_sdp`
-- and `olo_ft_private_scrubber`; the user-facing interface mirrors `olo_ft_ram_sdp` (write port +
-- read port) plus the scrubber control and status ports. The scrubber's write/read RAM channels map
-- 1:1 onto the RAM's ports, so the wrapper carries no mux logic of its own. It is synchronous-only
-- (no `IsAsync_g`, no `Rd_Clk` / `Rd_Rst`): the scrubber needs a single clock to spot idle cycles.
-- The scrubber acts only when both user ports are idle, so user accesses are never stalled and user
-- data is always authoritative (a user write to an in-flight scrub address aborts the writeback).
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ram_sdp_scrub.md
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
entity olo_ft_ram_sdp_scrub is
    generic (
        Depth_g        : positive range 2 to positive'high;
        Width_g        : positive;
        RamRdLatency_g : positive             := 1;
        RamStyle_g     : string               := "auto";
        RamBehavior_g  : string               := "RBW";
        EccPipeline_g  : natural range 0 to 2 := 0;
        -- Optional internal scrub pacer (see olo_ft_private_scrubber). ScrubClkHz_g = 0.0 disables.
        ScrubClkHz_g   : real                 := 0.0;
        ScrubPeriod_g  : real                 := 0.0
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Write Port
        Wr_Addr         : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Wr_Ena          : in    std_logic;
        Wr_Data         : in    std_logic_vector(Width_g - 1 downto 0);
        -- Read Port
        Rd_Addr         : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Rd_Ena          : in    std_logic;
        Rd_Data         : out   std_logic_vector(Width_g - 1 downto 0);
        Rd_Valid        : out   std_logic;
        Rd_EccSec       : out   std_logic;
        Rd_EccDed       : out   std_logic;
        -- Error Injection
        ErrInj_BitFlip  : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid    : in    std_logic                                                := '0';
        -- Scrubber Control
        Scrub_Enable    : in    std_logic                                                := '1';
        -- Scrubber Status. Scrub_EccSec / Scrub_EccDed are one-cycle pulses asserted when a
        -- scrubber read observed a SEC / DED (qualified internally; directly countable).
        Scrub_EccSec    : out   std_logic;
        Scrub_EccDed    : out   std_logic;
        Scrub_PassDone  : out   std_logic;
        Scrub_Overrun   : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sdp_scrub is

    constant AddrWidth_c : positive := log2ceil(Depth_g);

    -- Muxed RAM request channels driven by the scrubber; mapped 1:1 onto the RAM's ports.
    signal Ram_Wr_Addr : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Wr_Ena  : std_logic;
    signal Ram_Wr_Data : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_Rd_Addr : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Rd_Ena  : std_logic;

    -- RAM read outputs tapped from olo_ft_ram_sdp; forwarded to the user and observed by the
    -- scrubber. Ram_Rd_Valid pulses for any read (user or scrubber); it is fed to the scrubber,
    -- which masks the scrubber-owned cycles and returns the user-facing valid (User_Rd_Valid).
    signal Ram_Rd_Data   : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_Rd_EccSec : std_logic;
    signal Ram_Rd_EccDed : std_logic;
    signal Ram_Rd_Valid  : std_logic;

begin

    -- Opportunistic scrubber + user/scrubber arbitration. The user write/read ports feed the
    -- scrubber's user channels; its muxed RAM channels map straight onto the RAM ports below.
    i_scrubber : entity work.olo_ft_private_scrubber
        generic map (
            Depth_g            => Depth_g,
            Width_g            => Width_g,
            TotalReadLatency_g => RamRdLatency_g + EccPipeline_g,
            ScrubClkHz_g       => ScrubClkHz_g,
            ScrubPeriod_g      => ScrubPeriod_g
        )
        port map (
            Clk             => Clk,
            Rst             => Rst,
            Scrub_Enable    => Scrub_Enable,
            User_Wr_Addr    => Wr_Addr,
            User_Wr_Ena     => Wr_Ena,
            User_Wr_Data    => Wr_Data,
            User_Rd_Addr    => Rd_Addr,
            User_Rd_Ena     => Rd_Ena,
            Ram_Wr_Addr     => Ram_Wr_Addr,
            Ram_Wr_Ena      => Ram_Wr_Ena,
            Ram_Wr_Data     => Ram_Wr_Data,
            Ram_Rd_Addr     => Ram_Rd_Addr,
            Ram_Rd_Ena      => Ram_Rd_Ena,
            Ram_Rd_Data     => Ram_Rd_Data,
            Ram_Rd_EccSec   => Ram_Rd_EccSec,
            Ram_Rd_EccDed   => Ram_Rd_EccDed,
            Ram_Rd_Valid    => Ram_Rd_Valid,
            User_Rd_Valid   => Rd_Valid,
            Scrub_EccSec    => Scrub_EccSec,
            Scrub_EccDed    => Scrub_EccDed,
            Scrub_PassDone  => Scrub_PassDone,
            Scrub_Overrun   => Scrub_Overrun
        );

    -- Inner ECC-protected SDP RAM (encoder + olo_base_ram_sdp + decoder). Sync-only here
    -- (IsAsync_g => false), since the scrubber requires single-clock operation.
    i_ram_sdp : entity work.olo_ft_ram_sdp
        generic map (
            Depth_g        => Depth_g,
            Width_g        => Width_g,
            IsAsync_g      => false,
            RamRdLatency_g => RamRdLatency_g,
            RamStyle_g     => RamStyle_g,
            RamBehavior_g  => RamBehavior_g,
            EccPipeline_g  => EccPipeline_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            Rd_Clk         => '0',
            Rd_Rst         => '0',
            Wr_Addr        => Ram_Wr_Addr,
            Wr_Ena         => Ram_Wr_Ena,
            Wr_Data        => Ram_Wr_Data,
            Rd_Addr        => Ram_Rd_Addr,
            Rd_Ena         => Ram_Rd_Ena,
            Rd_Data        => Ram_Rd_Data,
            Rd_Valid       => Ram_Rd_Valid,
            Rd_EccSec      => Ram_Rd_EccSec,
            Rd_EccDed      => Ram_Rd_EccDed,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
        );

    -- Forward decoder outputs. The masked user Rd_Valid is driven by the scrubber
    -- (User_Rd_Valid in the port map above).
    Rd_Data   <= Ram_Rd_Data;
    Rd_EccSec <= Ram_Rd_EccSec;
    Rd_EccDed <= Ram_Rd_EccDed;

end architecture;
