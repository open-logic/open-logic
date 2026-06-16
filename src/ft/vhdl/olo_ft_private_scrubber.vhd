---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Private opportunistic memory-scrubber core. Instantiated by the ECC-protected RAM wrappers
-- (`olo_ft_ram_sp_scrub`, `olo_ft_ram_sdp_scrub`); not intended for end-user instantiation.
--
-- It owns both the scrub FSM and the user/scrubber arbitration. A generic write- and read-channel
-- interface keeps it reusable across the single- and dual-port wrappers: the user side
-- (`User_Wr_*` / `User_Rd_*`) carries the wrapper's user requests and the RAM side
-- (`Ram_Wr_*` / `Ram_Rd_*`) carries the muxed requests to the wrapped RAM. The user always wins --
-- the scrubber drives a channel only on cycles where the user is idle on both channels -- so user
-- accesses are never stalled and user data is always authoritative.
--
-- An optional internal pacer (enabled by ScrubClkHz_g > 0.0) limits scrubbing to one pass every
-- ScrubPeriod_g seconds and asserts Scrub_Overrun if a pass cannot finish in time; by default
-- (ScrubClkHz_g = 0.0) the scrubber is free-running.
--
-- See the documentation for the cycle-level read/decide/writeback sequence, the abort behaviour and
-- the read-valid masking.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/ft/olo_ft_private_scrubber.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_ft_private_scrubber is
    generic (
        Depth_g            : positive range 2 to positive'high;
        Width_g            : positive;
        TotalReadLatency_g : positive;
        -- Single-port address collapse: when true the scrubber also drives Ram_Addr (the write/read
        -- addresses muxed onto one physical port) for olo_ft_ram_sp_scrub; dual-port wrappers leave
        -- it false and map Ram_Wr_Addr / Ram_Rd_Addr 1:1.
        SinglePortRam_g    : boolean := false;
        -- Optional internal pacer: run one scrub pass every ScrubPeriod_g seconds. Disabled
        -- (free-running) when ScrubClkHz_g = 0.0 (the default).
        ScrubClkHz_g       : real    := 0.0;
        ScrubPeriod_g      : real    := 0.0
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
        -- Collapsed single-port RAM address (driven only when SinglePortRam_g = true, tied '0'
        -- otherwise): the write address when a write is active, else the read address.
        Ram_Addr        : out   std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        -- Decoded RAM Read (response, for the scrub FSM and writeback payload)
        Ram_Rd_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Ram_Rd_EccSec   : in    std_logic;
        Ram_Rd_EccDed   : in    std_logic;
        -- RAM read-valid (pulses for every read, user or scrubber)
        Ram_Rd_Valid    : in    std_logic;
        -- User-facing read valid: Ram_Rd_Valid with scrubber-owned read cycles masked out
        User_Rd_Valid   : out   std_logic;
        -- Scrub Status (validated internally: Scrub_EccSec/Scrub_EccDed pulse for one cycle on a
        -- scrubber read return that observed SEC/DED -- directly countable, no qualification needed)
        Scrub_EccSec    : out   std_logic;
        Scrub_EccDed    : out   std_logic;
        Scrub_PassDone  : out   std_logic;
        -- Pacer overrun: pulses (and a sim warning fires) when a new scrub period starts before the
        -- previous pass finished. Tied '0' when the pacer is disabled.
        Scrub_Overrun   : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_ft_private_scrubber is

    constant AddrWidth_c : positive := log2ceil(Depth_g);

    type ScrubFsm_t is (Idle_s, ReadWait_s, Decide_s);

    type TwoProcess_r is record
        Fsm       : ScrubFsm_t;
        ScrubAddr : unsigned(AddrWidth_c - 1 downto 0);
        WaitCnt   : natural range 0 to TotalReadLatency_g;
        ValidPipe : std_logic_vector(TotalReadLatency_g - 1 downto 0);
        PassDone  : std_logic;
        -- Registered decoder response. Breaks the RAM-read -> decode -> re-encode -> RAM-write
        -- combinational loop: Decide_s consumes these registers instead of the live decoder output,
        -- so decode and re-encode land in separate clock cycles.
        EccSecReg : std_logic;
        EccDedReg : std_logic;
        WbData    : std_logic_vector(Width_g - 1 downto 0);
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

    -- Optional pacer (enabled when ScrubClkHz_g > 0.0): a 1 kHz base tick from olo_base_strobe_gen,
    -- divided by olo_base_strobe_div, produces one "start a pass" strobe every ScrubPeriod_g
    -- seconds (1 ms granularity). ScrubActive is the effective paced enable; it is tied '1' (always
    -- free-running) when the pacer is disabled.
    constant Paced_c    : boolean  := ScrubClkHz_g > 0.0;
    constant BaseHz_c   : real     := 1000.0;
    constant DivRatio_c : positive := integer(round(maximum(1.0, ScrubPeriod_g * BaseHz_c)));

    signal ScrubActive : std_logic;
    signal Overrun_i   : std_logic;

begin

    -- User wins on either channel; the external Scrub_Enable pauses the scrubber, and the optional
    -- pacer (ScrubActive) gates it to one pass per period. ScrubActive is tied '1' when not paced.
    Scrub_Inhibit <= User_Wr_Ena or User_Rd_Ena or not ScrubActive or not Scrub_Enable;

    -- Request muxes: the user request passes through whenever it is active, otherwise the
    -- scrubber's request fills the idle cycle. Scrub_RdReq / Scrub_WrReq are guaranteed '0'
    -- while Scrub_Inhibit = '1', so the user is never overridden. On a scrubber writeback the
    -- payload is the *registered* decoded read data (WbData), which the wrapper's encoder
    -- re-encodes into the RAM.
    Ram_Wr_Addr <= User_Wr_Addr when User_Wr_Ena = '1' else Scrub_Addr;
    Ram_Wr_Ena  <= User_Wr_Ena  or  Scrub_WrReq;
    Ram_Wr_Data <= User_Wr_Data when User_Wr_Ena = '1' else r.WbData;
    Ram_Rd_Addr <= User_Rd_Addr when User_Rd_Ena = '1' else Scrub_Addr;
    Ram_Rd_Ena  <= User_Rd_Ena  or  Scrub_RdReq;

    -- Single-port address collapse (moved here from olo_ft_ram_sp_scrub). With SinglePortRam_g the
    -- wrapper drives the RAM's one physical port from Ram_Addr: the write address when a write is
    -- active, otherwise the read address. The user always wins arbitration, so when a user enable is
    -- high the scrubber is inhibited and Scrub_Addr is not selected; on an idle cycle the scrubber's
    -- own read and writeback both target Scrub_Addr. Tied '0' for dual-port wrappers.
    g_sp_addr : if SinglePortRam_g generate
        Ram_Addr <= User_Wr_Addr when User_Wr_Ena = '1' else
                    User_Rd_Addr when User_Rd_Ena = '1' else
                    Scrub_Addr;
    end generate;

    g_dp_addr : if not SinglePortRam_g generate
        Ram_Addr <= (others => '0');
    end generate;

    -- *** Optional pacer + overrun watchdog ***
    -- Config sanity (static, checked at elaboration).
    assert (not Paced_c) or (ScrubPeriod_g > 0.0)
        report "olo_ft_private_scrubber: ScrubPeriod_g must be > 0.0 when the pacer is enabled (ScrubClkHz_g > 0.0)"
        severity failure;
    assert (not Paced_c) or (ScrubClkHz_g >= BaseHz_c)
        report "olo_ft_private_scrubber: ScrubClkHz_g must be >= 1000.0 when the pacer is enabled"
        severity failure;

    g_paced : if Paced_c generate
        signal BaseTick    : std_logic;
        signal PeriodPulse : std_logic;
    begin

        -- 1 kHz base tick, divided down to one "start a pass" strobe every ScrubPeriod_g seconds.
        i_strobe : entity work.olo_base_strobe_gen
            generic map (
                FreqClkHz_g    => ScrubClkHz_g,
                FreqStrobeHz_g => BaseHz_c
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                Out_Valid => BaseTick
            );

        i_div : entity work.olo_base_strobe_div
            generic map (
                MaxRatio_g => DivRatio_c
            )
            port map (
                Clk       => Clk,
                Rst       => Rst,
                In_Valid  => BaseTick,
                Out_Valid => PeriodPulse
            );

        -- ScrubActive arms on a period strobe (only while externally enabled) and disarms when a
        -- full pass completes -> exactly one pass per period. Scrub_Overrun pulses (and warns in
        -- simulation) if a strobe arrives while the previous pass is still in progress.
        p_pace : process (Clk) is
        begin
            if rising_edge(Clk) then
                Overrun_i <= '0';
                if r.PassDone = '1' then
                    ScrubActive <= '0';
                end if;
                if PeriodPulse = '1' then
                    if ScrubActive = '1' and r.PassDone = '0' then
                        Overrun_i <= '1';
                        report "olo_ft_private_scrubber: scrub pass did not complete within ScrubPeriod_g (overrun)"
                            severity warning;
                    end if;
                    if Scrub_Enable = '1' then
                        ScrubActive <= '1';
                    end if;
                end if;
                if Rst = '1' then
                    ScrubActive <= '0';
                    Overrun_i   <= '0';
                end if;
            end if;
        end process;

    end generate;

    g_free : if not Paced_c generate
        ScrubActive <= '1';
        Overrun_i   <= '0';
    end generate;

    Scrub_Overrun <= Overrun_i;

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

        -- Register the decoder response every cycle; Decide_s consumes the time-aligned copy.
        v.EccSecReg := Ram_Rd_EccSec;
        v.EccDedReg := Ram_Rd_EccDed;
        v.WbData    := Ram_Rd_Data;

        case r.Fsm is

            when Idle_s =>
                if Scrub_Inhibit = '0' then
                    IssueRead_v := '1';
                    -- WaitCnt counts ReadWait cycles starting at 1. ReadWait now spans through the
                    -- codec-return cycle (WaitCnt = L), so Decide_s runs one cycle later and
                    -- consumes the *registered* decoder outputs (EccSecReg/EccDedReg/WbData), which
                    -- are valid the cycle after the live decoder output.
                    v.WaitCnt := 1;
                    v.Fsm     := ReadWait_s;
                end if;

            when ReadWait_s =>
                if Scrub_Inhibit = '1' then
                    v.Fsm := Idle_s;
                elsif r.WaitCnt = TotalReadLatency_g then
                    v.Fsm := Decide_s;
                else
                    v.WaitCnt := r.WaitCnt + 1;
                end if;

            when Decide_s =>
                if Scrub_Inhibit = '1' then
                    v.Fsm := Idle_s;
                else
                    -- Write back SEC only; DED is unreliable and not corrected. Uses the registered
                    -- decoder flags so the decision is not in the decode->writeback critical path.
                    if r.EccDedReg = '0' and r.EccSecReg = '1' then
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

        Scrub_RdReq <= IssueRead_v;
        Scrub_WrReq <= IssueWrite_v;
        Scrub_Addr  <= std_logic_vector(r.ScrubAddr);
        -- Mask the scrubber's own read cycles out of the user-facing read valid.
        User_Rd_Valid <= Ram_Rd_Valid and not r.ValidPipe(TotalReadLatency_g - 1);
        -- Status: gate the codec flags with the scrub read-return pulse so they are clean,
        -- directly countable pulses (the consumer no longer needs a separate qualifier).
        Scrub_EccSec   <= Ram_Rd_EccSec and r.ValidPipe(TotalReadLatency_g - 1);
        Scrub_EccDed   <= Ram_Rd_EccDed and r.ValidPipe(TotalReadLatency_g - 1);
        Scrub_PassDone <= r.PassDone;

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
                r.PassDone  <= '0';
                -- WaitCnt is intentionally not reset: it is loaded in Idle_s before ReadWait_s ever
                -- reads it, so it needs no reset value (and keeps reset fanout minimal). ValidPipe is
                -- reset so Scrub_Rd_Valid does not pulse on a random startup pattern.
                r.ValidPipe <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
