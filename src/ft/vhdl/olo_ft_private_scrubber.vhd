---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Private opportunistic memory-scrubber core for the ECC-protected RAM wrappers
-- (olo_ft_ram_sp_scrub, olo_ft_ram_sdp_scrub). It owns the scrub FSM and the user/scrubber
-- arbitration; the user always wins, so user accesses are never stalled. Scrub reads fill idle
-- read-port cycles, writebacks wait for a free write slot, and only a user write to the address
-- currently being scrubbed aborts the operation in flight. Not intended for end-user
-- instantiation.
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
        -- Single-port address collapse: drive Ram_Addr for olo_ft_ram_sp_scrub; false for dual-port.
        SinglePortRam_g    : boolean := false;
        -- Optional internal pacer: one scrub pass every ScrubPeriod_g seconds. Free-running when
        -- ScrubPeriod_g = 0.0 (the default). ScrubClkHz_g must be the actual Clk frequency.
        ScrubClkHz_g       : real    := 100000000.0;
        ScrubPeriod_g      : real    := 0.0
    );
    port (
        -- Clock and Reset
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Scrubber Enable ('0' suspends scrubbing and the pacer watchdog; the address is preserved)
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
        -- Collapsed single-port RAM address (driven only when SinglePortRam_g = true, else tied '0').
        Ram_Addr        : out   std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        -- Decoded RAM Read (response, for the scrub FSM and writeback payload)
        Ram_Rd_Data     : in    std_logic_vector(Width_g - 1 downto 0);
        Ram_Rd_EccSec   : in    std_logic;
        Ram_Rd_EccDed   : in    std_logic;
        -- RAM read-valid (pulses for every read, user or scrubber)
        Ram_Rd_Valid    : in    std_logic;
        -- User-facing read valid: Ram_Rd_Valid with scrubber-owned read cycles masked out
        User_Rd_Valid   : out   std_logic;
        -- Scrub Status
        Scrub_EccSec    : out   std_logic;
        Scrub_EccDed    : out   std_logic;
        Scrub_PassDone  : out   std_logic;
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
        Fsm         : ScrubFsm_t;
        ScrubAddr   : unsigned(AddrWidth_c - 1 downto 0);
        WaitCnt     : natural range 0 to TotalReadLatency_g;
        ValidPipe   : std_logic_vector(TotalReadLatency_g - 1 downto 0);
        PassDone    : std_logic;
        -- Pacer state: ScrubActive arms one pass per period strobe (constant '1' when
        -- free-running), Overrun pulses when a period strobe finds the pass still unfinished.
        ScrubActive : std_logic;
        Overrun     : std_logic;
        -- Decoder response registered on the scrub read-return cycle; breaks the
        -- read -> decode -> re-encode -> write combinational loop and holds the writeback payload
        -- stable while Decide_s waits for a free write slot (user read responses keep flowing
        -- through the shared decode path meanwhile).
        EccSecReg   : std_logic;
        EccDedReg   : std_logic;
        WbData      : std_logic_vector(Width_g - 1 downto 0);
    end record;

    signal r, r_next : TwoProcess_r;

    -- Scrubber-internal requests (FSM -> muxes). Scrub_RdReq/Scrub_WrReq are mutually exclusive,
    -- so a single Scrub_Addr feeds both muxes.
    signal Scrub_RdReq : std_logic;
    signal Scrub_WrReq : std_logic;
    signal Scrub_Addr  : std_logic_vector(AddrWidth_c - 1 downto 0);

    -- Optional pacer (ScrubPeriod_g > 0.0): one "start a pass" strobe every ScrubPeriod_g seconds.
    constant Paced_c    : boolean  := ScrubPeriod_g > 0.0;
    constant BaseHz_c   : real     := 1000.0;
    constant DivRatio_c : positive := integer(round(maximum(1.0, ScrubPeriod_g * BaseHz_c)));

    signal PeriodPulse : std_logic;

begin

    -- Request muxes: the user request wins, otherwise the scrubber fills the idle cycle. The
    -- writeback payload is the registered decoded read data (WbData).
    Ram_Wr_Addr <= User_Wr_Addr when User_Wr_Ena = '1' else Scrub_Addr;
    Ram_Wr_Ena  <= User_Wr_Ena  or  Scrub_WrReq;
    Ram_Wr_Data <= User_Wr_Data when User_Wr_Ena = '1' else r.WbData;
    Ram_Rd_Addr <= User_Rd_Addr when User_Rd_Ena = '1' else Scrub_Addr;
    Ram_Rd_Ena  <= User_Rd_Ena  or  Scrub_RdReq;

    -- Single-port address collapse: drive the one physical port from Ram_Addr (write address wins,
    -- else read address, else scrub address). Tied '0' for dual-port wrappers.
    g_sp_addr : if SinglePortRam_g generate
        Ram_Addr <= User_Wr_Addr when User_Wr_Ena = '1' else
                    User_Rd_Addr when User_Rd_Ena = '1' else
                    Scrub_Addr;
    end generate;

    g_dp_addr : if not SinglePortRam_g generate
        Ram_Addr <= (others => '0');
    end generate;

    -- *** Optional pacer period strobe ***
    -- Config sanity (static, checked at elaboration). The period resolution is 1 ms.
    assert (not Paced_c) or (ScrubClkHz_g >= BaseHz_c)
        report "olo_ft_private_scrubber: ScrubClkHz_g must be >= 1000.0 when the pacer is enabled (ScrubPeriod_g > 0.0)"
        severity failure;
    assert (not Paced_c) or (ScrubPeriod_g >= 0.001)
        report "olo_ft_private_scrubber: ScrubPeriod_g must be >= 0.001 s when the pacer is enabled (1 ms resolution)"
        severity failure;

    -- The period strobe is derived in two stages: olo_base_strobe_gen divides Clk down to a 1 kHz
    -- base tick and olo_base_strobe_div divides that tick down to one strobe per ScrubPeriod_g.
    -- A single olo_base_strobe_gen stage cannot cover realistic scrub periods: its ratio is
    -- limited to FreqClkHz_g / FreqStrobeHz_g <= 214'748'000, which at 100 MHz caps the period at
    -- about 2.1 s. The cascade supports periods up to 2**31 - 1 ms with 1 ms resolution.
    g_paced : if Paced_c generate
        signal BaseTick : std_logic;
    begin

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

    end generate;

    g_free : if not Paced_c generate
        PeriodPulse <= '0';
    end generate;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v                : TwoProcess_r;
        variable IssueRead_v      : std_logic;
        variable IssueWrite_v     : std_logic;
        variable Collision_v      : std_logic;
        variable PortBusy_v       : std_logic;
        variable NeedsWriteback_v : boolean;
        variable WrSlotFree_v     : boolean;
    begin
        -- Hold variables stable
        v := r;

        IssueRead_v  := '0';
        IssueWrite_v := '0';
        v.PassDone   := '0';
        v.Overrun    := '0';

        -- Only a user write to the address currently being scrubbed collides with the scrub
        -- operation (read-during-write hazard on issue, stale-writeback hazard in flight). All
        -- other user traffic merely occupies ports.
        Collision_v := '0';
        if User_Wr_Ena = '1' and unsigned(User_Wr_Addr) = r.ScrubAddr then
            Collision_v := '1';
        end if;

        -- On a single-port RAM any user access occupies the one physical port.
        if SinglePortRam_g then
            PortBusy_v := User_Wr_Ena or User_Rd_Ena;
        else
            PortBusy_v := '0';
        end if;

        -- Pacer: arm one pass per period strobe; disarm when the pass completes. A strobe that
        -- finds the pass still running flags an overrun. Suspension (Scrub_Enable = '0') disarms
        -- the pacer including its overrun watchdog.
        if Paced_c then
            if r.PassDone = '1' then
                v.ScrubActive := '0';
            end if;
            if Scrub_Enable = '0' then
                v.ScrubActive := '0';
            end if;
            if PeriodPulse = '1' and Scrub_Enable = '1' then
                if r.ScrubActive = '1' and r.PassDone = '0' then
                    v.Overrun := '1';
                end if;
                v.ScrubActive := '1';
            end if;
        else
            v.ScrubActive := '1';
        end if;

        -- Capture the decoder response on the scrub read-return cycle only; Decide_s consumes the
        -- time-aligned copy one cycle later and it stays stable while waiting for a write slot.
        if r.ValidPipe(TotalReadLatency_g - 1) = '1' then
            v.EccSecReg := Ram_Rd_EccSec;
            v.EccDedReg := Ram_Rd_EccDed;
            v.WbData    := Ram_Rd_Data;
        end if;

        NeedsWriteback_v := (r.EccSecReg = '1') and (r.EccDedReg = '0');
        WrSlotFree_v     := (User_Wr_Ena = '0') and (PortBusy_v = '0');

        case r.Fsm is

            when Idle_s =>
                -- Fill any idle read-port cycle, unless the pass is not armed or the user writes
                -- the scrub address in this very cycle. The check is on v.ScrubActive (computed
                -- above) so a completed pass disarms in the same beat and no extra operation
                -- leaks out at the pass boundary.
                if Scrub_Enable = '1' and v.ScrubActive = '1' and User_Rd_Ena = '0' and
                   PortBusy_v = '0' and Collision_v = '0' then
                    IssueRead_v := '1';
                    -- Start the read-latency count; Decide_s (one cycle after WaitCnt = L) consumes
                    -- the registered decoder outputs.
                    v.WaitCnt := 1;
                    v.Fsm     := ReadWait_s;
                end if;

            when ReadWait_s =>
                -- User reads and user writes to other addresses do not disturb the read in flight.
                if Collision_v = '1' or Scrub_Enable = '0' then
                    v.Fsm := Idle_s;
                elsif r.WaitCnt = TotalReadLatency_g then
                    v.Fsm := Decide_s;
                else
                    v.WaitCnt := r.WaitCnt + 1;
                end if;

            when Decide_s =>
                if Collision_v = '1' or Scrub_Enable = '0' then
                    -- Abort without advancing: the same address is retried.
                    v.Fsm := Idle_s;
                elsif (not NeedsWriteback_v) or WrSlotFree_v then
                    -- Write back SEC only (DED data is unreliable), using the registered flags.
                    -- Clean and DED words advance immediately; a pending SEC writeback executes
                    -- in the first free write slot (the state waits here for one).
                    if NeedsWriteback_v then
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

        -- Shift IssueRead_v through L stages, decoupled from FSM state so the scrub read-return
        -- pulse still lands on the codec-return cycle even when the FSM aborted mid-flight.
        v.ValidPipe(0) := IssueRead_v;

        for i in 1 to TotalReadLatency_g - 1 loop
            v.ValidPipe(i) := r.ValidPipe(i - 1);
        end loop;

        Scrub_RdReq <= IssueRead_v;
        Scrub_WrReq <= IssueWrite_v;
        Scrub_Addr  <= std_logic_vector(r.ScrubAddr);
        -- Mask the scrubber's own read cycles out of the user-facing read valid.
        User_Rd_Valid <= Ram_Rd_Valid and not r.ValidPipe(TotalReadLatency_g - 1);
        -- Status: gate the codec flags with the scrub read-return pulse to get clean countable pulses.
        Scrub_EccSec   <= Ram_Rd_EccSec and r.ValidPipe(TotalReadLatency_g - 1);
        Scrub_EccDed   <= Ram_Rd_EccDed and r.ValidPipe(TotalReadLatency_g - 1);
        Scrub_PassDone <= r.PassDone;
        Scrub_Overrun  <= r.Overrun;

        r_next <= v;

    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;

            -- synthesis translate_off
            assert r_next.Overrun = '0'
                report "olo_ft_private_scrubber: scrub pass did not complete within ScrubPeriod_g (overrun)"
                severity warning;
            -- synthesis translate_on

            if Rst = '1' then
                r.Fsm         <= Idle_s;
                r.ScrubAddr   <= (others => '0');
                r.PassDone    <= '0';
                r.ScrubActive <= '0';
                r.Overrun     <= '0';
                -- WaitCnt is intentionally not reset (loaded in Idle_s before ReadWait_s reads it).
                -- ValidPipe is reset so no spurious read-return pulse occurs at startup.
                r.ValidPipe   <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
