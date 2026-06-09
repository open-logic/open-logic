---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- ECC-protected single-port RAM with an opportunistic memory scrubber. Wraps
-- `olo_ft_ram_sp` and `olo_ft_private_scrubber`. The user-facing interface is
-- identical to `olo_ft_ram_sp` plus a scrubber-enable input and four
-- scrubber-status outputs.
--
-- The scrubber owns the user/scrubber arbitration (see olo_ft_private_scrubber).
-- This wrapper ties the single shared user port to both scrubber user channels
-- and collapses the scrubber's muxed write/read RAM channels back onto the one
-- physical port of olo_ft_ram_sp. Because the underlying RAM is single-port, the
-- scrubber acts only on cycles where the user is doing neither a read nor a
-- write; user accesses are never stalled. If the user writes to the address
-- currently being scrubbed at any point between the scrubber's read and
-- writeback, the writeback is aborted and user data is authoritative.
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
        Depth_g        : positive;
        Width_g        : positive;
        RamRdLatency_g : positive             := 1;
        RamStyle_g     : string               := "auto";
        RamBehavior_g  : string               := "RBW";
        EccPipeline_g  : natural range 0 to 2 := 0
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic                                                := '0';
        -- FT RAM Port
        Addr            : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        WrEna           : in    std_logic                                                := '1';
        WrData          : in    std_logic_vector(Width_g - 1 downto 0);
        RdEna           : in    std_logic                                                := '1';
        RdData          : out   std_logic_vector(Width_g - 1 downto 0);
        RdValid         : out   std_logic;
        RdEccSec        : out   std_logic;
        RdEccDed        : out   std_logic;
        -- Error Injection
        ErrInj_BitFlip  : in    std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0) := (others => '0');
        ErrInj_Valid    : in    std_logic                                                := '0';
        -- Scrubber Control. '0' suspends the scrubber FSM combinationally; the address counter
        -- is preserved so scrubbing resumes from the same address on '1'. Use this to pin the
        -- scrubber down during ECC error-injection tests.
        Scrub_Enable    : in    std_logic                                                := '1';
        -- Scrubber Status. Scrub_Rd_EccSec / Scrub_Rd_EccDed are valid only when
        -- Scrub_Rd_Valid='1' (cycle the scrubber's own read returns from the codec).
        Scrub_Rd_Valid  : out   std_logic;
        Scrub_Rd_EccSec : out   std_logic;
        Scrub_Rd_EccDed : out   std_logic;
        Scrub_PassDone  : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_sp_scrub is

    constant AddrWidth_c : positive := log2ceil(Depth_g);

    -- Muxed RAM request channels driven by the scrubber. For a single-port RAM the write and
    -- read channels are collapsed back onto one physical port below (they are mutually
    -- exclusive in time, so a single Ram_Addr suffices).
    signal Ram_Wr_Addr : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Wr_Ena  : std_logic;
    signal Ram_Wr_Data : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_Rd_Addr : std_logic_vector(AddrWidth_c - 1 downto 0);
    signal Ram_Rd_Ena  : std_logic;
    signal Ram_Addr    : std_logic_vector(AddrWidth_c - 1 downto 0);

    -- RAM read outputs tapped from olo_ft_ram_sp; forwarded to the user and observed by the
    -- scrubber. Ram_RdValid pulses for any read (user or scrubber); it is fed to the scrubber,
    -- which masks the scrubber-owned cycles and returns the user-facing valid (User_Rd_Valid).
    signal Ram_RdData   : std_logic_vector(Width_g - 1 downto 0);
    signal Ram_RdEccSec : std_logic;
    signal Ram_RdEccDed : std_logic;
    signal Ram_RdValid  : std_logic;

begin

    -- Opportunistic scrubber + user/scrubber arbitration. The single user port feeds both user
    -- channels; the scrubber returns muxed write and read RAM channels.
    i_scrubber : entity work.olo_ft_private_scrubber
        generic map (
            Depth_g            => Depth_g,
            Width_g            => Width_g,
            TotalReadLatency_g => RamRdLatency_g + EccPipeline_g
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
            Ram_Wr_Addr     => Ram_Wr_Addr,
            Ram_Wr_Ena      => Ram_Wr_Ena,
            Ram_Wr_Data     => Ram_Wr_Data,
            Ram_Rd_Addr     => Ram_Rd_Addr,
            Ram_Rd_Ena      => Ram_Rd_Ena,
            Ram_Rd_Data     => Ram_RdData,
            Ram_Rd_EccSec   => Ram_RdEccSec,
            Ram_Rd_EccDed   => Ram_RdEccDed,
            Ram_Rd_Valid    => Ram_RdValid,
            User_Rd_Valid   => RdValid,
            Scrub_Rd_Valid  => Scrub_Rd_Valid,
            Scrub_Rd_EccSec => Scrub_Rd_EccSec,
            Scrub_Rd_EccDed => Scrub_Rd_EccDed,
            Scrub_PassDone  => Scrub_PassDone
        );

    -- Collapse the write/read RAM channels onto the single physical port. They are mutually
    -- exclusive (the scrubber never reads and writes in the same cycle, and a user
    -- simultaneous read+write targets the same Addr), so the write address wins when a write
    -- is active and the read address is used otherwise.
    Ram_Addr <= Ram_Wr_Addr when Ram_Wr_Ena = '1' else Ram_Rd_Addr;

    -- Inner ECC-protected RAM (encoder + olo_base_ram_sp + decoder).
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

    -- Forward decoder outputs. The masked user RdValid and Scrub_Rd_Valid are driven by the
    -- scrubber (User_Rd_Valid / Scrub_Rd_Valid in the port map above).
    RdData   <= Ram_RdData;
    RdEccSec <= Ram_RdEccSec;
    RdEccDed <= Ram_RdEccDed;

end architecture;
