---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Private opportunistic memory-scrubber core. Instantiated by ECC-protected RAM
-- wrappers (`olo_ft_ram_sp_scrub`, `olo_ft_ram_sdp_scrub`); not intended for
-- end-user instantiation.
--
-- This core owns BOTH the scrub FSM and the user/scrubber arbitration. It is
-- reusable across the single- and dual-port wrappers by presenting a generic
-- write-channel + read-channel interface:
--   * the user side (`User_Wr_*` / `User_Rd_*`) carries the wrapper's user
--     requests,
--   * the RAM side (`Ram_Wr_*` / `Ram_Rd_*`) carries the muxed requests to the
--     wrapped RAM.
-- The user always wins: the scrubber drives a channel only on cycles where the
-- user is not using *either* channel. A single-port wrapper ties both user
-- channels to its shared port and collapses the two RAM channels back onto it;
-- a dual-port wrapper maps the channels 1:1 onto the RAM's write and read ports.
--
-- Operating principle: read each address in turn; L cycles later observe the
-- decoded ECC flags in Decide_s, fire the writeback in the same cycle when a
-- single-bit error was corrected, and advance ScrubAddr. The scrubber never
-- stalls the user: it issues bus requests only while the combined Scrub_Inhibit
-- (user-busy OR external Scrub_Enable deasserted) is low. An inhibit during the
-- read-decode window aborts the in-flight operation back to Idle_s without
-- advancing the address counter, so the scrubber retries the same address on the
-- next idle slot. User data is always authoritative.
--
-- Sequence per address (T = read-issue cycle, L = TotalReadLatency_g):
--   T        : assert the scrubber's read request (only when Scrub_Inhibit='0')
--   T .. T+L : if Scrub_Inhibit='1' on any cycle, abort to Idle_s; ValidPipe keeps
--              shifting so Scrub_Rd_Valid still pulses on the codec return cycle
--   T+L      : in Decide_s, observe Ram_Rd_Data and ECC flags; if EccSec='1' and
--              EccDed='0' assert the writeback (Ram_Wr_Data = Ram_Rd_Data through
--              the wrapper's encoder input); advance ScrubAddr; pulse
--              Scrub_PassDone on rollover; go to Idle_s.
--
-- Scrub_Rd_Valid is driven from a length-L shift register tracking every scrub
-- read-issue, so it still pulses on the codec return cycle when the FSM aborted in
-- the meantime. The core also owns the user-facing read-valid mask:
--   User_Rd_Valid = Ram_Rd_Valid and not Scrub_Rd_Valid
-- so the scrubber's own reads never surface as user reads. Scrub_Rd_EccSec /
-- Scrub_Rd_EccDed are pass-throughs of the codec output; the consumer must qualify
-- them with Scrub_Rd_Valid.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_ram_scrubber.md
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

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_ram_scrubber is
    generic (
        Depth_g            : positive;
        Width_g            : positive;
        TotalReadLatency_g : positive
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Scrubber Enable
        Scrub_Enable    : in    std_logic := '1';
        -- User Write Channel
        User_Wr_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        User_Wr_Ena     : in    std_logic;
        User_Wr_Data    : in    std_logic_vector(Width_g - 1 downto 0);
        -- User Read Channel
        User_Rd_Addr    : in    std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        User_Rd_Ena     : in    std_logic;
        -- RAM Write Channel (muxed user/scrubber requests)
        Ram_Wr_Addr     : out   std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Ram_Wr_Ena      : out   std_logic;
        Ram_Wr_Data     : out   std_logic_vector(Width_g - 1 downto 0);
        -- RAM Read Channel (muxed user/scrubber requests)
        Ram_Rd_Addr     : out   std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        Ram_Rd_Ena      : out   std_logic;
        -- Decoded RAM Read (response, for the scrub FSM and writeback payload)
        Ram_Rd_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Ram_Rd_EccSec   : in    std_logic;
        Ram_Rd_EccDed   : in    std_logic;
        -- RAM read-valid (pulses for every read, user or scrubber)
        Ram_Rd_Valid    : in    std_logic;
        -- User-facing read valid: Ram_Rd_Valid with scrubber-owned read cycles masked out
        User_Rd_Valid   : out   std_logic;
        -- Scrub Status
        Scrub_Rd_Valid  : out   std_logic;
        Scrub_Rd_EccSec : out   std_logic;
        Scrub_Rd_EccDed : out   std_logic;
        Scrub_PassDone  : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_ram_scrubber is

    constant AddrWidth_c : positive := log2ceil(Depth_g);

    type ScrubFsm_t is (Idle_s, ReadWait_s, Decide_s);

    type TwoProcess_r is record
        Fsm       : ScrubFsm_t;
        ScrubAddr : unsigned(AddrWidth_c - 1 downto 0);
        WaitCnt   : unsigned(log2ceil(TotalReadLatency_g + 1) - 1 downto 0);
        ValidPipe : std_logic_vector(TotalReadLatency_g - 1 downto 0);
        PassDone  : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Combined "do not act" signal: user is using a channel OR external disable.
    signal Scrub_Inhibit : std_logic;

    -- Scrubber-internal request signals (driven by the FSM, consumed by the muxes).
    -- Scrub_RdReq and Scrub_WrReq are mutually exclusive, so a single Scrub_Addr
    -- feeds both channel muxes.
    signal Scrub_RdReq : std_logic;
    signal Scrub_WrReq : std_logic;
    signal Scrub_Addr  : std_logic_vector(AddrWidth_c - 1 downto 0);

begin

    -- User wins on either channel; the external Scrub_Enable can also pause the scrubber.
    Scrub_Inhibit <= User_Wr_Ena or User_Rd_Ena or not Scrub_Enable;

    -- Request muxes: the user request passes through whenever it is active, otherwise the
    -- scrubber's request fills the idle cycle. Scrub_RdReq / Scrub_WrReq are guaranteed '0'
    -- while Scrub_Inhibit = '1', so the user is never overridden. On a scrubber writeback the
    -- payload is the decoded read data, which the wrapper's encoder re-encodes into the RAM.
    Ram_Wr_Addr <= User_Wr_Addr when User_Wr_Ena = '1' else Scrub_Addr;
    Ram_Wr_Ena  <= User_Wr_Ena  or  Scrub_WrReq;
    Ram_Wr_Data <= User_Wr_Data when User_Wr_Ena = '1' else Ram_Rd_Data;
    Ram_Rd_Addr <= User_Rd_Addr when User_Rd_Ena = '1' else Scrub_Addr;
    Ram_Rd_Ena  <= User_Rd_Ena  or  Scrub_RdReq;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v            : TwoProcess_r;
        variable IssueRead_v  : std_logic;
        variable IssueWrite_v : std_logic;
    begin
        -- Hold variables stable
        v := r;

        IssueRead_v  := '0';
        IssueWrite_v := '0';
        v.PassDone   := '0';

        case r.Fsm is

            when Idle_s =>
                if Scrub_Inhibit = '0' then
                    IssueRead_v := '1';
                    -- WaitCnt starts at 1: the Idle->ReadWait transition already
                    -- consumed cycle T->T+1, so ReadWait only needs to span L-1 more
                    -- cycles.
                    v.WaitCnt := to_unsigned(1, v.WaitCnt'length);
                    if TotalReadLatency_g = 1 then
                        -- L=1: data is back on T+1, skip ReadWait entirely.
                        v.Fsm := Decide_s;
                    else
                        v.Fsm := ReadWait_s;
                    end if;
                end if;

            when ReadWait_s =>
                if Scrub_Inhibit = '1' then
                    v.Fsm := Idle_s;
                elsif r.WaitCnt = TotalReadLatency_g - 1 then
                    v.Fsm := Decide_s;
                else
                    v.WaitCnt := r.WaitCnt + 1;
                end if;

            when Decide_s =>
                if Scrub_Inhibit = '1' then
                    v.Fsm := Idle_s;
                else
                    -- Write back SEC only; DED is unreliable and not corrected.
                    if Ram_Rd_EccDed = '0' and Ram_Rd_EccSec = '1' then
                        IssueWrite_v := '1';
                    end if;
                    if r.ScrubAddr = Depth_g - 1 then
                        v.ScrubAddr := (others => '0');
                        v.PassDone  := '1';
                    else
                        v.ScrubAddr := r.ScrubAddr + 1;
                    end if;
                    v.Fsm := Idle_s;
                end if;

            -- coverage off
            when others => v.Fsm := Idle_s; -- unreachable code, safe recovery
            -- coverage on

        end case;

        -- Shift IssueRead_v through L stages. Decoupled from FSM state so Scrub_Rd_Valid
        -- still pulses on the codec return cycle when the FSM aborted mid-flight.
        v.ValidPipe(0) := IssueRead_v;

        for i in 1 to TotalReadLatency_g - 1 loop
            v.ValidPipe(i) := r.ValidPipe(i - 1);
        end loop;

        Scrub_RdReq     <= IssueRead_v;
        Scrub_WrReq     <= IssueWrite_v;
        Scrub_Addr      <= std_logic_vector(r.ScrubAddr);
        Scrub_Rd_Valid  <= r.ValidPipe(TotalReadLatency_g - 1);
        User_Rd_Valid   <= Ram_Rd_Valid and not r.ValidPipe(TotalReadLatency_g - 1);
        Scrub_Rd_EccSec <= Ram_Rd_EccSec;
        Scrub_Rd_EccDed <= Ram_Rd_EccDed;
        Scrub_PassDone  <= r.PassDone;

        r_next <= v;

    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;

            if Rst = '1' then
                r.Fsm       <= Idle_s;
                r.ScrubAddr <= (others => '0');
                r.WaitCnt   <= (others => '0');
                r.PassDone  <= '0';
                -- Reset so Scrub_Rd_Valid does not pulse on a random startup pattern.
                r.ValidPipe <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
